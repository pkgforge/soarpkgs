#!/usr/bin/env bash
#[VERSION=1.0.5]
# source <(curl -qfsSL "https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/scripts/sbuild_linter.sh")
# source <(curl -qfsSL "https://l.ajam.dev/sbuild-linter")
# sbuild-linter example.SBUILD
# DEBUG=1|ON sbuild-linter example.SBUILD --> runs with set -x
# INSTALL_DEPS=1|ON sbuild-linter example.SBUILD --> Installs all deps via soar
# SHOW_DIFF=1|ON sbuild-linter example.SBUILD --> shows diff between example.SBUILD & example.SBUILD.validated
# SHELLCHECK=0|OFF sbuild-linter example.SBUILD --> Disables Shellcheck
# SBUILD_MODE=1|ON sbuild-linter example.SBUILD --> Exports needed ENV Vars to sbuild-runner
#-------------------------------------------------------#

#-------------------------------------------------------#
sbuild_linter()
 {
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
 ##Set ENV for Linter
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
     soar add b3sum grep jq sed shellcheck yj yq --yes
   fi
 fi
 for DEP_CMD in b3sum grep jq sed yq; do
    case "$(command -v "${DEP_CMD}" 2>/dev/null)" in
        "") echo -e "\n[✗] FATAL: ${DEP_CMD} is NOT INSTALLED\nInstall: soar add ${DEP_CMD} --yes\n"
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
 ##Validate
 #yaml
  validate_yaml(){
   #Sanity Check
    if [ ! -x "${SRC_SBUILD}" ] || [ ! -f "${SRC_SBUILD}" ]; then
       echo -e "\n[✗] FATAL: ${SRC_SBUILD} is NOT an executable file"
       export CONTINUE_SBUILD="NO" && return 1
    fi
   #Validator (Proper Yaml file), relying on exit status is good enough
    if ! yq eval . <(sed 's/[[:space:]]*$//' "${SRC_SBUILD}") >/dev/null 2>&1; then
      echo -e "\n[✗] ERROR (Validation Failed) Incorrect SBUILD File, Please recheck @ https://www.yamllint.com"
      show_docs
      #Also show what went wrong, (could capture the output status & log at same time, and print that, instead of rerunning? )
       yq eval . "${SRC_SBUILD}"
       export CONTINUE_SBUILD="NO" && return 1
    else
      echo -e "[✓] ${SRC_SBUILD} is a Valid YAML File"
      export CONTINUE_SBUILD="YES"
    fi
   #Validator (_disabled)
    if yq eval 'has("_disabled")' "${SRC_SBUILD}" >/dev/null 2>&1; then
     if ! yq eval '.["_disabled"] == true or .["_disabled"] == false' "${SRC_SBUILD}" >/dev/null 2>&1; then
       echo -e "\n[✗] ERROR (Validation Failed) '_disabled' must either be '_disabled: false' OR '_disabled: true'"
       show_docs
     else
      export CONTINUE_SBUILD="YES"
     fi
    else
      echo -e "\n[✗] ERROR (Validation Failed) '_disabled' DOES NOT EXIST"
      show_docs
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
    unset SBUILD_DUPES ; SBUILD_DUPES="$(awk -F: '/run:/ {exit} /^[[:space:]]*- url/ || /^[[:space:]]*out/ {next} !/^\s*-/ && $1 != "" {count[$1]++; lines[$1]=lines[$1] ? lines[$1] FS NR : NR; if (count[$1] == 2) order[++i] = $1} END {for (j = 1; j <= i; j++) {key = order[j]; print key, "(" count[key] ")", "on lines:", lines[key]}}' "${SRC_SBUILD_TMP}")"
    if [ -n "${SBUILD_DUPES}" ]; then
      echo -e "\n[✗] ERROR (Validation Failed) Duplicate Entries, Please recheck @ https://www.yamllint.com/\n"
      echo -e "${SBUILD_DUPES}\n"
      export CONTINUE_SBUILD="NO" && return 1
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
      export CONTINUE_SBUILD="NO" && return 1
    else
      echo -e "[✓] ${SRC_SBUILD} contains ALL ENFORCED Fields"
      export CONTINUE_SBUILD="YES"
    fi
   #Validator (Fields containing single Values)
   SINGLE_VALUES=(".pkg" ".pkg_id" ".pkg_type" ".description")
   for VALUE in "${SINGLE_VALUES[@]}"; do
      VALUE_CHECK="$(yq eval "${VALUE} | type" "${SRC_SBUILD_TMP}")"
      VALUE_CHECK="$(echo "${VALUE_CHECK}" | sed 's/^!!//')"
     if [[ "${VALUE_CHECK}" == "array" || "${VALUE_CHECK}" == "seq" ]]; then
        echo -e "[✗] ERROR (Validation Failed) '${VALUE}' contains Multiple Entries (Array/Sequence):"
        yq eval "${VALUE}" "${SRC_SBUILD_TMP}"
        export CONTINUE_SBUILD="NO" && return 1
     #elif [[ "${VALUE_CHECK}" == "null" ]]; then
     #   echo -e "[-] WARNING '${VALUE}' NOT Found in ${SRC_SBUILD_TMP}"
     elif [[ "${VALUE_CHECK}" != "str" ]]; then
        echo -e "[✗] ERROR (Validation Failed) '${VALUE}' is NOT A STRING (is ${VALUE_CHECK} ?)"
        export CONTINUE_SBUILD="NO" && return 1
     elif [[ "${VALUE_CHECK}" != "null" && "${VALUE_CHECK}" != "str" && "${VALUE_CHECK}" != "array" ]]; then
       echo -e "[✗] ERROR YQ Parser is broken (Was Checking Single Values for '${VALUE}', Found ${VALUE_CHECK})"
       export CONTINUE_SBUILD="NO" && return 1
     else
       export CONTINUE_SBUILD="YES"
     fi
   done
   #Validator (ENFORCED Values match a pattern)
    #EMPTY SPACES & SPECIAL CHARS
     for FIELD in ".pkg" ".pkg_id" ".pkg_type"; do
         CHARS="$(yq eval "${FIELD}" "${SRC_SBUILD_TMP}")"
         INVALID_CHARS=""
         for i in $(seq 0 $((${#CHARS} - 1))); do
             CHAR="${CHARS:i:1}"
             [[ "${CHAR}" =~ [[:space:][:punct:]] && ! "${CHAR}" =~ [\+\-_\.] ]] && INVALID_CHARS+="${CHAR// /[SPACE]} "
         done
         if [[ -n "${INVALID_CHARS}" ]]; then
             echo -e "[✗] ERROR (Validation Failed) '${FIELD}' == (${CHARS}) has Invalid Characters : ${INVALID_CHARS}"
             export CONTINUE_SBUILD="NO" && return 1
         else
           export CONTINUE_SBUILD="YES"
         fi
     done
    #Only Accepted (.pkg_type)
     readarray -t PKG_TYPES < <(echo -e "appbundle\nappimage\narchive\ndynamic\nflatimage\ngameimage\nnixappimage\nrunimage\nstatic")
     PKG_TYPE="$(yq eval '.pkg_type' "${SRC_SBUILD_TMP}" 2>/dev/null)"
     VALID_PKGTYPE=false
     for TYPE in "${PKG_TYPES[@]}"; do
         if [[ "${PKG_TYPE}" == "${TYPE}" ]]; then
             VALID_PKGTYPE=true
             break
         fi
     done
     if [[ "${VALID_PKGTYPE}" == false ]]; then
       echo -e "[✗] ERROR (Validation Failed) '.pkg_type' has Invalid Type: ${PKG_TYPE}"
       echo -e "[-] Correct Types (Only 1): ${PKG_TYPES[*]}"
       export CONTINUE_SBUILD="NO" && return 1
     else
       export CONTINUE_SBUILD="YES"
     fi
    #IF NOT Exists, create, if exist, Validate (.category)
     #https://specifications.freedesktop.org/menu-spec/latest/category-registry.html#main-category-registry
     #https://specifications.freedesktop.org/menu-spec/latest/additional-category-registry.html
     unset CATEGORIES ; CATEGORIES="$(curl -qfsSL 'https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/assets/category.json' | jq -r '.[] | keys[]' | sort -u)"
     if [ -n "${CATEGORIES}" ]; then
        CATS="$(yq eval '.category | join("\n")' "${SRC_SBUILD_TMP}" 2>/dev/null)"
        if [ -n "${CATS}" ]; then
          CATS=($(echo "${CATS}" | awk 'NF'))
          INVALID_CAT=()
          for CAT in "${CATS[@]}"; do
             if ! echo "${CATEGORIES}" | grep -qx "${CAT}"; then
                 INVALID_CAT+=("${CAT}")
             fi
          done
          if [ ${#INVALID_CAT[@]} -ne 0 ]; then
            echo -e "[✗] ERROR (Validation Failed) Invalid Categories"
            echo -e "[-] Main Categories: https://specifications.freedesktop.org/menu-spec/latest/category-registry.html#main-category-registry"
            echo -e "[-] Additional Categories: https://specifications.freedesktop.org/menu-spec/latest/additional-category-registry.html"
            echo -e "[-] Remove or Leave this field empty to AutoUse 'Utility' (Put this value in 'tag' Instead):"
            for I_CAT in "${INVALID_CAT[@]}"; do
                echo " - \"${I_CAT}\""
            done
            export CONTINUE_SBUILD="NO" && return 1
          else
           export CONTINUE_SBUILD="YES"
          fi
        else
          echo -e "[-] No Categories Found... Setting it to 'Utility'"
          echo -e "[-] Main Categories: https://specifications.freedesktop.org/menu-spec/latest/category-registry.html#main-category-registry"
          echo -e "[-] Additional Categories: https://specifications.freedesktop.org/menu-spec/latest/additional-category-registry.html"
          sed '/^category:/,/^description:/ { /^description:/!d }' -i "${SRC_SBUILD_TMP}"
          sed '/description:/i category:\n  - "Utility"' -i "${SRC_SBUILD_TMP}"
          CATS="$(yq eval '.category | join("\n")' "${SRC_SBUILD_TMP}" 2>/dev/null)"
          if [ -z "${CATS// }" ]; then
            echo -e "[✗] ERROR (Validation Failed) Could NOT Append Category, Add Manually"
            export CONTINUE_SBUILD="NO" && return 1
          fi
        fi
     else
        echo -e "\n[✗] FATAL: Couldn't Fetch Categories from Remote"
        export CONTINUE_SBUILD="NO" && return 1
     fi
    #INVALID URLS (.homepage)
     unset SRC_URLS ; SRC_URLS="$(yq eval '.homepage[] | select(. != null and . != "")' ${SRC_SBUILD_TMP} | paste -sd ' ' -)"
     if [[ -n "${SRC_URLS}" ]]; then
       unset NOT_URLS ; NOT_URLS="$(echo "${SRC_URLS}" | awk '{for(i=1;i<=NF;i++) if ($i !~ /^https?:\/\//) print $i}')"
       if [[ -n "${NOT_URLS}" ]]; then
         echo -e "[✗] ERROR (Validation Failed) 'homepage:' Contains Invalid URLs:"
         echo -e "${NOT_URLS}\n"
         export CONTINUE_SBUILD="NO" && return 1
       else
         export CONTINUE_SBUILD="YES"
       fi
     fi
    #INVALID URLS (.src_url)
     unset SRC_URLS ; SRC_URLS="$(yq eval '.src_url[] | select(. != null and . != "")' ${SRC_SBUILD_TMP} | paste -sd ' ' -)"
     if [[ -n "${SRC_URLS}" ]]; then
       unset NOT_URLS ; NOT_URLS="$(echo "${SRC_URLS}" | awk '{for(i=1;i<=NF;i++) if ($i !~ /^https?:\/\//) print $i}')"
       if [[ -n "${NOT_URLS}" ]]; then
         echo -e "[✗] ERROR (Validation Failed) 'src_url:' Contains Invalid URLs:"
         echo -e "${NOT_URLS}\n"
         export CONTINUE_SBUILD="NO" && return 1
       else
         export CONTINUE_SBUILD="YES"
       fi
     fi
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
          if [ "${SBUILD_MODE}" != "1" ] && [ "${SBUILD_MODE}" != "ON" ]; then
             rm -f "${SRC_BUILD_SCRIPT}" 2>/dev/null
          fi
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
  echo -e "\n[+] Validating YAML..."
  validate_yaml
  if [ "${CONTINUE_SBUILD}" == "NO" ]; then
    echo -e "[✗] ERROR (Validation Failed) Please correct all Mistakes & Try Again"
    echo -e "[+] TEMP_FILE: ${SRC_SBUILD_TMP}"
    show_docs
   return 1
  else
   #ShellCheck 
    if [ "${SHELLCHECK}" = "0" ] || [ "${SHELLCHECK}" = "OFF" ]; then
     echo -e "[-] Skipping Shellcheck... (Assuming You Checked it Manually)"
     echo -e "[+] unset SHELLCHECK || SHELLCHECK=ON , and ReRun to Enable it"
    else
     echo -e "\n[+] Validating Shell..."
     validate_shell
    fi
   #After All Checks 
    if [ "${CONTINUE_SBUILD}" != "NO" ]; then
      echo -e "[✓] ${SRC_SBUILD} Passed All Checks"
      mv -f "${SRC_SBUILD_TMP}" "${SRC_SBUILD}.validated"
      echo -e "[+] Compare ${SRC_SBUILD}.validated with ${SRC_SBUILD} again"
      if [ "${SHOW_DIFF}" = "1" ] || [ "${SHOW_DIFF}" = "ON" ]; then
         echo -e "\n" ; diff -y "${SRC_SBUILD}" "${SRC_SBUILD}.validated" 2>/dev/null ; echo -e "\n"
      fi
      if [ "${SBUILD_MODE}" = "1" ] || [ "${SBUILD_MODE}" = "ON" ]; then
       echo -e "[+] Exporting ENV VARS for sbuild-runner..."
       SRC_SBUILD_IN="$(realpath "${SRC_SBUILD}.validated")"
       export CONTINUE_SBUILD SRC_SBUILD_IN SRC_BUILD_SCRIPT
       unset CATEGORIES CATS CHAR DEP_CMD ENFORCE_FIELDS INPUT INVALID_CAT INVALID_CHARS MISSING_FIELDS NOT_URLS PKG_TYPES SBUILD_DUPES SBUILD_EMPTIES SBUILD_SHELL SELF_NAME SHELLCHECK SINGLE_VALUES SRC_SBUILD SRC_SBUILD_TMP SRC_URLS VALID_PKGTYPE VALUE VALUE_CHECK
      else
       echo -e "[+] Cleaning ENV VARS..."
       unset CATEGORIES CATS CHAR CONTINUE_SBUILD DEP_CMD ENFORCE_FIELDS INPUT INVALID_CAT INVALID_CHARS MISSING_FIELDS NOT_URLS PKG_TYPES SBUILD_DUPES SBUILD_EMPTIES SBUILD_SHELL SELF_NAME SHELLCHECK SINGLE_VALUES SRC_SBUILD SRC_BUILD_SCRIPT SRC_SBUILD_TMP SRC_URLS VALID_PKGTYPE VALUE VALUE_CHECK
       echo -e "[+] Create a PR @ https://github.com/pkgforge/soarpkgs/compare"
       echo -e "[+] Create an Issue @ https://github.com/pkgforge/soarpkgs/issues/new"
       show_docs
      fi
    fi
  fi
  #Disable Debug
  if [ "${DEBUG}" = "1" ] || [ "${DEBUG}" = "ON" ]; then
    set +x
  fi
}
export -f sbuild_linter
alias sbuild-linter="sbuild_linter"
#-------------------------------------------------------#