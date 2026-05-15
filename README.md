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
  --docker desktop \
  --default-shell zsh
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
./setup install --reconfigure
```

`--dry-run` shows the environment, identity, tool choices, Docker strategy, and
installation plan without creating files, links, backups, or installing tools.
`--no-doctor` skips the final doctor checks after a normal install.
Interactive mode asks whether zsh should become the login shell. In
non-interactive mode, the login shell is left unchanged unless
`--default-shell zsh` is provided.
Every real install first bootstraps the Ubuntu packages that later setup steps
assume are present: `build-essential`, `curl`, `wget`, `git`,
`ca-certificates`, `gnupg`, `jq`, `unzip`, `zip`, `locales`, and
`software-properties-common`. This dependency setup is shown in the
installation plan, but it is not a selectable or persisted tool group.
After a real install, setup saves the selected profile, tool groups, Docker
strategy, and default-shell choice under `~/.config/dotfiles/`. Plain reruns
reuse those choices and skip onboarding prompts, then show the final
installation confirmation in interactive mode. Use `--reconfigure` to edit the
saved choices; each prompt shows the saved value as the default, so pressing
Enter keeps the current selection. Explicit flags such as `--profile`,
`--tools`, `--with`, `--without`, `--docker`, and `--default-shell` override the
saved baseline for that run and are persisted after a real install.

## Interactive Tool Selection

The installer asks which groups to install. Each prompt includes a yes/no
choice, a recommendation tag when applicable, and a short explanation.
The interactive flow is grouped into sections: Environment, Identity, Tool
Selection, Docker, Installation Plan, Installation, Linking, and Doctor.
On reruns, existing local setup choices and Git identity are shown and
preserved instead of being requested again. `./setup install --reconfigure`
asks the setup questions again with saved values preselected.

Example:

```text
[Y/n] Shell       (Recommended) zsh, Starship, zoxide, fzf, and pinned plugins for a fast interactive shell.
[y/N] History                   Atuin enhanced searchable shell history.
```

Recommended groups:

- `shell`: zsh, prompt, navigation, fuzzy search, and plugins.
- `modern-cli`: faster search/listing/readability tools.
- `runtime`: mise-managed language runtimes.

Optional groups:

- `history`: Atuin.
- `corporate-ca`: work-profile follow-up for corporate TLS interception CAs.

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
- `~/.config/dotfiles/selected-tools`
- `~/.config/dotfiles/default-shell`
- `~/.config/dotfiles/corporate-ca.env`
- `~/.config/dotfiles/secrets.env`
- `~/.config/git/identity.gitconfig`
- `~/.ssh/config`

The installer creates local files only when missing.

## When Corporate CA Is Needed

Some corporate networks intercept TLS and present a company-controlled CA. If
tools such as `curl`, `git`, `mise`, `npm`, package installers, or Docker setup
fail with certificate verification errors on the work network, opt in explicitly:

```bash
./setup install --profile work --with corporate-ca
```

The installer copies
`templates/dotfiles/corporate-ca.env.template` to
`~/.config/dotfiles/corporate-ca.env` when missing. Put local hostnames, test
URLs, and the subject/issuer allowlist regex there. The repository intentionally
does not include company-specific hosts or certificate authority names.

Preview the refresh without changing system trust:

```bash
./scripts/update-corporate-ca --config ~/.config/dotfiles/corporate-ca.env --dry-run
```

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
- zsh startup checks for repo root detection, aliases, and module loading.
- Idempotency checks that local identity and SSH config are not overwritten.
- `verify` and `doctor` smoke tests.

`DOTFILES_TEST_MODE=1` skips package downloads, external installers, Docker Engine
changes, and Windows/WSL integration checks so the container can validate behavior
without mutating the host or depending on Windows APIs.
