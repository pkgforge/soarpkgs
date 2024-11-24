#!/usr/bin/env bash
#
# REQUIRES: awk + coreutils + curl + grep + jq + sed + yq
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/repology_fetcher.sh")
# source <(curl -qfsSL "https://l.ajam.dev/repology-fetcher")
#set -x
#-------------------------------------------------------#

#-------------------------------------------------------#
##Main
repology_fetcher()
{
  ##Enable Debug 
   if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
      set -x
   fi
  #ENV
   local INPUT="${1:-$(cat)}"
   local REPOLOGY_PKG="$(echo "${INPUT}" | tr -cd '[:alnum:]_-')"
   SYSTMP="$(dirname $(mktemp -u))"
   TMP_JSON="${SYSTMP}/repology.tmp.json"
   if [[ -z "${USER_AGENT}" ]]; then
     USER_AGENT="$(curl -qfsSL 'https://pub.ajam.dev/repos/Azathothas/Wordlists/Misc/User-Agents/ua_chrome_macos_latest.txt')"
   fi
  #Fetch
   rm -rf "${TMP_JSON}" 2>/dev/null
   echo -e "\n[+] Package: ${REPOLOGY_PKG} (${TMP_JSON})"
   curl -A "${USER_AGENT}" -qfsSL "https://repology.org/api/v1/project/${REPOLOGY_PKG}" -o "${TMP_JSON}" || curl -qfsSL "https://api.rl.pkgforge.dev/api/v1/project/${REPOLOGY_PKG}" -o "${TMP_JSON}"
   if [[ -s "${TMP_JSON}" ]] && [[ $(stat -c%s "${TMP_JSON}") -gt 100 ]]; then
     rm -rf "${SYSTMP}/repology.tmp.yaml" 2>/dev/null
     #Description
     {
      jq -r '.[] | select(.summary != null and .summary != "") | .summary' "${TMP_JSON}" | sed -e 's/["'\''`|]//g' -e 's/^[ \t]*//;s/[ \t]*$//' | sort -u | grep -viE 'l10n|ICU data|language pack' | awk '{print "description: \"" $0 "\""}' | awk '{ print length(), $0 }' | sort -n | awk '{sub(/^[0-9]+ /,""); print}'
     } 2>/dev/null > "${SYSTMP}/repology.tmp.yaml"
     #distro_pkg
      #jq -r '.[] | "[\(.repo)/\(.subrepo // "")] --> \(.srcname)"' "${TMP_JSON}" | sed -e 's/["'\''`|]//g' -e 's/^[ \t]*//;s/[ \t]*$//' | sort -u | grep -iE 'alpine_edge|arch|aur|debian_12|debian_13|debian_unstable|nix_unstable' ; echo
     {
      jq -r '{
        distro_pkg: (
          {
            archlinux: {
              aur: (
                [ .[] | select(.repo | test("aur")) ]
                | map(.srcname) | unique
              ),
              extra: (
                [ .[] | select(.repo == "arch" and .subrepo == "extra") ]
                | map(.srcname) | unique
              ),
              multilib: (
                [ .[] | select(.repo == "arch" and .subrepo == "multilib") ]
                | map(.srcname) | unique
              )
            },
            alpine: (
              [ .[] | select(.repo | test("^alpine_")) ]
              | map(.srcname) | unique
            ),
            debian: (
              [ .[] | select(.repo | test("^debian_")) ]
              | map(.srcname) | unique
            ),
            nixpkgs: (
              [ .[] | select(.repo | test("^nix_")) ]
              | map(.srcname) | unique
            )
          }
        )
      }' "${TMP_JSON}" | yq eval 'sort_keys(.distro_pkg) | del(.. | select(tag == "!!seq" and length == 0))' -P -oyaml | sed 's/- \(.*\)/- "\1"/'
     } 2>/dev/null >> "${SYSTMP}/repology.tmp.yaml"
     #HomePage
      {
       #Requires Xq 
        #curl -A "${USER_AGENT}" -qfsSL "https://repology.org/project/${REPOLOGY_PKG}/information" | xq --xpath="//section[@id='Homepage_links']//a[not(contains(@href, '/link/'))]/@href" | grep -oP 'http[^\s]+' | sed 's/\/$//' | awk 'BEGIN {print "homepage:"} {print "  - \"" $1 "\""}' | yq 'del(.. | select(tag == "!!seq" and length == 0))' -P -oyaml | sed 's/- \(.*\)/- "\1"/' ; echo
       #Just sed 
        curl -A "${USER_AGENT}" -qfsSL "https://repology.org/project/${REPOLOGY_PKG}/information" | sed -n '/<section id="Homepage_links">/,/<\/section>/p' | sed -n 's/.*<a href="\([^"]*\)".*/\1/p' | grep -oP 'http[^\s]+' | grep -Eiv "archive\.org" | sed 's/\/$//' | awk 'BEGIN {print "homepage:"} {print "  - \"" $1 "\""}' | yq 'del(.. | select(tag == "!!seq" and length == 0))' -P -oyaml | sed 's/- \(.*\)/- "\1"/' ; echo
      } 2>/dev/null >> "${SYSTMP}/repology.tmp.yaml"
     #license
     { 
      jq -r '.[] | select(.licenses != null and .licenses != "") | .licenses[]' "${TMP_JSON}" | sed -e 's/["'\''`|]//g' -e 's/^[ \t]*//;s/[ \t]*$//' -e 's/(.*)//g' | sort -u | awk '{print "  - \"" $0 "\""}' | awk 'BEGIN {print "license:"} {print}'
     } 2>/dev/null >> "${SYSTMP}/repology.tmp.yaml" 
     #tag
     {
      jq -r '.[] | select(.categories != null) | .categories[]' "${TMP_JSON}" | sed -e 's/["'\''`|]//g' -e 's/^[ \t]*//;s/[ \t]*$//' | sort -u | grep -viE 'app:gui|misc|unspecified' | awk 'BEGIN {print "tag:"} {print "  - \"" $1 "\""}'
     } 2>/dev/null >> "${SYSTMP}/repology.tmp.yaml"
     #Print Weburl
     echo -e "\n[+] https://repology.org/project/${REPOLOGY_PKG}/information\n"
     #Get Files
     sed 's/[[:space:]]*$//' "${SYSTMP}/repology.tmp.yaml" | yq 'del(.. | select(. == "" or . == []))' | yq eval 'del(.[] | select(. == null or . == ""))' | yq . > "$(realpath .)/SBUILD.rl.yaml"
     if [[ -s "$(realpath .)/SBUILD.rl.yaml" ]] && [[ $(stat -c%s "$(realpath .)/SBUILD.rl.yaml") -gt 100 ]]; then
       cat "$(realpath .)/SBUILD.rl.yaml" | yj -yj | jq . > "$(realpath .)/SBUILD.rl.json"
     fi
     #cat "$(realpath './SBUILD.rl.yaml')" && echo -e "\n"
     echo -e "\n" && yq . "$(realpath './SBUILD.rl.yaml')" && echo -e "\n"
     echo -e "[+] SBUILD (TEMP): $(realpath './SBUILD.rl.yaml')\n" 
   fi
  ##Disable Debug 
   if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
      set +x
   fi
  }
export -f repology_fetcher
alias repology-fetcher="repology_fetcher"
#Call func directly if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
   repology_fetcher "$@" <&0
fi
#-------------------------------------------------------#