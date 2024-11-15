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

- #### Contribution Guidelines
> ℹ️ There's no strict rules, exercise common sense & Keep the following in Mind:
> - Read the [SPEC](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md), the [Build Guide](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md) & [Some Examples](https://github.com/pkgforge/soarpkgs/tree/main/packages/86box) at least once to Understand what's what.
> - Once you think you have a rough idea, feel free to [create an Issue](https://github.com/pkgforge/soarpkgs/issues/new/choose), [Discussion](https://github.com/pkgforge/soarpkgs/discussions/new/choose) or [Pull Request](https://github.com/pkgforge/soarpkgs/compare)
> - We will `edit/fix/patch` any `errors/mistakes` you make along with providing helpful & detailed explaination of what went wrong or what could be better, so feel free to spam us.
---

- #### Package Request GuideLines
> ℹ️ There's no strict rules, however if you put in some effort, it will be Resolved Sooner
> - Read the Build Guide](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#write-an-sbuild-recipe)
> - Find out as much Information about the package you want to add including:
> > - Name (`.pkg`) : NAME_OF_PKG, This is what it will be installed as, so be extra sure
> > - ID (`.pkg_id`) : APPSTREAM_APP_ID, You can leave this empty if you don't know
> > - Type (`.pkg_type`) : Choose One: `(appbundle|appimage|archive|dynamic|flatimage|gameimage|nixappimage|runimage|static)`
> > - Description (`.description`) : DESCRIPTION_SUMMARY_ABOUT_PKG
> > - Homepage (`.homepage`) : WEBSITE_LINK_TO_MAIN_PROJECT_PAGE, you can add multiple links
> > - Repology (`.repology`) : REPOLOGY_PROJECT_LINK, Search here: https://repology.org/projects/
> > - Source (`.src_url`) : WEBSITE_LINK_TO_DOWNLOAD_PAGE, this page where we will download the package from, you can add multiple links
> > - Tag (`.tag`) : TAGS_CATEGORIES, comma separated list of tags
> - Once You have gathered this information, Create an Issue: https://github.com/pkgforge/soarpkgs/issues/new/choose >> `Package Request (Generic)`
> - Title: `[Package Request] NAME_OF_PKG (TYPE_OF_PKG)`
> - Body: Fill with correct/Relevant Values
---

- #### `DMCA`, `Copyright` & `Cease & Desist`
> - This Repository DOES NOT DISTRIBUTE ANY `BINARIES` OF ANY KIND.
> - This Repository DOES NOT STORE ANY `PREBUILT ARTIFACTS` ANYWHERE.
> - This Repository DOES NOT DISTRIBUTE ANY `CONTENTS` OTHER THAN BUILD RECIPES (SBUILD).
> - As such, this repository does not infringe upon any copyright laws by its very nature.
> - If you believe a copyright violation has occurred, please direct your concerns to the original source of the content, rather than this repository or its maintainers.
> - We respectfully request that any DMCA takedown notices or cease and desist demands be addressed appropriately and not directed at this repository without valid grounds.
 
