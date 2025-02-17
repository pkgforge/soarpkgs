#!/usr/bin/env bash

#-------------------------------------------------------#
## <DO NOT RUN STANDALONE, meant for CI Only>
## Meant to Set Env for Build
# FUNCS:
#  --> setup_env "/path/to/sbuild"
#  --> check_sane_env
#  --> gen_json_from_sbuild
#  --> build_progs
#  --> generate_json
#  --> upload_to_ghcr
#  --> cleanup_env
## Self: https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/.github/scripts/ci/helpers.sh
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/.github/scripts/ci/helpers.sh")
#-------------------------------------------------------#

#-------------------------------------------------------#
##Sets Dirs & Vars
setup_env()
{
 ##Version
 SBH_VERSION="0.0.1" && echo -e "[+] SBUILD Helpers Version: ${SBH_VERSION}" ; unset SBH_VERSION
 ##Input    
 INPUT_SBUILD="${1:-$(echo "$@" | tr -d '[:space:]')}"
 INPUT_SBUILD_PATH="$(realpath ${INPUT_SBUILD})" ; export INPUT_SBUILD="${INPUT_SBUILD_PATH}"
 if [[ ! -s "${INPUT_SBUILD}" || $(stat -c%s "${INPUT_SBUILD}") -le 10 ]]; then
   echo -e "\n[✗] FATAL: SBUILD (${INPUT_SBUILD}) seems Broken\n"
   export CONTINUE_SBUILD="NO"
  return 1 || exit 1
 fi
 BUILD_DIR="$(mktemp -d --tmpdir=${SYSTMP}/pkgforge XXXXXXX_$(basename "${INPUT_SBUILD}" | tr -d 'X'))"
 SBUILD_OUTDIR="${BUILD_DIR}/SBUILD_OUTDIR"
 SBUILD_TMPDIR="${SBUILD_OUTDIR}/SBUILD_TEMP"
 mkdir -p "${SBUILD_TMPDIR}/tmp"
 export BUILD_DIR INPUT_SBUILD SBUILD_OUTDIR SBUILD_TMPDIR
 #echo -e "\n[+] Building ["$(echo "${RECIPE}" | awk -F'/' '{print $(NF-1) "/" $NF}')"] (${INPUT_SBUILD}) --> ${SBUILD_OUTDIR} [$(TZ='UTC' date +'%A, %Y-%m-%d (%I:%M:%S %p)') UTC]\n"
 echo -e "\n[+] Building (${SBUILD_SCRIPT_BLOB:-${RECIPE}}) --> ${SBUILD_OUTDIR} [$(TZ='UTC' date +'%A, %Y-%m-%d (%I:%M:%S %p)') UTC]\n"
 echo -e "\n" && echo '###################################################################' && \
 cat "${INPUT_SBUILD}" && echo -e "\n" && echo '###################################################################' && echo -e "\n\n"
 cp -fv "${INPUT_SBUILD}" "${SBUILD_OUTDIR}/SBUILD"
 echo "export INPUT_SBUILD='${INPUT_SBUILD}'" > "${OCWD}/ENVPATH"
 echo "export BUILD_DIR='${BUILD_DIR}'" >> "${OCWD}/ENVPATH"
 echo "export SBUILD_OUTDIR='${SBUILD_OUTDIR}'" >> "${OCWD}/ENVPATH"
 echo "export SBUILD_TMPDIR='${SBUILD_TMPDIR}'" >> "${OCWD}/ENVPATH"
}
export -f setup_env
#-------------------------------------------------------#

#-------------------------------------------------------#
##Checks if needed vars,files & dirs exist
check_sane_env()
{
  unset CONTINUE_SBUILD
  if [[ -z "${INPUT_SBUILD//[[:space:]]/}" ]] || \
   [[ ! -d "${OCWD}" ]] || \
   [[ ! -d "${SBUILD_TMPDIR}" ]]; then
   echo -e "\n[✗] FATAL: CAN NOT CONTINUE\n"
   export CONTINUE_SBUILD="NO"
   return 1 || exit 1
  else
   export CONTINUE_SBUILD="YES"
  fi
}
export -f check_sane_env
#-------------------------------------------------------#

#-------------------------------------------------------#
##Cleanup & Purge Containers
cleanup_containers()
{
 #Alpine 
  ( docker stop "alpine-builder" >/dev/null 2>&1 ; docker rm "alpine-builder" >/dev/null 2>&1 ) &>/dev/null
  ( sudo docker stop "alpine-builder" >/dev/null 2>&1 ; sudo docker rm "alpine-builder" >/dev/null 2>&1 ) &>/dev/null
 #Alpine-mimalloc 
  ( docker stop "alpine-builder-mimalloc" >/dev/null 2>&1 ; docker rm "alpine-builder-mimalloc" >/dev/null 2>&1 ) &>/dev/null
  ( sudo docker stop "alpine-builder-mimalloc" >/dev/null 2>&1 ; sudo docker rm "alpine-builder-mimalloc" >/dev/null 2>&1 ) &>/dev/null
 #Archlinux 
  ( docker stop "archlinux-builder" >/dev/null 2>&1 ; docker rm "archlinux-builder" >/dev/null 2>&1 ) &>/dev/null
  ( sudo docker stop "archlinux-builder" >/dev/null 2>&1 ; sudo docker rm "archlinux-builder" >/dev/null 2>&1 ) &>/dev/null
 #Debian 
  ( docker stop "debian-builder" >/dev/null 2>&1 ; docker rm "debian-builder" >/dev/null 2>&1 ) &>/dev/null
  ( sudo docker stop "debian-builder" >/dev/null 2>&1 ; sudo docker rm "debian-builder" >/dev/null 2>&1 ) &>/dev/null
 #Debian-Unstable 
  ( docker stop "debian-builder-unstable" >/dev/null 2>&1 ; docker rm "debian-builder-unstable" >/dev/null 2>&1 ) &>/dev/null
  ( sudo docker stop "debian-builder-unstable" >/dev/null 2>&1 ; sudo docker rm "debian-builder-unstable" >/dev/null 2>&1 ) &>/dev/null
 #Ubuntu 
  ( docker stop "ubuntu-builder" >/dev/null 2>&1 ; docker rm "ubuntu-builder" >/dev/null 2>&1 ) &>/dev/null
  ( sudo docker stop "ubuntu-builder" >/dev/null 2>&1 ; sudo docker rm "ubuntu-builder" >/dev/null 2>&1 ) &>/dev/null
 #Cleanup 
  wait >/dev/null 2>&1 ; echo
}
export -f cleanup_containers
#-------------------------------------------------------#

#-------------------------------------------------------#
##Fetch Version (Upstream) (.version_upstream)
fetch_version_upstream()
{
 #Clear env
 unset PKG_VERSION_UPSTREAM
 #Check if it's even needed
 if echo "${SBUILD_PKGVER}" | grep -q '^HEAD-'; then
  #Fetch from Build Output
   if [[ -s "${SBUILD_TMPDIR}/upstream.version" && $(stat -c%s "${SBUILD_TMPDIR}/upstream.version") -gt 3 ]]; then
     PKG_VERSION_UPSTREAM="$(cat "${SBUILD_TMPDIR}/upstream.version" | tr -d '[:space:]')" ; export PKG_VERSION_UPSTREAM
     #Check
     if [ -n "${PKG_VERSION_UPSTREAM+x}" ] && [ "$(printf '%s' "${PKG_VERSION_UPSTREAM}" | tr -d '[:space:]' | wc -c)" -gt 2 ]; then
       echo -e "[+] Upstream Version: ${PKG_VERSION_UPSTREAM} ('.SBUILD') [${SBUILD_TMPDIR}/upstream.version]"
     else
       echo -e "[-] WARNING: Could NOT Fetch Version from Upstream ('.SBUILD') <== [${SBUILD_TMPDIR}/upstream.version]"
       export PKG_VERSION_UPSTREAM=""
       #PKG_VERSION_UPSTREAM="UNKNOWN-$(date --utc +'%y%m%dT%H%M%S')" ; export PKG_VERSION_UPSTREAM
     fi
  #Fetch from Repology
   elif [[ -n "${PKG_REPOLOGY[*]}" && "${#PKG_REPOLOGY[@]}" -gt 0 ]]; then
     unset REPOLOGY_PKGVER REPOLOGY_PKG REPOLOGY_VER ; declare -a REPOLOGY_PKGVER=()
     for REPOLOGY_PKG in "${PKG_REPOLOGY[@]}"; do
      {
       #curl -A "${USER_AGENT}" -qfsSL "https://api.rl.pkgforge.dev/api/v1/project/${REPOLOGY_PKG}"
       REPOLOGY_VER="$(curl -A "${USER_AGENT}" -qfsSL "https://repology.org/api/v1/project/${REPOLOGY_PKG}" 2>/dev/null | jq -r '.. | objects | select(has("version") and ((.. | objects | .repo? | select(. != null)) as $repo |["appget", "baulk", "choco", "chrome", "cygwin", "droid", "macports", "mysys2", "npackd", "opam", "pypi", "ruby", "scoop", "vcpkg", "winget", "yacp"] | index($repo) | not)) | .version' 2>/dev/null | grep -vE '^[A-Za-z]+$|^(.)\1*$' 2>/dev/null | grep -vE '\.[0-9a-f]{6,}$|[0-9a-f]{7,}$' 2>/dev/null | sort --version-sort --unique 2>/dev/null | tail -n 1 2>/dev/null | tr -d '[:space:]' 2>/dev/null)"
       if [ -n "${REPOLOGY_VER+x}" ] && [[ "${REPOLOGY_VER}" =~ ^[^[:space:]]+$ ]]; then
         REPOLOGY_PKGVER+=("${REPOLOGY_VER}")
       fi
      } 2>/dev/null
     done
     PKG_VERSION_UPSTREAM="$(printf "%s\n" "${REPOLOGY_PKGVER[@]}" | sort --version-sort --unique | tail -n 1 | tr -d '[:space:]')"
     unset REPOLOGY_PKGVER REPOLOGY_PKG REPOLOGY_VER ; export PKG_VERSION_UPSTREAM
    #Check
     if [ -n "${PKG_VERSION_UPSTREAM+x}" ] && [ "$(printf '%s' "${PKG_VERSION_UPSTREAM}" | tr -d '[:space:]' | wc -c)" -gt 2 ]; then
       echo -e "[+] Upstream Version: ${PKG_VERSION_UPSTREAM} ('.repology') [${PKG_REPOLOGY[*]}]" ; unset PKG_REPOLOGY
     else
       export PKG_VERSION_UPSTREAM=""
       #PKG_VERSION_UPSTREAM="UNKNOWN-$(date --utc +'%y%m%dT%H%M%S')" ; export PKG_VERSION_UPSTREAM
       echo -e "[-] WARNING: Could NOT Fetch Version from Upstream ('.repology') [${PKG_REPOLOGY[*]}]" ; unset PKG_REPOLOGY
     fi
   fi
 elif [ -n "${SBUILD_PKGVER+x}" ] && [ "$(printf '%s' "${SBUILD_PKGVER}" | tr -d '[:space:]' | wc -c)" -gt 2 ];then
   export PKG_VERSION_UPSTREAM="${SBUILD_PKGVER}"
   echo -e "[+] Upstream Version: ${PKG_VERSION_UPSTREAM} <==> \${SBUILD_PKGVER} [${SBUILD_OUTDIR}/${SBUILD_PKG}.version]"
 fi
}
export -f fetch_version_upstream
#-------------------------------------------------------#

#-------------------------------------------------------#
##Gen Json (SBUILD)
gen_json_from_sbuild()
{
 #Env
  check_sane_env
  if [[ "${CONTINUE_SBUILD}" == "YES" ]]; then
   TMPXVER="${BUILD_DIR}/SBUILD_VER.sh"
   TMPXRUN="${BUILD_DIR}/SBUILD_RUN.sh"
   TMPJSON="${BUILD_DIR}/SBUILD_RAW.json"
   export TMPJSON TMPXVER TMPXRUN
  #Gen
   yq eval "." "${INPUT_SBUILD}" --output-format "json" | jq 'del(.x_exec)' > "${TMPJSON}"
   if jq --exit-status . "${TMPJSON}" >/dev/null 2>&1; then
    ##Check & Set
     if [[ "$(yq '._disabled' "${INPUT_SBUILD}")" == "true" ]]; then
       echo -e "\n[✗] FATAL: SBUILD (${INPUT_SBUILD}) is Disabled ('_disabled: true')\n"
       yq 'select(has("_disabled_reason")) | .["_disabled_reason"]' "${INPUT_SBUILD}"
         export CONTINUE_SBUILD="NO"
         return 1 || exit 1
     else
       if yq e '.x_exec.host != null' "${INPUT_SBUILD}" | grep -qi 'true'; then
         if ! yq '.x_exec.host[]' "${INPUT_SBUILD}" | grep -v '^#' | grep -qi "${HOST_TRIPLET,,}"; then
           echo -e "\n[✗] WARNING: SBUILD (${INPUT_SBUILD}) is NOT Supported on ${HOST_TRIPLET}\n"
           yq '.x_exec.host[]' "${INPUT_SBUILD}"
           export CONTINUE_SBUILD="NO"
           return 0 || exit 0
         fi
       else
         echo -e "\n[✗] WARNING: SBUILD (${INPUT_SBUILD}) is DOES NOT Specify Any '.x_exec.host'"
         echo -e "[+] Assuming '.x_exec.host' ==> ${HOST_TRIPLET}\n"
       fi
       pkg="$(jq -r '"\(.pkg | select(. != "null") // "")"' "${TMPJSON}" | sed 's/\.$//' | tr -d '[:space:]')" ; export PKG="${pkg}"
       pkg_id="$(jq -r '"\(.pkg_id | select(. != "null") // "")"' "${TMPJSON}" | sed 's/\.$//' | tr -d '[:space:]')" ; export PKG_ID="${pkg_id}"
       pkg_type="$(jq -r '"\(.pkg_type | select(. != "null") // "")"' "${TMPJSON}" | sed 's/\.$//' | tr -d '[:space:]')" ; export PKG_TYPE="${pkg_type}"
       unset PKG_REPOLOGY ; PKG_REPOLOGY=()
       PKG_REPOLOGY=("$(jq -r 'if has("repology") then (if .repology | type == "array" then .repology[0] else .repology end) else "" end' "${TMPJSON}" 2>/dev/null | tr -d '[:space:]')")
       [[ "${PKG_REPOLOGY}" == "null" ]] && unset PKG_REPOLOGY
       if [ -n "${PKG_REPOLOGY+x}" ] && [[ "${PKG_REPOLOGY}" =~ ^[^[:space:]]+$ ]]; then
         PKG_REPOLOGY=($(printf "%s\n" "${PKG_REPOLOGY[@]}" 2>/dev/null | grep -iv 'null' | sort | uniq)) 
         export PKG_REPOLOGY
       else
         export PKG_REPOLOGY=""
       fi
       SBUILD_PKG="$(echo "${pkg}.${pkg_type}" | sed 's/\.$//' | tr -d '[:space:]')"
       export pkg pkg_id pkg_type SBUILD_PKG
       echo "export SBUILD_PKG='${SBUILD_PKG}'" >> "${OCWD}/ENVPATH"
       echo "export SBUILD_PKG_ID='${PKG_ID}'" >> "${OCWD}/ENVPATH"
       if [ "$(echo "${SBUILD_PKG}" | tr -d '[:space:]' | wc -c | tr -cd '0-9')" -le 1 ]; then
         echo -e "\n[✗] FATAL: ${SBUILD_PKG} ('.pkg+.pkg_type') is less than 1 Character\n"
         export CONTINUE_SBUILD="NO"
         return 1 || exit 1
       fi
     fi
     #Shell
      SBUILD_SHELL="$(yq '.x_exec.shell' "${INPUT_SBUILD}")"
     #Version 
      if yq eval '.pkgver | length > 0' "${INPUT_SBUILD}" | grep -q true; then
       SBUILD_PKGVER="$(yq eval '.pkgver' "${INPUT_SBUILD}" | tr -d '[:space:]')" ; export SBUILD_PKGVER
       echo "${SBUILD_PKGVER}" > "${SBUILD_OUTDIR}/${SBUILD_PKG}.version"
       echo -e "[+] Version: ${SBUILD_PKGVER} ('.pkgver') [${SBUILD_OUTDIR}/${SBUILD_PKG}.version]"
       export CONTINUE_SBUILD="YES"
      else
       echo -e '#!/usr/bin/env '"${SBUILD_SHELL}"'\n\n' > "${TMPXVER}"
       yq '.x_exec.pkgver' "${INPUT_SBUILD}" >> "${TMPXVER}"
       if [[ -s "${TMPXVER}" && $(stat -c%s "${TMPXVER}") -gt 10 ]]; then
         if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
           chmod +x "${TMPXVER}"
           {
            timeout -k 10s 60s "${TMPXVER}"
           } > "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" 2>/dev/null ; sleep 1
         else
           chmod +x "${TMPXVER}"
           {
            timeout -k 10s 60s "${TMPXVER}"
           } > "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" 2>&1 ; sleep 1
         fi
         if [[ -s "${SBUILD_OUTDIR}/${PKG}.version" && $(stat -c%s "${SBUILD_OUTDIR}/${PKG}.version") -gt 2 ]]; then
           cp -fv "${SBUILD_OUTDIR}/${PKG}.version" "${SBUILD_OUTDIR}/${SBUILD_PKG}.version"
         elif [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version") -gt 2 ]]; then
           cp -fv "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" "${SBUILD_OUTDIR}/${PKG}.version"
         fi
         if [[ ! -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" || $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version") -le 1 ]]; then
           echo -e "\n[✗] FATAL: Failed to Fetch Version ('x_exec.pkgver')\n"
           cat "${TMPXVER}" ; echo ; cat "${SBUILD_OUTDIR}/${SBUILD_PKG}.version"
           export CONTINUE_SBUILD="NO"
           return 1 || exit 1
         else
           SBUILD_PKGVER="$(cat "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" | tr -d '[:space:]')" ; export SBUILD_PKGVER
           if echo "${SBUILD_PKGVER}" | grep -qi "parserror"; then
             echo -e "\n[✗] FATAL: Failed to Parse ('x_exec.pkgver')\n"
             echo "${SBUILD_PKGVER}" ; echo ; cat "${TMPXVER}"
             export CONTINUE_SBUILD="NO"
             return 1 || exit 1
           else
             echo -e "[+] Version: ${SBUILD_PKGVER} ('.x_exec.pkgver') [${SBUILD_OUTDIR}/${SBUILD_PKG}.version]"
             if [[ "${SBUILD_REBUILD}" == "true" ]]; then
               echo -e "\n[+] Re Building: ${SBUILD_PKG} [${SBUILD_PKGVER}]"
               echo -e "[+] Re Run with: '.rebuild == false'"
             fi
           fi
         fi
       else
         echo -e "\n[✗] FATAL: Failed to Extract ('x_exec.pkgver')\n"
         cat "${INPUT_SBUILD}" ; echo ; cat "${TMPXVER}"
         export CONTINUE_SBUILD="NO"
         return 1 || exit 1
       fi
      fi
     #Run
      echo -e '#!/usr/bin/env '"${SBUILD_SHELL}"'\n\n' > "${TMPXRUN}"
      if [[ "${DEBUG_BUILD}" != "NO" ]]; then
       if [[ "${SBUILD_SHELL}" == "bash" ]]; then
         echo 'set -x' >> "${TMPXRUN}"
         #echo 'export SHELLOPTS' >> "${TMPXRUN}"
       elif [[ "${SBUILD_SHELL}" == "fish" ]]; then  
         echo 'set fish_trace 1' >> "${TMPXRUN}"
         echo 'set -g fish_trace 1' >> "${TMPXRUN}"
       elif [[ "${SBUILD_SHELL}" == "sh" ]]; then
         echo 'set -x' >> "${TMPXRUN}"
       elif [[ "${SBUILD_SHELL}" == "zsh" ]]; then
         echo 'setopt xtrace' >> "${TMPXRUN}"
         echo 'export SHELLOPTS' >> "${TMPXRUN}"
       fi
      fi
      yq '.x_exec.run' "${INPUT_SBUILD}" >> "${TMPXRUN}"
      if [[ -s "${TMPXRUN}" && $(stat -c%s "${TMPXRUN}") -gt 10 ]]; then
       chmod +x "${TMPXRUN}"
      else
        echo -e "\n[✗] FATAL: Failed to Extract ('x_exec.run')\n"
        cat "${INPUT_SBUILD}" ; echo ; cat "${TMPXRUN}"
        export CONTINUE_SBUILD="NO"
        return 1 || exit 1
      fi
   else
    echo -e "\n[✗] FATAL: Could NOT parse ${INPUT_SBUILD} ==> ${TMPJSON}\n"
    return 1 || exit 1
    export CONTINUE_SBUILD="NO"
   fi
  fi
}
export -f gen_json_from_sbuild
#-------------------------------------------------------#

#-------------------------------------------------------#
##Build Progs
build_progs()
{
unset SBUILD_SUCCESSFUL
if [[ "${CONTINUE_SBUILD}" == "YES" ]]; then
 if jq --exit-status . "${TMPJSON}" >/dev/null 2>&1; then
 #Additional Env
  PKGVER="${SBUILD_PKGVER}" ; pkgver="${PKGVER}"
  PKG_VER="${SBUILD_PKGVER}" ; pkg_ver="${PKG_VER}"
  export pkgver PKGVER pkg_ver PKG_VER
 #Get Progs
  if jq -e '.provides // empty' "${TMPJSON}" > /dev/null; then
   SBUILD_PKGS=()
   SBUILD_PKGS=($(jq -r '.provides[]' "${TMPJSON}" | awk -F'[:=]' '{print $1}'))
   SBUILD_PKGS+=("${PKG}")
   SBUILD_PKGS=($(printf "%s\n" "${SBUILD_PKGS[@]}" | sort | uniq)) ; export SBUILD_PKGS
   echo -e "[+] Progs: ${SBUILD_PKGS[*]}"
  else
   SBUILD_PKGS=("${PKG}") ; export SBUILD_PKGS
   echo -e "[+] Progs: ${SBUILD_PKGS[*]}"
  fi
  printf "export SBUILD_PKGS='%s'\n" "${SBUILD_PKGS[*]}" >> "${OCWD}/ENVPATH"
 #check rebuild
  declare -a FOUND_ARTIFACTS=()
  if [ -n "${GHCRPKG+x}" ] && [[ "${GHCRPKG}" =~ ^[^[:space:]]+$ ]]; then
    unset GHCRPKG_TAG; GHCRPKG_TAG="$(echo "${SBUILD_PKGVER}-${HOST_TRIPLET,,}" | sed 's/[^a-zA-Z0-9._-]/_/g; s/_*$//')" ; export GHCRPKG_TAG
    for PROG in "${SBUILD_PKGS[@]}"; do
      if [[ "${PROG}" =~ [^a-zA-Z0-9_+.-] ]]; then
       echo -e "\n[-] WARNING: ${PROG} contains Special Chars\n"
      fi
      oras manifest fetch "${GHCRPKG}/${PROG}:${GHCRPKG_TAG}" 2>/dev/null | jq . > "${SBUILD_TMPDIR}/MANIFEST.json"
      if [[ "$(jq -r '.annotations["org.opencontainers.image.version"]' "${SBUILD_TMPDIR}/MANIFEST.json")" == "${SBUILD_PKGVER}" ]]; then
         if [[ "$(jq -r '.. | .["org.opencontainers.image.title"]? // empty' "${SBUILD_TMPDIR}/MANIFEST.json" | sort -u | grep -E "^${PROG}$" | tr -d '[:space:]')" == "${PROG}" ]]; then
           if [[ "${SBUILD_REBUILD}" == "false" ]] && [[ "${FORCE_REBUILD_ALL}" != "YES" ]]; then
             echo -e "\n[+] FOUND: ${SBUILD_PKG} [${GHCRPKG}/${PROG}:${GHCRPKG_TAG}] (PreBuilt Exists)"
             FOUND_ARTIFACTS+=("${PROG}")
             export SBUILD_SKIPPED="YES"
             export CONTINUE_SBUILD="NO"
           fi
         else
           echo -e "\n[+] TAG: ${SBUILD_PKG} [${GHCRPKG}/${PROG}:${GHCRPKG_TAG}] (PreBuilt Exists)"
           echo -e "==> ARTIFACTS: \n$(jq -r '.. | .["org.opencontainers.image.title"]? // empty' "${SBUILD_TMPDIR}/MANIFEST.json" | sort -u)\n"
           echo -e "[-] FATAL: PROG ${PROG} DOES NOT Exist (Last Build Failed?)"
           echo -e "[+] Re Building: ${SBUILD_PKG} [${SBUILD_PKGVER}]\n"
           export CONTINUE_SBUILD="YES"
           break
         fi
      fi
    done
    if [[ "${#FOUND_ARTIFACTS[@]}" -eq "${#SBUILD_PKGS[@]}" ]]; then
     echo -e "\n[+] SKIPPED: All packages found with correct versions"
     echo -e "==> ARTIFACTS: \n$(jq -r '.. | .["org.opencontainers.image.title"]? // empty' "${SBUILD_TMPDIR}/MANIFEST.json" | sort -u)\n"
     echo -e "[+] ReRun with: '.rebuild == true'"
     echo -e "[+] Or: SBUILD_REBUILD=\"true\""
     echo -e "[+] Or: Re Build Everything: FORCE_REBUILD_ALL=\"YES\" sbuild-builder\n"
     export SBUILD_SKIPPED="YES"
     export CONTINUE_SBUILD="NO"
    else
     echo -e "\n[-] Missing packages. Found: ${FOUND_ARTIFACTS[*]}"
     echo -e "[+] Expected: ${SBUILD_PKGS[*]}"
     echo -e "[+] Continuing with build...\n"
     export CONTINUE_SBUILD="YES"
    fi
    unset FOUND_ARTIFACTS
  fi
 #Run
  if [[ "${CONTINUE_SBUILD}" == "YES" ]]; then
   check_sane_env
   pushd "${SBUILD_OUTDIR}" >/dev/null 2>&1
     #printf "\n" && timeout -k 5m 150m "${TMPXRUN}" ; printf "\n"
     cleanup_containers
     printf "\n" && timeout -k 5m 150m sbuild --log-level "verbose" "${INPUT_SBUILD}" --timeout-linter "120" --outdir "${SBUILD_OUTDIR}/BUILD" --keep
     printf "\n" && cleanup_containers
     sudo chown -Rv "$(whoami):$(whoami)" "${SBUILD_OUTDIR}" 2>/dev/null
     find "${SBUILD_OUTDIR}" -type f -exec sudo chmod -v +xwr "{}" \; 2>/dev/null
     unset ARTIFACTS_DIR ; ARTIFACTS_DIR="$(find "${SBUILD_OUTDIR}/BUILD" -name "SBUILD" -type f -exec dirname "{}" \; | xargs realpath | head -n 1 | tr -d '[:space:]')"
     if [ -d "${ARTIFACTS_DIR}" ] && [ $(du -s "${ARTIFACTS_DIR}" | cut -f1) -gt 10 ]; then
       rsync -achL "${ARTIFACTS_DIR}/." "${SBUILD_OUTDIR}"
       rm -rf "${SBUILD_OUTDIR}/BUILD.log" 2>/dev/null
       rm -rf "${ARTIFACTS_DIR}" 2>/dev/null
     fi
     if [ -d "${SBUILD_OUTDIR}" ] && [ $(du -s "${SBUILD_OUTDIR}" | cut -f1) -gt 10 ]; then
      #Rename/strip
       find "${SBUILD_OUTDIR}" -maxdepth 1 -type f -exec file -i "{}" \; |\
       grep "application/.*executable" | cut -d":" -f1 | xargs realpath | sort -u |\
       xargs -I "{}" bash -c '
         base=$(basename "{}")
         dir=$(dirname "{}")
         if [[ "$base" == *.no_strip ]]; then
           new_name="${base%.no_strip}"
           mv -fv "{}" "${dir}/${new_name}"
         fi
         if echo "${PKG_TYPE}" | grep -qi "static" ; then
           objcopy --remove-section=".comment" --remove-section=".note.*" "{}"
           strip --strip-debug --strip-dwo --strip-unneeded "{}"
         fi
       '
      #License
       if jq --exit-status . "${TMPJSON}" >/dev/null 2>&1; then
         if [[ ! -s "${SBUILD_OUTDIR}/LICENSE" || $(stat -c%s "${SBUILD_OUTDIR}/LICENSE") -le 10 ]]; then
           echo -e "\n[+] Fetching LICENSE ==> [${SBUILD_OUTDIR}/LICENSE]"
           unset LICENSE_SRC TMP_LICENSE
           LICENSE_SRC=()
           LICENSE_SRC=("$(jq -r 'if .license and (.license | type == "array") and (.license[0] | type == "object") then if ([.license[] | select(.id and .url)] | length > 0) then [.license[] | select(.id and .url) | .url] | .[] elif ([.license[] | select(.id and .file)] | length > 0) then [.license[] | select(.id and .file) | .file] | .[] else empty end else empty end' ${TMPJSON})")
           if [ ${#LICENSE_SRC[@]} -ne 0 ]; then
             for TMP_LICENSE in "${LICENSE_SRC[@]}"; do
              if [ -n "${TMP_LICENSE+x}" ] && [[ "${TMP_LICENSE}" =~ ^[^[:space:]]+$ ]]; then
               if echo "${TMP_LICENSE}" | grep -qE '^https?://'; then
                 curl -w "(License) <== %{url}\n" -fL "${TMP_LICENSE}" -o "${SBUILD_TMPDIR}/LICENSE" 2>/dev/null
                 if [[ -s "${SBUILD_TMPDIR}/LICENSE" && $(stat -c%s "${SBUILD_TMPDIR}/LICENSE") -gt 10 ]]; then
                   mv -fv "${SBUILD_TMPDIR}/LICENSE" "${SBUILD_OUTDIR}/LICENSE" 2>/dev/null
                  break
                 fi
               elif [[ -s "${SBUILD_OUTDIR}/${TMP_LICENSE}" && $(stat -c%s "${SBUILD_OUTDIR}/${TMP_LICENSE}") -gt 10 ]]; then
                   mv -fv "${SBUILD_OUTDIR}/${TMP_LICENSE}" "${SBUILD_OUTDIR}/LICENSE" 2>/dev/null
                  break
               fi
              fi
             done
             if [[ ! -s "${SBUILD_OUTDIR}/LICENSE" || $(stat -c%s "${SBUILD_OUTDIR}/LICENSE") -le 10 ]]; then
               echo -e "[-] WARNING: No Valid LICENSE Exists at ${SBUILD_OUTDIR}/LICENSE"
             elif [[ -s "${SBUILD_OUTDIR}/LICENSE" && $(stat -c%s "${SBUILD_OUTDIR}/LICENSE") -gt 10 ]]; then
               echo -e "\n" && cat "${SBUILD_OUTDIR}/LICENSE" && echo -e "\n"
             fi
           else
             echo -e "[-] No Valid SRC for LICENSE Exists in ${SBUILD_SCRIPT_BLOB:-${RECIPE}}"
           fi
           unset LICENSE_SRC TMP_LICENSE
         else
           echo -e "\n[+] Found LICENSE ==> [${SBUILD_OUTDIR}/LICENSE]"
           echo -e "\n" && cat "${SBUILD_OUTDIR}/LICENSE" && echo -e "\n"
         fi
       fi
      #Sanity
       find "${SBUILD_OUTDIR}" -type f -exec touch "{}" \;
       find "${SBUILD_OUTDIR}" -maxdepth 1 -type f -print | sort -u | xargs -I "{}" sh -c 'printf "\nFile: $(basename {})\n  Type: $(file -b {})\n  B3sum: $(b3sum {} | cut -d" " -f1)\n  SHA256sum: $(sha256sum {} | cut -d" " -f1)\n  Size: $(du -sh {} | cut -f1)\n"'
      #Checksum
       echo -e "\n[+] Generating (b3sum) Checksums ==> [${SBUILD_OUTDIR}/CHECKSUM]"
       find "${SBUILD_OUTDIR}" -maxdepth 1 -type f ! -iname "*CHECKSUM*" -exec b3sum "{}" + | awk '{gsub(".*/", "", $2); print $2 ":" $1}' | tee "${SBUILD_OUTDIR}/CHECKSUM"
       sed 's/\.\(appimage\|appbundle\|dynamic\|flatimage\|gameimage\|nixappimage\|runimage\|static\)//g' -i "${SBUILD_OUTDIR}/CHECKSUM"
      #Sign
       if [[ "${HAS_MINISIGN}" == "YES" ]]; then
         echo -e "\n[+] Signing ${SBUILD_PKG}"
         find "${SBUILD_OUTDIR}" -maxdepth 1 -type f ! -name "*.sig" -print0 | sort -zu | xargs -0 -I "{}" minisign -Sm "{}" -P "${MINISIGN_PUB_KEY}" -s "${HOME}/.minisign/minisign.key" -x "{}.sig"
         #find "${SBUILD_OUTDIR}" -maxdepth 1 -type f -name "*.sig" -exec bash -c 'printf "==> %s\n" "$(basename "{}")"' \; | sort -u
       fi
      #End
       export SBUILD_SUCCESSFUL="YES"
       echo "export SBUILD_SUCCESSFUL='${SBUILD_SUCCESSFUL}'" >> "${OCWD}/ENVPATH"
       [[ "${GHA_MODE}" == "MATRIX" ]] && echo "SBUILD_SUCCESSFUL=${SBUILD_SUCCESSFUL}" >> "${GITHUB_ENV}"
       echo -e "\n[✓] SuccessFully Built ${SBUILD_PKG} using ${SBUILD_SCRIPT_BLOB:-${INPUT_SBUILD}} [$(TZ='UTC' date +'%A, %Y-%m-%d (%I:%M:%S %p)') UTC]\n"
       echo -e "[+] Total Size: $(du -sh "${SBUILD_OUTDIR}" 2>/dev/null | awk '{print $1}' 2>/dev/null) (Includes DUPES+TMPFILES)"
       if [ -d "${OCWD}" ]; then
         echo -e "[+] LOGPATH='${SBUILD_OUTDIR}/${SBUILD_PKG}.log'"
         echo -e "[+] ENVPATH=$(realpath "${OCWD}/ENVPATH")"
         echo "export LOGPATH='${SBUILD_OUTDIR}/${SBUILD_PKG}.log'" >> "${OCWD}/ENVPATH"
       fi
       if [[ $(cat "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" | tr -d '[:space:]') != "${SBUILD_PKGVER}" ]]; then
         SBUILD_PKGVER="$(cat ${SBUILD_OUTDIR}/${SBUILD_PKG}.version)" ; export SBUILD_PKGVER
         echo -e "[+] Resetting Version: ${SBUILD_PKGVER} <== [${SBUILD_OUTDIR}/${SBUILD_PKG}.version]"
       fi
     else
       echo -e "\n[✗] FATAL: Could NOT Build ${SBUILD_PKG} using ${INPUT_SBUILD} [${SBUILD_SCRIPT_BLOB}]\n"
       echo -e "\n[+] Working Dir: $(realpath ${SBUILD_OUTDIR})"
       echo "[+] Version [${SBUILD_OUTDIR}/${SBUILD_PKG}.version] ==> $(cat "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" 2>/dev/null)"
       ls "${SBUILD_OUTDIR}" -lah
       export SBUILD_SUCCESSFUL="NO"
       echo "export SBUILD_SUCCESSFUL='${SBUILD_SUCCESSFUL}'" >> "${OCWD}/ENVPATH"
       [[ "${GHA_MODE}" == "MATRIX" ]] && echo "SBUILD_SUCCESSFUL=${SBUILD_SUCCESSFUL}" >> "${GITHUB_ENV}"
       cleanup_env ; return 1 || exit 1
     fi
   popd >/dev/null 2>&1
  fi
 else
   echo -e "\n[✗] FATAL: Could NOT parse ${INPUT_SBUILD} ==> ${TMPJSON}\n"
   export SBUILD_SUCCESSFUL="NO"
   echo "export SBUILD_SUCCESSFUL='${SBUILD_SUCCESSFUL}'" >> "${OCWD}/ENVPATH"
   [[ "${GHA_MODE}" == "MATRIX" ]] && echo "SBUILD_SUCCESSFUL=${SBUILD_SUCCESSFUL}" >> "${GITHUB_ENV}"
   cleanup_env ; return 1 || exit 1
 fi
fi
}
export -f build_progs
#-------------------------------------------------------#

#-------------------------------------------------------#
##Generate ghcrpkg_url
generate_ghcrpkgurl()
{
 unset GHCRPKG_URL
 if [ -n "${GHCRPKG+x}" ] && [[ "${GHCRPKG}" =~ ^[^[:space:]]+$ ]]; then
   GHCRPKG_URL="$(echo "${GHCRPKG}/${PROG}" | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')" ; export GHCRPKG_URL
 elif [[ -n "${PKG_REPO}" && "${PKG_REPO}" =~ ^[^[:space:]]+$ ]] && [[ -n "${PKG_FAMILY}" && "${PKG_FAMILY}" =~ ^[^[:space:]]+$ ]] || [[ -n "${PKG_NAME}" && "${PKG_NAME}" =~ ^[^[:space:]]+$ ]]; then
   GHCRPKG_URL="ghcr.io/${GITHUB_REPOSITORY}/${PKG_FAMILY:-${PKG_NAME}}/${PKG_NAME:-${PKG_FAMILY:-${PKG_ID}}}"
   GHCRPKG_URL="$(echo "${GHCRPKG_URL}/${PROG}" | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')" ; export GHCRPKG_URL
 fi
 if [ -z "${GHCRPKG_URL+x}" ]; then
   echo -e "\n[✗] FATAL: Could NOT generate \${GHCRPKG_URL}\n"
   return 1 || exit 1
   export CONTINUE_SBUILD="NO"
 elif [[ $(echo "${GHCRPKG_URL}" | grep -o "ghcr.io/${PKG_REPO_OWNER}" | wc -l) -ge 2 ]]; then
   echo -e "\n[✗] FATAL: Generated \${GHCRPKG_URL} [${GHCRPKG_URL}] contains Dupes\n"
   return 1 || exit 1
   export CONTINUE_SBUILD="NO"
 fi
}
export -f generate_ghcrpkgurl
#-------------------------------------------------------#

#-------------------------------------------------------#
##Generate Json
generate_json()
{
if [[ "${SBUILD_SUCCESSFUL}" == "YES" ]]; then
 #Generate Json for each $progs
 unset PROG ; for PROG in "${SBUILD_PKGS[@]}"; do
  if [[ -s "${SBUILD_OUTDIR}/${PROG}" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}") -gt 10 ]]; then
   export PROG SBUILD_PKGVER
  #Initial ENV
   GHCR_PKG="$(realpath ${SBUILD_OUTDIR}/${PROG})"
   PKG_DATE="$(date --utc +%Y-%m-%dT%H:%M:%S)Z"
   PKG_DESCRIPTION="$(jq -r '(env.PKG_DESCRIPTION // (if type == "object" and has("description") and (.description | type == "object") then (if env.PROG != null and (.description[env.PROG] != null) then .description[env.PROG] else .description["_default"] end) else .description end // ""))' ${TMPJSON})"
   PKG_NAME="$(echo "${PROG}" | tr -d '[:space:]')"
   PKG_ICON="$(jq -r '.icon' "${TMPJSON}" | tr -d '[:space:]')"
   PKG_ID="$(jq -r '.pkg_id' "${TMPJSON}" | tr -d '[:space:]')"
   PKG_BSUM="$(b3sum "${GHCR_PKG}" | grep -oE '^[a-f0-9]{64}' | tr -d '[:space:]')"
   PKG_SHASUM="$(sha256sum "${GHCR_PKG}" | grep -oE '^[a-f0-9]{64}' | tr -d '[:space:]')"
   PKG_SIZE_RAW="$(stat --format="%s" "${GHCR_PKG}" | tr -d '[:space:]')"
   #PKG_SIZE="$(echo "${PKG_SIZE_RAW}" | awk '{byte=$1; if (byte<1024) printf "%.2f B\n", byte; else if (byte<1024**2) printf "%.2f KB\n", byte/1024; else if (byte<1024**3) printf "%.2f MB\n", byte/(1024**2); else printf "%.2f GB\n", byte/(1024**3)}')"
   PKG_SIZE="$(du -sh "${GHCR_PKG}" | awk '{unit=substr($1,length($1)); sub(/[BKMGT]$/,"",$1); print $1 " " unit "B"}')"
   SBUILD_PKGVER="$(cat "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" | tr -d '[:space:]')" ; export SBUILD_PKGVER
   export GHCR_PKG PROG PKG_BSUM PKG_DATE PKG_ICON PKG_SIZE PKG_SIZE_RAW PKG_SHASUM SBUILD_PKGVER
  #ghcrpkgurl 
   unset GHCRPKG_URL SNAPSHOT_JSON SNAPSHOT_TAGS TAG_URL
   generate_ghcrpkgurl
   echo "export GHCRPKG_URL='${GHCRPKG_URL}'" >> "${OCWD}/ENVPATH"
   if [ -n "${GHCRPKG+x}" ] && [[ "${GHCRPKG}" =~ ^[^[:space:]]+$ ]]; then
     DOWNLOAD_URL="$(echo "${GHCRPKG}/${PROG}" | sed 's|^ghcr.io|https://api.ghcr.pkgforge.dev|' | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')?tag=${GHCRPKG_TAG}&download=${PROG}"
     BUILD_LOG="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.log/')"
   elif [ -n "${GHCRPKG_URL+x}" ] && [[ "${GHCRPKG_URL}" =~ ^[^[:space:]]+$ ]]; then
     DOWNLOAD_URL="$(echo "${GHCRPKG_URL}" | sed 's|^ghcr.io|https://api.ghcr.pkgforge.dev|' | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')?tag=${GHCRPKG_TAG}&download=${PROG}"
     BUILD_LOG="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.log/')"
   fi
   export BUILD_LOG DOWNLOAD_URL
  #json 
   echo -e "\n[+] Generating Json for ${SBUILD_PKG} (PROG=${PROG}) ==> ${SBUILD_OUTDIR}/${PROG}.json"
   echo -e "[+] ==> $(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.json/')"
   if [ -n "${SBUILD_SCRIPT+x}" ] && [[ "${SBUILD_SCRIPT}" =~ ^[^[:space:]]+$ ]]; then
    #Appstream
    unset PKG_APPSTREAM
    if [[ -s "${SBUILD_OUTDIR}/${PROG}.metainfo.xml" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.metainfo.xml") -gt 10 ]]; then
     PKG_APPSTREAM="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.metainfo.xml/')" ; export PKG_APPSTREAM
    elif [[ -s "${SBUILD_OUTDIR}/${PROG}.appdata.xml" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.appdata.xml") -gt 10 ]]; then
     PKG_APPSTREAM="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.appdata.xml/')" ; export PKG_APPSTREAM
    fi
    #Desktop
    unset PKG_DESKTOP
    if [[ -s "${SBUILD_OUTDIR}/${PROG}.desktop" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.desktop") -gt 10 ]]; then
     PKG_DESKTOP="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.desktop/')" ; export PKG_DESKTOP
    fi
    #Icon
     if [[ ! -s "${SBUILD_OUTDIR}/${PROG}.png" && ! -s "${SBUILD_OUTDIR}/${PROG}.svg" ]]; then
       echo -e "\n[+] Fetching Icon for ${SBUILD_PKG} (PROG=${PROG}) ==> ${SBUILD_OUTDIR}/${PROG}.{png|svg}"
       if echo "${PKG_ICON}" | grep -qE '^https?://'; then
         if echo "${PKG_ICON}" | grep -qE '\.png$'; then
           curl -w "(Icon PNG) <== %{url}\n" -fL "${PKG_ICON}" -o "${SBUILD_OUTDIR}/${PROG}.png" 2>/dev/null
         elif echo "${PKG_ICON}" | grep -qE '\.svg$'; then
           curl -w "(Icon SVG) <== %{url}\n" -fL "${PKG_ICON}" -o "${SBUILD_OUTDIR}/${PROG}.svg" 2>/dev/null
         else
           echo -e "[-] ${PKG_ICON} Must either be a PNG|SVG Icon"
         fi
       else
         BASE_URL="$(echo "${SBUILD_SCRIPT}" | sed 's|[^/]*$||')"
         if echo "${BASE_URL}" | grep -qE '^https?://'; then
           for ASSET in "assets/default.png" "assets/default.svg" "assets/${PROG}.png" "assets/${PROG}.svg"; do
            IMG_EXT="${ASSET##*.}"
            IMG_TMP="${SBUILD_TMPDIR}/default.${IMG_EXT}"
            IMG_FILE="${SBUILD_OUTDIR}/${PROG}.${IMG_EXT}"
            curl -w "(Trying ${ASSET}) <== %{url}\n" -fL "${BASE_URL}${ASSET}" -o "${IMG_TMP}" 2>/dev/null
            if [[ -s "${IMG_TMP}" && $(stat -c%s "${IMG_TMP}") -gt 10 ]]; then
              mv -fv "${IMG_TMP}" "${IMG_FILE}"
              case "${IMG_EXT}" in
                png|svg)
                 break
                 ;;
              esac
            fi
           done
         else
           echo "[-] \${BASE_URL} [${BASE_URL}] is NOT a Valid URL (Falling Back to Default Icon)"
         fi
       fi
       #Icons 
       unset BASE_URL EXT IMG_FILE IMG_TMP PKG_ICON
       if [[ -s "${SBUILD_OUTDIR}/${PROG}.png" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.png") -gt 10 ]]; then
        PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.png/')" ; export PKG_ICON
       elif [[ -s "${SBUILD_OUTDIR}/${PROG}.svg" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.svg") -gt 10 ]]; then
        PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.svg/')" ; export PKG_ICON
       elif [ ! -s "${SBUILD_OUTDIR}/${PROG}.png" ] && [ ! -s "${SBUILD_OUTDIR}/${PROG}.svg" ]; then
         if echo "${PKG_TYPE}" | grep -Eqi "static|dynamic" ; then
           curl -w "(Default) <== %{url}\n" -fL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/assets/base.png" -o "${SBUILD_OUTDIR}/${PROG}.png"
         else
           curl -w "(Default) <== %{url}\n" -fL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/assets/pkg.png" -o "${SBUILD_OUTDIR}/${PROG}.png"
         fi
        if [ ! -s "${SBUILD_OUTDIR}/${PROG}.png" ] && [ ! -s "${SBUILD_OUTDIR}/${PROG}.svg" ]; then
         echo '<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="4" fill="yellow"/></svg>' > "${SBUILD_OUTDIR}/${PROG}.svg"
         PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.svg/')" ; export PKG_ICON
        else
         PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.png/')" ; export PKG_ICON
        fi
       fi
       if [ -n "${PKG_ICON+x}" ] && [[ "${PKG_ICON}" =~ ^[^[:space:]]+$ ]]; then
        echo -e "[+] Fetched Icon for ${SBUILD_PKG} (PROG=${PROG}) ==> ${PKG_ICON}"
       fi
     elif [[ -s "${SBUILD_OUTDIR}/${PROG}.png" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.png") -gt 10 ]]; then
       echo -e "\n[+] Found ICON ==> [${SBUILD_OUTDIR}/${PROG}.png]"
       PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.png/')" ; export PKG_ICON
     elif [[ -s "${SBUILD_OUTDIR}/${PROG}.svg" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.svg") -gt 10 ]]; then
       echo -e "\n[+] Found ICON ==> [${SBUILD_OUTDIR}/${PROG}.svg]"
       PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.svg/')" ; export PKG_ICON
     fi
   fi
  #Generate GHA Vars
   unset BUILD_GHACTIONS BUILD_ID
   if [ -n "${GITHUB_SERVER_URL+x}" ] && [ -n "${GITHUB_REPOSITORY+x}" ] && [ -n "${GITHUB_RUN_ID+x}" ]; then
     BUILD_GHACTIONS="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
     BUILD_ID="${GITHUB_RUN_ID}"
   else
     BUILD_GHACTIONS="$(echo "local://$(hostname)/$(date --utc +'%Y%m%d%H%M%S')" | tr -d '[:space:]')"
     BUILD_ID="$(cat '/etc/machine-id' | tr -d '[:space:]')"
   fi
   export BUILD_GHACTIONS BUILD_ID
  #Generate Snapshots
   if [ -n "${GHCRPKG_URL+x}" ] && [[ "${GHCRPKG_URL}" =~ ^[^[:space:]]+$ ]]; then
    #Generate Manifest
     unset PKG_MANIFEST ; PKG_MANIFEST="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/manifest/')" ; export PKG_MANIFEST
     unset PKG_GHCR ; PKG_GHCR="${GHCRPKG_URL}:${GHCRPKG_TAG}" ; export PKG_GHCR
    #Generate Tags
     TAG_URL="https://api.ghcr.pkgforge.dev/$(echo "${GHCRPKG}" | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta' | sed -E 's|^ghcr\.io/||; s|^/+||; s|/+?$||' | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')/${PROG}?tags"
     echo -e "[+] Fetching Snapshot Tags <== ${TAG_URL} [\$GHCRPKG]"
     #readarray -t "SNAPSHOT_TAGS" < <(curl -qfsSL "${TAG_URL}" | grep -i "$(uname -m)" | uniq)
     readarray -t "SNAPSHOT_TAGS" < <(oras repo tags "${GHCRPKG_URL}" | grep -i "$(uname -m)" | uniq)
   else
     TAG_URL="https://api.ghcr.pkgforge.dev/${PKG_REPO_OWNER}/$(echo "${PKG_REPO}/${PKG_FAMILY:-${PKG_NAME}}/${PKG_NAME:-${PKG_FAMILY:-${PKG_ID}}}" | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')/${PROG}?tags"
     echo -e "[+] Fetching Snapshot Tags <== ${TAG_URL} [NO \$GHCRPKG]"
     #readarray -t "SNAPSHOT_TAGS" < <(curl -qfsSL "${TAG_URL}" | grep -i "$(uname -m)" | uniq)
     readarray -t "SNAPSHOT_TAGS" < <(oras repo tags "${GHCRPKG_URL}" | grep -i "$(uname -m)" | uniq)
   fi
   if [[ -n "${SNAPSHOT_TAGS[*]}" && "${#SNAPSHOT_TAGS[@]}" -gt 0 ]]; then
     echo -e "[+] Snapshots: ${SNAPSHOT_TAGS[*]}"
     unset S_TAG S_TAGS S_TAG_VALUE SNAPSHOT_JSON ; S_TAGS=()
     for S_TAG in "${SNAPSHOT_TAGS[@]}"; do
      S_TAG_VALUE="$(oras manifest fetch "${GHCRPKG_URL}:${S_TAG}" | jq -r '.annotations["dev.pkgforge.soar.version_upstream"]' | tr -d '[:space:]')"
      [[ "${S_TAG_VALUE}" == "null" ]] && unset S_TAG_VALUE
       if [ -n "${S_TAG_VALUE+x}" ] && [[ "${S_TAG_VALUE}" =~ ^[^[:space:]]+$ ]]; then
         S_TAGS+=("${S_TAG}[${S_TAG_VALUE}]")
       else
         S_TAGS+=("${S_TAG}")
       fi
     done
     if [[ -n "${S_TAGS[*]}" && "${#S_TAGS[@]}" -gt 0 ]]; then
       SNAPSHOT_JSON=$(printf '%s\n' "${S_TAGS[@]}" | jq -R . | jq -s 'if type == "array" then . else [] end')
       export SNAPSHOT_JSON
     else
       export SNAPSHOT_JSON="[]"
     fi
     unset S_TAG S_TAGS S_TAG_VALUE
   else
     echo -e "[-] INFO: Snapshots is empty (No Previous Build Exists?)"
     export SNAPSHOT_JSON="[]"
   fi
  #Fetch Upstream Version 
   fetch_version_upstream 2>/dev/null
  #Copy Version
   if [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" && ! -s "${SBUILD_OUTDIR}/${PROG}.version" ]]; then
     cp -fv "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" "${SBUILD_OUTDIR}/${PROG}.version"
   fi
   if [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version.sig" && ! -s "${SBUILD_OUTDIR}/${PROG}.version.sig" ]]; then
     cp -fv "${SBUILD_OUTDIR}/${SBUILD_PKG}.version.sig" "${SBUILD_OUTDIR}/${PROG}.version.sig"
   fi
  #Generate Webpage
   PKG_WEBPAGE="$(echo "https://github.com/${GITHUB_REPOSITORY}" | sed 's|^/*||; s|/*$||' | tr -d '[:space:]')" ; export PKG_WEBPAGE
  #Generate 
   if ! echo "${SNAPSHOT_JSON}" | jq empty 2>/dev/null; then
     SNAPSHOT_JSON="[]"
   fi
   cat "${TMPJSON}" | jq -r --argjson "snapshots" "${SNAPSHOT_JSON}" \
   '{
    "_disabled": (._disabled | tostring // "unknown"),
    "host": (env.HOST_TRIPLET // ""),
    "rank": (env.RANK // ""),
    "pkg": (env.SBUILD_PKG // .pkg // ""),
    "pkg_family": (env.PKG_FAMILY // ""),
    "pkg_id": (.pkg_id // ""),
    "pkg_name": (env.PROG // .pkg // ""),
    "pkg_type": (env.PKG_TYPE // .pkg_type // ""),
    "pkg_webpage": (env.PKG_WEBPAGE // ""),
    "app_id": (.app_id // ""),
    "appstream": (env.PKG_APPSTREAM // .appstream // ""),
    "category": (.category // []),
    "description": (env.PKG_DESCRIPTION // (if type == "object" and has("description") and (.description | type == "object") then (if env.PROG != null and (.description[env.PROG] != null) then .description[env.PROG] else .description["_default"] end) else .description end // "")),
    "desktop": (env.PKG_DESKTOP // .desktop // ""),
    "homepage": (.homepage // []),
    "icon": (env.PKG_ICON // .icon // ""),
    "license": (if .license then if (.license | type == "array") then if (.license[0] | type == "string") then (.license | unique | sort) elif (.license[0] | type == "object") then ([.license[] | .id] | unique | sort) else [] end else [] end else [] end),
    "maintainer": (.maintainer // []),
    "provides": (
      if (.provides | length > 0) then 
        .provides 
      else 
        [env.PKG // .pkg // ""]
      end
    ),
    "note": (
      if (.note | length > 0) then 
        [.note[] | select(. == "" or (. | ascii_downcase | contains("ci only") | not))]
      else 
        []
      end
    ),
    "repology": (.repology // []),
    "screenshots": (.screenshot // []),
    "src_url": (.src_url // []),
    "tag": (.tag // []),
    "version": (env.SBUILD_PKGVER // ""),
    "version_upstream": (env.PKG_VERSION_UPSTREAM // ""),
    "bsum": (env.PKG_BSUM // ""),
    "build_date": (env.PKG_DATE // ""),
    "build_gha": (env.BUILD_GHACTIONS // ""),
    "build_id": (env.BUILD_ID // ""),
    "build_log": (env.BUILD_LOG // ""),
    "build_script": (env.SBUILD_SCRIPT_BLOB // ""),
    "download_url": (env.DOWNLOAD_URL // ""),
    "ghcr_pkg": (env.PKG_GHCR // ""),
    "ghcr_url": (if (env.GHCRPKG_URL // "") | startswith("https://") then (env.GHCRPKG_URL // "") else "https://" + (env.GHCRPKG_URL // "") end),
    "manifest_url": (env.PKG_MANIFEST // ""),
    "shasum": (env.PKG_SHASUM // ""),
    "size": (env.PKG_SIZE // ""),
    "size_raw": (env.PKG_SIZE_RAW // ""),
    "snapshots": $snapshots
  }' | jq . > "${SBUILD_OUTDIR}/${PROG}.json"
   echo -e "\n" && jq . "${SBUILD_OUTDIR}/${PROG}.json" ; echo -e "\n"
  fi
 done
fi
}
export -f generate_json
#-------------------------------------------------------#

#-------------------------------------------------------#
##Upload Func
upload_to_ghcr()
{
local PROG="$1"
pushd "${SBUILD_OUTDIR}" >/dev/null 2>&1
unset GHCR_PKG ; GHCR_PKG="$(realpath ${SBUILD_OUTDIR})/${PROG}" ; export GHCR_PKG
if [[ "${SBUILD_SUCCESSFUL}" == "YES" ]] && [[ -s "${GHCR_PKG}" ]]; then
 #Clear ENV
  unset ARCH BUILD_LOG BUILD_SCRIPT DOWNLOAD_URL GHCRPKG_TAG GHCRPKG_URL MANIFEST_URL METADATA_URL PKG_BSUM PKG_APPSTREAM PKG_CATEGORY PKG_DATE PKG_DESCRIPTION PKG_DESKTOP PKG_HOMEPAGE PKG_ICON PKG_JSON PKG_NAME PKG_NOTE PKG_ORIG PKG_REPOLOGY PKG_SCREENSHOT PKG_SHASUM PKG_SIZE PKG_SIZE_RAW PKG_SRCURL PKG_TAG PKG_VERSION PKG_VERSION_UPSTREAM PKG_WEBPAGE PUSH_SUCCESSFUL VERSION
 #Parse (in order of dependencies)
  if jq --exit-status . "${SBUILD_OUTDIR}/${PROG}.json" >/dev/null 2>&1; then
  #json 
   PKG_JSON="$(realpath ${SBUILD_OUTDIR}/${PROG}.json)" ; export PKG_JSON
   echo "export PKG_JSON='${PKG_JSON}'" >> "${OCWD}/ENVPATH"
  #If Artifact exists 
   if [[ -s "${GHCR_PKG}" && $(stat -c%s "${GHCR_PKG}") -gt 100 ]]; then
    #pkg_name
     PKG_NAME="$(jq -r '.pkg_name' "${PKG_JSON}" | tr -d '[:space:]')"
    #build_gha
     BUILD_GHACTIONS="$(jq -r '.build_gha' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${BUILD_GHACTIONS}" == "null" ]] && BUILD_GHACTIONS=""
    #build_id
     BUILD_ID="$(jq -r '.build_id' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${BUILD_ID}" == "null" ]] && BUILD_ID=""
    #build_log 
     BUILD_LOG="$(jq -r '.build_log' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${BUILD_LOG}" == "null" ]] && BUILD_LOG=""
    #build_script 
     BUILD_SCRIPT="$(jq -r '.build_script' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${BUILD_SCRIPT}" == "null" ]] && unset BUILD_SCRIPT
     [ -z "${BUILD_SCRIPT}" ] && BUILD_SCRIPT="${SBUILD_SCRIPT_BLOB}"
    #download_url 
     if [ -z "${DOWNLOAD_URL+x}" ] || [ -z "${DOWNLOAD_URL##*[[:space:]]}" ]; then
       DOWNLOAD_URL="$(jq -r '.download_url' "${PKG_JSON}" | tr -d '[:space:]')"
       [[ "${DOWNLOAD_URL}" == "null" ]] && unset DOWNLOAD_URL
     fi
    #build_date 
     PKG_DATE="$(jq -r '.build_date' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_DATE}" == "null" ]] && unset PKG_DATE
     if [ -z "${PKG_DATE+x}" ] || [ -z "${PKG_DATE##*[[:space:]]}" ]; then
       PKG_DATETMP="$(date --utc +%Y-%m-%dT%H:%M:%S)Z"
       PKG_DATE="$(echo "${PKG_DATETMP}" | sed 's/ZZ\+/Z/Ig')" ; unset PKG_DATETMP
     else
       PKG_DATETMP="${PKG_DATE}"
       PKG_DATE="$(echo "${PKG_DATETMP}" | sed 's/ZZ\+/Z/Ig')" ; unset PKG_DATETMP
     fi
    #version 
     PKG_VERSION="$(jq -r '.version' "${PKG_JSON}" | tr -d '[:space:]')"
     if [[ "${PKG_VERSION}" == "latest" ]]; then
       if [[ -n "${PKG_DATE}" ]]; then
         PKG_VERSION="$(echo ${PKG_DATE} | tr -cd '0-9')"
       else
         PKG_VERSION="$(date --utc +'%y%m%dT%H%M%S')"
       fi
     fi
     echo "export PKG_VERSION='${PKG_VERSION}'" >> "${OCWD}/ENVPATH"
    #version_upstream 
     PKG_VERSION_UPSTREAM="$(jq -r '.version_upstream' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_VERSION_UPSTREAM}" == "null" ]] && unset PKG_VERSION_UPSTREAM
     echo "export PKG_VERSION_UPSTREAM='${PKG_VERSION_UPSTREAM}'" >> "${OCWD}/ENVPATH"     
    #tag 
     GHCRPKG_TAG="$(echo "${PKG_VERSION}-${HOST_TRIPLET,,}" | sed 's/[^a-zA-Z0-9._-]/_/g; s/_*$//')" ; export GHCRPKG_TAG
     echo "export GHCRPKG_TAG='${GHCRPKG_TAG}'" >> "${OCWD}/ENVPATH"
    #Sanity Check download_url
     generate_ghcrpkgurl
     if [ -n "${DOWNLOAD_URL+x}" ] && [[ "${DOWNLOAD_URL}" =~ ^[^[:space:]]+$ ]]; then
       echo "export DOWNLOAD_URL='${DOWNLOAD_URL}'" >> "${OCWD}/ENVPATH"
     else
       DOWNLOAD_URL="$(echo "${GHCRPKG_URL}" | sed 's|^ghcr.io|https://api.ghcr.pkgforge.dev|' | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')?tag=${GHCRPKG_TAG}&download=${PROG}" ; export DOWNLOAD_URL
       echo "export DOWNLOAD_URL='${DOWNLOAD_URL}'" >> "${OCWD}/ENVPATH"
     fi
    #Manifests & Metadata URLs
     if [ -n "${GHCRPKG_URL+x}" ] && [ -n "${GHCRPKG_TAG+x}" ]; then
       MANIFEST_URL="$(echo "${GHCRPKG_URL}" | sed 's|^ghcr.io|https://api.ghcr.pkgforge.dev|' | sed ':a; s|^\(https://\)\([^/]\)/\(/\)|\1\2/\3|; ta')?tag=${GHCRPKG_TAG}&manifest" ; export MANIFEST_URL
       echo "export MANIFEST_URL='${MANIFEST_URL}'" >> "${OCWD}/ENVPATH"
       METADATA_URL="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.json/')" ; export METADATA_URL
       echo "export METADATA_URL='${METADATA_URL}'" >> "${OCWD}/ENVPATH"
     fi
    #bsum
     PKG_BSUM="$(jq -r '.bsum' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_BSUM}" == "null" ]] && unset PKG_BSUM
     [ -z "${PKG_BSUM}" ] && PKG_BSUM="$(b3sum "${GHCR_PKG}" | grep -oE '^[a-f0-9]{64}' | tr -d '[:space:]')"
    #category 
     PKG_CATEGORY="$(jq -r 'if .category | type == "array" then .category[0] else .category end' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_CATEGORY}" == "null" ]] && PKG_CATEGORY=""
    #description 
     PKG_DESCRIPTION="$(jq -r '.description' "${PKG_JSON}")"
     if [ -z "${PKG_FAMILY+x}" ] || [ -z "${PKG_FAMILY##*[[:space:]]}" ]; then
       PKG_FAMILY="$(jq -r '.pkg_family' "${PKG_JSON}" | tr -d '[:space:]')"
       [[ "${PKG_FAMILY}" == "null" ]] && PKG_FAMILY="${PKG_NAME}"
     fi
    #homepage 
     PKG_HOMEPAGE="$(jq -r 'if .homepage | type == "array" then .homepage[0] else .homepage end' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_HOMEPAGE}" == "null" ]] && PKG_HOMEPAGE=""
    #icon 
     PKG_ICON="$(jq -r 'if .icon | type == "array" then .icon[0] else .icon end' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_ICON}" == "null" ]] && unset PKG_ICON
     if [ -z "${PKG_ICON+x}" ] || [ -z "${PKG_ICON##*[[:space:]]}" ]; then
       if [[ -s "${SBUILD_OUTDIR}/${PROG}.png" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.png") -gt 3 ]]; then
         PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.png/')"
         [[ "${HAS_MINISIGN}" == "YES" ]] && minisign -Sm "${SBUILD_OUTDIR}/${PROG}.png" -P "${MINISIGN_PUB_KEY}" -s "${HOME}/.minisign/minisign.key" -x "${SBUILD_OUTDIR}/${PROG}.png.sig"
       elif [[ -s "${SBUILD_OUTDIR}/${PROG}.svg" && $(stat -c%s "${SBUILD_OUTDIR}/${PROG}.svg") -gt 3 ]]; then
         PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.svg/')"
         [[ "${HAS_MINISIGN}" == "YES" ]] && minisign -Sm "${SBUILD_OUTDIR}/${PROG}.svg" -P "${MINISIGN_PUB_KEY}" -s "${HOME}/.minisign/minisign.key" -x "${SBUILD_OUTDIR}/${PROG}.svg.sig"
       else
         echo '<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="4" fill="yellow"/></svg>' > "${SBUILD_OUTDIR}/${PROG}.svg"
         PKG_ICON="$(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.svg/')"
         [[ "${HAS_MINISIGN}" == "YES" ]] && minisign -Sm "${SBUILD_OUTDIR}/${PROG}.svg" -P "${MINISIGN_PUB_KEY}" -s "${HOME}/.minisign/minisign.key" -x "${SBUILD_OUTDIR}/${PROG}.svg.sig"
       fi
     fi
    #pkg_id 
     PKG_ID="$(jq -r '.pkg_id' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_ID}" == "null" ]] && PKG_ID="${PKG_FAMILY}"
    #pkg_webpage
     PKG_WEBPAGE="$(jq -r '.pkg_webpage' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_WEBPAGE}" == "null" ]] && unset PKG_WEBPAGE
     if [ -z "${PKG_WEBPAGE+x}" ] || [ -z "${PKG_WEBPAGE##*[[:space:]]}" ]; then
       PKG_WEBPAGE="$(echo "https://github.com/${GITHUB_REPOSITORY}" | sed 's|^/*||; s|/*$||' | tr -d '[:space:]')" ; export PKG_WEBPAGE 
     fi
    #note 
     PKG_NOTE="$(jq -r 'if .note | type == "array" then .note[0] else .note end' "${PKG_JSON}")"
     [[ "${PKG_NOTE}" == "null" ]] && PKG_NOTE=""
    #pkg (original name) 
     PKG_ORIG="$(jq -r '.pkg' "${PKG_JSON}" | tr -d '[:space:]')"
    #repology 
     PKG_REPOLOGY="$(jq -r 'if has("repology") then (if .repology | type == "array" then .repology[0] else .repology end) else "" end' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_REPOLOGY}" == "null" ]] && PKG_REPOLOGY=""
    #screenshots
     PKG_SCREENSHOT="$(jq -r 'if .screenshots | type == "array" then .screenshots[0] else .screenshots end' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_SCREENSHOT}" == "null" ]] && PKG_SCREENSHOT=""
    #shasum 
     PKG_SHASUM="$(jq -r '.shasum' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_SHASUM}" == "null" ]] && unset PKG_SHASUM
     [ -z "${PKG_SHASUM}" ] && PKG_SHASUM="$(sha256sum "${GHCR_PKG}" | grep -oE '^[a-f0-9]{64}' | tr -d '[:space:]')"
    #src_url 
     PKG_SRCURL="$(jq -r 'if .src_url | type == "array" then .src_url[0] else .src_url end' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_SRCURL}" == "null" ]] && unset PKG_SRCURL
     if [[ -n "${PKG_SRCURL}" ]]; then
       [ -z "${PKG_HOMEPAGE}" ] && PKG_HOMEPAGE="${PKG_SRCURL}"
     elif [[ -n "${PKG_HOMEPAGE}" ]]; then
       PKG_SRCURL="${PKG_HOMEPAGE}"
     fi
    #tag 
     PKG_TAG="$(jq -r 'if .tag | type == "array" then .tag[0] else .tag end' "${PKG_JSON}" | tr -d '[:space:]')"
     [[ "${PKG_TAG}" == "null" ]] && PKG_TAG=""
    #size 
     PKG_SIZE="$(jq -r '.size' "${PKG_JSON}")"
     PKG_SIZE="${PKG_SIZE:-$(du -sh "${GHCR_PKG}" | awk '{unit=substr($1,length($1)); sub(/[BKMGT]$/,"",$1); print $1 " " unit "B"}')}"
    #size_raw 
     PKG_SIZE_RAW="$(jq -r '.size_raw' "${PKG_JSON}" | tr -d '[:space:]')"
     PKG_SIZE_RAW="${PKG_SIZE_RAW:-$(stat --format="%s" "${GHCR_PKG}" | tr -d '[:space:]')}"
   else
     echo -e "\n[✗] No Valid \$GHCR_PKG was Provided\n"
    return 1 || exit 1
   fi
  #Upload
   [[ ! -s "./${PROG}" ]] && echo -e "\n[✗] \${GHCR_PKG} ${PROG} was NOT Found at CWD\n" && return 1
   [[ ! -s "./${PROG}.json" ]] && echo -e "\n[✗] \${GHCR_PKG}.json ${PROG} was NOT Found at CWD\n" && return 1
   if [[ -s "./${PROG}" ]]; then
    if [[ ! -s "${LOGPATH}" ]]; then
     echo -e "\n[✗] \${LOGPATH} was NOT Found at CWD\n"
     return 1 || exit 1
    else
     cp -fv "${LOGPATH}" "${SBUILD_OUTDIR}/${PROG}.log"
     [[ "${HAS_MINISIGN}" == "YES" ]] && minisign -Sm "${SBUILD_OUTDIR}/${PROG}.log" -P "${MINISIGN_PUB_KEY}" -s "${HOME}/.minisign/minisign.key" -x "${SBUILD_OUTDIR}/${PROG}.log.sig"
     echo -e "[+] ==> $(echo "${DOWNLOAD_URL}" | sed 's/download=[^&]*/download='"${PROG}"'.log/')"
     echo -e "\n[+] Parsing/Uploading ${PKG_FAMILY}/${PKG_NAME} [${HOST_TRIPLET}]"
     jq . "./${PROG}.json" && echo -e "\n"
     [[ "${HAS_MINISIGN}" == "YES" ]] && minisign -Sm "./${PROG}.json" -P "${MINISIGN_PUB_KEY}" -s "${HOME}/.minisign/minisign.key" -x "./${PROG}.json.sig"
    #Check Tag
     if ! oras manifest fetch "${GHCRPKG_URL}:${GHCRPKG_TAG}" |\
       jq -r '.annotations["org.opencontainers.image.created"]' | tr -d '[:space:]' |\
        grep -qiE '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
         oras push --debug --config "/dev/null:application/vnd.oci.empty.v1+json" "${GHCRPKG_URL}:${GHCRPKG_TAG}"
         sleep 2
     fi
    #Construct Upload CMD
     ghcr_push_cmd()
     {
      for i in {1..10}; do
        #unset ghcr_push ; ghcr_push=(oras push --concurrency "10" --disable-path-validation)
        unset ghcr_push ; ghcr_push=(oras push --disable-path-validation)
        ghcr_push+=(--config "/dev/null:application/vnd.oci.empty.v1+json")
        ghcr_push+=(--annotation "com.github.package.type=container")
        #ghcr_push+=(--annotation "com.github.package.type=homebrew_bottle")
        #ghcr_push+=(--annotation "com.github.package.type=soar_pkg")
        ghcr_push+=(--annotation "dev.pkgforge.discord=https://discord.gg/djJUs48Zbu")
        ghcr_push+=(--annotation "dev.pkgforge.soar.build_date=${PKG_DATE}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.build_gha=${BUILD_GHACTIONS}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.build_id=${BUILD_ID}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.build_log=${BUILD_LOG}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.build_script=${SBUILD_SCRIPT:-${BUILD_SCRIPT}}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.bsum=${PKG_BSUM}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.category=${PKG_CATEGORY}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.description=${PKG_DESCRIPTION}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.download_url=${DOWNLOAD_URL}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.ghcr_pkg=${GHCRPKG_URL}:${GHCRPKG_TAG}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.homepage=${PKG_HOMEPAGE:-${PKG_SRCURL}}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.icon=${PKG_ICON}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.json=$(jq . ${PKG_JSON})")
        ghcr_push+=(--annotation "dev.pkgforge.soar.manifest_url=${MANIFEST_URL}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.metadata_url=${METADATA_URL}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.note=${PKG_NOTE}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.pkg=${SBUILD_PKG:-${PKG_ORIG}}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.pkg_family=${PKG_FAMILY}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.pkg_name=${PKG_NAME}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.pkg_webpage=${PKG_WEBPAGE}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.repology=${PKG_REPOLOGY}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.screenshot=${PKG_SCREENSHOT}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.shasum=${PKG_SHASUM}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.size=${PKG_SIZE}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.size_raw=${PKG_SIZE_RAW}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.src_url=${PKG_SRCURL:-${PKG_HOMEPAGE}}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.version=${PKG_VERSION}")
        ghcr_push+=(--annotation "dev.pkgforge.soar.version_upstream=${PKG_VERSION_UPSTREAM}")
        ghcr_push+=(--annotation "org.opencontainers.image.authors=https://docs.pkgforge.dev/contact/chat")
        ghcr_push+=(--annotation "org.opencontainers.image.created=${PKG_DATE}")
        ghcr_push+=(--annotation "org.opencontainers.image.description=${PKG_DESCRIPTION}")
        ghcr_push+=(--annotation "org.opencontainers.image.documentation=${PKG_WEBPAGE}")
        ghcr_push+=(--annotation "org.opencontainers.image.licenses=blessing")
        ghcr_push+=(--annotation "org.opencontainers.image.ref.name=${PKG_VERSION}")
        ghcr_push+=(--annotation "org.opencontainers.image.revision=${PKG_SHASUM:-${PKG_VERSION}}")
        ghcr_push+=(--annotation "org.opencontainers.image.source=${PKG_WEBPAGE}")
        ghcr_push+=(--annotation "org.opencontainers.image.title=${PKG_NAME}")
        ghcr_push+=(--annotation "org.opencontainers.image.url=${PKG_SRCURL}")
        ghcr_push+=(--annotation "org.opencontainers.image.vendor=pkgforge")
        ghcr_push+=(--annotation "org.opencontainers.image.version=${PKG_VERSION}")
        ghcr_push+=("${GHCRPKG_URL}:${GHCRPKG_TAG}" "./${PROG}")
        [[ -f "./${PROG}.sig" && -s "./${PROG}.sig" ]] && ghcr_push+=("./${PROG}.sig")
        [[ -f "./CHECKSUM" && -s "./CHECKSUM" ]] && ghcr_push+=("./CHECKSUM")
        [[ -f "./CHECKSUM.sig" && -s "./CHECKSUM.sig" ]] && ghcr_push+=("./CHECKSUM.sig")
        [[ -f "./LICENSE" && -s "./LICENSE" ]] && ghcr_push+=("./LICENSE")
        [[ -f "./LICENSE.sig" && -s "./LICENSE.sig" ]] && ghcr_push+=("./LICENSE.sig")
        [[ -f "./SBUILD" && -s "./SBUILD" ]] && ghcr_push+=("./SBUILD")
        [[ -f "./SBUILD.sig" && -s "./SBUILD.sig" ]] && ghcr_push+=("./SBUILD.sig")
        [[ -f "./${PROG}.appdata.xml" && -s "./${PROG}.appdata.xml" ]] && ghcr_push+=("./${PROG}.appdata.xml")
        [[ -f "./${PROG}.appdata.xml.sig" && -s "./${PROG}.appdata.xml.sig" ]] && ghcr_push+=("./${PROG}.appdata.xml.sig")
        [[ -f "./${PROG}.desktop" && -s "./${PROG}.desktop" ]] && ghcr_push+=("./${PROG}.desktop")
        [[ -f "./${PROG}.desktop.sig" && -s "./${PROG}.desktop.sig" ]] && ghcr_push+=("./${PROG}.desktop.sig")
        [[ -f "./${PROG}.json" && -s "./${PROG}.json" ]] && ghcr_push+=("./${PROG}.json")
        [[ -f "./${PROG}.json.sig" && -s "./${PROG}.json.sig" ]] && ghcr_push+=("./${PROG}.json.sig")
        [[ -f "./${PROG}.log" && -s "./${PROG}.log" ]] && ghcr_push+=("./${PROG}.log")
        [[ -f "./${PROG}.log.sig" && -s "./${PROG}.log.sig" ]] && ghcr_push+=("./${PROG}.log.sig")
        [[ -f "./${PROG}.metainfo.xml" && -s "./${PROG}.metainfo.xml" ]] && ghcr_push+=("./${PROG}.metainfo.xml")
        [[ -f "./${PROG}.metainfo.xml.sig" && -s "./${PROG}.metainfo.xml.sig" ]] && ghcr_push+=("./${PROG}.metainfo.xml.sig")
        [[ -f "./${PROG}.png" && -s "./${PROG}.png" ]] && ghcr_push+=("./${PROG}.png")
        [[ -f "./${PROG}.png.sig" && -s "./${PROG}.png.sig" ]] && ghcr_push+=("./${PROG}.png.sig")
        [[ -f "./${PROG}.version" && -s "./${PROG}.version" ]] && ghcr_push+=("./${PROG}.version")
        [[ -f "./${PROG}.version.sig" && -s "./${PROG}.version.sig" ]] && ghcr_push+=("./${PROG}.version.sig")
        [[ -f "./${PROG}.svg" && -s "./${PROG}.svg" ]] && ghcr_push+=("./${PROG}.svg")
        [[ -f "./${PROG}.svg.sig" && -s "./${PROG}.svg.sig" ]] && ghcr_push+=("./${PROG}.svg.sig")
        "${ghcr_push[@]}" ; sleep 5
       #Check
        if [[ "$(oras manifest fetch "${GHCRPKG_URL}:${GHCRPKG_TAG}" | jq -r '.annotations["dev.pkgforge.soar.build_date"]' | tr -d '[:space:]')" == "${PKG_DATE}" ]]; then
          echo -e "\n[+] Registry --> https://${GHCRPKG_URL}"
          echo -e "[+] ==> ${MANIFEST_URL:-${DOWNLOAD_URL}} \n"
          export PUSH_SUCCESSFUL="YES"
          #rm -rf "${GHCR_PKG}" "${PKG_JSON}" 2>/dev/null
          echo "export PUSH_SUCCESSFUL=YES" >> "${OCWD}/ENVPATH"
          [[ "${GHA_MODE}" == "MATRIX" ]] && echo GHCRPKG_URL="${GHCRPKG_URL}" >> "${GITHUB_ENV}"
          [[ "${GHA_MODE}" == "MATRIX" ]] && echo "PUSH_SUCCESSFUL=${PUSH_SUCCESSFUL}" >> "${GITHUB_ENV}"
          if [ -n "${METADATA_DIR+x}" ] && [[ "${METADATA_DIR}" =~ ^[^[:space:]]+$ ]]; then
            mkdir -pv "${METADATA_DIR}"
            cp -fv "${SBUILD_OUTDIR}/${PROG}.json" "${METADATA_DIR}/${PROG}.json"
          fi
          break
        else
          echo -e "\n[-] Failed to Push Artifact to ${GHCRPKG_URL}:${GHCRPKG_TAG} (Retrying ${i}/10)\n"
        fi
        sleep "$(shuf -i 500-4500 -n 1)e-3"
      done
     }
     export -f ghcr_push_cmd
    #First Set of tries
     ghcr_push_cmd
    #Check if Failed  
     if [[ "$(oras manifest fetch "${GHCRPKG_URL}:${GHCRPKG_TAG}" | jq -r '.annotations["dev.pkgforge.soar.build_date"]' | tr -d '[:space:]')" != "${PKG_DATE}" ]]; then
       echo -e "\n[✗] Failed to Push Artifact to ${GHCRPKG_URL}:${GHCRPKG_TAG}\n"
       #Second set of Tries
        echo -e "\n[-] Retrying ...\n"
        ghcr_push_cmd
         if [[ "$(oras manifest fetch "${GHCRPKG_URL}:${GHCRPKG_TAG}" | jq -r '.annotations["dev.pkgforge.soar.build_date"]' | tr -d '[:space:]')" != "${PKG_DATE}" ]]; then
           oras manifest fetch "${GHCRPKG_URL}:${GHCRPKG_TAG}" | jq .
           echo -e "\n[✗] Failed to Push Artifact to ${GHCRPKG_URL}:${GHCRPKG_TAG}\n"
           export PUSH_SUCCESSFUL="NO"
           echo "export PUSH_SUCCESSFUL=NO" >> "${OCWD}/ENVPATH"
           [[ "${GHA_MODE}" == "MATRIX" ]] && echo "PUSH_SUCCESSFUL=${PUSH_SUCCESSFUL}" >> "${GITHUB_ENV}"
           return 1 || exit 1
         fi
     fi
    fi
   else
    echo -e "\n[-] FAILED to Parse ${PKG_FAMILY}/${PKG_NAME} Metadata <-- ["${SBUILD_OUTDIR}/${PROG}.json"]\n"
    cat "${PKG_JSON}" 2>/dev/null
    return 1 || exit 1
   fi
  else
   echo -e "\n[✗] \${GHCR_PKG} ${PROG} was NOT Found at CWD\n"
   return 1 || exit 1
  fi
fi
popd >/dev/null 2>&1
}
export -f upload_to_ghcr
popd >/dev/null 2>&1
#-------------------------------------------------------#

#-------------------------------------------------------#
##Cleanup
cleanup_env()
{
#Cleanup Dir  
 if [ -n "${GITHUB_TEST_BUILD+x}" ]; then
  7z a -t7z -mx="9" -mmt="$(($(nproc)+1))" -bsp1 -bt "/tmp/BUILD_ARTIFACTS.7z" "${BUILD_DIR}" 2>/dev/null
 elif [[ "${KEEP_LOGS}" != "YES" ]]; then
  echo -e "\n[-] Removing ALL Logs & Files\n"
  rm -rvf "${BUILD_DIR}" 2>/dev/null
 fi
#Cleanup Env
 unset ARTIFACTS_DIR BUILD_DIR BUILD_GHACTIONS BUILD_ID ghcr_push ghcr_push_cmd GHCRPKG_URL GHCRPKG_TAG INPUT_SBUILD INPUT_SBUILD_PATH MANIFEST_URL OCWD pkg PKG PKG_APPSTREAM PKG_DESKTOP PKG_FAMILY PKG_GHCR pkg_id PKG_ID PKG_MANIFEST pkg_type PKG_TYPE pkgver PKGVER pkg_ver PKG_VER PKG_VERSION_UPSTREAM PKG_WEBPAGE PROG REPOLOGY_PKG REPOLOGY_PKGVER REPOLOGY_VER SBUILD_OUTDIR SBUILD_PKG SBUILD_PKGS SBUILD_PKGVER SBUILD_REBUILD SBUILD_SCRIPT SBUILD_SCRIPT_BLOB SBUILD_SKIPPED SBUILD_SUCCESSFUL SBUILD_TMPDIR SNAPSHOT_JSON SNAPSHOT_TAGS TAG_URL TMPJSON TMPXVER TMPXRUN
}
export -f cleanup_env
#-------------------------------------------------------#