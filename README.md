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
    <b><strong>soarpkgs - SBUILD Recipe Repository</strong></b>
    <br>Hosts SBUILD recipes used to build packages for Soar
    <br>
</p>

---

## Overview

This repository hosts [`.SBUILD` recipes](https://docs.pkgforge.dev/sbuild/introduction) used to build packages for [Soar](https://github.com/pkgforge/soar).

```bash
.
├── binaries    --> SBUILDs for building static binaries
├── packages    --> SBUILDs for building full packages
└── templates   --> SBUILD examples and templates
```

> [!NOTE]
> We recommend cloning with [`--filter=blob:none`](https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/) for local development<br>
> Package Listing & Searching: https://pkgs.pkgforge.dev

---

## About soarpkgs

soarpkgs is a community-driven repository of `.SBUILD` recipes that define how to build software packages. Each recipe contains:

- **Package metadata** - Name, description, license, dependencies
- **Build instructions** - Scripts to download, compile, and package software
- **Version tracking** - Automatic version detection and upstream comparison

Recipes are validated by [sbuilder](https://github.com/pkgforge/sbuilder) and built by CI workflows. The resulting packages are published to GHCR, with metadata available for:
- **bincache** - Static binaries
- **pkgcache** - Portable packages

---

## Search for packages

Visit: https://pkgs.pkgforge.dev

---

## Documentation

- [SBUILD Introduction](https://docs.pkgforge.dev/sbuild/introduction)
- [How to Write SBUILD Recipes](https://docs.pkgforge.dev/sbuild/instructions)
- [Contribution Guidelines](https://docs.pkgforge.dev/repositories/soarpkgs/contribution)
- [Request a Package](https://docs.pkgforge.dev/repositories/soarpkgs/package-request)
- [FAQs](https://docs.pkgforge.dev/repositories/soarpkgs/faq)

---

## Community

<a href="https://discord.gg/djJUs48Zbu"><img src="https://github.com/user-attachments/assets/5a336d72-6342-4ca5-87a4-aa8a35277e2f" width="18" height="18"><code>PkgForge Discord</code></a> ➼ [`https://discord.gg/djJUs48Zbu`](https://discord.gg/djJUs48Zbu)

---

## License

MIT License - see [LICENSE](LICENSE) for details
