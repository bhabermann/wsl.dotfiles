#requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$Distribution
)

$ErrorActionPreference = "Stop"
$escapedDistribution = $Distribution.Replace("'", "''")
$startMarker = "# >>> dotfiles docker-wsl >>>"
$endMarker = "# <<< dotfiles docker-wsl <<<"
$block = @"
$startMarker
function global:docker {
    & wsl.exe --distribution '$escapedDistribution' -- docker @args
}
$endMarker
"@

$documents = [Environment]::GetFolderPath("MyDocuments")
$profiles = @(
    (Join-Path $documents "WindowsPowerShell\profile.ps1"),
    (Join-Path $documents "PowerShell\profile.ps1")
)
$pattern = "(?ms)^$([regex]::Escape($startMarker)).*?^$([regex]::Escape($endMarker))\r?\n?"

foreach ($profilePath in $profiles) {
    $directory = Split-Path -Parent $profilePath
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $content = if (Test-Path $profilePath) { Get-Content -Raw $profilePath } else { "" }
    $content = [regex]::Replace($content, $pattern, "").TrimEnd()
    if ($content.Length -gt 0) { $content += [Environment]::NewLine + [Environment]::NewLine }
    $content += $block + [Environment]::NewLine
    Set-Content -Path $profilePath -Value $content -Encoding UTF8
    Write-Host "Configured WSL Docker bridge in $profilePath"
}
