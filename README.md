# habermann.dotfiles

Public-safe dotfiles for Ubuntu 24.04 on WSL2 running on Windows 11.

This project is interactive by default and keeps machine-specific identity,
secrets, and overrides outside the repository.

## Quick Start

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./setup install
```

For automation:

```bash
./setup install \
  --non-interactive \
  --profile personal \
  --git-name "Your Name" \
  --git-email you@example.com \
  --tools recommended \
  --docker desktop
```

## Commands

```bash
./setup install
./setup verify
./setup doctor
./setup update
./setup uninstall
```

Useful install options:

```bash
./setup install --dry-run
./setup install --no-doctor
```

`--dry-run` shows the environment, identity, tool choices, Docker strategy, and
installation plan without creating files, links, backups, or installing tools.
`--no-doctor` skips the final doctor checks after a normal install.

## Interactive Tool Selection

The installer asks which groups to install. Each prompt includes a yes/no
choice, a recommendation tag when applicable, and a short explanation.
The interactive flow is grouped into sections: Environment, Identity, Tool
Selection, Docker, Installation Plan, Installation, Linking, and Doctor.
On reruns, existing local profile and Git identity are shown and preserved
instead of being requested again.

Example:

```text
[Y/n] Shell       (Recommended) zsh, Starship, zoxide, fzf, and pinned plugins for a fast interactive shell.
[y/N] History                   Atuin enhanced searchable shell history.
```

Recommended groups:

- `base`: Ubuntu essentials.
- `shell`: zsh, prompt, navigation, fuzzy search, and plugins.
- `modern-cli`: faster search/listing/readability tools.
- `runtime`: mise-managed language runtimes.

Optional groups:

- `history`: Atuin.

Docker is selected with one strategy prompt:

- Docker Desktop: recommended default, verifies WSL integration.
- WSL Docker Engine: installs Docker Engine inside WSL.
- None: skips Docker setup.

## Profiles and Secrets

Repo-managed templates:

- `profiles/personal.env`
- `profiles/work.env`
- `templates/git/identity.gitconfig.template`
- `templates/dotfiles/local.env.template`
- `templates/ssh/config.template`

Machine-local files:

- `~/.config/dotfiles/profile`
- `~/.config/dotfiles/local.env`
- `~/.config/dotfiles/secrets.env`
- `~/.config/git/identity.gitconfig`
- `~/.ssh/config`

The installer creates local files only when missing.

## Windows Bootstrap

From PowerShell:

```powershell
.\windows\install.ps1
```

Non-interactive example:

```powershell
.\windows\install.ps1 -NonInteractive -Preset Recommended
```

The Windows bootstrap uses winget and asks about each tool by default.

## Docker

Docker Desktop is the recommended default:

```bash
./setup install --docker desktop
```

Docker Engine inside WSL is available as an explicit opt-in:

```bash
./setup install --docker wsl-engine
```

## Test Pipeline

Run the Docker test pipeline from the repo root:

```bash
./scripts/test-docker.sh
```

Docker Desktop must be running. The script uses `docker` when WSL integration is
enabled and falls back to `docker.exe` when the Windows Docker CLI is reachable.

The pipeline builds `Dockerfile.test` with Ubuntu 24.04 and runs:

- Bash syntax checks.
- `./setup help` smoke test.
- Tool selection parser tests for presets, `--with`, `--without`, and Docker strategy.
- Non-interactive install in `DOTFILES_TEST_MODE=1` with an isolated fake home.
- Dry-run and no-doctor behavior checks.
- Idempotency checks that local identity and SSH config are not overwritten.
- `verify` and `doctor` smoke tests.

`DOTFILES_TEST_MODE=1` skips package downloads, external installers, Docker Engine
changes, and Windows/WSL integration checks so the container can validate behavior
without mutating the host or depending on Windows APIs.
