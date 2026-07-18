#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/templates/zshrc"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "Installing zsh..."
sudo apt install -y zsh

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

mkdir -p "$ZSH_CUSTOM_DIR/plugins" "$ZSH_CUSTOM_DIR/themes"

clone_if_missing() {
  local repo=$1
  local dest=$2
  if [[ ! -d "$dest" ]]; then
    echo "Cloning $repo..."
    git clone --depth=1 "$repo" "$dest"
  else
    echo "Already present: $dest"
  fi
}

clone_if_missing \
  "https://github.com/zsh-users/zsh-autosuggestions" \
  "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"

clone_if_missing \
  "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

clone_if_missing \
  "https://github.com/spaceship-prompt/spaceship-prompt.git" \
  "$ZSH_CUSTOM_DIR/themes/spaceship-prompt"

SPACESHIP_LINK="$ZSH_CUSTOM_DIR/themes/spaceship.zsh-theme"
if [[ ! -e "$SPACESHIP_LINK" ]]; then
  ln -s "$ZSH_CUSTOM_DIR/themes/spaceship-prompt/spaceship.zsh-theme" "$SPACESHIP_LINK"
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Missing zshrc template: $TEMPLATE" >&2
  exit 1
fi

if [[ -f "$HOME/.zshrc" ]] && ! cmp -s "$TEMPLATE" "$HOME/.zshrc"; then
  backup="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing ~/.zshrc to $backup"
  cp "$HOME/.zshrc" "$backup"
fi

cp "$TEMPLATE" "$HOME/.zshrc"
echo "Deployed ~/.zshrc from template"

zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_shell" != "$zsh_path" ]]; then
  echo "Setting default shell to $zsh_path..."
  if chsh -s "$zsh_path"; then
    echo "Default shell set to zsh (takes effect on next login)"
  else
    echo "Could not change default shell automatically. Run: chsh -s $zsh_path" >&2
  fi
else
  echo "Default shell is already zsh"
fi

echo "zsh configured"
