# Dev Environment Bootstrap

One-command setup for a full development environment:

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
