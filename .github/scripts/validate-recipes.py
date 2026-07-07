#!/usr/bin/env python3
"""Validate `repology`, `build_asset` and `homepage` fields of changed recipes.

Usage: validate-recipes.py <file-with-list-of-recipe-paths>

Hard failures (exit 1):
  * a `repology:` project name that does not exist on repology.org
  * a `build_asset:` license `url:` that returns 404/410 (definitely missing)

Warnings only (never fail the build):
  * a `homepage:` URL that is not reachable
  * any URL that could not be verified (401/403/406 bot blocks, 429 rate
    limits, 5xx, timeouts, redirect loops). Hosts like SourceForge, Codeberg
    and gitlab.gnome.org refuse CI-runner IPs, so a non-404 response is treated
    as "unknown", not "broken".

Recipes without a `repology:` field are skipped for that check - omitting it is
the correct choice when the upstream is not packaged anywhere on repology.
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UA = "soarpkgs-ci/1.0 (+https://github.com/pkgforge/soarpkgs)"
REPOLOGY_API = "https://repology.org/api/v1/project/"
TIMEOUT = 25
RETRIES = 2


def gha(kind, message, file=None):
    """Emit a GitHub Actions annotation."""
    loc = f" file={file}" if file else ""
    # Collapse newlines so the annotation stays on one line.
    message = message.replace("\n", " ")
    print(f"::{kind}{loc}::{message}")


# --- recipe parsing (line based, no external deps) -------------------------

def _list_block(text, key):
    """Return the quoted string items of a top-level block list `key:`."""
    items = []
    capturing = False
    for line in text.splitlines():
        if re.match(rf"^{re.escape(key)}:\s*$", line):
            capturing = True
            continue
        if capturing:
            if re.match(r"^[A-Za-z_][\w]*:", line):  # next top-level key
                break
            m = re.match(r'^\s+-\s+"([^"]*)"\s*$', line)
            if not m:
                m = re.match(r"^\s+-\s+'([^']*)'\s*$", line)
            if not m:
                m = re.match(r"^\s+-\s+(\S+)\s*$", line)
            if m:
                items.append(m.group(1))
    return items


def _build_asset_urls(text):
    """Return the `url:` values inside the top-level build_asset block."""
    urls = []
    capturing = False
    for line in text.splitlines():
        if re.match(r"^build_asset:\s*$", line):
            capturing = True
            continue
        if capturing:
            if re.match(r"^[A-Za-z_][\w]*:", line):
                break
            m = re.search(r'url:\s+"([^"]*)"', line) or re.search(r"url:\s+'([^']*)'", line)
            if m:
                urls.append(m.group(1))
    return urls


def parse_recipe(path):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    return {
        "repology": [x for x in _list_block(text, "repology") if x and x.lower() != "null"],
        "homepage": [x for x in _list_block(text, "homepage") if x],
        "build_asset": [x for x in _build_asset_urls(text) if x and x.lower() != "null"],
    }


# --- network checks --------------------------------------------------------

def _get(url, headers, method="GET"):
    req = urllib.request.Request(url, headers=headers, method=method)
    return urllib.request.urlopen(req, timeout=TIMEOUT)


def repology_exists(name):
    """(ok, note). ok is None when the check could not be completed (infra)."""
    url = REPOLOGY_API + urllib.parse.quote(name, safe="")
    for attempt in range(RETRIES + 1):
        try:
            with _get(url, {"User-Agent": UA, "Accept": "application/json"}) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if isinstance(data, list) and len(data) > 0:
                    return True, f"{len(data)} repo entr{'y' if len(data) == 1 else 'ies'}"
                return False, "no matching project on repology.org"
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < RETRIES:
                time.sleep(3 * (attempt + 1))
                continue
            return None, f"repology API HTTP {e.code}"
        except Exception as e:  # noqa: BLE001 - network flakiness
            if attempt < RETRIES:
                time.sleep(2 * (attempt + 1))
                continue
            return None, f"repology API error: {e}"
    return None, "repology API unavailable"


def url_reachable(url):
    """(ok, note). ok is None when the check could not be completed (infra)."""
    if not re.match(r"^https?://", url):
        return None, "not an http(s) url"
    headers = {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
        "Accept": "*/*",
    }
    last = ""
    for attempt in range(RETRIES + 1):
        try:
            with _get(url, headers) as resp:
                code = resp.getcode()
                if code and code < 400:
                    return True, f"HTTP {code}"
                last = f"HTTP {code}"
                break
        except urllib.error.HTTPError as e:
            # Only 404/410 are a definitive "this file is not there" - a real
            # failure. Everything else (401/403/406 bot blocks, 429 rate limits,
            # 5xx) means we could not verify from a CI runner IP, so warn only.
            if e.code in (404, 410):
                return False, f"HTTP {e.code} (not found)"
            if e.code in (429, 500, 502, 503, 504) and attempt < RETRIES:
                time.sleep(2 * (attempt + 1))
                continue
            return None, f"HTTP {e.code} (could not verify)"
        except Exception as e:  # noqa: BLE001 - timeouts, redirect loops, DNS...
            last = str(e)
            if attempt < RETRIES:
                time.sleep(2 * (attempt + 1))
                continue
    # Timeouts, redirect loops, connection resets: cannot confirm - warn only.
    return None, f"{last or 'unreachable'} (could not verify)"


def main():
    if len(sys.argv) < 2:
        print("usage: validate-recipes.py <list-file>", file=sys.stderr)
        return 2

    with open(sys.argv[1], encoding="utf-8") as fh:
        recipes = [ln.strip() for ln in fh if ln.strip()]

    hard_failures = 0
    warnings = 0
    summary = ["## Recipe validation", ""]

    for path in recipes:
        if not os.path.isfile(path):
            continue
        fields = parse_recipe(path)
        rows = []

        for name in fields["repology"]:
            ok, note = repology_exists(name)
            if ok is False:
                hard_failures += 1
                gha("error", f"repology '{name}' is invalid ({note}). "
                    f"Fix the name or drop the repology field.", file=path)
                rows.append(f"| repology | `{name}` | ❌ {note} |")
            elif ok is None:
                warnings += 1
                gha("warning", f"could not verify repology '{name}' ({note})", file=path)
                rows.append(f"| repology | `{name}` | ⚠️ {note} |")
            else:
                rows.append(f"| repology | `{name}` | ✅ {note} |")
            time.sleep(1)  # be polite to the repology API

        for url in fields["build_asset"]:
            ok, note = url_reachable(url)
            if ok is False:
                hard_failures += 1
                gha("error", f"build_asset url unreachable ({note}): {url}", file=path)
                rows.append(f"| build_asset | {url} | ❌ {note} |")
            elif ok is None:
                warnings += 1
                gha("warning", f"could not verify build_asset url ({note}): {url}", file=path)
                rows.append(f"| build_asset | {url} | ⚠️ {note} |")
            else:
                rows.append(f"| build_asset | {url} | ✅ {note} |")

        for url in fields["homepage"]:
            ok, note = url_reachable(url)
            if ok is False or ok is None:
                warnings += 1
                gha("warning", f"homepage url not reachable ({note}): {url}", file=path)
                rows.append(f"| homepage | {url} | ⚠️ {note} |")
            else:
                rows.append(f"| homepage | {url} | ✅ {note} |")

        if rows:
            summary.append(f"### `{path}`")
            summary.append("")
            summary.append("| field | value | result |")
            summary.append("| --- | --- | --- |")
            summary.extend(rows)
            summary.append("")

    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as fh:
            fh.write("\n".join(summary) + "\n")
            if hard_failures:
                fh.write(f"\n**{hard_failures} hard failure(s), {warnings} warning(s).**\n")
            else:
                fh.write(f"\n**All good — {warnings} warning(s).**\n")

    if hard_failures:
        print(f"\n{hard_failures} hard failure(s), {warnings} warning(s).")
        return 1
    print(f"\nOK — {warnings} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
