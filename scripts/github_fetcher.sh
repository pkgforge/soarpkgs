#!/usr/bin/env bash
#
# REQUIRES: awk + coreutils + curl + grep + jq + sed + yq
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/github_fetcher.sh")
# source <(curl -qfsSL "https://l.ajam.dev/github-fetcher")
#set -x
#-------------------------------------------------------#

#-------------------------------------------------------#
##Main
github_fetcher()
{
  ##Enable Debug 
   if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
      set -x
   fi
  #ENV  
   local INPUT="${1:-$(cat)}"
   local REPO_NAME="$(echo ${INPUT} | sed -E 's|^(https://github.com/)?([^/]+/[^/]+).*|\2|' | tr -d '[:space:]')"
   SYSTMP="$(dirname $(mktemp -u))"
   TMP_JSON="${SYSTMP}/github.tmp.json"
   #if [[ -z "${USER_AGENT}" ]]; then
   #  USER_AGENT="$(curl -qfsSL 'https://pub.ajam.dev/repos/Azathothas/Wordlists/Misc/User-Agents/ua_chrome_macos_latest.txt')"
   #fi
  #Fetch Metadata
   rm -rf "${TMP_JSON}" 2>/dev/null
   echo -e "\n[+] URL: https://github.com/${REPO_NAME} (${TMP_JSON})"
   curl -qfsSL "https://api.gh.pkgforge.dev/repos/${REPO_NAME}" -o "${TMP_JSON}" || curl -qfsSL "https://api.github.com/repos/${REPO_NAME}" -o "${TMP_JSON}"
   if [[ -s "${TMP_JSON}" ]] && [[ $(stat -c%s "${TMP_JSON}") -gt 100 ]]; then
     rm -rf "${SYSTMP}/github.tmp.yaml" 2>/dev/null
     #Description
     {
      jq -r '.description // ""' "${TMP_JSON}" | sed 's/`//g' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed ':a;N;$!ba;s/\r\n//g; s/\n//g' | sed 's/["'\'']//g' | sed 's/|//g' | sed 's/`//g' | awk '{print "description: \"" $0 "\""}' | awk '{ print length(), $0 }' | sort -n | awk '{sub(/^[0-9]+ /,""); print}'
     } 2>/dev/null > "${SYSTMP}/github.tmp.yaml"
     #HomePage
     {
      echo "https://github.com/${REPO_NAME}" | awk 'BEGIN {print "homepage:"} {print "  - \"" $1 "\""}' | yq 'del(.. | select(tag == "!!seq" and length == 0))' -P -oyaml | sed 's/- \(.*\)/- "\1"/'
     } 2>/dev/null >> "${SYSTMP}/github.tmp.yaml"
     #license
     {
      jq -r '.license.name // ""' "${TMP_JSON}" | sed 's/"//g' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/["'\'']//g' | sed 's/|//g' | sed 's/`//g' | sed -e 's/["'\''`|]//g' -e 's/^[ \t]*//;s/[ \t]*$//' -e 's/(.*)//g' | sort -u | awk '{print "  - \"" $0 "\""}' | awk 'BEGIN {print "license:"} {print}'
     } 2>/dev/null >> "${SYSTMP}/github.tmp.yaml"
     #Src_url
      echo -e "src_url:\n" >> "${SYSTMP}/github.tmp.yaml"
      echo "  - \"https://github.com/${REPO_NAME}\"" >> "${SYSTMP}/github.tmp.yaml"
     #tag
     {
      jq -r '.topics[]' "${TMP_JSON}" | sed 's/, /, /g' | sed 's/,/, /g' | sed 's/|//g' | sed 's/"//g' | sed -e 's/["'\''`|]//g' -e 's/^[ \t]*//;s/[ \t]*$//' | sort -u | grep -viE 'hackathon|hacktober' | awk 'BEGIN {print "tag:"} {print "  - \"" $1 "\""}'
     } 2>/dev/null >> "${SYSTMP}/github.tmp.yaml"
  #Fetch Release
    #Latest Release
     RELEASE_TAG="$(curl -qfsSL "https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases?per_page=100" | jq -r '[.[] | select(.draft == false and .prerelease == false)] | .[0].tag_name | gsub("\\s+"; "")' | tr -d '[:space:]')" ; unset HAS_RELEASE
     if [ -n "${RELEASE_TAG}" ]; then
       curl -qfsSL "https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases/tags/${RELEASE_TAG}" -o "${TMP_JSON}" || curl -qfsSL "https://api.github.com/repos/${REPO_NAME}/releases/tags/${RELEASE_TAG}" -o "${TMP_JSON}"
       if [[ -s "${TMP_JSON}" ]] && [[ $(stat -c%s "${TMP_JSON}") -gt 100 ]]; then
         if jq -r '.assets[].browser_download_url' "${TMP_JSON}" | grep -Eiv "\.zsync$" | grep -Eiq 'appimage'; then
           HAS_RELEASE="YES" ; export HAS_RELEASE ; unset HAS_AARCH64
           if jq -r '.assets[].browser_download_url' "${TMP_JSON}" | grep -Eiq 'aarch64|arm64'; then
             HAS_AARCH64="YES"
           fi
          #x_exec.pkgver 
           echo -e "x_exec:\n  shell: "bash"\n  pkgver: |" >> "${SYSTMP}/github.tmp.yaml"
           if [[ "${RELEASE_TAG}" =~ ^[a-zA-Z]+$ ]]; then
             echo "    curl -qfsSL \"https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases/latest?per_page=100\" | jq -r '.. | objects | .browser_download_url? // empty' | sed -E 's/(x86_64|aarch64)//' | tr -d '[:alpha:]' | sed 's/^[^0-9]*//; s/[^0-9]*$//' | sort --version-sort | tail -n 1 | tr -d '[:space:]'" >> "${SYSTMP}/github.tmp.yaml"
           else
             echo "    curl -qfsSL \"https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases?per_page=100\" | jq -r '[.[] | select(.draft == false and .prerelease == false)] | .[0].tag_name | gsub(\"\\\\s+\"; \"\")' | tr -d '[:space:]'" >> "${SYSTMP}/github.tmp.yaml"
           fi
         fi
       fi
     fi
    #Latest Pre-Release
     if [ "${HAS_RELEASE}" != "YES" ]; then
       RELEASE_TAG="$(curl -qfsSL "https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases?per_page=100" | jq -r '[.[] | select(.draft == false and .prerelease == true)] | .[0].tag_name | gsub("\\s+"; "")' | tr -d '[:space:]')" ; unset HAS_RELEASE
       if [ -n "${RELEASE_TAG}" ]; then
         curl -qfsSL "https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases/tags/${RELEASE_TAG}" -o "${TMP_JSON}" || curl -qfsSL "https://api.github.com/repos/${REPO_NAME}/releases/tags/${RELEASE_TAG}" -o "${TMP_JSON}" 
         if [[ -s "${TMP_JSON}" ]] && [[ $(stat -c%s "${TMP_JSON}") -gt 100 ]]; then
           if jq -r '.assets[].browser_download_url' "${TMP_JSON}" | grep -Eiv "\.zsync$" | grep -Eiq 'appimage'; then
             HAS_RELEASE="YES" ; export HAS_RELEASE
             if jq -r '.assets[].browser_download_url' "${TMP_JSON}" | grep -Eiq 'aarch64|arm64'; then
               HAS_AARCH64="YES"
             fi
             echo -e "x_exec:\n  shell: "bash"\n  pkgver: |" >> "${SYSTMP}/github.tmp.yaml"
             if [[ "${RELEASE_TAG}" =~ ^[a-zA-Z]+$ ]]; then
               echo "    curl -qfsSL \"https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases/latest?per_page=100\" | jq -r '.. | objects | .browser_download_url? // empty' | sed -E 's/(x86_64|aarch64)//' | tr -d '[:alpha:]' | sed 's/^[^0-9]*//; s/[^0-9]*$//' | sort --version-sort | tail -n 1 | tr -d '[:space:]'" >> "${SYSTMP}/github.tmp.yaml"
             else
               echo "    curl -qfsSL \"https://api.gh.pkgforge.dev/repos/${REPO_NAME}/releases?per_page=100\" | jq -r '[.[] | select(.draft == false and .prerelease == true)] | .[0].tag_name | gsub(\"\\\\s+\"; \"\")' | tr -d '[:space:]'" >> "${SYSTMP}/github.tmp.yaml"
             fi
           fi
         fi
       fi
     fi
    #Append x_exec.run
    if [ "${HAS_RELEASE}" == "YES" ]; then
     #x_exec.run 
      echo -e "  run: |" >> "${SYSTMP}/github.tmp.yaml"
      if [[ "${RELEASE_TAG}" =~ ^[a-zA-Z]+$ ]]; then
       echo '    #Tag' >> "${SYSTMP}/github.tmp.yaml"
       echo '    RELEASE_TAG="$(cat ./${SBUILD_PKG}.version)"' >> "${SYSTMP}/github.tmp.yaml"
      fi
      echo '    #Download' >> "${SYSTMP}/github.tmp.yaml"
      echo '    case "$(uname -m)" in' >> "${SYSTMP}/github.tmp.yaml"
      if [ "${HAS_AARCH64}" == "YES" ]; then
       echo '      aarch64)' >> "${SYSTMP}/github.tmp.yaml"
       if [[ "${RELEASE_TAG}" =~ ^[a-zA-Z]+$ ]]; then
         echo "        soar dl \"https://github.com/${REPO_NAME}@\${RELEASE_TAG}\" --match \"appimage\" --exclude \"x86,x64,arm,zsync\" -o \"./\${SBUILD_PKG}\" --yes" >> "${SYSTMP}/github.tmp.yaml"
       else
         echo "        soar dl \"https://github.com/${REPO_NAME}\" --match \"appimage\" --exclude \"x86,x64,arm,zsync\" -o \"./\${SBUILD_PKG}\" --yes" >> "${SYSTMP}/github.tmp.yaml"
       fi
      else
       echo '      aarch64)' >> "${SYSTMP}/github.tmp.yaml"
       echo '        echo -e "\n[✗] aarch64 is Not Yet Supported\n"' >> "${SYSTMP}/github.tmp.yaml"
       echo '       exit 1' >> "${SYSTMP}/github.tmp.yaml"
      fi
      echo '        ;;' >> "${SYSTMP}/github.tmp.yaml"
      echo '      x86_64)' >> "${SYSTMP}/github.tmp.yaml"
       if [[ "${RELEASE_TAG}" =~ ^[a-zA-Z]+$ ]]; then
         echo "        soar dl \"https://github.com/${REPO_NAME}@\${RELEASE_TAG}\" --match \"appimage\" --exclude \"aarch64,arm,zsync\" -o \"./\${SBUILD_PKG}\" --yes" >> "${SYSTMP}/github.tmp.yaml"
       else
         echo "        soar dl \"https://github.com/${REPO_NAME}\" --match \"appimage\" --exclude \"aarch64,arm,zsync\" -o \"./\${SBUILD_PKG}\" --yes" >> "${SYSTMP}/github.tmp.yaml"
       fi
      echo '        ;;' >> "${SYSTMP}/github.tmp.yaml"
      echo '    esac' >> "${SYSTMP}/github.tmp.yaml"
    #Print ReleaseUrl
     echo -e "\n[+] REPO: https://github.com/${REPO_NAME}"
     echo -e "[+] TAG: ${RELEASE_TAG}"
     sed 's/[[:space:]]*$//' "${SYSTMP}/github.tmp.yaml" | yq 'del(.. | select(. == "" or . == []))' | yq eval 'del(.[] | select(. == null or . == ""))' | yq . > "$(realpath .)/SBUILD.gh.yaml"
     if [[ -s "$(realpath .)/SBUILD.gh.yaml" ]] && [[ $(stat -c%s "$(realpath .)/SBUILD.gh.yaml") -gt 100 ]]; then
       cat "$(realpath .)/SBUILD.gh.yaml" | yj -yj | jq . > "$(realpath .)/SBUILD.gh.json"
     fi
     #cat "$(realpath './SBUILD.gh.yaml')" && echo -e "\n"
     echo -e "\n" && yq . "$(realpath './SBUILD.gh.yaml')" && echo -e "\n"
     echo -e "[+] SBUILD (TEMP): $(realpath './SBUILD.gh.yaml')\n"     
    else
      echo "[-] FATAL: Couldn't Determine Release Tags"
    fi
   fi
  ##Disable Debug 
   if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
      set +x
   fi
  }
export -f github_fetcher
alias github-fetcher="github_fetcher"
#Call func directly if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
   github_fetcher "$@" <&0
fi
#-------------------------------------------------------#