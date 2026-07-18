#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$HOME/.sdkman" ]; then
  curl -s "https://get.sdkman.io" | bash
fi

# shellcheck disable=SC1091
source "$HOME/.sdkman/bin/sdkman-init.sh"

# shellcheck source=lib/versions.sh
source "$SCRIPT_DIR/lib/versions.sh"

JAVA_VER="$(latest_java_tem_lts)"
sdk install java "$JAVA_VER"
sdk default java "$JAVA_VER"

echo "Java $JAVA_VER installed via SDKMAN"
