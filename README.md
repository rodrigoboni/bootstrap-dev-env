# Dev Environment Bootstrap

One-command setup for a full development environment:

- zsh (Oh My Zsh + Spaceship)
- Docker
- Java (SDKMAN)
- Node (NVM)
- Python (pyenv)

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/<your-username>/bootstrap-dev-env/main/scripts/bootstrap.sh | bash
```

## Version policy

Language runtimes resolve the latest stable release at install time (no hardcoded pins):

- **Python** — latest stable CPython 3.x via pyenv
- **Java** — latest Temurin LTS via SDKMAN
- **Node** — latest Current release via NVM (NVM itself from the latest GitHub release)
- **Docker / apt packages** — latest from their respective repos

## Shell setup

Bootstrap installs **zsh**, **Oh My Zsh**, Spaceship theme, and the plugins `zsh-autosuggestions` / `zsh-syntax-highlighting`, then deploys [`scripts/templates/zshrc`](scripts/templates/zshrc) to `~/.zshrc` and sets zsh as the default login shell. The template also wires NVM, pyenv, and SDKMAN when those tools are present.

You can run shell setup alone:

```bash
bash scripts/zsh.sh
```

## Git & GitHub setup

The script will:

- Generate an SSH key (ed25519)
- Configure SSH agent
- Prompt for Git name/email
- Test connection with GitHub

### After running

Copy your public key and add it to GitHub:

https://github.com/settings/keys

## Extra scripts

- checkrk.sh - rootkit detection tool
- sysupdate.sh - system update script
- switch-java.sh - java version switch script
- zsh.sh - zsh / Oh My Zsh configuration
