#!/usr/bin/env python3
"""Check the pinned artifacts of a pull request against the forge.

Two independent checks, because they catch different things:

* The pinned sha256 must equal the digest the forge reports for that asset.
  This catches a hash that was never true of the artifact it sits beside.
* An artifact already released under a version must not change. A hash that
  moves while its version stands still means upstream replaced the file in
  place, which no amount of re-hashing would reveal.

Neither is provenance in the SLSA sense. That needs the publisher to sign
what it builds, and these releases carry no attestations today.
"""

import json
import os
import re
import subprocess
import sys
import urllib.parse

ASSET = re.compile(
    r"https://github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/(.+)$"
)
HASHED = re.compile(r'^(\S+)\s*=\s*"([0-9a-f]{64})"', re.M)
PINNED = re.compile(r'^(\S+)\s*=\s*"(https://\S+)"', re.M)


def gh(*args):
    out = subprocess.run(
        ["gh", *args], capture_output=True, text=True, timeout=60
    )
    return out.stdout.strip() if out.returncode == 0 else ""


def table(text, name):
    """The body of a [name] table, empty when the file has no such table."""
    found = re.search(rf"^\[{name}\]$(.*?)(?=^\[|\Z)", text, re.S | re.M)
    return dict(
        (HASHED if name != "url" else PINNED).findall(found.group(1))
    ) if found else {}


def version_of(text):
    found = re.search(r'^version\s*=\s*"([^"]+)"', text, re.M)
    return found.group(1) if found else None


def forge_digest(url):
    """What the forge says the asset is, or None if it cannot say."""
    matched = ASSET.match(url)
    if not matched:
        return None
    repo, tag, asset = matched.groups()
    digest = gh(
        "api",
        f"repos/{repo}/releases/tags/{urllib.parse.unquote(tag)}",
        "--jq",
        f'.assets[] | select(.name=="{urllib.parse.unquote(asset)}") | .digest',
    )
    return digest.removeprefix("sha256:") if digest else None


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    pr = os.environ["PR"]
    base = os.environ["BASE_SHA"]

    files = [
        f
        for f in gh(
            "api", f"repos/{repo}/pulls/{pr}/files", "--paginate", "--jq", ".[].filename"
        ).splitlines()
        if f.startswith("packages/") and not f.endswith("/pkg.toml")
    ]
    if not files:
        print("No pinned artifacts changed.")
        return 0

    problems = []
    for path in files:
        if not os.path.exists(path):
            continue
        text = open(path).read()
        urls, shas = table(text, "url"), table(text, "sha256")

        # Same version, different artifact: upstream swapped the file.
        previous = gh("api", f"repos/{repo}/contents/{path}?ref={base}",
                      "--jq", ".content")
        if previous:
            import base64

            was = base64.b64decode(previous).decode()
            if version_of(was) == version_of(text):
                for host, old in table(was, "sha256").items():
                    new = shas.get(host)
                    if new and new != old:
                        problems.append(
                            f"{path} [{host}]: version {version_of(text)} is "
                            f"unchanged but its hash moved\n"
                            f"    was {old}\n    now {new}"
                        )

        # The pin must match what the forge serves under that URL.
        for host, url in urls.items():
            pinned = shas.get(host)
            if not pinned:
                continue
            reported = forge_digest(url)
            if reported is None:
                print(f"  no digest available: {path} [{host}]")
            elif reported != pinned:
                problems.append(
                    f"{path} [{host}]: pinned hash is not what the forge "
                    f"reports\n    forge  {reported}\n    pinned {pinned}"
                )
            else:
                print(f"  ok: {path} [{host}]")

    if problems:
        print("\nPinned artifacts did not check out:\n")
        for p in problems:
            print(f"  {p}\n")
        return 1
    print(f"\n{len(files)} changed version files check out against the forge.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
