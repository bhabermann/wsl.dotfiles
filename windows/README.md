# Windows Integration

This directory previously contained automatic Windows integration scripts that required PowerShell execution policy changes and administrative access. These have been removed in favor of simpler, manual setup approaches.

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

After installing, fully restart Windows Terminal and set the profile font face
to `JetBrainsMono Nerd Font` (or `JetBrainsMono NF`).

If a corporate proxy blocks the download, grab `JetBrainsMono.zip` from
<https://github.com/ryanoasis/nerd-fonts/releases/latest> and install the
`.ttf` files via the Fonts GUI (right-click -> **Install**, not "Install for
all users").

## Benefits of Manual Setup

- No PowerShell execution policy changes required
- No administrative access needed for most operations
- Clear understanding of what's being configured
- Works with restricted corporate environments