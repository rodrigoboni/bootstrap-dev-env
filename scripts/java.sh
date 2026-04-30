#!/usr/bin/env bash
set -e

if [ ! -d "$HOME/.sdkman" ]; then
  curl -s "https://get.sdkman.io" | bash
fi

source "$HOME/.sdkman/bin/sdkman-init.sh"

sdk install java 21-tem || true
sdk install java 17-tem || true

sdk default java 21-tem

echo "Java installed via SDKMAN"
