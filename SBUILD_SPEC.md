### Intro
A `.SBUILD` file is a build script in spirit of [APKBUILD](https://wiki.alpinelinux.org/wiki/APKBUILD_Reference) & [PKGBUILD](https://wiki.archlinux.org/title/PKGBUILD), but fear not, it is much more flexible & forgiving.<br>
It is a [yaml file](https://web.archive.org/web/2/https://spacelift.io/blog/yaml) & should be relatively easier to read, understand & write.<br>
See some examples: 
> - [Minimal](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md#minimal-bare-minimum)
> - [Generic/Recommended](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md#generic-recommended)

### Prerequisite
- We start by learning:
> - `Interpreter` is just a name given to the soar parser which will parse & run the `.SBUILD` Script. Also Reffered as `Runner` Sometimes.
> - `ENFORCED` means the field is NOT Skippable & MUST Exist
> - `NON_ENFORCED` means the field is Skippable & NOT Mandatory
> - `RECOMMENDED` means, it can be skipped, but best to try to include it if possible
> - `$SBUILD_OUTDIR` is a temporary directory the `Interpreter` uses to run the `.SBUILD` Script in. Also Reffered as `$TMPDIR` Sometimes.
> - `$SBUILD_TMPDIR` is a dir inside `$SBUILD_OUTDIR` (PATH: `$SBUILD_OUTDIR/SBUILD_TEMP`) that can be used to store [NON-NEEDED Files](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#needed-files)
> - `x_exec.run` refers to the raw/vanilla shell cmds that are run
- It is always RECOMMENDED to check your `.SBUILD` with [yamllint](https://www.yamllint.com/) & the `x_exec.run` with [shellcheck](https://www.shellcheck.net/)
- For more [Detailed Guide](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#write-an-sbuild-recipe): https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#write-an-sbuild-recipe

### Sections
> ℹ️ Make sure to `Click ▶` to **Expand**
<!--  -->
<details id="shebang"><summary><b><code>1. Shebang (TYPE:ENFORCED)</code></a></b></summary>
  
  - It starts with `#!/SBUILD ver @${VERSION}` `(TYPE:RECOMMENDED)`
  - It is followed by `_disabled: boolean`, which can either be `true` or `false` which will disable or enable the entire script respectively. `(TYPE:ENFORCED)`
  ```yaml
  #!/SBUILD ver @v0.4.5 #Tells the Interpreter the version
  _disabled: false #Tells the Interpreter to run it
  ```
</details>
<!--  -->
<details id="build_asset"><summary><b><code>2. Build Assets (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  #All of the files will be downloaded & added to "${SBUILD_OUTDIR/SBUILD_TEMP}" (Also Known as $SBUILD_TMPDIR prior to running the x_exec part
  build_asset:
    - url: "https://example.com/fileA.tar" #Downloaded
      out: "example_01.tar" #Saved as $SBUILD_OUTDIR/SBUILD_TEMP/example_01.tar
    - url: "https://example.com/abc.gif" #Downloaded
      out: "xyz.gif" #Saved as $SBUILD_OUTDIR/SBUILD_TEMP/xyz.gif
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This can be used to pull in Static Assets needed for `x_exec.run` part.
  - Accessible using `${SBUILD_TMPDIR}/$FILE` OR `$SBUILD_OUTDIR/SBUILD_TEMP/$FILE` [`ENV VARS`]().
  - The benefit of using this over doing it manually in `x_exec.run` is that it's parallelized & pre-downloaded
  - Can have single or multiple entries
</details>
<!--  -->
<details id="build_util"><summary><b><code>3. Build Utils (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  #WARNING: DO NOT USE THIS TO INSTALL STUFF LIKE GIT as that is known not to work as static binary
  #This should only be used for static bins, (use build_dep instead CURRENTLY NOT IMPLEMENTED)
  #soar will add these using soar dl temporarily in cache prior to running the x_exec part
  #if these are already installed/cached by soar, soar will skip them (Unless Upgrade is found)
  build_util:
    - "curl" #for web stuff
    - "ouch" #to extract archives easily without remembering flags
    - "squishy-cli" #to extract appimages/squashfs archives for Desktop, icon Files etc
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This can be used to pull in Static Binaries if some extra tools are being used
  - Use this only if your distro doesn't provide it or you need the latest version of a tool
  - Can have single or multiple entries
</details>
<!--  -->
<details id="pkg"><summary><b><code>4. Pkg (TYPE:ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  pkg: "Real Name, It will be Installed & Integrated based on this Value"
  pkg_id: "Appstream App Id, flatpak's scheme preferred, otherwise can be empty"
  pkg_type: "Pkg Format, if empty or nonexistent, Interpreter reads Magic Bytes to determine format"
  ```
  - `pkg` is Canonical name of the Package. It will be installed as this regardless of the actual filename. Desktop entry will also show this name `(TYPE:ENFORCED)`
  - `pkg_id` is [AppStream App Id](https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html#tag-id-generic). `(TYPE:RECOMMENDED)`
  > - You can find the `pkg_id` by searching it on [Flathub](https://flathub.org/)
  > > ![image](https://github.com/user-attachments/assets/877263b5-8cbd-4a76-bcb6-1df738643fa2)
  > - You can also find it in Appstream `Appdata.xml` or `Metainfo.xml` files
  > > ![image](https://github.com/user-attachments/assets/0f4d2c3e-95a9-4ad0-b57d-05bbca6f3748)
  > - Sometimes, this id can also be found in `.Desktop` file.
  > - If you can't ind the `pkg_id` at all, you may create a dummy one in `xxx.${TLD}.${DOMAIN}.${PROJECT_NAME}` format
  > > ```bash
  > > xxx.io.github.SuperApp --> #Created from a the site's Homepage: SuperApp.github.io
  > > xxx.com.github.CoolApp --> #Created from https://github.com/CoolApp
  > > ```
  > - `pkg_type` is the Package Format, it can be one of the following (`lowercase`) `(TYPE:RECOMMENDED)` :
  > > - [`AppImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/APPIMAGES.md) denotes it is an [AppImage](https://appimage.org/) `pkg_type: "appimage"`
  > > - [`AppBundle`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/APPBUNDLES.md) denotes it is an [AppBundle](https://github.com/xplshn/pelf/) `pkg_type: "appbundle"`
  > > - [`archive`](https://github.com/ouch-org/ouch?tab=readme-ov-file#supported-formats) denotes it is an archive (`SELF-EXTRACTABLE`) format: `.7z` `.bz` `.bz2` `.gz` `.lz4` `.lzma` `.rar` `.sz` `.tar` `.xz` `.zst` or a mix-mash of these. This includes formats like [alpix](https://github.com/QaidVoid/alpix), [staticx](https://github.com/JonathonReinhart/staticx) etc. `pkg_type: "archive"`
  > > - [`dynamic`]() denotes it is a Dynamic Binary `pkg_type: "dynamic"`
  > > - [`FlatImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/FLATIMAGES.md) denotes it is a [FlatImage](https://github.com/ruanformigoni/flatimage) `pkg_type: "flatimage"`
  > > - [`GameImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/GAMEIMAGES.md) denotes it is a [GameImage](https://github.com/ruanformigoni/gameimage) `pkg_type: "gameimage"`
  > > - [`NixAppImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/NIXAPPIMAGES.md) denotes it is a [NixAppImage](https://github.com/ralismark/nix-appimage) `pkg_type: "nixappimage"`
  > > - [`RunImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/RUNIMAGES.md) denotes it is a [RunImage](https://github.com/VHSgunzo/runimage) `pkg_type: "runimage"`
  > > - [`static`](https://en.wikipedia.org/wiki/Static_build) denotes it is a Static Binary `pkg_type: "static"`
  > - `Note:` Interpreter will read the magic bytes to determine correct format in case this field is empty.
</details>
<!--  -->
<details id="category"><summary><b><code>5. Category (TYPE:RECOMMENDED)</code></a></b></summary>

  - This is Optional & can be left empty or removed completely `(TYPE:RECOMMENDED)`
  - If it is left empty or doesn't exist, It is set to `Utility` by default.
  - If it is used, it MUST be one of the Registered Categories as per the FreeDesktop Spec
  > - [Main Categories](https://specifications.freedesktop.org/menu-spec/latest/category-registry.html)
  > - [Additional Categories](https://specifications.freedesktop.org/menu-spec/latest/additional-category-registry.html)
  - It can contain multiple entries
  > ```yaml
  > #Example ONLY
  > category:
  >   - "Core"
  >   - "Utility"
  > ```
</details>
<!--  -->
<details id="description"><summary><b><code>6. Description (TYPE:ENFORCED)</code></a></b></summary>
 
  ```yaml
  #Example ONLY
  description: "A short summary about the pkg"
  ``` 
  - Short Summarized Description about the `$pkg` `(TYPE:ENFORCED)`
  - [repology-fetcher](https://github.com/pkgforge/soarpkgs/blob/main/scripts/repology_fetcher.sh) will Autogenerate Multiple Description from [Repology](https://repology.org/projects/), Pick the Best one.
  - [search.nixos.org](https://search.nixos.org/packages) also has Saner Descriptions
  - Otherwise Use abridged version from the `$pkg`'s Homepage etc
</details> 
<!--  -->
<details id="desktop"><summary><b><code>7. Desktop (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  desktop: "#A Direct RAW URL to download a .desktop file"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - Only One entry is supported
  - This is applicable only if `$pkg_type` is a portable format like `AppImage`, `FlatImage` etc
  - This will be downloaded & saved as `$pkg.desktop` inside `$TMPDIR`
  - This MAY BE OVERWRITTEN, if `x_exec.run` does something to the file, otherwise is used as the default `.Desktop` file
</details>
<!--  -->
<details id="distro_pkg"><summary><b><code>8. Distro Packages (TYPE:NON_ENFORCED)</code></a></b></summary>
 
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - Use [repology/projects/$pkg](https://repology.org/projects/) to quickly fetch this Information, Or You can [Automate It](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#write-an-sbuild-recipe)
  ```yaml
  #Example ONLY
  distro_pkg:
   #Not ALL fileds are necessary, they can be left empty or deleted
    #suggests alpine has it
    alpine:
      - "mypkg"
    #suggests archlinux has it
    archlinux:
      #suggests aur has it
      aur:
        - "mypkg-bin"
        - "mypkg-git"
      extra:
      #suggest extra has it
        - "mypkg"
    #suggests debian has it    
    deb:
      - "mypkg"
    #suggests nixpkg has it
    nixpkgs:
      - "#mypkg"
  ``` 
</details> 
<!--  -->
<details id="homepage"><summary><b><code>9. Homepage (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  homepage:
    - "https://mypkg.net"
    - "https://mypkg.readthedocs.io"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This contains the urls to homepage, project page & source code (Git/SVN/etc)
  - This should `NOT BE CONFUSED` with `src_url` which <ins>contains urls</ins> to the page that contains the `download_link`
  - Can have single or multiple entries
  - Use [repology/projects/$pkg/information](https://repology.org/projects/) to quickly fetch this Information
</details>
<!--  -->
<details id="icon"><summary><b><code>10. Icon (.DirIcon) (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  icon: "#A Direct RAW URL to download a icon/logo file"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - Only One entry is supported
  - If `$pkg_type` is a NON portable format, then this is used only for `soar query/info`
  - If `$pkg_type` is a portable format like `AppImage`, `FlatImage` , then it is downloaded & saved as `.DirIcon` as `${SBUILD_OUTDIR}/.DirIcon`
  - This MAY BE OVERWRITTEN, if `x_exec.run` does something to the file, otherwise is used as the default `.DirIcon` & `${SBUILD_OUTDIR}/${SBUILD_PKG}.png` file
  - If the `icon` file is NOT a `png` File, it MUST BE RENAMED to correct `$pkg.format` in the `x_exec.run` step.
</details>
<!--  -->
<details id="license"><summary><b><code>11. License (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  license:
    - "GPL-2+"
    - "GPL-2.0"
    - "GPL-2.0-only"
    - "GPL-2.0-or-later"
    - "GPL2"
    - "GPLv3"
    - "Unfree"
    - "spdx:GPL-2.0-or-later"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - Can have single or multiple entries
  - Use [repology/projects/$pkg/information](https://repology.org/projects/) to quickly fetch this Information
</details>
<!--  -->
<details id="maintainer"><summary><b><code>12. Maintainer (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  maintainer:
    - "Azathothas (https://github.com/Azathothas)"
    - "QaidVoid (Qaid@Qaidvoid.dev)"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This shows the author/maintainer of the `$pkg.SBUILD` script
  - A single pkg can have multiple maintainers & contact details or websites can be embedded inside `()`
  - Can have single or multiple entries 
  - You will usually add yourself to this field
</details>
<!--  -->
<details id="note"><summary><b><code>13. Note (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  note:
    - "Some note"
    - "Some other note"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This contains extra information about the `$pkg` such as setup information or errors & quirk.
  - Can have single or multiple entries 
</details>
<!--  -->
<details id="provides"><summary><b><code>14. Provides (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  # $pkg itself will always be a default value, so not needed if contains only 1 program and that 1 program is $pkg itself
  provides:
    - "prog-a"
    - "prog-b"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This lists all programs that are fetched/built during the `x_exec.run` part.
  - If this field is empty or doesn't exist, the interpreter will use `$pkg` as the only value of `provides` by default.
  - If this field exists, soar will treat it as a `$pkg` family containing all programs from `provides`
  - `soar install $pkg` by default will install all programs from `provides`. This is same as `$pkg` when `provides` is empty/nonexistent.
  - `soar install $pkg/$prog` will only install `$prog` from the `$pkg`'s `.SBUILD`
  - Can have single or multiple entries
</details>
<!--  -->
<details id="repology"><summary><b><code>15. Repology (TYPE:RECOMMENDED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  repology:
    - "mypkg"
    - "mypkg-bin"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:RECOMMENDED)`
  - This contains the package name that [repology](https://repology.org/projects/) uses.
  - Can have single or multiple entries
</details>
<!--  -->
<details id="src_url"><summary><b><code>16. Source (Download) URL (TYPE:ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  src_url:
    - "https://gitlab.com/mypkg"
    - "https://github.com/mypkg"
  ```
  - This MUST contain at least `1` URL `(TYPE:ENFORCED)`
  - This contains the url to the `download/source` page which contains the download link for the `pkg`
  - This should `NOT BE CONFUSED` with `homepage`
  - Can have only single or multiple entries
</details>
<!--  -->
<details id="tag"><summary><b><code>17. Tags (TYPE:RECOMMENDED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  tag:
    - "app-emulation"
    - "emulators"
    - "game"
    - "system
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:RECOMMENDED)`
  - This contains tags for better `soar search` as the existing `Category` is quite Limited & Strict
  - Can have single or multiple entries
</details>
<!--  -->
<details id="x_exec"><summary><b><code>18. x_exec (TYPE:ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  x_exec:
    shell: bash #Invokes /usr/bin/env ${SHELL}, bash in this case
    run: |
     ${RAW SHELL CMDS}
  ```  
  - This is the Core part, & what actually does all the work. `(TYPE:ENFORCED)`
  - `shell` set's the real interpreter using `/usr/bin/env ${SHELL}`, this can be any shell: `sh` `bash` `fish` `nu` `oils` `zsh`
  - `run` block's shell script MUST not have errors, use [Shellcheck](https://www.shellcheck.net/) to check for it.
  - [`Runner`](https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_runner.sh) will run the [`Linter|Validator`](https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_linter.sh), if & only if the `.SBUILD` is validated, it will proceed further.
  - [`Runner`](https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_runner.sh) will run the shell session with [a list of ENV_VARS](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#env-vars-x_execrun) pre set & configured. [More Details](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#env-vars-x_execrun): https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#env-vars-x_execrun
  - [`Runner`](https://github.com/pkgforge/soarpkgs/blob/main/scripts/sbuild_runner.sh) will setup a `$TMPDIR` & set it as Current Working Dir `${SBUILD_OUTDIR}`
  - The Shell CMDs here can be anything but MUST, at end, produce these [`NEEDED FILES`](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#needed-files):
  > - `${SBUILD_OUTDIR}/${SBUILD_PKG}` file (`>100KB`), this is the main Pkg we are trying to Install
  > - `${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop` file (`>3B`) if `${PKG_TYPE}` is a Portable Format like AppImage, Otherwise Skipped [Not Needed, if used `desktop`]
  > - `${SBUILD_OUTDIR}/.DirIcon` file (`>1KB`) if `${PKG_TYPE}` is a Portable Format like AppImage, Otherwise Skipped [Not Needed, if used `icon`, but may need to rename it to correct `$pkg.format`]
  > - `${SBUILD_OUTDIR}/${SBUILD_PKG}.png` file (`>1KB`) if `${PKG_TYPE}` is a Portable Format like AppImage & `.DirIcon` doesn't exist
  > - `${SBUILD_OUTDIR}/${SBUILD_PKG}.svg` file (`>1KB`) if `${PKG_TYPE}` is a Portable Format like AppImage & both `.DirIcon` & `${SBUILD_OUTDIR}/${SBUILD_PKG}.png` don't exist
  > - `${SBUILD_OUTDIR}/${SBUILD_PKG}.version` file (`>3B`) containing the `$version` information, Otherwise Auto Determined using `Date|BSUM`
  - At END, `soar` will copy all the needed files from this `${SBUILD_OUTDIR}` to relevant dirs & cleanup (Unless used `--no-clean`)
  - At END, `soar` will also save the entire build log in "${SOAR_ROOT}/packages/${PKG}/${PKG_NAME}.log"
</details>
<!--  -->

### Examples
> ℹ️ Read the [Dedicated Guide](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#write-an-sbuild-recipe): https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md#write-an-sbuild-recipe
- ##### [Minimal (Bare Minimum)](https://github.com/pkgforge/soarpkgs/blob/main/templates/minimal.SBUILD.yaml)
> ```yaml
> #!/SBUILD ver @v0.4.5
> _disabled: false
> pkg: "86box"
> build_util:
>   - "squishy-cli"
> description: "Emulator of x86-based machines"
> src_url:
>  - "https://github.com/86Box/86Box"
> x_exec:
>   shell: bash
>   run: |
>     #Remember we are inside some random dir and we have got the env vars injected ($SBUILD_PKG etc)
>     ##Download the file
>     case "$(uname -m)" in
>       aarch64)
>         soar dl "https://github.com/86Box/86Box" --match "appimage|arm64" --exclude "x64|x86|zsync" -o "./${SBUILD_PKG}" --yes && chmod +x "./${SBUILD_PKG}"
>         ;;
>       x86_64)
>         soar dl "https://github.com/86Box/86Box" --match "appimage|x86_64" --exclude "aarch64|arm|zsync" -o "./${SBUILD_PKG}" --yes && chmod +x "./${SBUILD_PKG}"
>         ;;
>     esac
>     #We extract the needed files Runner Wants (All of the Files are saved with ${SBUILD_PKG}.$file Prefix)
>     squishy-cli appimage "./${SBUILD_PKG}" --icon --desktop --appstream --write
>     #We get Version Using Curl
>     curl -qfsSL "https://api.github.com/repos/86Box/86Box/releases/latest" | jq -r '.tag_name' > "./${SBUILD_PKG}.version"
>     #We do a final sanity check to ensure we have all the needed files
>     find "." -type f -iname "*${PKG%%-*}*" -print | xargs -I {} sh -c 'file {}; b3sum {}; sha256sum {}; du -sh {}'
>     #We are done and can let the Runner take it from here
> ```

- ##### [Generic (Recommended)](https://github.com/pkgforge/soarpkgs/blob/main/templates/generic.SBUILD.yaml)
> ```yaml
> #!/SBUILD ver @v0.4.5
> _disabled: false
> 
> pkg: "86box"
> pkg_id: "net._86box._86Box"
> pkg_type: "AppImage"
> build_util:
>   - "squishy-cli"
> category:
>   - "Emulator"
> description: "Emulator of x86-based machines"
> distro_pkg:
>   archlinux:
>     aur:
>       - "86box"
>       - "86box-appimage"
>       - "86box-git"
>   nixpkgs:
>     - "86Box"
> homepage:
>   - "https://86box.net"
>   - "https://86box.readthedocs.io"
> license:
>   - "GPL-2+"
>   - "GPL-2.0"
>   - "GPL-2.0-only"
>   - "GPL-2.0-or-later"
>   - "GPL2"
>   - "GPLv3"
>   - "Unfree"
>   - "spdx:GPL-2.0-or-later"
> maintainer:
>   - "Azathothas (https://github.com/Azathothas)"
> note:
>  - "Officially Created AppImage. Check/Report @ https://github.com/86Box/86Box"
>  - "You need to download ROMS: https://86box.readthedocs.io/en/latest/usage/roms.html"
> repology:
>  - "86box"
> src_url:
>  - "https://github.com/86Box/86Box"
> tag:
>   - "app-emulation"
>   - "emulators"
>   - "game"
>   - "system"
> x_exec:
>   shell: bash
>   run: |
>     #Remember we are inside some random dir and we have got the env vars injected ($SBUILD_PKG etc)
>     ##Download the file
>     case "$(uname -m)" in
>       aarch64)
>         soar dl "https://github.com/86Box/86Box" --match "appimage|arm64" --exclude "x64|x86|zsync" -o "./${SBUILD_PKG}" --yes && chmod +x "./${SBUILD_PKG}"
>         ;;
>       x86_64)
>         soar dl "https://github.com/86Box/86Box" --match "appimage|x86_64" --exclude "aarch64|arm|zsync" -o "./${SBUILD_PKG}" --yes && chmod +x "./${SBUILD_PKG}"
>         ;;
>     esac
>     #We extract the needed files Runner Wants (All of the Files are saved with ${SBUILD_PKG}.$file Prefix)
>     squishy-cli appimage "./${SBUILD_PKG}" --icon --desktop --appstream --write
>     #We get Version Using Curl
>     curl -qfsSL "https://api.github.com/repos/86Box/86Box/releases/latest" | jq -r '.tag_name' > "./${SBUILD_PKG}.version"
>     #We do a final sanity check to ensure we have all the needed files
>     find "." -type f -iname "*${PKG%%-*}*" -print | xargs -I {} sh -c 'file {}; b3sum {}; sha256sum {}; du -sh {}'
>     #We are done and can let the Runner take it from here
> ```
