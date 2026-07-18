#!/usr/bin/env bash
# Shared helpers to resolve latest stable tool versions at install time.
# Source from install scripts after the relevant version manager is available.

# Latest stable CPython 3.x known to pyenv (excludes a/b/rc/dev).
latest_python_stable() {
  local ver
  ver="$(pyenv latest --known 3)"
  if [[ -z "$ver" ]]; then
    echo "Failed to resolve latest stable Python version" >&2
    return 1
  fi
  echo "Resolved Python: $ver" >&2
  printf '%s\n' "$ver"
}

# True if major is a Java LTS (8, 11, or 17+ every 4 years).
_is_java_lts_major() {
  local major=$1
  case "$major" in
    8|11) return 0 ;;
  esac
  if (( major >= 17 && (major - 17) % 4 == 0 )); then
    return 0
  fi
  return 1
}

# Latest Temurin LTS identifier from SDKMAN (e.g. 25.0.3-tem).
latest_java_tem_lts() {
  local best="" best_major=0 best_ver=""
  local id major ver

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    major="${id%%.*}"
    if ! _is_java_lts_major "$major"; then
      continue
    fi
    ver="${id%-tem}"
    if (( major > best_major )) || {
      (( major == best_major )) &&
        [[ "$(printf '%s\n%s\n' "$best_ver" "$ver" | sort -V | tail -1)" == "$ver" && "$ver" != "$best_ver" ]]
    }; then
      best_major=$major
      best_ver=$ver
      best=$id
    fi
  done < <(sdk list java | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?-tem' | sort -u)

  if [[ -z "$best" ]]; then
    echo "Failed to resolve latest Temurin LTS Java version" >&2
    return 1
  fi
  echo "Resolved Java: $best" >&2
  printf '%s\n' "$best"
}

# Latest NVM release tag from GitHub (e.g. v0.40.6).
latest_nvm_tag() {
  local tag
  tag="$(
    curl -fsSL -A "bootstrap-dev-env" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/repos/nvm-sh/nvm/releases/latest |
      grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' |
      head -1 |
      sed -E 's/.*"([^"]+)".*/\1/'
  )"
  if [[ -z "$tag" || "$tag" != v* ]]; then
    echo "Failed to resolve latest NVM release tag" >&2
    return 1
  fi
  echo "Resolved NVM: $tag" >&2
  printf '%s\n' "$tag"
}
