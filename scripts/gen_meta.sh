#!/usr/bin/env bash
## <DO NOT RUN STANDALONE, meant for CI Only>
## Meant to Convert SBUILDS --> JSON --> METADATA, file will exist at ${SYSTMP}/SBUILD_METADATA.json (${SYSTMP} == /tmp)
## Requires: https://github.com/Azathothas/Arsenal/blob/main/misc/Linux/install_dev_tools.sh
# bash <(curl -qfsSL "https://pub.ajam.dev/repos/Azathothas/Arsenal/misc/Linux/install_dev_tools.sh")
## Self: https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/gen_meta.sh
# bash <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/gen_meta.sh")
#-------------------------------------------------------#

#-------------------------------------------------------#
##ENV
export TZ="UTC"
SYSTMP="$(dirname $(mktemp -u))" && export SYSTMP="${SYSTMP}"
TMPDIR="$(mktemp -d)" && export TMPDIR="${TMPDIR}" ; echo -e "\n[+] Using TEMP: ${TMPDIR}\n"
##Repo
 pushd "$(mktemp -d)" >/dev/null 2>&1 && git clone --filter="blob:none" --depth="1" "https://github.com/pkgforge/soarpkgs" && cd "./soarpkgs"
  find . -type f ! -path "./.git/*" -exec dos2unix --quiet "{}" \; 2>/dev/null
  GH_REPO_PATH="$(realpath .)" ; export GH_REPO_PATH
 popd >/dev/null 2>&1
##Progs
 curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_linter.sh" -o "${TMPDIR}/sbuild-linter"
 dos2unix --quiet "${TMPDIR}/sbuild-linter" ; chmod +x "${TMPDIR}/sbuild-linter"
 if [[ ! -s "${TMPDIR}/sbuild-linter" || $(stat -c%s "${TMPDIR}/sbuild-linter") -le 3 ]]; then
   echo -e "\n[✗] FATAL: sbuild-linter Appears to be NOT INSTALLED...\n"
  exit 1 
 fi
#-------------------------------------------------------#

#-------------------------------------------------------#
##Validate everything
find "${GH_REPO_PATH}/packages" -type f -iregex '.*\.\(yml\|yaml\)$' -print0 | xargs -0 -I{} -P0 sh -c 'SHOW_PKGVER="1" "${TMPDIR}/sbuild-linter" "{}"'
##Store Validated files
find "${GH_REPO_PATH}/packages" -type f -iregex '.*\.validated$' > "${TMPDIR}/valid_pkgs.txt"
readarray -t "VALID_PKGS" < "${TMPDIR}/valid_pkgs.txt"
##Loop & Generate
for SBUILD in "${VALID_PKGS[@]}"; do
    #VALID_PKGSRC="$(echo "${SBUILD}" | sed -E 's|.*/packages/||; s|\.validated$||' | tr -d '[:space:]')"
    VALID_PKGSRC="$(echo "${SBUILD##*/packages/}" | tr -d '[:space:]')"
    PKG_VERSION="$(echo "${SBUILD}" | sed 's/\.validated$/.pkgver/' | xargs cat | tr -d '[:space:]')"
    yq . "${SBUILD}" | yj -yj | jq 'del(.x_exec)' | jq --arg PKG_VERSION "${PKG_VERSION:-}" \
      --arg VALID_PKGSRC "${VALID_PKGSRC:-}" \
  '{
   "_disabled": ._disabled,
   "pkg": .pkg,
   "pkg_id": (.pkg_id // ""),
   "pkg_type": (.pkg_type // ""),
   "app_id": (.app_id // ""),
   "description": .description,
   "note": (.note // []),
   "version": $PKG_VERSION,
   "download_url": ("https://soarpkgs.pkgforge.dev/packages/" + $VALID_PKGSRC),
   "size": "",
   "bsum": "",
   "shasum": "",
   "build_date": "",
   "repology": (.repology // ""),
   "src_url": (.src_url // []),
   "homepage": (.homepage // []),
   "build_script": ("https://github.com/pkgforge/soarpkgs/blob/main/packages/" + $VALID_PKGSRC),
   "build_log": "",
   "appstream": "",
   "category": (.category // []),
   "desktop": "",
   "icon": "",
   "license" : (.license // []),
   "provides": (.provides // []),
   "snapshots": (.snapshots // []),
   "tag": (.tag // []),
  }' | jq . > "${SBUILD}.json"
done
##Merge
find "${GH_REPO_PATH}/packages" -type f -iregex '.*\.validated.json$' -exec jq -s '.' {} + > "${TMPDIR}/METADATA.json.bak"
##Check
if jq --exit-status . "${TMPDIR}/METADATA.json.bak" >/dev/null 2>&1; then
   cat "${TMPDIR}/METADATA.json.bak" | jq -s '.' | jq 'walk(if type == "string" and . == "null" then "" else . end)' > "${TMPDIR}/METADATA.json"
fi
##Recheck
if jq --exit-status . "${TMPDIR}/METADATA.json" >/dev/null 2>&1; then
   cp -fv "${TMPDIR}/METADATA.json" "${SYSTMP}/SBUILD_METADATA.json"
fi
##END
#-------------------------------------------------------#