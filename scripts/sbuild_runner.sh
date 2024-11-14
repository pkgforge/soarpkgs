#!/usr/bin/env bash
#[VERSION=1.0.1]
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_runner.sh")
# source <(curl -qfsSL "https://l.ajam.dev/sbuild-runner")
# sbuild-runner example.SBUILD
# DEBUG=1|ON sbuild-runner example.SBUILD --> runs with set -x
#-------------------------------------------------------#

#-------------------------------------------------------#
## SOAR REF
# SBUILD_SUCCESSFUL=YES|NO --> Whether to proceed at all or exit early
# SBUILD_PKG --> .pkg (or .name|.bin_name as it used to be called)
# PKG_TYPE --> One of appbundle|appimage|archive|dynamic|flatimage|gameimage|nixappimage|runimage|static
#  --> If this is empty, check using magic bytes
#  --> Even if this isn't empty, check using magic bytes regardless
#  --> dynamic|static are binaries (cli), don't need integration
#  --> UNKNOWN means, the pkg_type value was empty, so check using magic bytes
# SBUILD_OUTDIR --> $TMPDIR soar will try to look for files In
#  --> ${SBUILD_OUTDIR}/${SBUILD_PKG} (Actual Binary)
#  --> ${SBUILD_OUTDIR}/.DirIcon (DirIcon Main location)
#  --> ${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon (DirIcon Alt location)
#  --> ${SBUILD_OUTDIR}/${SBUILD_PKG}.png (Icon location)
#  --> ${SBUILD_OUTDIR}/${SBUILD_PKG}.svg (Icon location)
#  --> ${SBUILD_OUTDIR}/${SBUILD_PKG}.appdata.xml (AppStream Location)
#  --> ${SBUILD_OUTDIR}/${SBUILD_PKG}.metainfo.xml (AppStream Location)
# SBUILD_TMPDIR --> $TMPDIR ($SBUILD_OUTDIR/SBUILD_TEMP) that can be used to store unrelated files
# SBUILD_META --> Metadata JSON, soar will parse & get all values from (for soar info|query)
#-------------------------------------------------------#

#-------------------------------------------------------#
unset CONTINUE_SBUILD SBUILD_SUCCESSFUL
##Enable Debug
 if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
    set -x
 fi
##Get/Set ENVS (from Host)
 #User
 case "${USER}" in
   "" )
     echo "WARNING: \$USER is Unknown"
     USER="$(whoami)"
     export USER
     if [ -z "${USER}" ]; then
       echo -e "[-] INFO: Setting USER --> ${USER}"
     else
       echo -e "[-] WARNING: FAILED to find \$USER"
     fi
     ;;
 esac
 #Home
 if [ -z "${HOME}" ] || [ "${HOME}" = "" ]; then
    echo "WARNING: HOME Directory is empty/unset"
    HOME="$(getent passwd "${USER}" | cut -d: -f6)" ; export HOME
 fi
##Fail if no Soar
 if ! command -v "soar" >/dev/null 2>&1; then
   echo -e "\n[✗] FATAL: soar is NOT INSTALLED\nInstall: https://github.com/pkgforge/soar#-installation\n"
   exit 1
 else
  #Check if SOAR's path is in USER's PATH
  if [[ "${PATH}" != *"soar/bin"* ]]; then
   echo -e "\n[✗] FATAL: soar/bin is NOT in \$PATH\n$(soar env)\n"
  else
   echo -e "\n[+] Printing Soar's ENV_VARS...\n$(soar env)\n"
  fi
 fi
##Get Input
 #INPUT="${1:-$(cat)}"
 INPUT="${1:-$(echo "$@" | tr -d '[:space:]')}" ; export INPUT
 SELF_NAME="${ARGV0:-${0##*/}}" ; export SELF_NAME
##Get Linter & Validate
 source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_linter.sh")
 if declare -F sbuild_linter &>/dev/null || declare -F sbuild-linter &>/dev/null; then
   echo -e "\n[+] Validating ${INPUT} ..."
   INSTALL_DEPS="ON" SBUILD_MODE="ON" sbuild_linter "${INPUT}"
 else
   echo -e "\n[✗] FATAL: sbuild-validator could NOT BE Found\n"
   exit 1
 fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Verify & BootStrap
 if [[ "${CONTINUE_SBUILD}" == "YES" && -s "${SRC_SBUILD_IN}" && -s "${SRC_BUILD_SCRIPT}" ]]; then
  ##BootStrap
   echo -e "\n[+] Bootstrapping & Preparing to Run ${SRC_SBUILD_IN}\n"
   if [[ "$(yq '._disabled' "${SRC_SBUILD_IN}")" == "true" ]]; then
     echo -e "\n[✗] FATAL: SBUILD (${SRC_SBUILD_IN}) is Disabled ('_disabled: true')\n"
     exit 1
   fi
   chmod +x "${SRC_BUILD_SCRIPT}"
   SBUILD_META="$(mktemp)" ; SBUILD_OUTDIR="$(mktemp -d)"
   export SBUILD_META SBUILD_OUTDIR
   SBUILD_TMPDIR="${SBUILD_OUTDIR}/SBUILD_TEMP" ; export SBUILD_TMPDIR ; mkdir -p "${SBUILD_TMPDIR}"
   echo -e "[+] SBUILD (Recipe) == ${SRC_SBUILD_IN}"
   echo -e "[+] SBUILD (Metadata) == ${SBUILD_META}"
   echo -e "[+] SBUILD (OUTDIR) == ${SBUILD_OUTDIR}"
   echo -e "[+] SBUILD (TMPDIR) == ${SBUILD_TMPDIR}"
   echo -e "[+] SBUILD (.x_exec.run) == ${SRC_BUILD_SCRIPT}"
  #Funcs 
   #List Dirs
   list_dirs(){
     echo -e "\n[+] SBUILD OUTDIR: ${SBUILD_OUTDIR}\n $(ls -lah "${SBUILD_OUTDIR}")\n"
     echo -e "\n[+] SBUILD TMPDIR: ${SBUILD_TMPDIR}\n $(ls -lah "${SBUILD_TMPDIR}")\n"
   }
   export -f list_dirs
   #Clean Dirs
   cleanup_dirs()
   {
     rm -rf "${SBUILD_OUTDIR}" 2>/dev/null
     rm -rf "${SBUILD_TMPDIR}" 2>/dev/null
   }
   export -f cleanup_dirs
   #List files
   list_files(){
     find "${SBUILD_OUTDIR}" -type f -iname "*${SBUILD_PKG%%-*}*" -print | xargs -I {} sh -c 'file {}; b3sum {}; sha256sum {}; du -sh {}'
   }
   export -f list_files
   #Clean Files
   cleanup_files()
   {
     rm -rf "${SBUILD_META}" 2>/dev/null
     rm -rf "${SRC_BUILD_SCRIPT}" 2>/dev/null
   }
   export -f cleanup_files
   #Squishy
   install_squishy(){
     soar add squishy-cli --yes
     if ! command -v "squishy-cli" >/dev/null 2>&1; then
       echo -e "\n[✗] FATAL: squishy-cli NOT FOUND\n"
     else
       export HAS_SQUISHY="YES"
     fi
   }
   export -f install_squishy
   use_squishy(){
     unset HAS_SQUISHY
     install_squishy
     if [[ "${HAS_SQUISHY}" == "YES" ]]; then
       #Only Desktop
       if [ -n "${SQUISHY_DESKTOP}" ]; then
        squishy-cli appimage --desktop --appstream --write "${SBUILD_OUTDIR}"
       #Only Icon 
       elif [ -n "${SQUISHY_ICON}" ]; then
        squishy-cli appimage --icon --appstream --write "${SBUILD_OUTDIR}"
       #Mostly for NixAppImages 
       elif [ -n "${SQUISHY_FILTER}" ]; then
        squishy-cli appimage "${SBUILD_OUTDIR}/${SBUILD_PKG}" --filter "${SQUISHY_FILTER}" --icon --desktop --appstream --write "${SBUILD_OUTDIR}"
       #For Generic Broken AppImages 
       else
        squishy-cli appimage "${SBUILD_OUTDIR}/${SBUILD_PKG}" --icon --desktop --appstream --write "${SBUILD_OUTDIR}"
       fi
     fi
   }
   export -f use_squishy
  #Convert to Json & Prep
   yq . "${SRC_SBUILD_IN}" | yj -yj | jq 'del(.x_exec)' > "${SBUILD_META}"
   if [[ -s "${SBUILD_META}" ]] && jq --exit-status '.' "${SBUILD_META}" > /dev/null 2>&1; then
    #Get pkg
     pkg="$(jq -r '"\(.pkg | select(. != "null") // "")"' "${SBUILD_META}" | sed 's/\.$//' | tr -d '[:space:]')" ; export PKG="${pkg}"
     pkg_id="$(jq -r '"\(.pkg_id | select(. != "null") // "")"' "${SBUILD_META}" | sed 's/\.$//' | tr -d '[:space:]')" ; export PKG_ID="${pkg_id}"
     pkg_type="$(jq -r '"\(.pkg_type | select(. != "null") // "")"' "${SBUILD_META}" | sed 's/\.$//' | tr -d '[:space:]')" ; export PKG_TYPE="${pkg_type}"
     SBUILD_PKG="$(echo "${pkg}.${pkg_type}" | sed 's/\.$//' | tr -d '[:space:]')"
     export pkg pkg_id pkg_type SBUILD_PKG
     if [ "$(echo "${SBUILD_PKG}" | tr -d '[:space:]' | wc -c | tr -cd '0-9')" -le 1 ]; then
       echo -e "\n[✗] FATAL: ${SBUILD_PKG} ('.pkg+.pkg_type') is less than 1 Character\n"
       export CONTINUE_SBUILD="NO" ; exit 1
     fi
    #Get .desktop url 
     SBUILD_DESKTOP_URL="$(jq -r 'try .desktop // empty' "${SBUILD_META}" | tr -d '[:space:]')" ; export SBUILD_DESKTOP_URL
     if [ -n "${SBUILD_DESKTOP_URL}" ] && echo "${SBUILD_DESKTOP_URL}" | grep -m 1 -q 'http[s]\?://'; then
        echo -e "[+] Downloading '.desktop' (${SBUILD_DESKTOP_URL}) ==> ("${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop")"
       #DL 
        if [[ -n "${USER_AGENT}" ]]; then
         curl -A "${USER_AGENT}" -qfsSL "${SBUILD_DESKTOP_URL}" -o "${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop"
        else
         curl -qfsSL "${SBUILD_DESKTOP_URL}" -o "${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop"
        fi
       #Verify
        if [[ ! -f "${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop" ]] || [[ $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop") -le 10 ]]; then
         echo -e "[-] WARNING: FAILED to DOWNLOAD (Or Broken) '.desktop' from ${SBUILD_DESKTOP_URL}"
        fi
     fi
    #Get .icon url 
     SBUILD_ICON_URL="$(jq -r 'try .icon // empty' "${SBUILD_META}" | tr -d '[:space:]')" ; export SBUILD_ICON_URL
     if [ -n "${SBUILD_ICON_URL}" ] && echo "${SBUILD_ICON_URL}" | grep -q 'http[s]\?://'; then
        echo -e "[+] Downloading '.icon' (${SBUILD_ICON_URL}) ==> ("${SBUILD_OUTDIR}/${SBUILD_PKG}.icon")"
       #DL
        if [[ -n "${USER_AGENT}" ]]; then
         curl -A "${USER_AGENT}" -qfsSL "${SBUILD_ICON_URL}" -o "${SBUILD_OUTDIR}/${SBUILD_PKG}.icon"
        else
         curl -qfsSL "${SBUILD_DESKTOP_URL}" -o "${SBUILD_OUTDIR}/${SBUILD_PKG}.icon"
        fi
       #Verify 
        if [[ -f "${SBUILD_OUTDIR}/${SBUILD_PKG}.icon" ]] && [[ $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.icon") -gt 100 ]]; then
           ICON_TYPE="$(file -i "${SBUILD_OUTDIR}/${SBUILD_PKG}.icon")"
           if echo "${ICON_TYPE}" | grep -qE 'image/(png)'; then
             echo -e "[+] Renaming ("${SBUILD_OUTDIR}/${SBUILD_PKG}.icon") ==> ("${SBUILD_OUTDIR}/${SBUILD_PKG}.png")"
             mv -fv "${SBUILD_OUTDIR}/${SBUILD_PKG}.icon" "${SBUILD_OUTDIR}/${SBUILD_PKG}.png"
             cp -fv "${SBUILD_OUTDIR}/${SBUILD_PKG}.png" "${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon"
           elif echo "${ICON_TYPE}" | grep -qE 'image/(svg)'; then
             echo -e "[+] Renaming ("${SBUILD_OUTDIR}/${SBUILD_PKG}.icon") ==> ("${SBUILD_OUTDIR}/${SBUILD_PKG}.svg")"
             mv -fv "${SBUILD_OUTDIR}/${SBUILD_PKG}.icon" "${SBUILD_OUTDIR}/${SBUILD_PKG}.svg"
             cp -fv "${SBUILD_OUTDIR}/${SBUILD_PKG}.svg" "${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon"
           else
             echo -e "[-] WARNING: ("${SBUILD_OUTDIR}/${SBUILD_PKG}.icon") is of Type ("${ICON_TYPE}")"
             echo -e "[-] Only PNG/SVG Icons are Supported"
           fi
           unset ICON_TYPE
        else
         echo -e "[-] WARNING: FAILED to DOWNLOAD (Or Broken) '.icon' from ${SBUILD_ICON_URL}"
        fi
     fi
    #Get .src_url url(s) 
     jq -r 'try .src_url[] // empty' "${SBUILD_META}" > "${SBUILD_TMPDIR}/src_url.txt"
    #Get .build_util prog(s)
     jq -r 'try .build_util[] // empty' "${SBUILD_META}" > "${SBUILD_TMPDIR}/build_util.txt"
     if [ -s "${SBUILD_TMPDIR}/build_util.txt" ] && [ $(stat -c%s "${SBUILD_TMPDIR}/build_util.txt") -gt 2 ]; then
       echo -e "[+] Installing Build Depedencies ('.build_util') ..."
       cat "${SBUILD_TMPDIR}/build_util.txt" | soar add - --yes
     fi
    #Get .build_asset url(s) 
     if [[ -n "${USER_AGENT}" ]]; then
       jq -r --arg user_agent "${USER_AGENT}" --arg tmpdir "${SBUILD_TMPDIR}" 'try .build_asset[] // empty | "curl -A \"\($user_agent)\" -qfsSL \"\(.url // empty)\" -o \"\($tmpdir)/\(.out // empty)\""' "${SBUILD_META}" > "${SBUILD_TMPDIR}/build_asset.txt"
     else
       jq -r --arg tmpdir "${SBUILD_TMPDIR}" 'try .build_asset[] // empty | "curl -qfsSL \"\(.url // empty)\" -o \"\($tmpdir)/\(.out // empty)\""' "${SBUILD_META}" > "${SBUILD_TMPDIR}/build_asset.txt"
     fi
     #DL
     if [ -s "${SBUILD_TMPDIR}/build_util.txt" ] && [ $(stat -c%s "${SBUILD_TMPDIR}/build_util.txt") -gt 3 ]; then
       echo -e "[+] Downloading Build Assets ('.build_asset') --> (${SBUILD_TMPDIR})"
       #xargs etc all choke due to some chars
      {
        while read -r URL; do
         [[ "$URL" =~ ^[[:space:]]*$ ]] && continue
         echo " + ${URL}" && eval "${URL}" &
        done < "${SBUILD_TMPDIR}/build_asset.txt"
        wait
      }
     fi
   ##List
     list_dirs
     export CONTINUE_SBUILD="YES"
   else
   echo -e "\n[✗] FATAL: EMPTY/Invalid Metadata JSON (${SBUILD_META})\n"
   export CONTINUE_SBUILD="NO"
   cleanup_dirs ; exit 1
   fi
 else
   echo -e "\n[✗] FATAL: CAN NOT CONTINUE\n"
   export CONTINUE_SBUILD="NO"
   exit 1
 fi
##Final Check
 echo -e "\n[+] Doing Final Sanity Checks...\n"
 set -x
  if [[ -z "${SBUILD_PKG//[[:space:]]/}" ]] || \
   [[ ! -f "${SRC_SBUILD_IN}" || ! -s "${SRC_SBUILD_IN}" ]] || \
   [[ ! -f "${SBUILD_META}" || ! -s "${SBUILD_META}" ]] || \
   [[ ! -f "${SRC_BUILD_SCRIPT}" || ! -s "${SRC_BUILD_SCRIPT}" || ! -x "${SRC_BUILD_SCRIPT}" ]] || \
   [[ ! -d "${SBUILD_OUTDIR}" || ! -e "${SBUILD_OUTDIR}" ]] || \
   [[ ! -d "${SBUILD_TMPDIR}" || ! -e "${SBUILD_TMPDIR}" ]]; then
   echo -e "\n[✗] FATAL: CAN NOT CONTINUE\n"
   export CONTINUE_SBUILD="NO" ; exit 1
  else
   export CONTINUE_SBUILD="YES" ; set +x
  fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Run
if [[ "${CONTINUE_SBUILD}" == "YES" ]]; then
 echo -e "\n[+] Running ${SRC_SBUILD_IN} [x_exec.run == ${SRC_BUILD_SCRIPT}] using DIR ${SBUILD_OUTDIR}\n"
  pushd "${SBUILD_OUTDIR}" >/dev/null 2>&1
  #Run [MAIN]
   "${SRC_BUILD_SCRIPT}"
  #POSTRUN
   if [[ -f "${SBUILD_OUTDIR}/${SBUILD_PKG}" ]] && [[ $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}") -gt 1024 ]]; then
     export SBUILD_SUCCESSFUL="YES" ; chmod +x "${SBUILD_OUTDIR}/${SBUILD_PKG}"
     echo -e "[✓] SuccessFully Built ${SBUILD_PKG} using ${SRC_SBUILD_IN}"
    #Check for .pkg_type
     SBUILD_PKG_TYPE="$(echo "${SBUILD_PKG}" | grep -iEo '\.(appbundle|appimage|archive|dynamic|flatimage|gameimage|nixappimage|runimage|static)$')"
     if [[ -n "${SBUILD_PKG_TYPE}" ]]; then
       export PKG_TYPE="${SBUILD_PKG_TYPE:1}"
       echo -e "[+] ${SBUILD_PKG} is of Type: ${PKG_TYPE} (Using '.pkg_type')"
     else
       export PKG_TYPE="UNKNOWN"
       echo -e "[-] WARNING: ${SBUILD_PKG} is of Type 'Unknown' (Using '.pkg_type')"
       echo -e "[-] Maybe '.pkg_type' is missing/incorrect in ${SRC_SBUILD_IN}?"
       echo -e "[-] Tried Extension: ${SBUILD_PKG##*.}"
     fi
    #Check for required files
     unset DIRICON_TYPE ICON_PATH HAS_APPSTREAM HAS_DESKTOP HAS_DIRICON
     #Appstream Files (Only if Exists)
     if [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.appdata.xml" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.appdata.xml") -gt 3 ]]; then
       echo -e "[✓] Appstream Exists as ${SBUILD_PKG}.appdata.xml ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.appdata.xml"
       HAS_APPSTREAM="YES"
     elif [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.metainfo.xml" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.metainfo.xml") -gt 3 ]]; then
       echo -e "[✓] Appstream Exists as ${SBUILD_PKG}.metainfo.xml ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.metainfo.xml"
       HAS_APPSTREAM="YES"
     fi
     #Desktop (Only if Exists)
     if [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop") -gt 3 ]]; then
       echo -e "[✓] Desktop Exists as ${SBUILD_PKG}.desktop ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop"
       HAS_DESKTOP="YES"
     fi
     #DirIcon (Only if Exists)
     if [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon") -gt 1024 ]]; then
       echo -e "[✓] DirIcon Exists as ${SBUILD_PKG}.DirIcon ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon"
       HAS_DIRICON="YES" ; DIRICON_PATH="${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon"
       DIRICON_TYPE="$(file -i ${DIRICON_PATH})"
     elif [[ -s "${SBUILD_OUTDIR}/.DirIcon" && $(stat -c%s "${SBUILD_OUTDIR}/.DirIcon") -gt 1024 ]]; then
       echo -e "[✓] DirIcon Exists as '.DirIcon' ==> ${SBUILD_OUTDIR}/.DirIcon"
       HAS_DIRICON="YES" ; DIRICON_PATH="${SBUILD_OUTDIR}/.DirIcon"
       DIRICON_TYPE="$(file -i ${DIRICON_PATH})"
     fi
     #DirIcon/Icon (Only if Exists)
     if [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.png" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.png") -gt 1024 ]]; then
       echo -e "[✓] Icon Exists as ${SBUILD_PKG}.png ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.png"
       HAS_ICON="YES" ; ICON_PATH="${SBUILD_OUTDIR}/${SBUILD_PKG}.png"
       if [[ "${HAS_DIRICON}" != "YES" ]]; then
         cp -fv "${ICON_PATH}" "${SBUILD_OUTDIR}/.DirIcon"
         cp -fv "${ICON_PATH}" "${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon"
       fi
     elif [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.svg" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.svg") -gt 1024 ]]; then
       echo -e "[✓] Icon Exists as ${SBUILD_PKG}.svg ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.svg"
       HAS_ICON="YES" ; ICON_PATH="${SBUILD_OUTDIR}/${SBUILD_PKG}.svg"
       if [[ "${HAS_DIRICON}" != "YES" ]]; then
         cp -fv "${ICON_PATH}" "${SBUILD_OUTDIR}/.DirIcon"
         cp -fv "${ICON_PATH}" "${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon"
       fi
     elif [[ "${HAS_DIRICON}" == "YES" ]]; then
       if echo "${DIRICON_TYPE}" | grep -qE 'image/(png)'; then
         echo -e "[+] Copying '.DirIcon' (${DIRICON_PATH}) ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.png"
         HAS_ICON="YES" ; ICON_PATH="${SBUILD_OUTDIR}/${SBUILD_PKG}.png"
       elif echo "${DIRICON_TYPE}" | grep -qE 'image/(svg)'; then
         echo -e "[+] Copying '.DirIcon' (${DIRICON_PATH}) ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.svg"
         HAS_ICON="YES" ; ICON_PATH="${SBUILD_OUTDIR}/${SBUILD_PKG}.svg"
       else
         echo -e "[-] WARNING: (${DIRICON_PATH}) is of Type ("${DIRICON_TYPE}")"
         echo -e "[-] Only PNG/SVG Icons are Supported (Forcefully Copying as '.png')"
         cp -fv "${DIRICON_PATH}" "${SBUILD_OUTDIR}/${SBUILD_PKG}.png"
       fi
     fi
     #Version (12c if doesn't Exists)
     if [[ -s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version" && $(stat -c%s "${SBUILD_OUTDIR}/${SBUILD_PKG}.version") -gt 3 ]]; then
       echo -e "[✓] Version Exists as "$(cat ${SBUILD_OUTDIR}/${SBUILD_PKG}.version)" ==> ${SBUILD_OUTDIR}/${SBUILD_PKG}.version"
     else
       #echo -e "[-] WARNING: ${SBUILD_OUTDIR}/${SBUILD_PKG}.version is Empty/NonExistent (Using b3sum as Version)"
       #b3sum "${SBUILD_OUTDIR}/${SBUILD_PKG}" | grep -oE '^[a-f0-9]{64}' | tr -d '[:space:]' | head -c 8 > "${SBUILD_OUTDIR}/${SBUILD_PKG}.version"
       echo -e "[-] WARNING: ${SBUILD_OUTDIR}/${SBUILD_PKG}.version is Empty/NonExistent (Using date as Version)"
       date --utc +"%Y%m%d-%H%M%S" | tr -d '[:space:]' > "${SBUILD_OUTDIR}/${SBUILD_PKG}.version"
     fi
    #Check for required files for
     #AppBundle
     if echo "${PKG_TYPE}" | grep -qiE '(appbundle)$'; then
      #Attempt to fetch/fix media
       if [[ "${HAS_DESKTOP}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE 'Desktop' (Attempting to Extract Automatically)"
         timeout 10 "${SBUILD_OUTDIR}/${SBUILD_PKG}" --pbundle_desktop | base64 -d > "${SBUILD_OUTDIR}/${SBUILD_PKG}.desktop"
       fi
       if [[ "${HAS_DIRICON}" != "YES" ]] && [[ "${HAS_ICON}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         timeout 10 "${SBUILD_OUTDIR}/${SBUILD_PKG}" --pbundle_pngIcon | base64 -d > "${SBUILD_OUTDIR}/${SBUILD_PKG}.DirIcon"
       fi
     #AppImage
     elif echo "${PKG_TYPE}" | grep -qiE '(appimage)$'; then
      #Attempt to fetch/fix media
       if [[ "${HAS_DESKTOP}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         unset SQUISHY_ICON SQUISHY_FILTER; SQUISHY_DESKTOP="ON" use_squishy
       fi
       if [[ "${HAS_DIRICON}" != "YES" ]] && [[ "${HAS_ICON}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         unset SQUISHY_DESKTOP SQUISHY_FILTER; SQUISHY_ICON="ON" use_squishy
       fi
     #Archive
     elif echo "${PKG_TYPE}" | grep -qiE '(archive)$'; then
       if [[ "${HAS_DESKTOP}" != "YES" ]]; then
        echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE 'Desktop' (Requires Manual Fix)"
       fi
       if [[ "${HAS_DIRICON}" != "YES" ]] && [[ "${HAS_ICON}" != "YES" ]]; then
        echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Requires Manual Fix)"
       fi
     #FlatImage|GameImage
     elif echo "${PKG_TYPE}" | grep -qiE '(flatimage|gameimage)$'; then
      #Attempt to fetch/fix media
       if [[ "${HAS_DESKTOP}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         #todo
       fi
       if [[ "${HAS_DIRICON}" != "YES" ]] && [[ "${HAS_ICON}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         #todo
       fi
     #NixAppImage
     elif echo "${PKG_TYPE}" | grep -qiE '(nixappimage)$'; then
      #Attempt to fetch/fix media
       if [[ "${HAS_DESKTOP}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         unset SQUISHY_ICON ; SQUISHY_FILTER="${PKG%%-*}" SQUISHY_DESKTOP="ON" use_squishy
       fi
       if [[ "${HAS_DIRICON}" != "YES" ]] && [[ "${HAS_ICON}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         unset SQUISHY_DESKTOP ; SQUISHY_FILTER="${PKG%%-*}" SQUISHY_ICON="ON" use_squishy
       fi
     #RunImage
     elif echo "${PKG_TYPE}" | grep -qiE '(runimage)$'; then
      #Attempt to fetch/fix media
       if [[ "${HAS_DESKTOP}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         #squishy??
       fi
       if [[ "${HAS_DIRICON}" != "YES" ]] && [[ "${HAS_ICON}" != "YES" ]]; then
         echo -e "[-] WARNING: ${SBUILD_PKG} DOES NOT HAVE '.DirIcon|Icon' (Attempting to Extract Automatically)"
         #squishy??
       fi
     #Unknown
     elif echo "${PKG_TYPE}" | grep -qiE '(UNKNOWN)$'; then
       echo -e "[-] WARNING: ${SBUILD_PKG} is of Type 'Unknown' (Using '.pkg_type')"
       echo -e "[-] Maybe '.pkg_type' is missing/incorrect in ${SRC_SBUILD_IN}?"
       echo -e "[-] Tried Extension: ${SBUILD_PKG##*.}, will use Default (Generic) Desktop|Icon"
     fi
    #List Dirs & Files
     list_dirs ; list_files
     export SBUILD_SUCCESSFUL="YES"
   else
     echo -e "\n[✗] FATAL: CAN NOT Find ${SBUILD_PKG} in ${SBUILD_OUTDIR}\n"
     list_dirs ; list_files
     export SBUILD_SUCCESSFUL="NO"
   fi
  popd >/dev/null 2>&1
fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Cleanup & Keep Only Needed ENV
 unset cleanup_dirs cleanup_files CONTINUE_SBUILD DIRICON_PATH DIRICON_TYPE HAS_APPSTREAM HAS_DESKTOP HAS_DIRICON HAS_ICON HAS_SQUISHY ICON_PATH ICON_TYPE INPUT install_squishy list_dirs list_files sbuild_linter SBUILD_MODE SELF_NAME SQUISHY_DESKTOP SBUILD_DESKTOP_URL SBUILD_ICON_URL SBUILD_PKG_TYPE SQUISHY_FILTER SQUISHY_ICON SRC_SBUILD_IN SRC_BUILD_SCRIPT URL use_squishy
##Disable Debug
 if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
   set +x
 fi
#-------------------------------------------------------#