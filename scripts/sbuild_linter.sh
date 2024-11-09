#!/usr/bin/env bash
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_linter.sh")
# source <(curl -qfsSL "https://l.ajam.dev/sbuild-linter")
# sbuild-linter example.SBUILD
#
#set -x
#-------------------------------------------------------#

#-------------------------------------------------------#
sbuild_linter()
 {
 ##ENV
  #INPUT="${1:-$(cat)}"
  INPUT="${1:-$(echo "$@" | tr -d '[:space:]')}"
  SELF_NAME="${ARGV0:-${0##*/}}" ; export SELF_NAME
  if [[ -z "${INPUT}" ]]; then
    echo -e "\n[✗] FATAL: Rerun: ${SELF_NAME} /path/to/SBUILD_FILE\n"
    export CONTINUE_SBUILD="NO" && return 1
  else
    if [ -f "${INPUT}" ] && [ -s "${INPUT}" ]; then
      SRC_SBUILD="$(realpath ${INPUT})"
      SRC_SBUILD_TMP="$(mktemp)"
      SRC_BUILD_SCRIPT="$(mktemp)"
      export SRC_SBUILD SRC_SBUILD_TMP
      chmod +xwr "${SRC_SBUILD}"
      echo -e "\n[+] FILE: ${SRC_SBUILD}"
      export CONTINUE_SBUILD="YES"
    else
      echo -e "\n[✗] FATAL: ${INPUT} is NOT a file\n"
      export CONTINUE_SBUILD="NO" && return 1
    fi
  fi
  SYSTMP="$(dirname $(mktemp -u))"
 ##CMD
 #jq: Needed for some validators, yq's json support is limited
 #Shellcheck: Needed for checking x_exec.run
 #Yq: The main parser & validator
 for DEP_CMD in grep jq sed shellcheck yq; do
    case "$(command -v "${DEP_CMD}" 2>/dev/null)" in
        "") echo -e "\n[✗] FATAL: ${DEP_CMD} is NOT INSTALLED\nInstall: soar add ${DEP_CMD} --yes\n"
            export CONTINUE_SBUILD="NO"
            return 1 ;;
    esac
 done
 ##Validate
 #yaml
  validate_yaml(){
   #Sanity Check
    if [ ! -x "${SRC_SBUILD}" ] || [ ! -f "${SRC_SBUILD}" ]; then
       echo -e "\n[✗] FATAL: ${SRC_SBUILD} is NOT an executable file"
       export CONTINUE_SBUILD="NO" && return 1
    fi
   #Validator (Proper Yaml file), relying on exit status is good enough
    if ! yq eval . "$(sed 's/[[:space:]]*$//' "${SRC_SBUILD}")" >/dev/null 2>&1; then
       echo -e "\n[✗] ERROR (Validation Failed) Incorrect SBUILD File, Please recheck @ https://www.yamllint.com/\n"
      #Also show what went wrong, (could capture the output status & log at same time, and print that, instead of rerunning? )
       yq eval . "${SRC_SBUILD}"
       export CONTINUE_SBUILD="NO" && return 1
    else
      echo -e "[✓] ${SRC_SBUILD} is a Valid YAML File"
      export CONTINUE_SBUILD="YES"
    fi
   #Validator (No Empty Entries)
    unset SBUILD_EMPTIES ; SBUILD_EMPTIES="$(grep '""' "${SRC_SBUILD}")"
    if [ -n "${SBUILD_EMPTIES}" ]; then
       echo -e "[-] WARNING EMPTY Entries found, Please recheck ${SRC_SBUILD}"
       echo -e "\n${SBUILD_EMPTIES}\n"
       echo -e "[-] Removing Empty Entries..."
       grep -iv '""' "${SRC_SBUILD}" | yq 'del(.. | select(. == "" or . == []))' | yq eval 'del(.[] | select(. == null or . == ""))' | yq . > "${SRC_SBUILD_TMP}"
    else
      #Remove all trailing space, empty fields & Copy to tmp
       echo -e "[✓] ${SRC_SBUILD} contains no Empty Entries"
       sed 's/[[:space:]]*$//' "${SRC_SBUILD}" | yq 'del(.. | select(. == "" or . == []))' | yq eval 'del(.[] | select(. == null or . == ""))' | yq . > "${SRC_SBUILD_TMP}"
    fi
   #Validator (No Dupes) #Yq manages to figure it out if at top level, however chokes if deeper
    unset SBUILD_DUPES ; SBUILD_DUPES="$(awk -F: '!/^\s*-/ && $1 != "" {count[$1]++; lines[$1]=lines[$1] ? lines[$1] FS NR : NR; if (count[$1] == 2) order[++i] = $1} END {for (j = 1; j <= i; j++) {key = order[j]; print key, "(" count[key] ")", "on lines:", lines[key]}}' "${SRC_SBUILD_TMP}")"
    if [ -n "${SBUILD_DUPES}" ]; then
      echo -e "\n[✗] ERROR (Validation Failed) Duplicate Entries, Please recheck @ https://www.yamllint.com/\n"
      echo -e "${SBUILD_DUPES}\n"
      export CONTINUE_SBUILD="NO"
    else
      echo -e "[✓] ${SRC_SBUILD} contains No Duplicate Entries"
      export CONTINUE_SBUILD="YES"
    fi
   #Validator (Required Fields)
    ENFORCE_FIELDS=("pkg" "description" "src_url" "x_exec.shell" "x_exec.run")
    MISSING_FIELDS=()
    for field in "${ENFORCE_FIELDS[@]}"; do
        field_value="$(yq e ".${field}" "${SRC_SBUILD_TMP}")"
        if [[ "$field_value" == "null" || -z "$field_value" ]]; then
            MISSING_FIELDS+=("$field")
        fi
    done
    if [ ${#MISSING_FIELDS[@]} -ne 0 ]; then
      echo -e "[✗] ERROR (Validation Failed) Missing Fields (or Empty Value): ${MISSING_FIELDS[*]}"
      export CONTINUE_SBUILD="NO"
    else
      echo -e "[✓] ${SRC_SBUILD_TMP} contains ALL ENFORCED Fields"
      export CONTINUE_SBUILD="YES"
    fi
   #Validator (ENFORCED Values match a pattern)
    #EMPTY SPACES/CHARS (.pkg)
    unset EMPTIES ; EMPTIES="$(yq eval '.pkg | select(test("^[a-zA-Z0-9-_+]+$") | not) | . as $value | $value | match("[^a-zA-Z0-9-_+]";"g") | select(.string == " ") | .offset' "${SRC_SBUILD_TMP}" | paste -sd ' ' -)"
    if [ ${#EMPTIES[@]} -ne 0 ]; then
       VALUE="$(yq eval '.pkg' ${SRC_SBUILD_TMP})"
       echo -e "[✗] ERROR (Validation Failed) '.pkg' Contains Empty WhiteSpaces/TabChars == (${VALUE}) @Positions: ${EMPTIES}"
       export CONTINUE_SBUILD="NO"
    fi
    #IF NOT Exists, create, if exist, Validate
     #https://specifications.freedesktop.org/menu-spec/latest/category-registry.html#main-category-registry
     #https://specifications.freedesktop.org/menu-spec/latest/additional-category-registry.html
    CATEGORIES="$(curl -qfsSL 'https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/assets/category.json' | jq -r '.[] | keys[]' | sort -u | paste -sd ' ' -)"





    
    #INVALID URLS (.src_url)
    unset SRC_URLS ; SRC_URLS="$(yq eval '.src_url[] | select(. != null and . != "")' ${SRC_SBUILD_TMP} | paste -sd ' ' -)"
    unset NOT_URLS ; NOT_URLS="$(echo "${SRC_URLS}" | awk '{for(i=1;i<=NF;i++) if ($i !~ /^https?:\/\//) print $i}')"
    if [[ -n "${NOT_URLS}" ]]; then
      echo -e "[✗] ERROR (Validation Failed) src_url Contains Invalid URLs:"
      echo -e "${NOT_URLS}\n"
      export CONTINUE_SBUILD="NO"
    fi
   #Validator (ENFORCED Values match a pattern)
  }
  export -f validate_yaml
 #shell
  validate_shell()
  {
    SBUILD_SHELL="$(yq '.x_exec.shell' "${SRC_SBUILD_TMP}")" ; export SBUILD_SHELL="${SBUILD_SHELL}"
    if ! command -v "${SBUILD_SHELL}" &> /dev/null; then
      echo -e "\n[✗] FATAL: x_exec.shell ${SBUILD_SHELL} is NOT Installed (Available) on your ${PATH}\n"
      export CONTINUE_SBUILD="NO" && return 1
    else
      echo -e "[+] x_exec.shell == ${SBUILD_SHELL}"
      echo -e '#!/usr/bin/env '"${SBUILD_SHELL}"'\n\n'"$(yq '.x_exec.run' "${SRC_SBUILD}")" > "${SRC_BUILD_SCRIPT}"
      chmod +x "${SRC_BUILD_SCRIPT}"
      if [ ! -f "${SRC_BUILD_SCRIPT}" ] || [ ! -s "${SRC_BUILD_SCRIPT}" ]; then
        echo -e "\n[✗] FATAL: ${SRC_BUILD_SCRIPT} (Temp .x_exec.run) is NOT an executable file\n"
        cat --show-all "${SRC_BUILD_SCRIPT}"
        export CONTINUE_SBUILD="NO" && return 1
      else
        if shellcheck --severity="error" "${SRC_BUILD_SCRIPT}"; then
          echo -e "[✓] x_exec.run is a Valid ${SBUILD_SHELL} Script\n"
          shellcheck --severity="warning" "${SRC_BUILD_SCRIPT}"
          rm -f "${SRC_BUILD_SCRIPT}" 2>/dev/null
          export CONTINUE_SBUILD="YES"
        else
          echo -e "\n[✗] FATAL: x_exec.shell is NOT a Valid Script"
          echo -e "\n x_exec.run: \n$(cat "${SRC_BUILD_SCRIPT}")\n"
          #DISABLED:shellcheck --severity="warning" "${SRC_BUILD_SCRIPT}" ; echo -e "\n"
          export CONTINUE_SBUILD="NO" && return 1
        fi
      fi
    fi
  }
  export -f validate_shell
 ##Check
  echo -e "\n[+] Validating YAML"
  validate_yaml
  if [ "${CONTINUE_SBUILD}" == "NO" ]; then
    echo -e "[✗] ERROR (Validation Failed) Please correct all Mistakes & Try Again"
    echo -e "[+] TEMP_FILE: ${SRC_SBUILD_TMP}"
    echo -e "[-] Build Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md"
    echo -e "[-] Spec Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md\n"
   return 1
  else
    echo -e "\n[+] Validating Shell"
    validate_shell
    if [ "${CONTINUE_SBUILD}" != "NO" ]; then
      echo -e "[✓] ${SRC_SBUILD} Passed All Checks"
      mv -f "${SRC_SBUILD_TMP}" "${SRC_SBUILD}.validated"
      echo -e "[✓] Compare ${SRC_SBUILD}.validated with ${SRC_SBUILD} again"
      echo -e "\n" ; diff -y "${SRC_SBUILD}" "${SRC_SBUILD}.validated" 2>/dev/null ; echo -e "\n"
      echo -e "[+] Create a PR @ https://github.com/pkgforge/soarpkgs/compare"
      echo -e "[+] Build Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD.md"
      echo -e "[+] Spec Docs: https://github.com/pkgforge/soarpkgs/blob/main/SBUILD_SPEC.md\n"
    fi
  fi
}
export -f sbuild_linter
alias sbuild-linter="sbuild_linter"
#-------------------------------------------------------#
