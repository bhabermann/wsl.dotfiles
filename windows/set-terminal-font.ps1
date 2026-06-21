#requires -Version 5.1

<#
.SYNOPSIS
    Sets the Windows Terminal font face for the current user.

.DESCRIPTION
    Locates the Windows Terminal settings.json (Store, Preview, or unpackaged
    install), backs it up, and sets profiles.defaults.font.face so every
    profile inherits the chosen font. The default matches the family name the
    per-user Nerd Font install registers ("JetBrainsMono NF").

    No administrator rights are required.

.PARAMETER FontFace
    Exact font family name to apply. Must match a registered family. List the
    available names with:
        Add-Type -AssemblyName System.Drawing
        [System.Drawing.FontFamily]::Families |
            Where-Object { $_.Name -like "*JetBrains*" } |
            Select-Object -ExpandProperty Name

.PARAMETER SettingsPath
    Explicit path to a Windows Terminal settings.json. Overrides auto-detection.

.PARAMETER DefaultsOnly
    Only set profiles.defaults.font.face and leave per-profile font.face
    overrides untouched. By default the script also rewrites any per-profile
    font.face so an individual profile cannot override the chosen font.
#>

param(
    [string]$FontFace = "JetBrainsMono NF",
    [string]$SettingsPath,
    [switch]$DefaultsOnly
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[wt-font] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[warning] $Message" -ForegroundColor Yellow
}

# Locate settings.json across the common Windows Terminal install flavors.
if (-not $SettingsPath) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
    )
    $SettingsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $SettingsPath -or -not (Test-Path $SettingsPath)) {
    throw "Could not find Windows Terminal settings.json. Pass -SettingsPath explicitly."
}

Write-Step "Using settings file: $SettingsPath"

$raw = Get-Content -Raw -Path $SettingsPath
try {
    $json = $raw | ConvertFrom-Json
} catch {
    throw "Failed to parse settings.json. If it contains // or /* */ comments, remove them and retry. Error: $($_.Exception.Message)"
}

# Ensure profiles.defaults.font.face exists, then set it.
if ($null -eq $json.profiles) {
    $json | Add-Member -NotePropertyName profiles -NotePropertyValue ([PSCustomObject]@{}) -Force
}
if ($null -eq $json.profiles.defaults) {
    $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([PSCustomObject]@{}) -Force
}
if ($null -eq $json.profiles.defaults.font) {
    $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([PSCustomObject]@{}) -Force
}

$changes = New-Object System.Collections.Generic.List[string]

# 1) profiles.defaults.font.face
$current = $json.profiles.defaults.font.face
if ($current -ne $FontFace) {
    $json.profiles.defaults.font | Add-Member -NotePropertyName face -NotePropertyValue $FontFace -Force
    $from = if ($current) { "'$current'" } else { "<unset>" }
    $changes.Add("defaults: $from -> '$FontFace'")
}

# 2) per-profile font.face overrides (unless -DefaultsOnly)
if (-not $DefaultsOnly -and $json.profiles.list) {
    foreach ($prof in $json.profiles.list) {
        if ($null -ne $prof.font -and $null -ne $prof.font.face -and $prof.font.face -ne $FontFace) {
            $name = if ($prof.name) { $prof.name } else { $prof.guid }
            $changes.Add("profile '$name': '$($prof.font.face)' -> '$FontFace'")
            $prof.font.face = $FontFace
        }
    }
}

if ($changes.Count -eq 0) {
    Write-Step "Font face is already '$FontFace' everywhere. Nothing to change."
    return
}

# Back up before writing.
$backup = "$SettingsPath.bak"
Copy-Item -Path $SettingsPath -Destination $backup -Force
Write-Step "Backed up current settings to $backup"

$json | ConvertTo-Json -Depth 32 | Set-Content -Path $SettingsPath -Encoding UTF8

Write-Step "Applied font changes:"
$changes | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
Write-Host "Fully close and reopen Windows Terminal for the change to take effect." -ForegroundColor Cyan
