- #### Intro
> - [`Soarpkgs`](https://github.com/pkgforge/soarpkgs) is the Official Community Repository for [`Building`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#write-an-sbuild-recipe), [`Installing`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#buildinstallrun-an-sbuild-recipe) & [`Running`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#buildinstallrun-an-sbuild-recipe) `Communtiy Submitted`, `Local` or [`UnCached`](https://github.com/pkgforge/pkgcache) Packages with [Soar](https://github.com/pkgforge/soar).
> - Think of it as [Alpine's Community](https://wiki.alpinelinux.org/wiki/Repositories) or better [Arch's AUR](https://wiki.archlinux.org/title/Arch_User_Repository).
> - Packages are first added here before being added to [`bincache`](https://github.com/Azathothas/Toolpacks)/[`pkgcache`](https://github.com/pkgforge/pkgcache) based on [certain criteria](https://github.com/pkgforge/soarpkgs/blob/main/Docs/README.md#criteria-for-addition-to-bincachepkgcache) with some [major differences](https://github.com/pkgforge/soarpkgs/blob/main/Docs/README.md#differences-from-bincachepkgcache).
>
---

- #### Differences from [`bincache`](https://github.com/Azathothas/Toolpacks)/[`pkgcache`](https://github.com/pkgforge/pkgcache)
> | [`SoarPkgs`](https://github.com/pkgforge/soarpkgs) | [`BinCache`](https://github.com/Azathothas/Toolpacks)/[`PkgCache`](https://github.com/pkgforge/pkgcache) |
> |----------|----------|
> | No PreBuilt Cache, All Packages are Built & Installed Locally | `PreBuilt` [Binary Cache](https://huggingface.co/datasets/pkgforge/bincache)/[Package Cache](https://huggingface.co/datasets/pkgforge/pkgcache), All Packages are Downloaded & Installed Directly from Remote Sources
> | Local Resources like CPU, MEM, DISK, Bandwidth etc Are Used | Only Storage (Disk) & Bandwidth is Used |
> | `.SBUILD` runs Locally on User's System, so Security depends on each package & their Maintainers | All Scripts are run on Secure Isolated Containers & Transparent Build Logs are provided, but Security still depends on each Package |
> | Decentralized | Centralized & Managed by [PkgForge's Core Team](https://github.com/orgs/pkgforge/people) |
> | Contribution GuideLine is Simple & Forgiving | Each Contribution goes through Rigorous Review before being Merged |
---

- #### Criteria for Addition to [`bincache`](https://github.com/Azathothas/Toolpacks)/[`pkgcache`](https://github.com/pkgforge/pkgcache)
> ℹ️ Exceptions Apply, Discussion is encouraged
> - If on [GitHub](https://github.com/)/[GitLab](https://gitlab.com) etc, must have at least `100 Stars`
> - Must have an entry on [RepoLogy](https://repology.org/projects/)
> - Must have received an `update` within the `last 6 Month` or at the very extent, within the `last 12 Month`.
---
