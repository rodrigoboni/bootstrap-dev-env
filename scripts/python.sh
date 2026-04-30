#!/usr/bin/env bash
set -e

sudo apt install -y \
  make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev curl \
  libncursesw5-dev xz-utils tk-dev libxml2-dev \
  libxmlsec1-dev libffi-dev liblzma-dev

if [ ! -d "$HOME/.pyenv" ]; then
  curl https://pyenv.run | bash
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv init --path)"
eval "$(pyenv init -)"

pyenv install -s 3.13.2
pyenv install -s 3.12.7

pyenv global 3.13.2

echo "Python installed via pyenv"
