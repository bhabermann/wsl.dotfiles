Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8File {
    param([string]$Path, [string]$Content, [switch]$Backup)
    if (Test-Path -LiteralPath $Path) {
        $old = [IO.File]::ReadAllText($Path)
        if ($old -eq $Content) { return }
        if ($Backup) { Copy-Item -LiteralPath $Path -Destination "$Path.bak.$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssffff'))" }
    }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding $false))
}

function Get-VerifiedDownload {
    param([string]$Url, [string]$Sha256, [string]$Destination)
    if ($Sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw "A SHA256 checksum is required for $Url" }
    if ((Test-Path -LiteralPath $Destination) -and (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -eq $Sha256) { return $Destination }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Destination)) | Out-Null
    $temporary = "$Destination.partial"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $temporary
        if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $Sha256) { throw "Checksum mismatch: $Url" }
        Move-Item -LiteralPath $temporary -Destination $Destination -Force
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
    return $Destination
}

function Get-TerminalSettingsPath {
    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
    return $candidates[0]
}

function Set-JsoncDefaultProfile {
    param([string]$Text, [string]$Guid)
    # Scan strings and comments; replace only the root property.
    $depth = 0; $i = 0; $root = -1
    while ($i -lt $Text.Length) {
        $c = $Text[$i]
        if ($c -eq '/' -and $i + 1 -lt $Text.Length) {
            if ($Text[$i+1] -eq '/') {
                while ($i -lt $Text.Length -and $Text[$i] -ne [char]10) { $i++ }
                continue
            }
            if ($Text[$i+1] -eq '*') {
                $end = $Text.IndexOf('*/', $i+2)
                if ($end -lt 0) { throw 'Unterminated Terminal settings comment' }
                $i = $end + 2; continue
            }
        }
        if ($c -eq '"') {
            $start = $i; $i++
            while ($i -lt $Text.Length) {
                if ($Text[$i] -eq '\') { $i += 2; continue }
                if ($Text[$i] -eq '"') { break }
                $i++
            }
            if ($i -ge $Text.Length) { throw 'Unterminated Terminal settings string' }
            $token = $Text.Substring($start, $i-$start+1)
            if ($depth -eq 1 -and $token -eq '"defaultProfile"') {
                $tail = [regex]::Match($Text.Substring($i+1), '^\s*:\s*"([^"\\]|\\.)*"')
                if (-not $tail.Success) { throw 'Unsupported defaultProfile value; restore valid Terminal settings.' }
                $valueOffset = $tail.Value.IndexOf('"')
                $valueStart = $i + 1 + $valueOffset
                $valueLength = $tail.Length - $valueOffset
                return $Text.Substring(0,$valueStart) + '"' + $Guid + '"' + $Text.Substring($valueStart+$valueLength)
            }
        } elseif ($c -eq '{' -or $c -eq '[') {
            if ($c -eq '{' -and $depth -eq 0) { $root = $i }
            $depth++
        } elseif ($c -eq '}' -or $c -eq ']') { $depth-- }
        $i++
    }
    if ($root -lt 0 -or $depth -ne 0) { throw 'Invalid Terminal settings object' }
    $rest = $Text.Substring($root+1)
    $withoutComments = [regex]::Replace($rest, '(?s)/\*.*?\*/|//[^\r\n]*', '')
    $comma = if ($withoutComments.TrimStart().StartsWith('}')) { '' } else { ',' }
    return $Text.Substring(0,$root+1) + [Environment]::NewLine + '    "defaultProfile": "' + $Guid + '"' + $comma + $rest
}

function Install-TerminalProfile {
    param([string]$Template, [string]$Distribution, [string]$User,
          [string]$FragmentDirectory, [string]$SettingsPath, [switch]$MakeDefault)
    $fragment = Get-Content -Raw -LiteralPath $Template | ConvertFrom-Json
    $md5 = [Security.Cryptography.MD5]::Create()
    try { $bytes = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes("wsl.dotfiles/$Distribution")) } finally { $md5.Dispose() }
    $guid = '{' + (New-Object Guid (,$bytes)).ToString() + '}'
    $fragment.profiles[0].guid = $guid
    $fragment.profiles[0].name = "WSL $Distribution"
    $fragment.profiles[0].commandline = "wsl.exe --distribution $Distribution --user $User --cd ~"
    Write-Utf8File -Path (Join-Path $FragmentDirectory "$Distribution.json") -Content ($fragment | ConvertTo-Json -Depth 12) -Backup
    if ($MakeDefault) {
        $text = if (Test-Path -LiteralPath $SettingsPath) { [IO.File]::ReadAllText($SettingsPath) } else { '{}' }
        Write-Utf8File -Path $SettingsPath -Content (Set-JsoncDefaultProfile -Text $text -Guid $guid) -Backup
    }
    return $guid
}

function Install-UserFont {
    param($Asset, [string]$Cache, [string]$FontDirectory, [string]$RegistryPath, [switch]$ForceInstall)
    Add-Type -AssemblyName System.Drawing
    $family = 'JetBrainsMono Nerd Font Mono'
    $fonts = New-Object Drawing.Text.InstalledFontCollection
    try { if (-not $ForceInstall -and $fonts.Families.Name -contains $family) { Write-Host "Font already available: $family"; return } }
    finally { $fonts.Dispose() }
    $archive = Get-VerifiedDownload -Url $Asset.url -Sha256 $Asset.sha256 -Destination (Join-Path $Cache 'JetBrainsMono.zip')
    $extract = Join-Path $Cache 'JetBrainsMono'
    Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
    if (-not $FontDirectory) { $FontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts' }
    [IO.Directory]::CreateDirectory($fontDirectory) | Out-Null
    $registry = if ($RegistryPath) { $RegistryPath } else { 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' }
    New-Item -Path $registry -Force | Out-Null
    if (-not ('Dotfiles.NativeFonts' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace Dotfiles {
 public static class NativeFonts {
  [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResource(string path);
  [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern bool RemoveFontResource(string path);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(
    IntPtr window, uint message, UIntPtr wparam, string lparam, uint flags, uint timeout, out UIntPtr result);
 }
}
"@
    }
    $selected = @(Get-ChildItem -LiteralPath $extract -Recurse -File |
        Where-Object { $_.Name -match '^JetBrainsMonoNerdFontMono-(Regular|Bold|Italic|BoldItalic)\.ttf$' })
    if ($selected.Count -ne 4) { throw 'Expected the four JetBrains Mono Nerd Font Mono faces' }
    foreach ($font in $selected) {
        $destination = Join-Path $fontDirectory $font.Name
        Copy-Item -LiteralPath $font.FullName -Destination $destination -Force
        $private = New-Object Drawing.Text.PrivateFontCollection
        try {
            $private.AddFontFile($destination)
            $label = $private.Families[0].Name + ' ' + ($font.BaseName -replace '^.*-','') + ' (TrueType)'
        } finally { $private.Dispose() }
        New-ItemProperty -Path $registry -Name $label -Value $destination -PropertyType String -Force | Out-Null
        [Dotfiles.NativeFonts]::AddFontResource($destination) | Out-Null
    }
    $result = [UIntPtr]::Zero
    [Dotfiles.NativeFonts]::SendMessageTimeout([IntPtr]0xffff, 0x001d, [UIntPtr]::Zero, '', 2, 1000, [ref]$result) | Out-Null
}

function Add-UserPath {
    param([string]$Directory)
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    $entries = @($userPath -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ine $Directory.TrimEnd('\') })
    [Environment]::SetEnvironmentVariable('Path', (@($Directory) + $entries -join ';'), 'User')
    $processEntries = @($env:Path -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ine $Directory.TrimEnd('\') })
    $env:Path = @($Directory) + $processEntries -join ';'
}

function Install-PortableApp {
    param([string]$Repository, [string]$Pattern, [string]$Command, [string]$Root, [string]$Cache)
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest"
    $assets = @($release.assets | Where-Object { $_.name -match $Pattern })
    if ($assets.Count -ne 1 -or -not $assets[0].digest -or $assets[0].digest -notmatch '^sha256:') {
        throw "No uniquely matched checksummed portable release of $Repository"
    }
    $asset = $assets[0]
    $archive = Get-VerifiedDownload -Url $asset.browser_download_url -Sha256 ($asset.digest -replace '^sha256:','') -Destination (Join-Path $Cache $asset.name)
    $destination = Join-Path $Root $Command
    Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
    $binary = @(Get-ChildItem -LiteralPath $destination -Recurse -Filter "$Command.exe" -File)
    if ($binary.Count -ne 1) { throw "Cannot locate $Command.exe in portable release" }
    Add-UserPath -Directory $binary[0].DirectoryName
}

function Install-UserApp {
    param([string]$Id, [string]$Command, [string]$Root, [string]$Cache)
    if ($Command -and (Get-Command $Command -ErrorAction SilentlyContinue)) { Write-Host "Already available: $Command"; return }
    $installed = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget list --id $Id --exact --disable-interactivity --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "Already installed: $Id"; return }
        $arguments = @('install','--id',$Id,'--exact','--source','winget','--silent','--disable-interactivity',
            '--accept-package-agreements','--accept-source-agreements')
        # Terminal's MSIX is inherently registered per user.
        if ($Id -ne 'Microsoft.WindowsTerminal') { $arguments += @('--scope','user') }
        & winget @arguments | Out-Host
        $installed = $LASTEXITCODE -eq 0
        $newUserPath = [Environment]::GetEnvironmentVariable('Path','User')
        foreach ($entry in ($newUserPath -split ';')) {
            if ($entry -and @($env:Path -split ';') -notcontains $entry) { $env:Path += ";$entry" }
        }
    }
    if ($installed) { return }
    switch ($Id) {
        'Microsoft.PowerShell' { Install-PortableApp 'PowerShell/PowerShell' '^PowerShell-[\d.]+-win-x64\.zip$' pwsh $Root $Cache }
        'Starship.Starship' { Install-PortableApp 'starship/starship' '^starship-x86_64-pc-windows-msvc\.zip$' starship $Root $Cache }
        'ajeetdsouza.zoxide' { Install-PortableApp 'ajeetdsouza/zoxide' '^zoxide-[\d.]+-x86_64-pc-windows-msvc\.zip$' zoxide $Root $Cache }
        'jdx.mise' { Install-PortableApp 'jdx/mise' '^mise-v[\d.]+-windows-x64\.zip$' mise $Root $Cache }
        'GitHub.cli' { Install-PortableApp 'cli/cli' '^gh_[\d.]+_windows_amd64\.zip$' gh $Root $Cache }
        default { throw "No available no-admin installation for $Id. Install its user edition manually, then rerun." }
    }
}

function Set-ManagedProfileBlock {
    param([string]$Content, [string]$ProfileScript)
    $begin = '# >>> dotfiles windows >>>'
    $end = '# <<< dotfiles windows <<<'
    $starts = ([regex]::Matches($Content, [regex]::Escape($begin))).Count
    $ends = ([regex]::Matches($Content, [regex]::Escape($end))).Count
    if ($starts -ne $ends -or $starts -gt 1) { throw 'Malformed dotfiles PowerShell block; repair it before rerunning' }
    $pattern = '(?ms)^' + [regex]::Escape($begin) + '.*?^' + [regex]::Escape($end) + '\r?\n?'
    $contentWithoutBlock = [regex]::Replace($Content, $pattern, '').TrimEnd()
    $quoted = $ProfileScript.Replace("'","''")
    return $contentWithoutBlock + [Environment]::NewLine + $begin + [Environment]::NewLine +
        ". '$quoted'" + [Environment]::NewLine + $end + [Environment]::NewLine
}

function Remove-KnownInitializers {
    param([string]$Content, [string[]]$Tools)
    foreach ($tool in $Tools) {
        $pattern = switch ($tool) {
            starship { '(?im)^[ \t]*Invoke-Expression[ \t]+\(&[ \t]*starship(?:\.exe)?[ \t]+init[ \t]+powershell(?:[ \t]+--print-full-init)?[ \t]*\)[ \t]*;?[ \t]*\r?\n?' }
            mise { '(?im)^[ \t]*mise(?:\.exe)?[ \t]+activate[ \t]+pwsh[ \t]*\|[ \t]*Out-String[ \t]*\|[ \t]*Invoke-Expression[ \t]*;?[ \t]*\r?\n?' }
            zoxide { '(?im)^[ \t]*Invoke-Expression[ \t]+\(&[ \t]*\{[ \t]*\(zoxide(?:\.exe)?[ \t]+init[ \t]+powershell[ \t]*\|[ \t]*Out-String\)[ \t]*\}\)[ \t]*;?[ \t]*\r?\n?' }
        }
        $Content = [regex]::Replace($Content, $pattern, '')
    }
    return $Content
}

function Install-PowerShellProfile {
    param([string]$ConfigRoot, [string]$Documents, [string]$Source, [string]$Distribution,
          [string[]]$Integrations = @(), [string]$StarshipConfig,
          [ValidateSet('shims','full')][string]$MiseActivation = 'shims')
    [IO.Directory]::CreateDirectory((Join-Path $ConfigRoot 'init')) | Out-Null
    $profiles = @(
        (Join-Path $Documents 'WindowsPowerShell\profile.ps1'),
        (Join-Path $Documents 'PowerShell\profile.ps1'),
        (Join-Path $Documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $Documents 'PowerShell\Microsoft.PowerShell_profile.ps1')
    )
    $contents = @{}
    foreach ($path in $profiles) {
        $contents[$path] = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) } else { '' }
        $contents[$path] = Remove-KnownInitializers -Content $contents[$path] -Tools $Integrations
    }
    $enabled = @()
    foreach ($tool in $Integrations) {
        $custom = $false
        foreach ($path in $profiles) {
            $tokens = $null; $parseErrors = $null
            $ast = [Management.Automation.Language.Parser]::ParseInput($contents[$path], [ref]$tokens, [ref]$parseErrors)
            if ($parseErrors.Count) { throw "Invalid PowerShell profile: $path" }
            $commands = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)
            foreach ($command in $commands) {
                if ($command.GetCommandName() -match "(^|[\\/])$tool(\.exe)?$") { $custom = $true }
            }
        }
        if ($custom) { Write-Warning "Preserving custom $tool profile code; managed initialization disabled to avoid duplicates."; continue }
        $binary = Get-Command "$tool.exe" -ErrorAction SilentlyContinue
        if (-not $binary) { Write-Warning "$tool unavailable; skipped profile integration"; continue }
        $arguments = switch ($tool) {
            starship { @('init','powershell','--print-full-init') }
            zoxide { @('init','powershell') }
            mise { @('activate','pwsh') }
        }
        if ($tool -eq 'mise' -and $MiseActivation -eq 'shims') {
            $shimPath = (Join-Path $env:LOCALAPPDATA 'mise\shims').Replace("'","''")
            $script = '$env:Path = ' + "'$shimPath;' + " + '$env:Path'
        } else {
            $script = (& $binary.Source @arguments | Out-String)
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($script)) { throw "Cannot generate $tool integration" }
        }
        $scriptTokens = $null; $scriptErrors = $null
        [Management.Automation.Language.Parser]::ParseInput($script, [ref]$scriptTokens, [ref]$scriptErrors) | Out-Null
        if ($scriptErrors.Count) { throw "Invalid generated $tool integration" }
        $initPath = Join-Path $ConfigRoot "init\$tool.ps1"
        Write-Utf8File -Path $initPath -Content $script
        $enabled += @{ name=$tool; init=$initPath; executable=$binary.Source; stamp=(Get-Item -LiteralPath $binary.Source).LastWriteTimeUtc.Ticks; interactive=($tool -ne 'mise' -or $MiseActivation -eq 'full') }
    }
    $merged = ''
    foreach ($name in @('mise','zoxide','starship')) {
        foreach ($integration in $enabled) {
            if ($integration.name -ne $name) { continue }
            $condition = if ($integration.interactive) { '$__dfInteractive' } else { '$true' }
            $executable = $integration.executable.Replace("'","''")
            $merged += "if (($condition) -and [IO.File]::Exists('$executable')) {" + [Environment]::NewLine
            if ($name -eq 'starship') { $merged += '$env:STARSHIP_CONFIG = $__dfConfig.starshipConfig' + [Environment]::NewLine }
            $merged += [IO.File]::ReadAllText($integration.init) + [Environment]::NewLine + '}' + [Environment]::NewLine
        }
    }
    $compiledConfig = '$__dfConfig = @{ distribution=' + "'" + $Distribution.Replace("'","''") + "'; starshipConfig='" + (Join-Path $ConfigRoot 'starship.toml').Replace("'","''") + "' }"
    $profileText = [IO.File]::ReadAllText($Source).Replace('# DOTFILES_GENERATED_INTEGRATIONS', $merged).Replace('# DOTFILES_GENERATED_CONFIG', $compiledConfig)
    Write-Utf8File -Path (Join-Path $ConfigRoot 'profile.ps1') -Content $profileText
    Write-Utf8File -Path (Join-Path $ConfigRoot 'starship.toml') -Content ([IO.File]::ReadAllText($StarshipConfig))
    $config = @{ distribution=$Distribution; starshipConfig=(Join-Path $ConfigRoot 'starship.toml'); integrations=@($enabled) }
    Write-Utf8File -Path (Join-Path $ConfigRoot 'profile.json') -Content ($config | ConvertTo-Json -Depth 6)
    foreach ($path in $profiles) {
        $content = $contents[$path]
        if ($path -in $profiles[0..1]) { $content = Set-ManagedProfileBlock -Content $content -ProfileScript (Join-Path $ConfigRoot 'profile.ps1') }
        if ($content -or (Test-Path -LiteralPath $path)) { Write-Utf8File -Path $path -Content $content -Backup }
    }
}

function Install-DockerLauncher {
    param([string]$Directory, [string]$Distribution)
    if ($Distribution -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { throw 'Invalid distro name' }
    $text = '@echo off' + [Environment]::NewLine +
        '"%SystemRoot%\System32\wsl.exe" --distribution ' + $Distribution +
        ' --cd "%CD%" --exec /usr/local/bin/dotfiles-docker %*' + [Environment]::NewLine +
        'exit /b %ERRORLEVEL%' + [Environment]::NewLine
    Write-Utf8File -Path (Join-Path $Directory 'docker.cmd') -Content $text -Backup
}

Export-ModuleMember -Function *
