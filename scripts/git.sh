#!/usr/bin/env bash
set -e

echo "Configuring Git..."

read -p "Enter your Git user name: " GIT_NAME
read -p "Enter your Git email: " GIT_EMAIL

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Useful defaults
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "vim"

echo "Git configured!"

# Test GitHub SSH connection
echo ""
echo "🔗 Testing GitHub SSH connection..."
ssh -T git@github.com || true

echo ""
echo "Installing github cli"

sudo apt install gh
gh auth login
gh ssh-key add ~/.ssh/id_ed25519.pub
