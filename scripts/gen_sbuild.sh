#!/usr/bin/env bash
#
# REQUIRES: awk + coreutils + curl + grep + jq + sed + yq
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/github_fetcher.sh")
# source <(curl -qfsSL "https://l.ajam.dev/github-fetcher")
#-------------------------------------------------------#

#-------------------------------------------------------#
##Enable Debug 
 if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
    set -x
 fi
 SBG_VERSION="0.0.1" && echo -e "[+] SBUILD Generator Version: ${SBG_VERSION}" ; unset SBG_VERSION
#-------------------------------------------------------#

#-------------------------------------------------------#
##CLEAR_ENV
PKG_NAME="${PKG_NAME:-}"
SRC_URL="${SRC_URL:-}"
APP_ID="${APP_ID:-}"
CATEGORY="${CATEGORY:-}"
PKG_DESCR="${PKG_DESCR:-}"
PKG_MAINTAINER="${PKG_MAINTAINER:-}"
PKG_ID="${PKG_ID:-}"
PKG_TYPE="${PKG_TYPE:-}"
RELEASE_TAG="${RELEASE_TAG:-}"
REPOLOGY="${REPOLOGY:-}"
unset GH_FETCH
##Set ENV
SELF_NAME="${ARGV0:-${0##*/}}" ; export SELF_NAME
SYSTMP="$(dirname $(mktemp -u))"
#User (For Maintainer)
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
#TMPDIR
mkdir -p "$(dirname $(mktemp -u))"
SYSTMP="$(dirname $(realpath $(mktemp -u)))"
mkdir -p "${SYSTMP}" 2>/dev/null
#-------------------------------------------------------#

#-------------------------------------------------------#
##Help
show_help() 
 {
    echo "Usage: $0 [-p|--pkg PKG_NAME] [-s|--srcurl SRC_URL] [-appid|--appid APP_ID] [-c|--category CATEGORY]"
    echo "          [-d|--desc DESCRIPTION] [-m|--maintainer MAINTAINER] [-pkgid|--pkgid PKG_ID]"
    echo "          [-t|--tag RELEASE_TAG]"
    echo
    echo "Required Options:"
    echo "  -p,  --pkg         Package name"
    echo "  -s,  --srcurl      Source URL"
    echo
    echo "Additional Options:"
    echo "  -appid,   --appid       Application ID (.app_id)"
    echo "  -c,       --category    Category (.category)"
    echo "  -d,       --desc        Package description (.description)"
    echo "  -m,       --maintainer  Package maintainer (.maintainer)"
    echo "  -pkgid,   --pkgid       Package ID (.pkg_id)"
    echo "  -pkgtype, --pkgtype     Package Type (.pkg_type)"
    echo "  -r,       --repology    Repology Project Name (.repology)"
    echo "  -t,       --tag         Release tag (Github Release Tag)"
    exit 1
 }
##ARGS
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--pkg)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                echo "Error: Package name cannot be empty or start with -"
                show_help
            fi
            PKG_NAME="$2"
            shift 2
            ;;
        -s|--srcurl)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                echo "Error: Source URL cannot be empty or start with -"
                show_help
            fi
            SRC_URL="$2"
            shift 2
            ;;
        -appid|--appid)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                APP_ID="$2"
                shift 2
            else
                echo "Error: Invalid value for APP_ID"
                show_help
            fi
            ;;
        -c|--category)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                CATEGORY="$2"
                shift 2
            else
                echo "Error: Invalid value for CATEGORY"
                show_help
            fi
            ;;
        -d|--desc)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                PKG_DESCR="$2"
                shift 2
            else
                echo "Error: Invalid value for PKG_DESCR"
                show_help
            fi
            ;;
        -m|--maintainer)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                PKG_MAINTAINER="$2"
                shift 2
            else
                echo "Error: Invalid value for PKG_MAINTAINER"
                show_help
            fi
            ;;
        -pkgid|--pkgid)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                PKG_ID="$2"
                shift 2
            else
                echo "Error: Invalid value for PKG_ID"
                show_help
            fi
            ;;
        -pkgtype|--pkgtype)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                PKG_TYPE="$2"
                shift 2
            else
                echo "Error: Invalid value for PKG_TYPE"
                show_help
            fi
            ;;
        -r|--repology)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                REPOLOGY="$2"
                shift 2
            else
                echo "Error: Invalid value for REPOLOGY"
                show_help
            fi
            ;;
        -t|--tag)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                RELEASE_TAG="$2"
                shift 2
            else
                echo "Error: Invalid value for RELEASE_TAG"
                show_help
            fi
            ;;
        *)
            echo -e "\n[✗] FATAL: Unknown option $1"
            show_help
            ;;
    esac
done
#-------------------------------------------------------#


#-------------------------------------------------------#
##Sanity Checks
#Required
PKG_NAME="$(echo "${PKG_NAME}" | tr -d '[:space:]')"
 if [[ -z "${PKG_NAME// }" ]]; then
    echo -e "\n[✗] FATAL: A Valid Package name (-p|--pkg) is Required\n"
    show_help
 fi
SRC_URL="$(echo "${SRC_URL}" | tr -d '[:space:]')"
 if [[ -z "${SRC_URL// }" ]]; then
    echo -e "\n[✗] FATAL: A Valid Source URL (-s|--srcurl) is Required\n"
    show_help
 elif [[ ! "${SRC_URL}" == http://* && ! "${SRC_URL}" == https://* ]]; then
    echo -e "\n[✗] FATAL: A Valid Source URL (https://) (-s|--srcurl) is Required\n"
    show_help
 else
    if echo "${SRC_URL}" | grep -Eqi "github.com"; then
     export GH_FETCH="YES"
    fi
 fi
##CMD
 #b3sum: Needed for Checksums
 #jq: Needed for some validators, yq's json support is limited (https://github.com/jqlang/jq)
 #Shellcheck: Needed for checking x_exec.run (https://github.com/koalaman/shellcheck)
 #Yj: Needed to convert Yaml <--> Json (https://github.com/sclevine/yj)
 #Yq: The main parser & validator (https://github.com/mikefarah/yq)
 if [ "${INSTALL_DEPS}" = "1" ] || [ "${INSTALL_DEPS}" = "ON" ]; then
   if ! command -v "soar" >/dev/null 2>&1; then
     echo -e "\n[✗] FATAL: soar is NOT INSTALLED\nInstall: https://github.com/pkgforge/soar#-installation\n"
     export CONTINUE_SBUILD="NO"
     return 1
   else
     soar env
     soar add 'b3sum#bin' 'curl#bin' 'grep/grep#base' 'jq#bin' 'sed#bin' 'shellcheck#bin' 'yj#bin' 'yq#bin' --yes
   fi
 fi
 for DEP_CMD in awk b3sum curl find grep jq sed xargs yj yq; do
    case "$(command -v "${DEP_CMD}" 2>/dev/null)" in
        "") echo -e "\n[✗] FATAL: ${DEP_CMD} is NOT INSTALLED\nInstall: soar add \"${DEP_CMD}#bin\" --yes\n"
            export CONTINUE_SBUILD="NO"
            return 1 ;;
    esac
 done
 if [ "${SHELLCHECK}" != "0" ] || [ "${SHELLCHECK}" != "OFF" ]; then
   if ! command -v "shellcheck" >/dev/null 2>&1; then
     echo -e "\n[✗] FATAL: shellcheck is NOT INSTALLED\nInstall: soar add shellcheck --yes\n"
     export CONTINUE_SBUILD="NO"
     return 1
   fi
 fi
##Docs
 show_docs(){
  echo -e "[+] Build Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md"
  echo -e "[+] Spec Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md\n"
 }
 export -f show_docs
#Export Everything
export PKG_NAME SRC_URL APP_ID CATEGORY PKG_DESCR PKG_MAINTAINER PKG_ID PKG_TYPE RELEASE_TAG REPOLOGY
TMPDIR="$(mktemp -d)" && export TMPDIR="${TMPDIR}" ; echo -e "\n[+] Using TEMP: ${TMPDIR}\n"
#Gh
if [ "${GH_FETCH}" == "YES" ]; then
 curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/github_fetcher.sh" -o "${TMPDIR}/github-fetcher"
 if [[ ! -s "${TMPDIR}/github-fetcher" || $(stat -c%s "${TMPDIR}/github-fetcher") -le 10 ]]; then
   echo -e "\n[✗] FATAL: github-fetcher could NOT BE Found\n"
  exit 1
 else
   chmod +x "${TMPDIR}/github-fetcher"
   echo -e "[+] Fetched github-fetcher ..."
 fi
fi
#Repology
curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/repology_fetcher.sh" -o "${TMPDIR}/repology-fetcher"
 if [[ ! -s "${TMPDIR}/repology-fetcher" || $(stat -c%s "${TMPDIR}/repology-fetcher") -le 10 ]]; then
   echo -e "\n[✗] FATAL: repology-fetcher could NOT BE Found\n"
  exit 1
 else
   chmod +x "${TMPDIR}/repology-fetcher"
   echo -e "[+] Fetched repology-fetcher ..."
 fi
#Get Linter
 curl -qfsSL "https://api.gh.pkgforge.dev/repos/pkgforge/sbuilder/releases?per_page=100" | jq -r '.. | objects | .browser_download_url? // empty' | grep -Ei "$(uname -m)" | grep -Eiv "tar\.gz|\.b3sum" | grep -Ei "sbuild-linter" | sort --version-sort | tail -n 1 | tr -d '[:space:]' | xargs -I "{}" curl -qfsSL "{}" -o "${TMPDIR}/sbuild-linter"
 if [[ ! -s "${TMPDIR}/sbuild-linter" || $(stat -c%s "${TMPDIR}/sbuild-linter") -le 1024 ]]; then
   echo -e "\n[✗] FATAL: sbuild-linter could NOT BE Found\n"
  exit 1
 else
   chmod +x "${TMPDIR}/sbuild-linter"
   PATH="${TMPDIR}:${PATH}"
    if ! command -v "sbuild-linter" >/dev/null 2>&1; then
     echo -e "\n[✗] FATAL: Failed to Add ${TMPDIR} to \$PATH\n"
    exit 1
    else
     echo -e "[+] Fetched sbuild-linter ..."
    fi
 fi
#-------------------------------------------------------#

#-------------------------------------------------------#
pushd "${TMPDIR}" >/dev/null 2>&1
##Github Fetcher
 if [ "${GH_FETCH}" == "YES" ]; then
   RELEASE_TAG="$(echo "${RELEASE_TAG}" | tr -d '[:space:]')"
   echo "[+] Running github-fetcher --> \"${SRC_URL}\""
   {
    github-fetcher "${SRC_URL}"
   } >/dev/null 2>&1
   if [[ -s "$(realpath './SBUILD.gh.yaml')" && $(stat -c%s "$(realpath './SBUILD.gh.yaml')") -gt 10 ]]; then
     mv -f "$(realpath './SBUILD.gh.yaml')" "${TMPDIR}/${PKG_NAME}.gh.yaml"
     GH_DESCR="$(yq e '.description' ${TMPDIR}/${PKG_NAME}.gh.yaml)"
     GH_HOMEPAGE="$(yq e '.homepage[]' ${TMPDIR}/${PKG_NAME}.gh.yaml)"
     HAS_GHFETCH="YES"
   else
     echo -e "\n[✗] FATAL: github-fetcher Failed\n"
     HAS_GHFETCH="NO"
   fi
 fi
##Repology Fetcher
 REPOLOGY="$(echo "${REPOLOGY}" | tr -d '[:space:]')"
 if [[ -n "${REPOLOGY}" ]]; then
   echo "[+] Running github-fetcher --> \"${REPOLOGY}\""
   {
    repology-fetcher "${REPOLOGY}"
   } >/dev/null 2>&1
   if [[ -s "$(realpath './SBUILD.rl.yaml')" && $(stat -c%s "$(realpath './SBUILD.rl.yaml')") -gt 10 ]]; then
     mv -f "$(realpath './SBUILD.rl.yaml')" "${TMPDIR}/${PKG_NAME}.rl.yaml"
     readarray -t "RL_DESCR" < <(sed -n 's/^description: //p' "${TMPDIR}/${PKG_NAME}.rl.yaml")
     HAS_REPOLOGY="YES"
   else
     echo -e "\n[✗] FATAL: repology-fetcher Failed\n"
     HAS_REPOLOGY="NO"
   fi
 fi
##Create
if [ "${HAS_GHFETCH}" == "YES" ]; then
 #Touch
  touch "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #Shebang
  echo "[+] Appending SBUILD Shebang ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
  echo '#!/SBUILD' > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #Disabled 
  echo "[+] Appending 'disabled: false' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
  echo -e "_disabled: false\n" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #pkg 
  echo "[+] Appending 'pkg: \"${PKG_NAME}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
  echo -e "pkg: \"${PKG_NAME}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #pkg_id 
  if [[ -n "${PKG_ID}" ]]; then
   echo "[+] Appending 'pkg_id: \"${PKG_ID}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "pkg_id: \"${PKG_ID}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
 #pkg_type (Default: appimage) 
  if [[ -n "${PKG_TYPE}" ]]; then
   echo "[+] Appending 'pkg_type: \"${PKG_TYPE}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "pkg_type: \"${PKG_TYPE}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  else
   echo "[+] Appending 'pkg_type: \"appimage\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "pkg_type: \"appimage\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
 #app_id
  if [[ -n "${APP_ID}" ]]; then
   echo "[+] Appending 'app_id: \"${APP_ID}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "app_id: \"${APP_ID}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
 #build_util
  echo "[+] Appending Common Build Utils (.build_util) ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
  echo -e 'build_util:\n  - "curl#bin"\n  - "jq#bin"\n  - "squishy-cli#bin"' >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #Category
  if [[ -n "${CATEGORY}" ]]; then
   echo "[+] Appending Categories (\${CATEGORY}) ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo "${CATEGORY}" | tr ',' '\n' | awk 'NF { printf "  - \"%s\"\n", $0 } BEGIN { print "category:" }' >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
 #Description
  if [[ -n "${DESCRIPTION}" ]]; then
   echo "[+] Appending 'description: \"${DESCRIPTION}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "description: \"${DESCRIPTION}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  elif [[ -n "${GH_DESCR}" ]]; then
   echo "[+] Appending 'description: \"${GH_DESCR}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "description: \"${GH_DESCR}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  elif [[ -n "${RL_DESCR}" ]]; then
   PS3="Please choose a description (1-${#RL_DESCR[@]}): "
   select CHOSEN in "${RL_DESCR[@]}"; do
       if [[ -n "${CHOSEN}" ]]; then
           echo "You selected: ${CHOSEN}"
           export DESCRIPTION="${CHOSEN}"
           break
       else
           echo "Invalid selection. Please try again."
       fi
   done
   if [[ -n "${DESCRIPTION}" ]]; then
     echo "[+] Appending 'description: \"${DESCRIPTION}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
     echo -e "description: \"${DESCRIPTION}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
   else
     echo -e "[-] FAILED to Fetch A Valid Description (Setting it to Empty)"
     echo -e "description: \"${DESCRIPTION}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
   fi
  fi
 #Distro PKG
  if [ "${HAS_REPOLOGY}" == "YES" ]; then
   echo "[+] Appending 'distro_pkg' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   yq eval-all 'select(fileIndex == 0) * {"distro_pkg": (select(fileIndex == 1).distro_pkg)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.rl.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
 #HomePage 
  if [[ -n "${GH_HOMEPAGE}" ]]; then
   echo "[+] Appending 'homepage' (Github) ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "homepage:\n  - \"${GH_HOMEPAGE}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
   echo -e "  - \"${SRC_URL}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
   if [ "${HAS_REPOLOGY}" == "YES" ]; then
    echo "[+] Appending 'homepage' (Repology) ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
    yq eval-all 'select(fileIndex == 0) + {"homepage": (select(fileIndex == 1).homepage)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.rl.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
    yq eval '.homepage |= unique | .homepage |= sort' -i "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
   fi
  fi
 #License
  echo "[+] Appending 'license' (Github) ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
  echo -e "license:\n  - \"\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  yq eval-all 'select(fileIndex == 0) + {"license": (select(fileIndex == 1).license)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.gh.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  if [ "${HAS_REPOLOGY}" == "YES" ]; then
    echo "[+] Appending 'license' (Repology) ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
    yq eval-all 'select(fileIndex == 0) + {"license": (select(fileIndex == 1).license)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.rl.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
  yq eval '.license |= unique | .license |= sort' -i "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #Maintainer
  if [[ -n "${PKG_MAINTAINER}" ]]; then
   echo "[+] Appending 'maintainer: \"${PKG_MAINTAINER}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "maintainer:\n  - \"${PKG_MAINTAINER}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  else
   echo "[+] Appending 'maintainer: \"${USER}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "maintainer:\n  - \"${USER}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
 #Repology
  if [ "${HAS_REPOLOGY}" == "YES" ]; then
   echo "[+] Appending 'repology: \"${REPOLOGY}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
   echo -e "repology: \"${REPOLOGY}\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
 #Src URl
  echo "[+] Appending 'src_url:' \"${SRC_URL}\"' ... [$(wc -l < ${TMPDIR}/${PKG_NAME}.SBUILD.yaml)]"
  echo -e "src_url:\n  - \"\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  yq eval-all 'select(fileIndex == 0) + {"src_url": (select(fileIndex == 1).src_url)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.gh.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  yq eval '.src_url |= unique | .src_url |= sort' -i "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #Tag
  echo "[+] Appending 'tag' (Github) ..."
  echo -e "tag:\n  - \"\"" >> "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  yq eval-all 'select(fileIndex == 0) + {"tag": (select(fileIndex == 1).tag)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.gh.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  if [ "${HAS_REPOLOGY}" == "YES" ]; then
    echo "[+] Appending 'tag' (Repology) ..."
    yq eval-all 'select(fileIndex == 0) + {"tag": (select(fileIndex == 1).tag)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.rl.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
  fi
  yq eval '.tag |= unique | .tag |= sort' -i "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
 #X_exec
  echo "[+] Appending 'x_exec' (Repology) ..."
  yq eval-all 'select(fileIndex == 0) + {"x_exec": (select(fileIndex == 1).x_exec)}' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "${TMPDIR}/${PKG_NAME}.gh.yaml" > "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" && [[ $(wc -l < "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp") -gt 4 ]] && mv "${TMPDIR}/${PKG_NAME}.SBUILD.yaml.tmp" "${TMPDIR}/${PKG_NAME}.SBUILD.yaml"
fi
popd >/dev/null 2>&1
#-------------------------------------------------------#

#-------------------------------------------------------#
if ! yq eval . <(sed 's/[[:space:]]*$//' "${TMPDIR}/${PKG_NAME}.SBUILD.yaml") >/dev/null 2>&1; then
   echo -e "\n[✗] ERROR (Generation Failed) Incorrect SBUILD File, Please Check the Logs"
   echo -e "[+] Re Run: DEBUG="1" \"${SELF_NAME}\" {OPTIONS}"
   echo -e "[+] Build Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md"
   echo -e "[+] Spec Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md"
   echo -e "[+] Inspect: \"${TMPDIR}\""
   read -t 10 -p "Remove ${TMPDIR}? [y/N] " r || r=y
   [[ ${r,,} =~ ^(n|no)$ ]] || rm -rf "${TMPDIR:?}" 2>/dev/null
 exit 1
else
   mv -f "${TMPDIR}/${PKG_NAME}.SBUILD.yaml" "$(realpath .)/${PKG_NAME}.SBUILD.yaml"
   echo -e "\n[✓] AutoGenerated SBUILD ==> $(realpath .)/${PKG_NAME}.SBUILD.yaml"
   echo -e "[+] Linting $(realpath .)/${PKG_NAME}.SBUILD.yaml ...\n"
   sbuild-linter "$(realpath .)/${PKG_NAME}.SBUILD.yaml" --pkgver
   read -t 10 -p "Remove ${TMPDIR}? [y/N] " r || r=y
   [[ ${r,,} =~ ^(n|no)$ ]] || rm -rf "${TMPDIR:?}" 2>/dev/null
fi
#-------------------------------------------------------#