# wsl.dotfiles

> 🐧 Ubuntu 26.04 on WSL2 + 🪟 Windows 11

Interactive dotfiles that keep secrets, identity, and machine overrides outside the repo.

---

## 🚀 Minimum WSL Setup

> Starting from a clean Windows install? See
> [windows/README.md](windows/README.md#install-wsl--ubuntu-2604) for how to
> install the WSL2 platform, register a named `Ubuntu-26.04` distro, and set it
> as the default before continuing below.

Three steps to a working shell: install a Nerd Font, configure Windows Terminal, then run the WSL installer.

### 1️⃣ Install Nerd Font (Windows PowerShell)

```powershell
.\windows\install-fonts-user.ps1
```

- No admin rights needed
- Installs JetBrainsMono NF for Starship icons

### 2️⃣ Set Windows Terminal font (Windows PowerShell)

```powershell
.\windows\set-terminal-font.ps1
```

Then fully restart Windows Terminal.

### 3️⃣ Install dotfiles (inside WSL)

```bash
git clone https://github.com/bhabermann/wsl.dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./setup install
```

Or step by step:

```bash
git clone https://github.com/bhabermann/wsl.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup install
```

---

## 🛠️ Setup Commands

```bash
./setup install      # install / configure
./setup verify       # show installed state
./setup doctor       # health checks
./setup update       # update packages
./setup uninstall    # remove managed files
```

Handy flags:

```bash
./setup install --dry-run          # preview only
./setup install --no-doctor        # skip final checks
./setup install --reconfigure      # re-run choices
./setup install --default-shell zsh
```

Non-interactive example:

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

---

## 📦 What Gets Installed

### Base system

Every real install first bootstraps these Ubuntu packages:

```text
build-essential curl wget git openssh-client ca-certificates openssl gnupg jq unzip zip less locales
software-properties-common xdg-utils libicu78 libssl3t64 zlib1g libgssapi-krb5-2 tzdata
```

Then the CA refresh runs before any network-heavy tools.

### Tool groups

| Group | Description |
| --- | --- |
| `shell` | zsh, Starship, zoxide, fzf, zsh plugins |
| `modern-cli` | ripgrep, fd, bat, eza, tree, tmux, jq, gh, yq |
| `runtime` | mise-managed node, dotnet, python, go, uv, java |
| `history` | Atuin enhanced shell history |
| `corporate-ca` | TLS interception CA refresh |

Recommended defaults are `shell`, `modern-cli`, and `runtime`.

Runtimes are managed by `mise`:

- `node@24.17.0`
- `dotnet@10.0.301`
- `python@3.13.14`
- `go@1.26.3`
- `uv@0.11.21`
- `java@21`

### Docker

```bash
./setup install --docker wsl-engine   # default: Docker Engine inside WSL
./setup install --docker desktop      # Docker Desktop integration
./setup install --docker none         # skip Docker
```

---

## 🪟 Windows Integration

### Windows Terminal

Install if needed:

```powershell
winget install Microsoft.WindowsTerminal
```

Then run the font helper and restart the terminal:

```powershell
.\windows\set-terminal-font.ps1
```

### Docker from Windows

If you installed Docker Engine inside WSL (`--docker wsl-engine`), `docker ps` works in WSL. To use that same engine from Windows without Docker Desktop, add a `cmd` shim:

```powershell
$bin = "$env:USERPROFILE\bin"
New-Item -ItemType Directory -Force -Path $bin | Out-Null

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$bin", 'User')
}

$docker = @"
@echo off
wsl.exe -- docker %*
"@
$compose = @"
@echo off
wsl.exe -- docker compose %*
"@

$docker | Set-Content -Encoding ascii "$bin\docker.cmd"
$compose | Set-Content -Encoding ascii "$bin\docker-compose.cmd"
```

Open a new terminal and run `docker ps` from Windows.

Quick one-off without a shim:

```powershell
wsl -- docker ps
```

See [windows/README.md](windows/README.md) for details.

---

## 🔐 Profiles & Secrets

Repo templates:

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

Setup only creates local files when they are missing.

---

## 🏢 Corporate CA

If TLS interception breaks `curl`, `git`, `mise`, or `npm`, setup can refresh CA certificates from Windows stores.

```bash
./scripts/update-corporate-ca --config ~/.config/dotfiles/corporate-ca.env
```

Preview without changes:

```bash
./scripts/update-corporate-ca --config ~/.config/dotfiles/corporate-ca.env --dry-run
```

The template is `templates/dotfiles/corporate-ca.env.template`.

---

## 🧪 Test Pipeline

```bash
./scripts/test-docker.sh
```

Tests run in an Ubuntu 26.04 container and cover:

- Bash syntax checks
- Setup help / smoke test
- Tool selection parser
- Non-interactive install
- Dry-run and no-doctor behavior
- zsh startup checks
- Idempotency
- `verify` and `doctor`

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 License

MIT. See [LICENSE](LICENSE).
