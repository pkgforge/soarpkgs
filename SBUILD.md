- ### Prerequisite
> - #### [`Install Soar`](https://soar.qaidvoid.dev/installation)
> > Yes, really. Do it Now: https://soar.qaidvoid.dev/install
> - #### Dependencies (Host)
> > - You will need to Install the following:<br>
> > > [bash](https://command-not-found.com/bash), [b3sum](https://github.com/BLAKE3-team/BLAKE3), [curl](https://curl.se/download.html), [coreutils](https://en.wikipedia.org/wiki/List_of_GNU_Core_Utilities_commands), [file](https://command-not-found.com/file), [findutils (find, xargs)](https://command-not-found.com/find), [fuse3 (fusermount3)](https://command-not-found.com/mount.fuse3), [gettext](https://command-not-found.com/gettext), [grep](https://command-not-found.com/grep), [jq](https://github.com/jqlang/jq), [moreutils](https://command-not-found.com/sponge), [sed](https://command-not-found.com/sed), [shellcheck](https://github.com/koalaman/shellcheck), [util-linux](https://en.wikipedia.org/wiki/Util-linux), [wget](https://command-not-found.com/wget), [yj](https://github.com/sclevine/yj), [yq](https://github.com/mikefarah/yq)
> >
> > - Some of these can be Installed with [`Soar`](https://soar.qaidvoid.dev/install):
> > > ```bash
> > > soar add 'bash/bash#base' \
> > > 'b3sum#bin' \
> > > 'curl#bin' \
> > > 'findutils/find#base' \
> > > 'grep/grep#base' \
> > > 'jq#bin' \
> > > 'sed#bin' \
> > > 'shellcheck#bin' \
> > > 'findutils/xargs#base' \
> > > 'yj#bin' \
> > > 'yq#bin' --yes
> > > ```
> > But if Possible, Use your Distro's own PKG Manager to avoid breaking stuff
---

- ### Write a `.SBUILD` Recipe
> 1. Read the [`Spec`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md): https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md
> 2. View [Some Examples](https://github.com/pkgforge/soarpkgs/tree/main/packages): https://github.com/pkgforge/soarpkgs/tree/main/packages
> 3. Copy the [Generic Template](https://github.com/pkgforge/soarpkgs/blob/main/templates/generic.SBUILD.yaml): https://github.com/pkgforge/soarpkgs/blob/main/templates/generic.SBUILD.yaml
> 4. Use the [Repology Fetcher](https://github.com/pkgforge/soarpkgs/blob/main/scripts/repology_fetcher.sh): https://github.com/pkgforge/soarpkgs/blob/main/scripts/repology_fetcher.sh
> > ```bash
> > !#Assuming You have READ & VERIFIED what the script contains
> > source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/pkgcache/main/.github/scripts/repology_fetcher.sh")
> > #The function itself is `repology_fetcher` but is aliased to `repology-fetcher` for convenience
> > 
> > !#Run it with the app/pkg_name
> > repology-fetcher "pkg_name"
> > #Example: repology-fetcher "librewolf"
> > ```
> 5. Start Filling in the [Generic Template](https://github.com/pkgforge/soarpkgs/blob/main/templates/generic.SBUILD.yaml) by Consulting an [`Example`](https://github.com/pkgforge/soarpkgs/tree/main/packages) or the [`SPEC`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md)
> 6. After you are done, you can validate it using the [`Linter`](https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_linter.sh): https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_linter.sh
> > ```bash
> > !#Assuming You have READ & VERIFIED what the script contains
> > source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_linter.sh")
> > #The function itself is `sbuild_linter` but is aliased to `sbuild-linter` for convenience
> > 
> > !#Run it with /path/to/your/SBUILD
> > sbuild-linter ./example.SBUILD
> >
> > !#If it complains about cmd not found, You should install the Depedencies (See Beginning of this Page)
> > #You can also install some (NOT ALL) using:
> > INSTALL_DEPS="ON" sbuild-linter "./example.SBUILD"
> >
> > !#Extra options
> > # sbuild-linter example.SBUILD
> > DEBUG=1|ON sbuild-linter example.SBUILD --> runs with set -x
> > INSTALL_DEPS=1|ON sbuild-linter example.SBUILD --> Installs all deps via soar
> > SHOW_DIFF=1|ON sbuild-linter example.SBUILD --> shows diff between example.SBUILD & example.SBUILD.validated
> > SHELLCHECK=0|OFF sbuild-linter example.SBUILD --> Disables Shellcheck
> > SBUILD_MODE=1|ON sbuild-linter example.SBUILD --> Exports needed ENV Vars to sbuild-runner
> > ```
> 7. If your `SBUILD` get's validated successfully, Congrats! You can now create a [`Pull Request`](https://github.com/pkgforge/soarpkgs/compare) or an [`Issue`](https://github.com/pkgforge/soarpkgs/issues/new/choose), Remeber to `Link/Copy&Paste` the `.validated` version of your `SBUILD`
> 8. You can also test it locally using the [`Runner`](https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_runner.sh)
> > ```bash
> > !#Assuming You have READ & VERIFIED what the script contains
> > bash <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_runner.sh") example.SBUILD #Runs it directly
> > #To DL it locally:
> > curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_runner.sh" -o "./sbuild-runner" && chmod +x "./sbuild-runner"
> > "./sbuild-runner" example.SBUILD
> >
> > !#Extra options
> > sbuild-runner example.SBUILD
> > DEBUG=1|ON sbuild-runner example.SBUILD --> runs with set -x
> > ```
> >
---
