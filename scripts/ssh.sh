#!/usr/bin/env bash
set -e

SSH_KEY="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY" ]; then
  echo "SSH key already exists, skipping..."
else
  read -p "Enter your email for SSH key: " EMAIL

  ssh-keygen -t ed25519 -C "$EMAIL" -f "$SSH_KEY" -N ""

  eval "$(ssh-agent -s)"
  ssh-add "$SSH_KEY"

  echo "🔑 SSH key generated:"
  cat "$SSH_KEY.pub"

  echo ""
  echo "👉 Add this key to GitHub:"
  echo "https://github.com/settings/keys"
fi

# Ensure SSH agent loads key automatically
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if ! grep -q "AddKeysToAgent yes" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config <<EOF
Host *
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
EOF
fi
