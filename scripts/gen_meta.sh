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
 #QSV
 timeout 30 eget "https://github.com/dathere/qsv" --asset "qsv" --asset "$(uname -m)" --asset "gnu" --asset "zip" --file "qsv" --to "${TMPDIR}/qsv"
 chmod +x "${TMPDIR}/qsv"
 if [[ ! -s "${TMPDIR}/qsv" || $(stat -c%s "${TMPDIR}/qsv") -le 1024 ]]; then
   echo -e "\n[✗] FATAL: qsv Appears to be NOT INSTALLED...\n"
  exit 1
 fi
 #curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_linter.sh" -o "${TMPDIR}/sbuild-linter"
 curl -qfsSL "https://api.gh.pkgforge.dev/repos/pkgforge/sbuilder/releases?per_page=100" | jq -r '.. | objects | .browser_download_url? // empty' | grep -Ei "$(uname -m)" | grep -Eiv "tar\.gz|\.b3sum" | grep -Ei "sbuild-linter" | sort --version-sort | tail -n 1 | tr -d '[:space:]' | xargs -I "{}" curl -qfsSL "{}" -o "${TMPDIR}/sbuild-linter"
 chmod +x "${TMPDIR}/sbuild-linter"
 if [[ ! -s "${TMPDIR}/sbuild-linter" || $(stat -c%s "${TMPDIR}/sbuild-linter") -le 1024 ]]; then
   echo -e "\n[✗] FATAL: sbuild-linter Appears to be NOT INSTALLED...\n"
  exit 1
 fi
#-------------------------------------------------------#

#-------------------------------------------------------#
##Validate everything
#First Run
find "${GH_REPO_PATH}/packages" -type f -iregex '.*\.\(yml\|yaml\)$' -print0 | xargs -0 "${TMPDIR}/sbuild-linter" --parallel "50" --fail "${TMPDIR}/INVALID_SBUILDS_01.txt" --pkgver
#Retry
cat "${TMPDIR}/INVALID_SBUILDS_01.txt" | xargs "${TMPDIR}/sbuild-linter" --parallel "50" --fail "${TMPDIR}/INVALID_SBUILDS_02.txt" --pkgver
#Retry without --pkgver
cat "${TMPDIR}/INVALID_SBUILDS_02.txt" | xargs "${TMPDIR}/sbuild-linter" --parallel "50" --fail "${TMPDIR}/INVALID_SBUILDS_03.txt"
#Log Output & Gen metadata
readarray -t "FAILED_SBUILD" < "${TMPDIR}/INVALID_SBUILDS_03.txt"
{
  for F_SBUILD in "${FAILED_SBUILD[@]}"; do
  echo '```bash'
   "${TMPDIR}/sbuild-linter" "${F_SBUILD}"
  echo '```'
  done
} >> "${TMPDIR}/INVALID_SBUILDS_log.txt" 2>&1
sed 's|.*/packages|https://github.com/pkgforge/soarpkgs/blob/main/packages|' "${TMPDIR}/INVALID_SBUILDS_log.txt" | ansi2txt | tee "${SYSTMP}/INVALID_SBUILDS.txt"
##Store Validated files
find "${GH_REPO_PATH}/packages" -type f -iregex '.*\.validated$' > "${TMPDIR}/valid_pkgs.txt"
readarray -t "VALID_PKGS" < "${TMPDIR}/valid_pkgs.txt"
##Loop & Generate
for SBUILD in "${VALID_PKGS[@]}"; do
    #VALID_PKGSRC="$(echo "${SBUILD}" | sed -E 's|.*/packages/||; s|\.validated$||' | tr -d '[:space:]')"
    VALID_PKGSRC="$(echo "${SBUILD##*/packages/}" | sed -E 's|\.validated$||' | tr -d '[:space:]')"
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
   cat "${TMPDIR}/METADATA.json.bak" | jq '.' | jq 'walk(if type == "string" and . == "null" then "" else . end)' | jq 'sort_by(.pkg)' > "${TMPDIR}/METADATA.json"
fi
##Recheck
if jq --exit-status . "${TMPDIR}/METADATA.json" >/dev/null 2>&1; then
   cp -fv "${TMPDIR}/METADATA.json" "${SYSTMP}/SBUILD_METADATA.json"
   if [[ -s "${SYSTMP}/SBUILD_METADATA.json" ]] && jq --exit-status '.' "${SYSTMP}/SBUILD_METADATA.json" > /dev/null 2>&1; then
    #Convert to Sqlite
     jq -c '.[]' "${SYSTMP}/SBUILD_METADATA.json" > "${TMPDIR}/SBUILD_METADATA.jsonl"
     "${TMPDIR}/qsv" jsonl "${TMPDIR}/SBUILD_METADATA.jsonl" > "${TMPDIR}/SBUILD_METADATA.csv"
     "${TMPDIR}/qsv" to sqlite "${SYSTMP}/SBUILD_METADATA.db" "${TMPDIR}/SBUILD_METADATA.csv"
   fi
fi
##END
#-------------------------------------------------------#