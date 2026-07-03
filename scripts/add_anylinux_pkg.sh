#!/usr/bin/env bash
# =============================================================================
# add_anylinux_pkg.sh — Add Anylinux AppImage packages to soarpkgs, one at a time
#
# Usage:
#   ./add_anylinux_pkg.sh list                # Show missing packages
#   ./add_anylinux_pkg.sh <repo> [pkg_name]   # Generate a package YAML
#
# Examples:
#   ./add_anylinux_pkg.sh htop-AppImage
#   ./add_anylinux_pkg.sh Azahar-AppImage-Enhanced
#   ./add_anylinux_pkg.sh htop-AppImage htop     # override pkg name
#
# Dependencies: curl, jq
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$(dirname "${SCRIPT_DIR}")/packages"
MAINTAINER="QaidVoid (contact@qaidvoid.dev)"

# --- Colors ------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_BOLD='\033[1m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'; C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'; C_RESET='\033[0m'
else
  C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BLUE=''; C_CYAN=''; C_RESET=''
fi

# Authenticated GitHub API calls when GITHUB_TOKEN is set (avoids CI rate limits)
gh_api() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -sSL -H "Authorization: Bearer ${GITHUB_TOKEN}" "$@"
  else
    curl -sSL "$@"
  fi
}

log()   { echo -e "${C_BLUE}>>${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}>>${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}!!${C_RESET} $*"; }
err()   { echo -e "${C_RED}!!${C_RESET} $*" >&2; }

# =============================================================================
# Derive pkg name from repo name
#   htop-AppImage                 -> htop
#   Azahar-AppImage-Enhanced      -> azahar-enhanced
#   are-emu-appimage              -> ares-emu
# =============================================================================
derive_pkg_name() {
  local repo="$1"
  if echo "$repo" | grep -qiE -- '-[Aa]pp[Ii]mage-[Ee]nhanced$'; then
    echo "$repo" | sed -E 's/-[Aa]pp[Ii]mage-[Ee]nhanced$//' | tr '[:upper:]' '[:lower:]' | sed 's/$/-enhanced/'
  elif echo "$repo" | grep -qiE -- '-[Aa]pp[Ii]mage$'; then
    echo "$repo" | sed -E 's/-[Aa]pp[Ii]mage$//' | tr '[:upper:]' '[:lower:]'
  else
    echo "$repo" | tr '[:upper:]' '[:lower:]'
  fi
}

# =============================================================================
# List missing packages
# =============================================================================
list_missing() {
  log "Fetching package list from Anylinux-AppImages..."

  local readme_repos
  readme_repos=$(
    curl -sSL "https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/main/README.md" \
      | grep -oP 'github\.com/pkgforge-dev/\K[A-Za-z0-9_-]+' \
      | sort -u
  )

  local existing
  existing=$(
    grep -rh 'github.com/pkgforge-dev/' "${PACKAGES_DIR}"/*/*.yaml 2>/dev/null \
      | grep -oP 'pkgforge-dev/\K[A-Za-z0-9_-]+' \
      | sort -u
  )

  local count=0
  while IFS= read -r repo; do
    if ! echo "$existing" | grep -qi "^${repo}$"; then
      local pkg
      pkg=$(derive_pkg_name "$repo")
      printf "  ${C_YELLOW}%-45s${C_RESET} -> ${C_CYAN}%s${C_RESET}\n" "$repo" "$pkg"
      ((count++)) || true
    fi
  done <<< "$readme_repos"

  echo ""
  if (( count == 0 )); then
    ok "All Anylinux AppImage packages are already in soarpkgs!"
  else
    warn "Found ${count} missing packages."
    echo ""
    echo -e "  Add one with: ${C_BOLD}./add_anylinux_pkg.sh <repo>${C_RESET}"
  fi
}

# =============================================================================
# Generate a single package YAML
# =============================================================================
add_package() {
  local repo="$1"
  local pkg="${2:-$(derive_pkg_name "$repo")}"
  local pkg_dir="${PACKAGES_DIR}/${pkg}"
  local yaml_file="${pkg_dir}/appimage.stable.yaml"

  # --- Pre-flight checks -----------------------------------------------------
  if [[ -d "$pkg_dir" ]]; then
    err "Package '${pkg}' already exists at ${pkg_dir}"
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    err "jq is required but not installed."
    return 1
  fi

  # --- Fetch repo metadata ---------------------------------------------------
  log "Fetching metadata for pkgforge-dev/${repo}..."
  local api_data
  api_data=$(gh_api "https://api.github.com/repos/pkgforge-dev/${repo}" 2>/dev/null || echo '{}')

  local description homepage license_spdx
  description=$(echo "$api_data" | jq -r '.description // empty')
  homepage=$(echo "$api_data" | jq -r '.homepage // empty')
  license_spdx=$(echo "$api_data" | jq -r '.license.spdx_id // empty')

  # Fall back to sane TODO placeholders
  [[ -z "$description" || "$description" == "null" ]] && description="TODO: Add description"
  [[ -z "$homepage" || "$homepage" == "null" ]] && homepage=""
  [[ -z "$license_spdx" || "$license_spdx" == "null" || "$license_spdx" == "NOASSERTION" ]] && license_spdx="TODO"

  # --- Detect architectures from latest release assets -----------------------
  log "Checking release assets for architecture support..."
  local release_data
  release_data=$(gh_api "https://api.github.com/repos/pkgforge-dev/${repo}/releases/latest" 2>/dev/null || echo '{}')

  local asset_names
  asset_names=$(echo "$release_data" | jq -r '.assets[].name // empty')

  local hosts=()
  echo "$asset_names" | grep -qiE 'x86_64|x64|amd64' && hosts+=('"x86_64-linux"')
  echo "$asset_names" | grep -qiE 'aarch64|arm64'    && hosts+=('"aarch64-linux"')
  [[ ${#hosts[@]} -eq 0 ]] && hosts+=('"x86_64-linux"')

  local hosts_yaml=""
  for h in "${hosts[@]}"; do
    hosts_yaml+="    - ${h}\n"
  done

  # --- Check if version tags have 'v' prefix --------------------------------
  local tag_name
  tag_name=$(echo "$release_data" | jq -r '.tag_name // ""')

  local strip_v=""
  if [[ "$tag_name" =~ ^v[0-9] ]]; then
    strip_v=' | sed "s/^v//"'
  fi

  # --- Build homepage YAML ---------------------------------------------------
  local homepage_yaml="  - \"https://github.com/pkgforge-dev/${repo}\""
  if [[ -n "$homepage" ]]; then
    homepage_yaml="  - \"${homepage}\"\n${homepage_yaml}"
  fi

  # --- Generate YAML ---------------------------------------------------------
  log "Generating ${yaml_file}..."
  mkdir -p "$pkg_dir"

  cat > "$yaml_file" << EOF
#!/SBUILD
_disabled: false

pkg: "${pkg}"
pkg_id: "pkgforge-dev.${pkg}"
pkg_type: "appimage"
ghcr_pkg: "pkgforge-dev/${pkg}"
category:
  - "TODO"
description: "${description}"
homepage:
$(echo -e "$homepage_yaml")
maintainer:
  - "${MAINTAINER}"
license:
  - "${license_spdx}"
build_asset:
  - url: "TODO"
    out: "LICENSE"
note:
  - "Fetched from Pre Built Community Created AppImage. Check/Report @ https://github.com/pkgforge-dev/${repo}"
  - "[PORTABLE] (Works on AnyLinux)"
provides:
  - "${pkg}"
repology:
  - "${pkg}"
src_url:
  - "https://github.com/pkgforge-dev/${repo}"
tag:
  - "TODO"
x_exec:
  host:
$(echo -e "$hosts_yaml")
  shell: "sh"
  pkgver: |
    VERSION=\$(curl -qfsSL "https://api.github.com/repos/pkgforge-dev/${repo}/releases/latest?per_page=20" | jq -r '.tag_name')
    echo "\${VERSION%%@*}"${strip_v}
    echo "\$VERSION"
  run: |
    soar dl "https://github.com/pkgforge-dev/${repo}@\${REMOTE_PKGVER}" --glob "*\${ARCH}*.appimage" -o "./\${PKG}" --yes
EOF

  ok "Created: ${yaml_file}"
  echo ""
  warn "Review and fill in TODO fields:"
  echo -e "  ${C_CYAN}category${C_RESET}    — https://specifications.freedesktop.org/menu-spec/latest/apa.html"
  echo -e "  ${C_CYAN}build_asset${C_RESET} — URL to upstream LICENSE file"
  echo -e "  ${C_CYAN}tag${C_RESET}         — sensible tags for the app"
  echo -e "  ${C_CYAN}repology${C_RESET}    — search at https://repology.org/projects/"
  echo ""
  echo -e "  Edit: ${C_BOLD}${yaml_file}${C_RESET}"
}

# =============================================================================
# Main
# =============================================================================
main() {
  case "${1:-}" in
    ""|-h|--help|help)
      echo "Usage: $0 <command>"
      echo ""
      echo "Commands:"
      echo "  list                      Show missing Anylinux packages"
      echo "  <repo> [pkg_name]         Generate package YAML from a pkgforge repo"
      echo ""
      echo "Examples:"
      echo "  $0 list"
      echo "  $0 htop-AppImage"
      echo "  $0 Azahar-AppImage-Enhanced"
      echo "  $0 htop-AppImage htop"
      ;;
    list|--list|-l)
      list_missing
      ;;
    *)
      add_package "$@"
      ;;
  esac
}

main "$@"
