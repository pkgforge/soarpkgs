<div align="center">

[discord-shield]: https://img.shields.io/discord/1313385177703256064?logo=%235865F2&label=Discord
[discord-url]: https://discord.gg/djJUs48Zbu
[stars-shield]: https://img.shields.io/github/stars/pkgforge/soarpkgs.svg
[stars-url]: https://github.com/pkgforge/soarpkgs/stargazers
[issues-shield]: https://img.shields.io/github/issues/pkgforge/soarpkgs.svg
[issues-url]: https://github.com/pkgforge/soarpkgs/issues
[license-shield]: https://img.shields.io/github/license/pkgforge/soarpkgs.svg
[license-url]: https://github.com/pkgforge/soarpkgs/blob/main/LICENSE
[doc-shield]: https://img.shields.io/badge/docs.pkgforge.dev-blue
[doc-url]: https://docs.pkgforge.dev

[![Discord][discord-shield]][discord-url]
[![Documentation][doc-shield]][doc-url]
[![Issues][issues-shield]][issues-url]
[![License: MIT][license-shield]][license-url]
[![Stars][stars-shield]][stars-url]
</div>

<p align="center">
    <b><strong>soarpkgs - Package Repository</strong></b>
    <br>Declarative, hash-pinned package definitions for Soar
    <br>
</p>

---

## Overview

This repository hosts declarative package definitions for [Soar](https://github.com/pkgforge/soar).

Every package pins its upstream artifact together with that artifact's hash, in
git. Nothing here is executed: a client resolves a package by parsing alone, so
the download can be verified against a hash that was reviewed in a commit
rather than measured after the fact.

See [`docs/FORMAT.md`](docs/FORMAT.md) for the format and its
rationale.

```bash
.
└── packages
    └── <name>
        ├── pkg.toml              --> identity, metadata, update policy
        └── <name>-<version>.toml --> pinned URL, hash and size per host
```

> [!NOTE]
> We recommend cloning with [`--filter=blob:none`](https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/) for local development<br>
> Package Listing & Searching: https://soarpkgs.qaidvoid.dev

---

## Search for packages

Visit: https://soarpkgs.qaidvoid.dev

---

## Documentation

- [Port format](docs/FORMAT.md)
- [Contribution Guidelines](https://docs.pkgforge.dev/repositories/soarpkgs/contribution)
- [Request a Package](https://docs.pkgforge.dev/repositories/soarpkgs/package-request)
- [FAQs](https://docs.pkgforge.dev/repositories/soarpkgs/faq)

---

## License

MIT License - see [LICENSE](LICENSE) for details
