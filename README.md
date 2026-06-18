# wsl.dotfiles

Public-safe dotfiles for Ubuntu 26.04 on WSL2 running on Windows 11.

This project is interactive by default and keeps machine-specific identity,
secrets, and overrides outside the repository.

## Quick Start

Bootstrap from a fresh Ubuntu shell with one command:

```bash
git clone https://github.com/bhabermann/wsl.dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./setup install
```

Or use the step-by-step form:

```bash
git clone https://github.com/bhabermann/wsl.dotfiles.git ~/.dotfiles
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
  --docker wsl-engine \
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

- `--dry-run` previews the environment, identity, tool choices, Docker strategy,
  and installation plan without creating files, links, backups, or installing
  tools.
- `--no-doctor` skips the final doctor checks after a normal install.
- `--default-shell zsh` or `--default-shell bash` selects the login shell. Interactive installs ask
  before changing the login shell; non-interactive installs leave it unchanged
  unless this option is provided.
- `--reconfigure` edits saved setup choices. Prompts show the saved value as the
  default, so pressing Enter keeps the current selection.

Every real install first bootstraps the Ubuntu packages that later setup steps
assume are present:

```text
build-essential curl wget git openssh-client ca-certificates gnupg jq unzip zip less locales software-properties-common xdg-utils libicu78 libssl3t64 zlib1g libgssapi-krb5-2 tzdata
```

Dependency setup appears in the installation plan, but it is not a selectable
or persisted tool group.

The runtime libraries include the native ICU, SSL, Kerberos, timezone, and
compression dependencies required by mise-managed .NET. The installer also
provides `wslview`; commands honoring `BROWSER` open URLs in the default Windows
browser through `explorer.exe`.

After a real install, setup saves the selected profile, tool groups, Docker
strategy, and default-shell choice under `~/.config/dotfiles/`. Plain reruns
reuse those choices and skip onboarding prompts, then show the final
installation confirmation in interactive mode.

Explicit flags such as `--profile`, `--tools`, `--with`, `--without`,
`--docker`, and `--default-shell` override the saved baseline for that run and
are persisted after a real install.

Existing Git identity values are detected and displayed. Interactive reruns ask
whether to change them and default to preserving them; explicit `--git-name`
and `--git-email` flags update the managed identity.

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
- `modern-cli`: apt-installed search/listing/readability tools, GitHub CLI, YAML/JSON tools, and tmux.
- `runtime`: mise-managed global `node@24.17.0`, `dotnet@10.0.301`, `python@3.13.14`, `go@1.26.3`, `uv@0.11.21`, and `java@21`.

Optional groups:

- `history`: Atuin.
- `corporate-ca`: work-profile CA refresh for corporate TLS interception CAs.

Work profile installs include `corporate-ca` automatically on the first run.

## Package Policy

Ubuntu apt owns WSL system tools and general CLIs. That includes `zsh`, `fzf`,
`direnv`, `starship`, `zoxide`, `zsh-autosuggestions`,
`zsh-syntax-highlighting`, `atuin`, `ripgrep`, `fd-find`, `bat`, `tree`,
`tmux`, `jq`, `gh`, `eza`, and `yq`. `zsh-completions` remains a Git-installed
exception because Ubuntu 26.04 does not package it.

Both Bash and Zsh are configured regardless of the selected login shell. Setup
keeps `~/.bashrc` and `~/.zshrc` as regular user-owned files and maintains one
small source block in each. Shared environment, PATH, aliases, profile loading,
and local overrides live under `~/.config/dotfiles/shell/`; shell-specific
history, completion, hooks, plugins, and prompt setup remain separate. Rerunning
setup repairs missing or malformed managed source blocks while preserving user
content outside those blocks.

mise is installed from its official Ubuntu 26.04 PPA and owns globally
available developer language runtimes and project version switching for
`node`, `dotnet`, `python`, `go`, `uv`, and `java`. The managed defaults are
`node@24.17.0`, `dotnet@10.0.301`, `python@3.13.14`, `go@1.26.3`,
`uv@0.11.21`, and `java@21`. The installer links
the global mise config into `~/.config/mise/`, keeps `~/.local/bin` and
`~/.local/share/mise/shims` on `PATH`, activates mise from both Bash and Zsh,
and installs the managed global toolchain during setup so new shells should not
require a manual `mise install`.

Docker is selected with one strategy prompt:

- WSL Docker Engine: recommended default, installs Docker Engine inside WSL.
- Docker Desktop: optionally verifies Windows-side WSL integration.
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

Some corporate networks intercept TLS and present a company-controlled CA. The
work profile now includes this refresh on the first install. If tools such as
`curl`, `git`, `mise`, `npm`, package installers, or Docker setup still fail
with certificate verification errors on the work network, set up
`~/.config/dotfiles/corporate-ca.env` and rerun the refresh:

```bash
./scripts/update-corporate-ca --config ~/.config/dotfiles/corporate-ca.env
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

Docker Engine inside WSL is the recommended default:

```bash
./setup install --docker wsl-engine
```

Docker Desktop integration remains available as an explicit opt-in:

```bash
./setup install --docker desktop
```

## Test Pipeline

Run the Docker test pipeline from the repo root:

```bash
./scripts/test-docker.sh
```

Docker Engine must be running inside WSL. Setup enables its systemd service and
adds a managed PowerShell `docker` function that forwards to this WSL distro.
The test script uses `docker` when available
and can still fall back to `docker.exe` when Docker Desktop integration is used.
If Docker group membership was added during setup but the current shell session
is stale, the Docker test wrapper re-enters through `newgrp docker` so the test
command can run without requiring a manual logout/login cycle first.

The pipeline builds `Dockerfile.test` with Ubuntu 26.04 and runs:

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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the repository policy and validation
checks.

## License

MIT. See [LICENSE](LICENSE).
