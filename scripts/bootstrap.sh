#!/usr/bin/env bash

set -euo pipefail

echo "🚀 Starting dev environment bootstrap..."

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure sudo upfront
if ! sudo -v; then
  echo "❌ Sudo privileges required"
  exit 1
fi

# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Detect OS
if ! grep -qi ubuntu /etc/os-release; then
  echo "⚠️ This script is optimized for Ubuntu"
fi

# Core dependencies
echo "📦 Installing base packages..."
sudo apt update
sudo apt install -y \
  curl git unzip build-essential ca-certificates gnupg

# Run modules
echo "🐳 Installing Docker..."
bash "$BASE_DIR/docker.sh"

echo "☕ Installing Java (SDKMAN)..."
bash "$BASE_DIR/java.sh"

echo "🟢 Installing Node (NVM)..."
bash "$BASE_DIR/node.sh"

echo "🐍 Installing Python (pyenv)..."
bash "$BASE_DIR/python.sh"

echo "🔐 Setting up SSH..."
bash "$BASE_DIR/ssh.sh"

echo "📦 Configuring Git..."
bash "$BASE_DIR/git.sh"

echo "✅ Bootstrap completed!"
echo "👉 Restart your terminal or run: source ~/.zshrc"

