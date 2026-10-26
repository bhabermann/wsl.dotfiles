#requires -Version 5.1

<#
.SYNOPSIS
    Installs a Nerd Font for the current user without administrator rights.

.DESCRIPTION
    Downloads a Nerd Font archive from the official ryanoasis/nerd-fonts
    releases and installs the .ttf files into the per-user font store
    (%LOCALAPPDATA%\Microsoft\Windows\Fonts) plus the HKCU font registry.
    Neither location requires elevation, so this avoids the UAC prompt that
    the machine-wide winget font package triggers.

.PARAMETER FontName
    The Nerd Font release asset base name (without .zip). Defaults to
    JetBrainsMono, matching the terminal font expected by starship.toml.

.PARAMETER Force
    Reinstall fonts even if they already exist in the per-user store.
#>

param(
    [string]$FontName = "JetBrainsMono",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[fonts] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[warning] $Message" -ForegroundColor Yellow
}

$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$regKey = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
if (-not (Test-Path $regKey)) {
    New-Item -Path $regKey -Force | Out-Null
}

# Skip the download if the font already appears installed for this user.
$existing = Get-ChildItem -Path $fontDir -Filter "$FontName*.ttf" -ErrorAction SilentlyContinue
if ($existing -and -not $Force) {
    Write-Step "$FontName already installed for the current user ($($existing.Count) files). Use -Force to reinstall."
    return
}

$tmp = Join-Path $env:TEMP "nerdfont-$FontName"
$zip = Join-Path $tmp "$FontName.zip"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$FontName.zip"
Write-Step "Downloading $FontName Nerd Font from $url"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
} catch {
    Write-Warn "Download failed: $($_.Exception.Message)"
    Write-Warn "If a corporate proxy blocks the download, fetch $FontName.zip manually from"
    Write-Warn "https://github.com/ryanoasis/nerd-fonts/releases/latest and extract its .ttf files into:"
    Write-Warn "  $fontDir"
    throw
}

Write-Step "Extracting archive"
Expand-Archive -Path $zip -DestinationPath $tmp -Force

$ttfFiles = Get-ChildItem -Path $tmp -Filter "*.ttf" -Recurse
if (-not $ttfFiles) {
    throw "No .ttf files found in $FontName.zip"
}

$installed = 0
$locked = 0
foreach ($ttf in $ttfFiles) {
    $dest = Join-Path $fontDir $ttf.Name
    try {
        Copy-Item $ttf.FullName $dest -Force -ErrorAction Stop
    } catch {
        # Typically the file is in use by a running app (Windows Terminal,
        # VS Code, ...). It is already installed, so the existing copy and its
        # registration remain valid; skip and continue with the rest.
        $locked++
        continue
    }
    # Register so applications (Windows Terminal, VS Code, ...) can resolve it.
    Set-ItemProperty -Path $regKey -Name $ttf.BaseName -Value $dest
    $installed++
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

Write-Step "Installed/updated $installed font file(s) into $fontDir"
if ($locked -gt 0) {
    Write-Warn "$locked file(s) were in use and left unchanged. Close Windows Terminal, VS Code and other apps using the font, then rerun with -Force to update them."
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Fully close and reopen Windows Terminal so it picks up the new font."
Write-Host "2. Set the profile font face to 'JetBrainsMono Nerd Font' (or 'JetBrainsMono NF')."
