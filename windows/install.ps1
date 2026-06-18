#requires -Version 5.1

param(
    [switch]$NonInteractive,
    [ValidateSet("Minimal", "Recommended", "All")]
    [string]$Preset = "Recommended",
    [switch]$SkipDocker,
    [switch]$SkipFonts,
    [switch]$SkipOptionalApps
)

$ErrorActionPreference = "Stop"

$Tools = @(
    @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal"; Recommended = $true; Optional = $false; Description = "Modern terminal host for PowerShell and WSL." },
    @{ Id = "Microsoft.PowerShell"; Name = "PowerShell 7"; Recommended = $true; Optional = $false; Description = "Current PowerShell runtime." },
    @{ Id = "Git.Git"; Name = "Git for Windows"; Recommended = $true; Optional = $false; Description = "Windows-side Git and SSH support." },
    @{ Id = "GitHub.cli"; Name = "GitHub CLI"; Recommended = $true; Optional = $false; Description = "GitHub authentication and repository operations." },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code"; Recommended = $true; Optional = $false; Description = "Editor with WSL integration." },
    @{ Id = "Docker.DockerDesktop"; Name = "Docker Desktop"; Recommended = $false; Optional = $true; Description = "Optional Windows-side Docker backend; Docker Engine inside WSL is preferred." },
    @{ Id = "AgileBits.1Password"; Name = "1Password"; Recommended = $true; Optional = $false; Description = "Secrets app and SSH agent integration." },
    @{ Id = "AgileBits.1Password.CLI"; Name = "1Password CLI"; Recommended = $true; Optional = $false; Description = "Command line access to 1Password." },
    @{ Id = "Starship.Starship"; Name = "Starship"; Recommended = $true; Optional = $false; Description = "Cross-shell prompt support on Windows." },
    @{ Id = "DEVCOM.JetBrainsMonoNerdFont"; Name = "JetBrains Mono Nerd Font"; Recommended = $true; Optional = $false; Description = "Terminal glyph and font support." },
    @{ Id = "Obsidian.Obsidian"; Name = "Obsidian"; Recommended = $false; Optional = $true; Description = "Optional notes app." }
)

function Write-Step {
    param([string]$Message)
    Write-Host "[windows-bootstrap] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[warning] $Message" -ForegroundColor Yellow
}

function Test-Command {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Confirm-Tool {
    param([hashtable]$Tool)

    $defaultYes = [bool]$Tool.Recommended
    $label = if ($defaultYes) { "[Y/n]" } else { "[y/N]" }
    $tag = if ($Tool.Recommended) { " (Recommended)" } else { "" }
    $answer = Read-Host "Install $($Tool.Name)? $label$tag - $($Tool.Description)"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $defaultYes
    }
    return $answer -match "^[Yy]"
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Write-Step "Installing/upgrading $Name"
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements 2>$null
    if ($LASTEXITCODE -ne 0) {
        winget upgrade --id $Id --exact --silent --accept-package-agreements --accept-source-agreements 2>$null
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Could not install or upgrade $Name automatically. Try: winget install --id $Id --exact"
    }
}

if (-not (Test-Command winget)) {
    throw "winget is not available. Install App Installer from Microsoft Store first."
}

$Selected = New-Object System.Collections.Generic.List[hashtable]
foreach ($tool in $Tools) {
    if ($SkipDocker -and $tool.Id -eq "Docker.DockerDesktop") { continue }
    if ($SkipFonts -and $tool.Id -eq "DEVCOM.JetBrainsMonoNerdFont") { continue }
    if ($SkipOptionalApps -and $tool.Optional) { continue }

    $install = $false
    if ($NonInteractive) {
        $install = switch ($Preset) {
            "Minimal" { -not $tool.Optional -and $tool.Id -notin @("Docker.DockerDesktop", "DEVCOM.JetBrainsMonoNerdFont") }
            "Recommended" { [bool]$tool.Recommended }
            "All" { $true }
        }
    } else {
        $install = Confirm-Tool -Tool $tool
    }

    if ($install) {
        $Selected.Add($tool)
    }
}

Write-Step "Selected Windows tools"
$Selected | ForEach-Object { Write-Host "  - $($_.Name): $($_.Description)" }

if (-not $NonInteractive) {
    $confirm = Read-Host "Proceed with Windows installation? [Y/n]"
    if ($confirm -match "^[Nn]") {
        throw "Installation cancelled"
    }
}

$Folders = @(
    "C:\vm",
    "C:\vm\wsl",
    "C:\vm\wsl\exports",
    "C:\repos",
    "$env:USERPROFILE\.ssh"
)

foreach ($folder in $Folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}

foreach ($tool in $Selected) {
    Install-WingetPackage -Id $tool.Id -Name $tool.Name
}

Write-Step "Validating WSL"
wsl --status

Write-Step "Windows bootstrap complete"
Write-Host ""
Write-Host "Manual checks:" -ForegroundColor Cyan
Write-Host "1. 1Password -> Settings -> Developer -> enable CLI integration and SSH Agent."
Write-Host "2. In Ubuntu WSL, run ./setup install --docker wsl-engine to install the recommended Docker backend."
Write-Host "3. Configure terminal font to JetBrains Mono Nerd Font."
