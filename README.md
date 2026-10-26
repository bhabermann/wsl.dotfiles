# wsl.dotfiles â€” one account

A lean Debian 13 WSL 2 development environment for Windows 11 x64: one Linux
user, one Git identity, zsh, and Docker Engine. Windows setup runs without
administrator privileges. WSL 2 must already be enabled.

## Start from Windows

From this checkout in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1
```

Setup offers individual Windows apps and Linux tools, asks for a Linux password
and Git identity, and creates a distro named `dev` under
`%LOCALAPPDATA%\wsl\dev`. Linux sudo requires that password after provisioning.
The new distro and its Windows Terminal profile become defaults after successful
setup. Existing distros and unrelated profile settings remain available.

Windows Terminal uses Catppuccin Mocha and JetBrains Mono Nerd Font Mono. Missing
font faces install under the current user's font directory and HKCU font key.
No machine-wide package install or elevation fallback is used. Optional apps
that cannot install per user are reported rather than installed system-wide.

Customize from a PowerShell session:

```powershell
.\windows\install.ps1 -Distribution dev -LinuxUser developer `
  -Apps powershell,git,vscode,zoxide,starship,mise `
  -Integrations zoxide,starship,mise -LinuxTools ripgrep,fd,bat,gh,node,python

.\windows\install.ps1 -DryRun -NonInteractive
.\windows\install.ps1 -Reconfigure
```

`-InstallDirectory` changes the initial disk location. `-KeepDefaults` adds the
new environment without changing the WSL or Terminal defaults. `-SkipApps`
skips optional Windows app installation. Terminal, fonts, and the Docker bridge
are core preparation. An existing distro with an unmanaged name is never adopted.

Choices are saved under `%LOCALAPPDATA%\wsl.dotfiles`. Reruns reuse them.
First provisioning is interactive for password entry; `-NonInteractive` supports
managed reruns with an existing password and saved Git identity. A temporary
sudo rule is scoped to the provisioning process and removed on exit.

## Shell and tool choices

Core Linux tools: zsh, Starship, zoxide, fzf, Git/SSH, suggestions, syntax
highlighting, and pinned additional completions. Ctrl-R searches history with
fzf, Ctrl-T selects files, Alt-C selects a directory, and `z` / `zi` navigate
with zoxide. Optional Atuin takes over the history shortcut when selected.

Choose individual optional tools: `ripgrep`, `fd`, `bat`, `eza`, `jq`, `yq`,
`gh`, `tmux`, `tree`, `direnv`, `atuin`, `mise`, `node`, `dotnet`, `python`,
`go`, `uv`, and `java`. Debian's `yq` is the jq-based implementation.

No language runtime is installed by default. The recommended Linux preset adds
ripgrep, fd, bat, eza, jq, gh, tmux, and direnv. Mise installs only the selected
runtimes. Versions listed in `mise/default-tools.toml` are pinned; optional
Python and Java use mise defaults when no version is listed.

Inside the new distro:

```bash
cd ~/.dotfiles
./setup install --with node --with python
./setup install --reconfigure
./setup install --dry-run
./setup verify
./setup doctor
./setup update
./setup uninstall  # guidance only; does not delete data
```

`--tools minimal|recommended|all` replaces the saved baseline; `--with TOOL`
and `--without TOOL` override it. `--docker wsl-engine|none` controls Docker.
`--default-shell zsh|bash|unchanged` controls the login shell. Use
`--non-interactive --git-name "Your Name" --git-email you@example.com` for a
fresh Linux-only setup. Work/personal profiles and corporate CA tooling have
been removed; `--profile` reports its retirement.

Mise shims are the fast default on Windows and Linux. They select runtime
versions for the current project without running environment hooks at startup.
For full environment activation, use `-MiseActivation full` on Windows, or add
`export DOTFILES_MISE_ACTIVATE=1` to `~/.config/dotfiles/local.env` in Linux.

Windows zoxide, Starship, and mise installations and profile integrations are
separate choices. Initialization scripts are generated during setup, then loaded
from local files. There are no shell-startup downloads, updates, or version
probes. Rerun setup after upgrading these tools to refresh cached initialization.
Known existing initializers are migrated; custom code is preserved and duplicate
managed initialization is skipped with a setup-time warning.

Bash and zsh rc files remain regular user-owned files with a small managed source
block. Existing Git and SSH files are backed up or preserved. Keep local secrets
in `~/.config/dotfiles/secrets.env`; they are never added to this repository.
Use `~/src` for projects stored on the Linux filesystem.

## Docker from Windows

Docker Engine, Compose, and Buildx run inside the new distro. No Docker Desktop
installation or network-exposed Docker API is needed. Opening the distro or
running a Windows Docker command starts it on demand; the bridge waits up to
30 seconds for daemon readiness. There is no Windows sign-in startup task.

After reopening PowerShell or cmd:

```powershell
docker version
docker build -t my-app .
docker compose up -d
docker run --rm -v "${PWD}:/work:ro" busybox:1.37.0 ls /work
```

PowerShell uses a function; cmd and programs resolving commands through PATH
use `docker.cmd`. Both explicitly target the configured distro and retain the
current Windows working directory. The bridge supports Windows drive paths in:

- build/buildx contexts and Dockerfile `-f` / `--file`;
- Compose `-f` / `--file`, `--project-directory`, and `--env-file`;
- run/create `-v` / `--volume`, bind `--mount`, and `--env-file`;
- `docker cp` source/destination paths.

Relative paths and Linux paths pass through. Other Docker arguments are not
rewritten. Native Windows clients that require a Docker API endpoint are outside
this wrapper's scope. Windows shell quoting rules still apply to cmd commands.

## Verification

```powershell
.\scripts\test-windows.ps1 -FontTest -Benchmark
.\scripts\test-wsl.ps1
```

Windows fixtures use temporary profiles, settings, and a scratch registry key.
The font test exercises all four font faces without touching the real font
registry key. The WSL integration test creates a uniquely named disposable distro,
checks real Docker builds, mounts, Compose, PowerShell 5.1/7 and cmd forwarding,
and removes the test distro afterward. It requires network access and disk space.
It does not change daily-use defaults or profiles.

```bash
bash scripts/test-linux.sh
bash scripts/test-docker.sh
```

`DOTFILES_TEST_MODE=1` is a fixture-only mode that skips package and system changes.
The Debian container suite tests installer behavior; real systemd/WSL behavior is
covered by the disposable-distro test. See `docs/validation.md` for measured results.

The rootfs and font URLs/checksums are pinned in `windows/assets.lock.json`.
Update both URL and SHA256 when refreshing those assets; a checksum failure stops
the installer before importing or registering the download.
