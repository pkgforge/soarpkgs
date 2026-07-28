# Package format

Packages are declared in TOML. Nothing in this tree executes: a client
resolves a package by parsing it, and verifies every download against a hash
recorded here.

```
packages/<name>/
  pkg.toml                 identity, update policy, how to find the artifact
  <name>-<version>.toml    the resolved URL, its hashes, and any side files
```

A package may hold several version files; each becomes its own entry in the
generated index, so a specific version can be installed.

## pkg.toml

```toml
[pkg]
name        = "gh"
type        = "static"            # static | appimage
description = "GitHub CLI tool"
homepage    = ["https://cli.github.com"]
license     = ["MIT"]
maintainer  = ["Someone <you@example.com>"]
category    = ["ConsoleOnly", "Development"]
repology    = ["github-cli"]
provides    = ["gh"]

[host]
supported = ["x86_64-linux", "aarch64-linux"]

[arch]                            # host arch -> what upstream calls it
x86_64  = "amd64"
aarch64 = "arm64"

[update]                          # how to find the current version
strategy     = "github-releases"
repo         = "cli/cli"
strip-prefix = "v"

[source]                          # how to find the artifact in that release
url = "https://github.com/cli/cli/releases/download/v${version}/gh_${version}_linux_${arch}.tar.gz"

[source.install]                  # where things live inside the archive
"gh_${version}_linux_${arch}/bin/gh"  = "gh"
"gh_${version}_linux_${arch}/LICENSE" = "LICENSE"
```

Required: `name`, `description`, `[host]`, `[update]`, `[source]`. The
upstream repository is taken from `[update].repo` and the package identifier
from `name`.

The rest are for exceptions:

| field | default | state it when |
|---|---|---|
| `family` | `name` | the directory name differs from the package name |
| `channel` | `stable` | the package tracks `unstable` or `nightly` |
| `portable` | `true` | it needs something from the host, with `portable-reason` |
| `src` | derived | upstream is not the repository in `[update]` |
| `note` | none | there is something a user genuinely needs told |
| `disabled` | `false` | it should not be installable, with `disabled-reason` |

### `[update]` versus `[source]`

`[update]` answers *which version is current*; `[source]` answers *which file
is the artifact*. Both are read only by `sbuild resolve`. A client never sees
either, because resolution has already happened by the time an index is built.

Strategies: `github-releases`, `github-tags`, `gitlab-tags`, `html-regex`.
Use `tag-prefix` when one repository publishes releases for several packages.

`[source]` selects the artifact either by templated URL, or by globbing the
assets of a release:

```toml
[source]
github = "pkgforge-dev/Ruffle-AppImage"
glob   = "*${arch}*.appimage"
```

`${version}` and `${arch}` are the only substitutions; `${arch}` passes
through `[arch]` first. There are no expressions. Anything that cannot be
expressed this way goes in a per-host table:

```toml
[source.url]
x86_64-linux  = "https://github.com/Schniz/fnm/releases/download/v${version}/fnm-linux.zip"
aarch64-linux = "https://github.com/Schniz/fnm/releases/download/v${version}/fnm-arm64.zip"
```

## The version file

Written by `sbuild resolve` and `sbuild hashfill`. Everything here is
literal, and this is what a client acts on.

```toml
version = "2.96.0"

[url]
x86_64-linux  = "https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_linux_amd64.tar.gz"

[blake3]
x86_64-linux  = "..."             # what soar verifies against

[sha256]
x86_64-linux  = "..."             # what a forge API reports, so it can be cross-checked

[size]
x86_64-linux  = 14652560

[[extra]]                         # a side file the artifact does not carry
url    = "https://raw.githubusercontent.com/cli/cli/master/LICENSE"
to     = "LICENSE"
blake3 = "..."
sha256 = "..."
```

Side files are pinned per version: most licence URLs point at a branch, so
their content can change without a release, and a change shows up as a diff on
the next bump.

Any `pkg.toml` field may be overridden here; lists replace rather than merge.

## Licences

A licence is shipped when the project has one to ship.

* If the archive contains it, `[source.install]` takes it out.
* If not, `[[extra]]` fetches it, pinned like anything else.
* For the GPL family the text is verbatim by requirement, so
  `license = "GPL-3.0"` uses the shared copy in `licenses/`. This does **not**
  apply to MIT or BSD, whose text carries a per-project copyright line.
* Proprietary software usually has no licence file at all, only terms on a web
  page. That belongs in `note` as a link, not fetched and saved as `LICENSE`.

## Verification

```
hash recorded in this tree
  -> signed index          minisign, public key in keys/
  -> artifact checked against that hash
```

Signature and hash are checked independently, so a validly signed index
carrying a wrong hash still fails at install. Anyone can verify a package
without trusting this repository: download the pinned URL, hash it, compare.

Packages that cannot be pinned from an upstream release are built in
[pkgforge/builds](https://github.com/pkgforge/builds), which publishes releases
this tree pins like any other upstream.

## Tooling

```sh
sbuild validate                  # every pinned URL has a hash; CI gate
sbuild new <name> <owner/repo>   # scaffold a package
sbuild resolve . [package ...]   # pin current versions
sbuild hashfill                  # hash what the forge could not vouch for
sbuild audit . [package ...]     # check install paths against real archives
sbuild meta --arch <host> --output metadata.json
```

`validate` and `meta` need no network. `audit` downloads each archive and
checks every install path resolves inside it, which static checking cannot do.
