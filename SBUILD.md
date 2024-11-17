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

- ### Write an `.SBUILD` Recipe
> 1. Read the [`Spec`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md): https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md
> 2. View [Some Examples](https://github.com/pkgforge/soarpkgs/tree/main/packages): https://github.com/pkgforge/soarpkgs/tree/main/packages
> 3. Copy the [Generic Template](https://github.com/pkgforge/soarpkgs/blob/main/templates/generic.SBUILD.yaml): https://github.com/pkgforge/soarpkgs/blob/main/templates/generic.SBUILD.yaml
> 4. Use the [Repology Fetcher](https://github.com/pkgforge/soarpkgs/blob/main/scripts/repology_fetcher.sh): https://github.com/pkgforge/soarpkgs/blob/main/scripts/repology_fetcher.sh
> > ```bash
> > !#Assuming You have READ & VERIFIED what the script contains
> > source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/repology_fetcher.sh")
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
> > #It can be downloaded and run:
> > curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_linter.sh" -o "./sbuild-linter" && chmod +x "./sbuild-linter"
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
> > SHOW_PKGVER=1|ON sbuild-linter example.SBUILD --> fetches Version (Using .pkgver or .x_exec.pkgver), writes to example.SBUILD.pkgver 
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
> > SBUILD_ID="test123" sbuild-runner example.SBUILD --> Saves the env as ${SOAR_CACHEPATH}/test123.SBUILD.env
> > # By default, it will save as ${SOAR_CACHEPATH}/${SBUILD_PKG}.SBUILD.env (SBUILD_ID == .pkg + .pkg_type)
> > # Regardless, it will also always save the env file next to example.SBUILD as example.SBUILD.env
> > ```
> >
---

- #### `Build|Install|Run` an `.SBUILD` Recipe
> TODO
---

- #### [`ENV VARS (x_exec.run)`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md#x_exec)
> List of Environment Variables that are Accessible Inside `x_exec.run`
> - `${pkg}` | `{PKG}`
> > - Description: `The raw value of .pkg from .SBUILD <ALWAYS Available>`
> - `${pkg_id}` |  `${PKG_ID}`
> > - Description: `The raw value of .pkg_id from .SBUILD <Empty if not Available>`
> - `${pkg_type}` | `${PKG_TYPE}`
> > - Description: `The raw value of .pkg_type from .SBUILD <Empty if not Available>`
> - `${SBUILD_PKG}`
> > - Description: `The raw value of .pkg + .pkg_type from .SBUILD <ALWAYS Available>`
> > - `ALWAYS USE ${SBUILD_PKG} for output, example: ${SBUILD_PKG} (Main Binary), ${SBUILD_PKG}.png (Icon), ${SBUILD_PKG}.desktop (Desktop) etc`
> - `${SBUILD_OUTDIR}`
> > - Description: `The Root (Temporary) Working Directory x_exec.run is Run From <ALWAYS Available>`
> > - `All NEEDED Files must exist in this Directory`
> - `${SBUILD_TMPDIR}`
> > - Description: `The SBUILD_TEMP Directory inside ${SBUILD_OUTDIR} (PATH: ${SBUILD_OUTDIR}/SBUILD_TEMP), used for storing NON-NEEDED Files <ALWAYS Available>`
> > - `Use this dir to do Additional Steps, keep the main ${SBUILD_OUTDIR} clutter free` 
> - `${USER_AGENT}`
> > - Description: `USER_AGENT from Host <Empty if not Available>`
> - [`${GITHUB_TOKEN}`](https://cli.github.com/) | [`${GH_TOKEN}`](https://cli.github.com/)
> > - Description: `GITHUB TOKEN from Host <Empty if not Available>`
> - [`${GITLAB_TOKEN}`](https://gitlab.com/gitlab-org/cli) | [`${GL_TOKEN}`](https://gitlab.com/gitlab-org/cli)
> > - Description: `GITLAB TOKEN from Host <Empty if not Available>`
> - [`${HF_TOKEN}`](https://huggingface.co/docs/huggingface_hub/en/guides/cli)
> > - Description: `HuggingFaceHub Token from Host <Empty if not Available>`
---

- #### [`ENV VARS (Runner)`](https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_runner.sh)
> - `${SBUILD_SUCCESSFUL}`
> > - Description: `If the Build Was Successful or Failed, if It Failed (SBUILD_SUCCESSFUL==NO) Bail & Exit Immediately`
> > - Values: `YES | NO`
> - `${SBUILD_PKG}`
> > - Description: `The Package Name, used as Prefix for ALL NEEDED Files <ALWAYS Available>`
> - `${PKG_TYPE}`
> > - Description: `One of appbundle|appimage|archive|dynamic|flatimage|gameimage|nixappimage|runimage|static`
> > - `ALWAYS Re-Checked using Magic Bytes for Utmost Sanity`
> > - `dynamic|static are binaries (cli), don't need Integration (Desktop,Icons etc)`
> > - `UNKNOWN means, the pkg_type value was empty, Rechecked anyway`
> - `${SBUILD_OUTDIR}`
> > - Description: `The Root (Temporary) Working Directory where ${SBUILD_PKG} & ALL NEEDED Files are Stored <ALWAYS Available>`
> - `${SBUILD_TMPDIR}`
> > - Description: `The SBUILD_TEMP Directory inside ${SBUILD_OUTDIR} (PATH: ${SBUILD_OUTDIR}/SBUILD_TEMP), used for storing NON-NEEDED Files <ALWAYS Available>`
> - `${SBUILD_META}`
> > - Description: `JSON Metadata file, is also available at ${SBUILD_OUTDIR}/${SBUILD_PKG}.json`
---

- #### `NEEDED FILES`
> - `${SBUILD_OUTDIR}/${SBUILD_PKG}`
> > - Description: `The actual binary/package that was built`
> > - Min_Size: `> 100KB`
> - `${SBUILD_OUTDIR}/.desktop` | `${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop`
> > - Description: `Desktop File, Is Edited/Fixed during Integration`
> > - Min_Size: `> 3B`
> > - `Only Available for Portable Packages`
> - `${SBUILD_OUTDIR}/.DirIcon` | `${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon`
> > - Description: `DirIcon, Preferred as 'Icon' if '${SBUILD_OUTDIR}/${SBUILD_PKG}.png' OR '${SBUILD_OUTDIR}/${SBUILD_PKG}.svg' DO NOT Exist`
> > - Min_Size: `> 1KB`
> > - `Only Available for Portable Packages`
> - `${SBUILD_OUTDIR}/${SBUILD_PKG}.png` | `${SBUILD_OUTDIR}/${SBUILD_PKG}.svg`
> > - Description: `Preferred even if '${SBUILD_OUTDIR}/${SBUILD_PKG}.png' OR '${SBUILD_OUTDIR}/${SBUILD_PKG}.svg' Exists due to Higher Resolution`
> > - Min_Size: `> 1KB`
> > - `Only Available for Portable Packages`
> - `${SBUILD_OUTDIR}/${SBUILD_PKG}.appdata.xml` | `${SBUILD_OUTDIR}/${SBUILD_PKG}.metainfo.xml`
> > - Description: `Prefer metainfo.xml over appdata.xml as appdata.xml is now Legacy`
> > - Min_Size: `> 3B`
> > - `Only Available for Portable Packages`
> - `${SBUILD_OUTDIR}/metadata.json` | `${SBUILD_OUTDIR}/${SBUILD_PKG}.json` | `${SBUILD_META}`
> > - Description: `JSON Metadata file, if empty, create based on this Template`
> > > ```json
> > > {
> > >   "_disabled": true,
> > >   "pkg": "${value SBUILD_PKG or filename}",
> > >   "pkg_type": "${PKG_TYPE, determine using magic bytes}",
> > >   "category": [
> > >     "Utility"
> > >   ],
> > >   "description": "This Package has Incomplete Metadata",
> > >   "icon": "/path/to/icon otherwise /path/to/local/default/icon",
> > >   "maintainer": [
> > >     "Soar (https://github.com/pkgforge/soar)"
> > >   ],
> > >   "note": [
> > >     "No Metadata was found for this Package, so Please Fix it Manually"
> > >   ],
> > >   "src_url": [
> > >     "https://unknown.unknown/fix-me"
> > >   ],
> > >   "tag": [
> > >     "broken-pkg",
> > >     "invalid-metadata",
> > >     "no-metadata"
> > >   ]
> > > }
> > > ```
> > - Min_Size: `> 3B`
> > - `Available for ALL Packages` 
> - `${SBUILD_OUTDIR}/.version` | `${SBUILD_OUTDIR}/${SBUILD_PKG}.version`
> > - Description: `Version File, Contains Version, if empty, then Use Version based on Date/BSUM`
> > - Min_Size: `> 3B`
> > - `Available for ALL Packages`
---
