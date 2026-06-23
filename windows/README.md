# Windows Integration

This directory previously contained automatic Windows integration scripts that required PowerShell execution policy changes and administrative access. These have been removed in favor of simpler, manual setup approaches.

## Install WSL + Ubuntu 26.04

Run these from **Windows PowerShell** on a fresh machine. `wsl --install` does not
require admin on Windows 11, but may prompt for a reboot the first time the WSL
platform is enabled.

```powershell
# 1. Enable the WSL2 platform + kernel (one-time on a fresh machine).
#    --no-distribution skips the default Ubuntu so you can pick a named one.
wsl --install --no-distribution

# 2. Confirm Ubuntu-26.04 is offered by your catalog.
wsl --list --online

# 3. Install Ubuntu 26.04 as a NAMED distro. Registering it under this exact
#    name is what the docker shim's "pin to a specific distro" option targets.
wsl --install -d Ubuntu-26.04

# 4. Make it the default so `wsl` and the docker shim hit it automatically.
wsl --set-default Ubuntu-26.04

# 5. Launch it and create your Unix user.
wsl -d Ubuntu-26.04
```

Inside the new distro, finish the package update and install the dotfiles:

```bash
sudo apt update && sudo apt upgrade -y
git clone https://github.com/bhabermann/wsl.dotfiles.git ~/.dotfiles \
  && cd ~/.dotfiles && ./setup install
```

Verify from Windows:

```powershell
wsl --status          # Default Distribution: Ubuntu-26.04
wsl --list --verbose  # Ubuntu-26.04 should carry the * marker
```

> Catalog names in `wsl --list --online` shift over time. If `Ubuntu-26.04` is
> not listed, `wsl --install -d Ubuntu` grabs the current latest Ubuntu (today
> 26.04) but registers it as `Ubuntu` rather than `Ubuntu-26.04` — the named
> install above is the more deterministic path and matches the docker-shim
> examples in this document.

## Docker Integration

After `./setup install` installs Docker Engine inside WSL, you can call it from
WSL directly:

```bash
docker ps
```

To call the same engine from Windows, you have two options.

### Quick one-off

```powershell
wsl -- docker ps
```

### Recommended: a `.cmd` shim (the docker-shim helper)

A tiny `.cmd` shim on your Windows `PATH` makes `docker` work transparently from
PowerShell, cmd, and any other Windows process. It needs no Docker Desktop, no
`DOCKER_HOST`, no admin/UAC, and no PowerShell profile or execution-policy
changes.

The shim is just a two-line batch file. The default-distro form below follows
whatever `wsl --set-default` points at:

`docker.cmd`

```bat
@echo off
wsl.exe -- docker %*
```

`docker-compose.cmd`

```bat
@echo off
wsl.exe -- docker compose %*
```

**Step 1 — create a `bin` directory and add it to your user `PATH`** (one-time,
no admin needed):

```powershell
$bin = "$env:USERPROFILE\bin"
New-Item -ItemType Directory -Force -Path $bin | Out-Null

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$bin", 'User')
}
```

**Step 2 — write the shims** (here-strings must start at column 0):

```powershell
$bin = "$env:USERPROFILE\bin"

@"
@echo off
wsl.exe -- docker %*
"@ | Set-Content -Encoding ascii "$bin\docker.cmd"

@"
@echo off
wsl.exe -- docker compose %*
"@ | Set-Content -Encoding ascii "$bin\docker-compose.cmd"
```

**Step 3 — open a new terminal and verify:**

```powershell
docker ps
```

#### Pin to a specific distro (optional)

If you do not want to rely on the default distro, target one explicitly by
adding `-d <DistroName>`:

```bat
@echo off
wsl.exe -d <DistroName> -- docker %*
```

Replace `<DistroName>` with the value from `wsl --list --verbose` (for example
`Ubuntu-26.04`). A distro-pinned shim keeps hitting that distro even if you
change your default WSL distro later.

## Corporate CA Certificates

If your network uses TLS interception and you need to import corporate CA certificates into Windows:

```powershell
# Requires admin rights
certutil -addstore -f "ROOT" "path\to\corporate-ca.crt"
```

## Windows Terminal

For the best WSL experience, install Windows Terminal:

```powershell
winget install Microsoft.WindowsTerminal
```

## Fonts (no admin required)

The starship prompt relies on Nerd Font glyphs (language icons, git symbols).
The winget font package (`DEVCOM.JetBrainsMonoNerdFont`) installs machine-wide
and triggers a UAC/admin prompt. To install the font **for the current user
only**, with no admin rights, use the helper script instead:

```powershell
.\windows\install-fonts-user.ps1
```

It downloads the official JetBrains Mono Nerd Font release and copies the
`.ttf` files into `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, registering them in
the per-user (`HKCU`) font store. Pass `-Force` to reinstall, or `-FontName`
to fetch a different Nerd Font (e.g. `-FontName FiraCode`).

`install.ps1` runs this automatically unless you pass `-SkipFonts`.

After installing, fully restart Windows Terminal and set the profile font face.
You can do this automatically with the helper script:

```powershell
.\windows\set-terminal-font.ps1
```

It finds `settings.json`, backs it up to `settings.json.bak`, sets
`profiles.defaults.font.face`, and rewrites any per-profile `font.face`
overrides so an individual profile cannot fall back to the wrong font. The
default font name is `JetBrainsMono NF`, which is the exact family name the
per-user install registers. Override with `-FontFace "<name>"`, or pass
`-DefaultsOnly` to leave per-profile overrides untouched.

> The registered family name is **not** `JetBrainsMono Nerd Font` — Windows
> Terminal needs the exact name. List the installed names with:
>
> ```powershell
> Add-Type -AssemblyName System.Drawing
> [System.Drawing.FontFamily]::Families |
>     Where-Object { $_.Name -like "*JetBrains*" } |
>     Select-Object -ExpandProperty Name
> ```

To set it manually instead, point the profile font face at `JetBrainsMono NF`.

If a corporate proxy blocks the download, grab `JetBrainsMono.zip` from
<https://github.com/ryanoasis/nerd-fonts/releases/latest> and install the
`.ttf` files via the Fonts GUI (right-click -> **Install**, not "Install for
all users").

## Benefits of Manual Setup

- No PowerShell execution policy changes required
- No administrative access needed for most operations
- Clear understanding of what's being configured
- Works with restricted corporate environments