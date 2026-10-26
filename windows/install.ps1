#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$Distribution = 'dev',
    [ValidatePattern('^[a-z_][a-z0-9_-]{0,30}$')][string]$LinuxUser,
    [string]$InstallDirectory,
    [string[]]$Apps,
    [ValidateSet('zoxide','starship','mise')][string[]]$Integrations,
    [ValidateSet('shims','full')][string]$MiseActivation = 'shims',
    [string[]]$LinuxTools,
    [switch]$NonInteractive, [switch]$Reconfigure, [switch]$DryRun,
    [switch]$KeepDefaults, [switch]$SkipApps
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Bootstrap.psm1') -Force -DisableNameChecking
$repo = Split-Path -Parent $PSScriptRoot
$configRoot = Join-Path $env:LOCALAPPDATA 'wsl.dotfiles'
$cache = Join-Path $configRoot 'cache'
$statePath = Join-Path $configRoot "distros\$Distribution.json"
$state = if (Test-Path -LiteralPath $statePath) { Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json } else { $null }
if ($state) {
    if (-not $PSBoundParameters.ContainsKey('LinuxUser')) { $LinuxUser = $state.linuxUser }
    if (-not $PSBoundParameters.ContainsKey('InstallDirectory')) { $InstallDirectory = $state.installDirectory }
    if (-not $PSBoundParameters.ContainsKey('Apps')) { $Apps = @($state.apps) }
    if (-not $PSBoundParameters.ContainsKey('Integrations')) { $Integrations = @($state.integrations) }
    if (-not $PSBoundParameters.ContainsKey('LinuxTools')) { $LinuxTools = @($state.linuxTools) }
    if (-not $PSBoundParameters.ContainsKey('MiseActivation') -and $state.PSObject.Properties.Name -contains 'miseActivation') { $MiseActivation = $state.miseActivation }
    if (-not $PSBoundParameters.ContainsKey('KeepDefaults') -and $state.PSObject.Properties.Name -contains 'keepDefaults') { $KeepDefaults = [bool]$state.keepDefaults }
}
if (-not $LinuxUser) {
    $candidate = $env:USERNAME.ToLowerInvariant()
    if ($candidate -match '^[a-z_][a-z0-9_-]{0,30}$') { $LinuxUser = $candidate }
    elseif ($NonInteractive) { throw 'Provide -LinuxUser with a valid Linux username.' }
    else { $LinuxUser = Read-Host 'Linux username' }
}
if ($LinuxUser -notmatch '^[a-z_][a-z0-9_-]{0,30}$' -or $LinuxUser -eq 'root') { throw 'Choose a normal Linux username, not root.' }
if (-not $InstallDirectory) { $InstallDirectory = Join-Path $env:LOCALAPPDATA "wsl\$Distribution" }
$InstallDirectory = [IO.Path]::GetFullPath($InstallDirectory)
if (-not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'This version requires Windows 11 x64 and a 64-bit PowerShell.' }
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'Enable WSL 2 before running this no-admin installer.' }
$versionOutput = (& wsl.exe --version 2>&1 | Out-String) -replace [char]0, ''
if ($LASTEXITCODE -ne 0) { throw 'Install a current WSL 2 release before running this no-admin installer.' }
$distros = @((& wsl.exe --list --quiet | ForEach-Object { ($_ -replace [char]0,'').Trim() }) | Where-Object { $_ })
if ($LASTEXITCODE -ne 0) { throw 'Unable to list WSL distributions' }
$exists = $distros -contains $Distribution
if ($exists -and -not $state) { throw "Distro '$Distribution' exists and is not managed by this installer. Choose another name." }
if ($state -and ($LinuxUser -ne $state.linuxUser -or $InstallDirectory -ne $state.installDirectory)) { throw 'Changing the user or disk location of a managed distro is not supported. Choose a new distro name.' }
if ($exists) {
    $registration = @(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' | Get-ItemProperty | Where-Object DistributionName -eq $Distribution)
    if ($registration.Count -ne 1 -or ($registration[0].BasePath -replace '^\\\\\?\\','').TrimEnd('\') -ine $InstallDirectory.TrimEnd('\')) {
        throw 'The registered distro location differs from saved ownership. Refusing to adopt it.'
    }
}
if (-not $exists -and -not $DryRun -and $NonInteractive) { throw 'First provisioning requires interactive Linux password setup. Rerun without -NonInteractive.' }
if (-not $exists -and (Test-Path -LiteralPath $InstallDirectory) -and @(Get-ChildItem -LiteralPath $InstallDirectory -Force).Count) { throw "Install directory is not empty: $InstallDirectory" }
$catalog = @(
    @{name='powershell';id='Microsoft.PowerShell';command='pwsh.exe';description='PowerShell 7';recommended=$true},
    @{name='git';id='Git.Git';command='git.exe';description='Git for Windows';recommended=$true},
    @{name='gh';id='GitHub.cli';command='gh.exe';description='GitHub CLI';recommended=$false},
    @{name='vscode';id='Microsoft.VisualStudioCode';command='code';description='Visual Studio Code';recommended=$true},
    @{name='1password';id='AgileBits.1Password';command='';description='1Password';recommended=$false},
    @{name='op';id='AgileBits.1Password.CLI';command='op.exe';description='1Password CLI';recommended=$false},
    @{name='obsidian';id='Obsidian.Obsidian';command='';description='Obsidian';recommended=$false},
    @{name='zoxide';id='ajeetdsouza.zoxide';command='zoxide.exe';description='Smarter directory navigation';recommended=$false},
    @{name='starship';id='Starship.Starship';command='starship.exe';description='Fast configurable prompt';recommended=$false},
    @{name='mise';id='jdx.mise';command='mise.exe';description='Developer runtime manager';recommended=$false}
)
if (-not $Apps -and -not $state -and -not $PSBoundParameters.ContainsKey('Apps')) { $Apps = @($catalog | Where-Object recommended | ForEach-Object name) }
if (-not $NonInteractive -and -not $SkipApps -and (-not $state -or $Reconfigure)) {
    $chosen = @()
    if (-not $PSBoundParameters.ContainsKey('Apps')) {
        foreach ($app in $catalog) {
            $default = $Apps -contains $app.name
            $label = if ($default) { 'Y/n' } else { 'y/N' }
            $answer = Read-Host "Install $($app.description)? [$label]"
            if (($answer -eq '' -and $default) -or $answer -match '^[Yy]') { $chosen += $app.name }
        }
        $Apps = $chosen
    }
    if (-not $PSBoundParameters.ContainsKey('Integrations')) {
        $hooks = @()
        foreach ($tool in @('zoxide','starship','mise')) {
            if ($Apps -contains $tool) {
                $answer = Read-Host "Enable $tool in your PowerShell profile? [Y/n]"
                if ($answer -notmatch '^[Nn]') { $hooks += $tool }
            }
        }
        $Integrations = $hooks
    }
}
foreach ($app in $Apps) { if ($app -notin @($catalog | ForEach-Object name)) { throw "Unknown app: $app" } }
foreach ($tool in $Integrations) {
    if ($tool -notin $Apps -and -not (Get-Command "$tool.exe" -ErrorAction SilentlyContinue)) { throw "Select -Apps $tool before enabling its integration." }
}
Write-Host "Distro: $Distribution | User: $LinuxUser | Disk: $InstallDirectory"
Write-Host "Windows apps: $($Apps -join ', ') | Profile integrations: $($Integrations -join ', ')"
Write-Host 'Base: pinned Debian 13 slim; zsh, Docker Engine, Compose, Buildx; optional Linux tool menu.'
Write-Host "Make WSL and Terminal defaults: $(-not $KeepDefaults)"
if ($DryRun) { Write-Host 'Dry run: no changes made.'; return }

$assets = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'assets.lock.json') | ConvertFrom-Json
$originalDefault = ((& wsl.exe --list --verbose | Out-String) -replace [char]0,'')
if (-not $exists) {
    $rootfs = Get-VerifiedDownload -Url $assets.rootfs.url -Sha256 $assets.rootfs.sha256 -Destination (Join-Path $cache 'debian13-amd64.tar.gz')
    & wsl.exe --import $Distribution $InstallDirectory $rootfs --version 2
    if ($LASTEXITCODE -ne 0) { throw 'WSL import failed' }
    $state = [pscustomobject]@{ linuxUser=$LinuxUser; installDirectory=$InstallDirectory; apps=@($Apps); integrations=@($Integrations); linuxTools=@($LinuxTools); originalDefault=$originalDefault; complete=$false }
    Write-Utf8File -Path $statePath -Content ($state | ConvertTo-Json -Depth 6)
}
$provisionWindows = Join-Path $PSScriptRoot 'provision.sh'
$provisionLinux = (& wsl.exe -d $Distribution -u root --exec wslpath -u $provisionWindows | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot map provisioning script into WSL' }
& wsl.exe -d $Distribution -u root --exec bash $provisionLinux $LinuxUser
if ($LASTEXITCODE -ne 0) { throw 'Linux system provisioning failed; rerun to resume.' }
$passwordState = (& wsl.exe -d $Distribution -u root --exec passwd --status $LinuxUser | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Linux account' }
if ($passwordState -notmatch '^\S+\s+P\s') {
    if ($NonInteractive) { throw "Set a Linux password interactively: wsl -d $Distribution -u root -- passwd $LinuxUser" }
    & wsl.exe -d $Distribution -u root --exec passwd $LinuxUser
    if ($LASTEXITCODE -ne 0) { throw 'Linux password setup did not complete' }
}
& wsl.exe --terminate $Distribution
if ($LASTEXITCODE -ne 0) { throw 'Cannot restart the new distro' }
$sourceLinux = (& wsl.exe -d $Distribution -u $LinuxUser --exec wslpath -u $repo | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot map source directory into WSL' }
& wsl.exe -d $Distribution -u $LinuxUser --exec bash "$sourceLinux/windows/copy-source.sh" $sourceLinux
if ($LASTEXITCODE -ne 0) { throw 'Cannot copy dotfiles to the Linux filesystem' }
$setupArguments = @('install','--no-doctor')
if ($NonInteractive) { $setupArguments += '--non-interactive' }
if ($Reconfigure) { $setupArguments += '--reconfigure' }
if ($LinuxTools) {
    $setupArguments += @('--tools','minimal')
    foreach ($tool in $LinuxTools) { $setupArguments += @('--with',$tool) }
}
& wsl.exe -d $Distribution -u root --exec bash "/home/$LinuxUser/.dotfiles/windows/run-setup.sh" $LinuxUser @setupArguments
if ($LASTEXITCODE -ne 0) { throw 'Linux setup failed; rerun to resume.' }
& wsl.exe -d $Distribution -u $LinuxUser --exec /usr/local/bin/dotfiles-docker version
if ($LASTEXITCODE -ne 0) { throw 'Docker verification failed' }
Install-UserApp -Id Microsoft.WindowsTerminal -Command wt.exe -Root (Join-Path $configRoot apps) -Cache $cache
Install-UserFont -Asset $assets.font -Cache $cache
if (-not $SkipApps) {
    foreach ($name in $Apps) {
        $app = $catalog | Where-Object name -eq $name
        try { Install-UserApp -Id $app.id -Command $app.command -Root (Join-Path $configRoot apps) -Cache $cache }
        catch { Write-Warning "Optional app $name failed: $_" }
    }
}
$bin = Join-Path $configRoot bin
Install-DockerLauncher -Directory $bin -Distribution $Distribution
Add-UserPath -Directory $bin
if ($Apps -contains 'mise' -or $Integrations -contains 'mise') { Add-UserPath -Directory (Join-Path $env:LOCALAPPDATA 'mise\shims') }
Install-PowerShellProfile -ConfigRoot $configRoot -Documents ([Environment]::GetFolderPath('MyDocuments')) -Source (Join-Path $PSScriptRoot 'profile.ps1') -Distribution $Distribution -Integrations $Integrations -StarshipConfig (Join-Path $repo 'starship\starship.toml') -MiseActivation $MiseActivation
Install-TerminalProfile -Template (Join-Path $PSScriptRoot 'terminal-profile.json') -Distribution $Distribution -User $LinuxUser -FragmentDirectory (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\wsl.dotfiles') -SettingsPath (Get-TerminalSettingsPath) -MakeDefault:(-not $KeepDefaults) | Out-Null
if (-not $KeepDefaults) {
    & wsl.exe --set-default $Distribution
    if ($LASTEXITCODE -ne 0) { throw 'Could not set the default distro' }
}
$state.apps = @($Apps); $state.integrations = @($Integrations); $state.linuxTools = @($LinuxTools); $state.complete = $true
$state | Add-Member -NotePropertyName miseActivation -NotePropertyValue $MiseActivation -Force
$state | Add-Member -NotePropertyName keepDefaults -NotePropertyValue ([bool]$KeepDefaults) -Force
Write-Utf8File -Path $statePath -Content ($state | ConvertTo-Json -Depth 6) -Backup
Write-Host "Complete. Open a new Terminal tab for $Distribution. Windows docker commands target that distro."
