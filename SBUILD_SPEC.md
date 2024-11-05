### Intro
A `.SBUILD` file is a build script in spirit of [APKBUILD](https://wiki.alpinelinux.org/wiki/APKBUILD_Reference) & [PKGBUILD](https://wiki.archlinux.org/title/PKGBUILD), but fear not, it is much more flexible & forgiving.<br>
It is a [yaml file](https://web.archive.org/web/2/https://spacelift.io/blog/yaml) & should be relatively easier to read, understand & write.<br>
See some examples: 
> - [Minimal](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md#minimal-bare-minimum)
> - [Generic/Recommended](https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md#generic-recommended)

### Prerequisite
- We start by learning:
> - `Interpreter` is just a name given to the soar parser which will parse & run the `.SBUILD` Script
> - `ENFORCED` means the field is NOT Skippable & MUST Exist
> - `NON_ENFORCED` means the field is Skippable & NOT Mandatory
> - `RECOMMENDED` means, it can be skipped, but best to try to include it if possible
> - `$TMPDIR` is a temporary directory the `Interpreter` uses to run the `.SBUILD` Script in.
> - `x_exec.run` refers to the raw/vanilla shell cmds that are run
- It is always RECOMMENDED to check your `.SBUILD` with [yamllint](https://www.yamllint.com/) & the `x_exec.run` with [shellcheck](https://www.shellcheck.net/)


### Sections
<!--  -->
<details><summary><b><code>1. Shebang (TYPE:ENFORCED)</code></a></b></summary>
  
  - It starts with `#!/SBUILD ver @${VERSION}` `(TYPE:RECOMMENDED)`
  - It is followed by `_disabled: boolean`, which can either be `true` or `false` which will disable or enable the entire script respectively. `(TYPE:ENFORCED)`
  ```yaml
  #!/SBUILD ver @v0.4.5 #Tells the Interpreter the version
  _disabled: false #Tells the Interpreter to run it
  ```
</details>
<!--  -->
<details><summary><b><code>2. Build Assets (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  #soar will add these using soar dl to $TMPDIR/$OUT prior to running the x_exec part
  build_asset:
    - url: "https://example.com/fileA.tar" #soar dl downloads it
      out: "example_01.tar" #It's saved as $TMPDIR/example_01.tar
    - url: "https://example.com/abc.gif" #soar dl downloads it
      out: "xyz.gif" #It's saved as xyz.gif
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This can be used to pull in Static Assets needed for `x_exec.run` part
  - The benefit of using this over doing it manually in `x_exec.run` is that it's parallelized & pre-downloaded
  - Can have single or multiple entries
</details>
<!--  -->
<details><summary><b><code>3. Build Utils (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  #WARNING: DO NOT USE THIS TO INSTALL STUFF LIKE GIT as that is known not to work as static binary
  #This should only be used for static bins, (use build_dep instead CURRENTLY NOT IMPLEMENTED)
  #soar will add these using soar dl temporarily in cache prior to running the x_exec part
  build_util:
    - "curl" #for web stuff
    - "eget" #to dl from github without curl + jq
    - "ouch" #to extract archives easily without remembering flags
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - This can be used to pull in Static Binaries if some extra tools are being used
  - Use this only if your distro doesn't provide it or you need the latest version of a tool
  - Can have single or multiple entries
</details>
<!--  -->
<details><summary><b><code>4. Pkg (TYPE:ENFORCED)</code></a></b></summary>

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
  > - `pkg_type` is the Package Format, it can be one of the following (`Case-Sensitive`) `(TYPE:RECOMMENDED)` :
  > > - [`AppImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/APPIMAGES.md) denotes it is an [AppImage](https://appimage.org/)
  > > - [`AppBundle`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/APPBUNDLES.md) denotes it is an [AppBundle](https://github.com/xplshn/pelf/)
  > > - [`archive`](https://github.com/ouch-org/ouch?tab=readme-ov-file#supported-formats) denotes it is an archive format: `.7z` `.bz` `.bz2` `.gz` `.lz4` `.lzma` `.rar` `.sz` `.tar` `.xz` `.zst` or a mix-mash of these.
  > > - [`dynamic`]() denotes it is a Dynamic Binary
  > > - [`FlatImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/FLATIMAGES.md) denotes it is a [FlatImage](https://github.com/ruanformigoni/flatimage)
  > > - [`GameImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/GAMEIMAGES.md) denotes it is a [GameImage](https://github.com/ruanformigoni/gameimage)
  > > - [`NixAppImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/NIXAPPIMAGES.md) denotes it is a [NixAppImage](https://github.com/ralismark/nix-appimage)
  > > - [`RunImage`](https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/RUNIMAGES.md) denotes it is a [RunImage](https://github.com/VHSgunzo/runimage)
  > > - [`static`](https://en.wikipedia.org/wiki/Static_build) denotes it is a Static Binary
  > - `Note:` Interpreter will read the magic bytes to determine correct format in case this field is empty.
</details>
<!--  -->
<details><summary><b><code>5. Category (TYPE:RECOMMENDED)</code></a></b></summary>

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
<details><summary><b><code>6. Description (TYPE:ENFORCED)</code></a></b></summary>
 
  ```yaml
  #Example ONLY
  description: "A short summary about the pkg"
  ``` 
  - Short Summarized Description about the `$pkg` `(TYPE:ENFORCED)`
  - Use [search.nixos.org](https://search.nixos.org/packages) as they have best Descriptions
  - Otherwise Use abridged version from the `$pkg`'s Homepage etc
</details> 
<!--  -->
<details><summary><b><code>7. Desktop (TYPE:NON_ENFORCED)</code></a></b></summary>

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
<details><summary><b><code>8. Distro Packages (TYPE:NON_ENFORCED)</code></a></b></summary>
 
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - Use [repology/projects/$pkg](https://repology.org/projects/) to quickly fetch this Information
  ```yaml
  #Example ONLY
  distro_pkg:
   #Not ALL fileds are necessary, they can be left empty or deleted
    #suggests alpine has it
    alpine
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
<details><summary><b><code>9. Homepage (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  homepage:
    - "https://mypkg.net"
    - "https://mypkg.readthedocs.io"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - Can have single or multiple entries
  - Use [repology/projects/$pkg/information](https://repology.org/projects/) to quickly fetch this Information
</details>
<!--  -->
<details><summary><b><code>10. Icon (.DirIcon) (TYPE:NON_ENFORCED)</code></a></b></summary>

  ```yaml
  icon: "#A Direct RAW URL to download a icon/logo file"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:NON_ENFORCED)`
  - Only One entry is supported
  - If `$pkg_type` is a NON portable format, then this is used only for `soar query/info`
  - If `$pkg_type` is a portable format like `AppImage`, `FlatImage` , then it is downloaded & saved as `.DirIcon` inside `$TMPDIR`
  - This MAY BE OVERWRITTEN, if `x_exec.run` does something to the file, otherwise is used as the default `.DirIcon` & `$pkg.png` file
  - If the `icon` file is NOT a `png` File, it MUST BE RENAMED to correct `$pkg.format` in the `x_exec.run` step.
</details>
<!--  -->
<details><summary><b><code>11. License (TYPE:NON_ENFORCED)</code></a></b></summary>

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
<details><summary><b><code>12. Maintainer (TYPE:NON_ENFORCED)</code></a></b></summary>

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
<details><summary><b><code>13. Note (TYPE:NON_ENFORCED)</code></a></b></summary>

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
<details><summary><b><code>14. Provides (TYPE:NON_ENFORCED)</code></a></b></summary>

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
<details><summary><b><code>15. Repology (TYPE:RECOMMENDED)</code></a></b></summary>

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
<details><summary><b><code>16. Source URL (TYPE:RECOMMENDED)</code></a></b></summary>

  ```yaml
  #Example ONLY
  src_url:
    - "https://gitlab.com/mypkg"
    - "https://github.com/mypkg"
  ```
  - This is Optional & can be left empty or removed completely `(TYPE:RECOMMENDED)`
  - This contains the url to source code (Git/SVN/etc)
  - Can have single or multiple entries
</details>
<!--  -->
<details><summary><b><code>17. Tags (TYPE:RECOMMENDED)</code></a></b></summary>

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
<details><summary><b><code>18. x_exec (TYPE:ENFORCED)</code></a></b></summary>

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
  - `Interpreter` will run the shell session with `$pkg` `$pkg_id` env variables pre set & configured.
  - `Interpreter` will also setup `GITHUB_TOKEN` `GITLAB_TOKEN` `HF_TOKEN` if they were exported prior to running `soar build` (Useful for using [gh cli](https://cli.github.com/), [glab](https://gitlab.com/gitlab-org/cli), [eget](https://github.com/zyedidia/eget), [HF CLI](https://huggingface.co/docs/huggingface_hub/en/guides/cli) etc)
  - `Interpreter` will setup a `$TMPDIR` & set it as Current Working Dir `CWD`
  - The Shell CMDs here can be anything but MUST, at end, produce the following files:
  > - `$pkg` file (`>100KB`), this is the main Pkg we are trying to Install
  > - `$pkg.desktop` file (`>3B`) if `$pkg_type` is a Portable Format like AppImage, Otherwise Skipped [Not Needed, if used `desktop`]
  > - `.DirIcon` file (`>1KB`) if `$pkg_type` is a Portable Format like AppImage, Otherwise Skipped [Not Needed, if used `icon`, but may need to rename it to correct `$pkg.format`]
  > - `$pkg.png` file (`>1KB`) if `$pkg_type` is a Portable Format like AppImage & `.DirIcon` doesn't exist
  > - `$pkg.version` file (`>3B`) containing the `$version` information, Otherwise considered `latest`
  - At END, `soar` will copy all the needed files from this `$TMPDIR` to relevant dirs & cleanup (Unless used `--no-clean`)
  - At END, `soar` will also save the entire build log in "${SOAR_DIR}/.cache/logs"
</details>
<!--  -->

### Examples
- ##### Minimal (Bare Minimum)
> ```yaml
> #!/SBUILD ver @v0.4.5
> _disabled: false
> pkg: "86box"
> description: "Emulator of x86-based machines"
> x_exec:
>   shell: bash
>   run: |
>     #Remember we are inside some random dir and we have got the env vars injected ($pkg etc)
>     #We use eget to download the AppImage
>     case "$(uname -m)" in
>       aarch64)
>         timeout 3m eget "https://github.com/86Box/86Box" --asset "arm64" --asset "AppImage" --asset "^.zsync" --to "./${pkg}" && chmod +x "./${pkg}"
>         ;;
>       x86_64)
>         timeout 3m eget "https://github.com/86Box/86Box" --asset "x86_64" --asset "AppImage" --asset "^.zsync" --to "./${pkg}" && chmod +x "./${pkg}"
>         ;;
>     esac
>     #We extract the needed files soar wants
>     "./${pkg}" --appimage-extract *.desktop 1>/dev/null && mv "./squashfs-root/"*.desktop "./${pkg}.desktop"
>     "./${pkg}" --appimage-extract .DirIcon 1>/dev/null && mv "./squashfs-root/.DirIcon" "./.DirIcon"
>     cp "./.DirIcon" "./${pkg}.png"
>     #We get Version Using Curl
>     curl -qfsSL "https://api.github.com/repos/86Box/86Box/releases/latest" | jq -r '.tag_name' > "./${pkg}.version"
>     #We do a final sanity check to ensure we have all the needed files
>     if [[ -s "./${pkg}" && $(stat -c%s "./${pkg}") -gt 1024 ]] && \
>        [[ -s "./${pkg}.desktop" && $(stat -c%s "./${pkg}.desktop") -gt 3 ]] && \
>        [[ -s "./.DirIcon" && $(stat -c%s "./.DirIcon") -gt 1024 ]] && \
>        [[ -s "./${pkg}.png" && $(stat -c%s "./${pkg}.png") -gt 1024 ]] && \
>        [[ -s "./${pkg}.version" && $(stat -c%s "./${pkg}.version") -gt 3 ]]; then
>       echo "All files exist"
>     else
>        echo "One or more files are missing or less than 1KB."
>     fi
>     #We are done and can let soar take it from here
> ```

- ##### Generic (Recommended)
> ```yaml
> #!/SBUILD ver @v0.4.5
> _disabled: false
> 
> pkg: "86box"
> pkg_id: "net._86box._86Box"
> pkg_type: "AppImage"
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
> src_url: "https://github.com/86Box/86Box"
> tag:
>   - "app-emulation"
>   - "emulators"
>   - "game"
>   - "system"
> x_exec:
>   shell: bash
>   run: |
>     #Remember we are inside some random dir and we have got the env vars injected ($pkg etc)
>     #We use eget to download the AppImage
>     case "$(uname -m)" in
>       aarch64)
>         timeout 3m eget "https://github.com/86Box/86Box" --asset "arm64" --asset "AppImage" --asset "^.zsync" --to "./${pkg}" && chmod +x "./${pkg}"
>         ;;
>       x86_64)
>         timeout 3m eget "https://github.com/86Box/86Box" --asset "x86_64" --asset "AppImage" --asset "^.zsync" --to "./${pkg}" && chmod +x "./${pkg}"
>         ;;
>     esac
>     #We extract the needed files soar wants
>     "./${pkg}" --appimage-extract *.desktop 1>/dev/null && mv "./squashfs-root/"*.desktop "./${pkg}.desktop"
>     "./${pkg}" --appimage-extract .DirIcon 1>/dev/null && mv "./squashfs-root/.DirIcon" "./.DirIcon"
>     cp "./.DirIcon" "./${pkg}.png"
>     #We get Version Using Curl
>     curl -qfsSL "https://api.github.com/repos/86Box/86Box/releases/latest" | jq -r '.tag_name' > "./${pkg}.version"
>     #We do a final sanity check to ensure we have all the needed files
>     if [[ -s "./${pkg}" && $(stat -c%s "./${pkg}") -gt 1024 ]] && \
>        [[ -s "./${pkg}.desktop" && $(stat -c%s "./${pkg}.desktop") -gt 3 ]] && \
>        [[ -s "./.DirIcon" && $(stat -c%s "./.DirIcon") -gt 1024 ]] && \
>        [[ -s "./${pkg}.png" && $(stat -c%s "./${pkg}.png") -gt 1024 ]] && \
>        [[ -s "./${pkg}.version" && $(stat -c%s "./${pkg}.version") -gt 3 ]]; then
>       echo "All files exist"
>     else
>        echo "One or more files are missing or less than 1KB."
>     fi
>     #We are done and can let soar take it from here
> ```