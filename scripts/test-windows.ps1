#requires -Version 5.1
param([switch]$Benchmark, [switch]$FontTest, [switch]$ToolDownloads)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'windows\Bootstrap.psm1') -Force -DisableNameChecking
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-fixtures-' + [guid]::NewGuid().ToString('N'))
$fontRegistry = $null
$originalPath = $env:Path
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
function Assert-True { param([bool]$Value,[string]$Message); if (-not $Value) { throw $Message } }
try {
    if ($ToolDownloads) {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest'
        $asset = @($release.assets | Where-Object name -match '^zoxide-[\d.]+-x86_64-pc-windows-msvc\.zip$')
        Assert-True ($asset.Count -eq 1 -and $asset[0].digest -match '^sha256:') 'Checksummed zoxide asset missing'
        $archive = Get-VerifiedDownload -Url $asset[0].browser_download_url -Sha256 ($asset[0].digest -replace '^sha256:','') -Destination (Join-Path $testRoot 'zoxide.zip')
        $tools = Join-Path $testRoot tools
        Expand-Archive -LiteralPath $archive -DestinationPath $tools
        $binary = @(Get-ChildItem -LiteralPath $tools -Recurse -Filter zoxide.exe)
        Assert-True ($binary.Count -eq 1) 'Portable zoxide missing'
        $env:Path = $binary[0].DirectoryName + ';' + $env:Path
    }
    $tokens=$null; $errors=$null
    foreach ($file in (Get-ChildItem (Join-Path $repo windows) -Recurse -File | Where-Object Extension -in '.ps1','.psm1')) {
        [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
        Assert-True ($errors.Count -eq 0) "Parse failed: $file"
    }
    $jsonc = @'
{
  // a "defaultProfile": "comment" and URL https://example.com
  "profiles": { "defaults": { "defaultProfile": "nested" } },
  "defaultProfile": "old", /* keep this */
}
'@
    $edited = Set-JsoncDefaultProfile -Text $jsonc -Guid '{new}'
    Assert-True ($edited.Contains('"defaultProfile": "{new}"')) 'Root default not updated'
    Assert-True ($edited.Contains('"defaultProfile": "nested"')) 'Nested property changed'
    Assert-True ($edited.Contains('/* keep this */')) 'JSONC comment lost'
    Assert-True ((Set-JsoncDefaultProfile -Text $edited -Guid '{new}') -eq $edited) 'JSONC edit not idempotent'
    foreach ($empty in @('{}','{/* comment */}')) {
        $result = Set-JsoncDefaultProfile -Text $empty -Guid '{new}'
        Assert-True ($result -notmatch '"\{new\}",') 'Empty object got trailing comma'
    }
    $fragmentDirectory = Join-Path $testRoot fragments
    $settings = Join-Path $testRoot settings.json
    Write-Utf8File $settings $jsonc
    $parameters = @{
        Template=(Join-Path $repo 'windows\terminal-profile.json')
        Distribution='fixture-dev';User='developer';FragmentDirectory=$fragmentDirectory
        SettingsPath=$settings;MakeDefault=$true
    }
    $first = Install-TerminalProfile @parameters
    $second = Install-TerminalProfile @parameters
    Assert-True ($first -eq $second) 'Profile GUID changed'
    $fragment = Get-Content -Raw (Join-Path $fragmentDirectory 'fixture-dev.json') | ConvertFrom-Json
    Assert-True ($fragment.profiles[0].commandline -eq 'wsl.exe --distribution fixture-dev --user developer --cd ~') 'Wrong Terminal target'
    Assert-True (@(Get-ChildItem $fragmentDirectory -Filter '*.json').Count -eq 1) 'Duplicate Terminal profile'

    $block = Set-ManagedProfileBlock -Content '# keep user aliases' -ProfileScript "C:\fixture's path\profile.ps1"
    $again = Set-ManagedProfileBlock -Content $block -ProfileScript "C:\fixture's path\profile.ps1"
    Assert-True ($block -eq $again) 'Profile source block not idempotent'
    Assert-True ($block.Contains("fixture''s path")) 'Profile path not escaped'
    $failed=$false
    try { Set-ManagedProfileBlock -Content '# >>> dotfiles windows >>>' -ProfileScript 'x' | Out-Null } catch { $failed=$true }
    Assert-True $failed 'Malformed source block was accepted'
    $canonical = @'
# keep this
Invoke-Expression (&starship init powershell)
mise activate pwsh | Out-String | Invoke-Expression
'@
    $migrated = Remove-KnownInitializers -Content $canonical -Tools starship,mise
    Assert-True ($migrated.Contains('# keep this') -and $migrated -notmatch 'Invoke-Expression') 'Initializer migration failed'
    $documents = Join-Path $testRoot documents
    $profileRoot = Join-Path $testRoot config
    $hostProfile = Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
    Write-Utf8File $hostProfile $canonical
    $profileParameters = @{
        ConfigRoot=$profileRoot;Documents=$documents;Source=(Join-Path $repo 'windows\profile.ps1')
        Distribution='fixture-dev';Integrations=@('zoxide','starship','mise')
        StarshipConfig=(Join-Path $repo 'starship\starship.toml')
    }
    Install-PowerShellProfile @profileParameters
    Install-PowerShellProfile @profileParameters
    if ($ToolDownloads) {
        $configuration = Get-Content -Raw (Join-Path $profileRoot 'profile.json') | ConvertFrom-Json
        Assert-True (@($configuration.integrations | Where-Object name -eq zoxide).Count -eq 1) 'zoxide integration not generated'
    }
    Assert-True ((Get-Content -Raw $hostProfile) -notmatch 'Invoke-Expression') 'Duplicate initializer survived migration'
    Assert-True ((Get-Content -Raw (Join-Path $documents 'PowerShell\profile.ps1')) -match 'dotfiles windows') 'All-host profile missing'
    Install-DockerLauncher -Directory (Join-Path $testRoot bin) -Distribution fixture-dev
    Assert-True ((Get-Content -Raw (Join-Path $testRoot 'bin\docker.cmd')).Contains('--distribution fixture-dev')) 'cmd bridge targets wrong distro'
    $fake = Join-Path $testRoot fake.bin
    Write-Utf8File $fake 'fixture payload'
    $hash = (Get-FileHash $fake -Algorithm SHA256).Hash
    Assert-True ((Get-VerifiedDownload -Url 'https://invalid.invalid/' -Sha256 $hash -Destination $fake) -eq $fake) 'Verified download cache missed'
    $failed=$false
    try { Get-VerifiedDownload -Url 'https://invalid.invalid/' -Sha256 'invalid' -Destination $fake | Out-Null } catch { $failed=$true }
    Assert-True $failed 'Invalid digest accepted'
    if ($FontTest) {
        $fontRegistry = 'HKCU:\Software\wsl.dotfiles.tests\' + [guid]::NewGuid().ToString('N')
        $fontDirectory = Join-Path $testRoot fonts
        $asset = (Get-Content -Raw (Join-Path $repo 'windows\assets.lock.json') | ConvertFrom-Json).font
        Install-UserFont -Asset $asset -Cache (Join-Path ([IO.Path]::GetTempPath()) 'wsl-dotfiles-artifacts') -FontDirectory $fontDirectory -RegistryPath (Join-Path $fontRegistry Fonts) -ForceInstall
        $registered = (Get-ItemProperty -LiteralPath (Join-Path $fontRegistry Fonts)).PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS' }
        Assert-True (@($registered).Count -eq 4) 'Not all four font faces registered'
        foreach ($item in $registered) { Assert-True (Test-Path -LiteralPath $item.Value) 'Registered font file missing' }
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        Write-Host "PASS: four per-user font registrations (elevated: $($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))"
    }
    Write-Host 'PASS: Windows fixtures (no real profiles, fonts, PATH, or defaults modified)'
    if ($Benchmark) {
        $executable = (Get-Process -Id $PID).Path
        $baseline=@(); $configured=@()
        $profileScript = (Join-Path $profileRoot 'profile.ps1').Replace("'","''")
        foreach ($i in 1..11) {
            $watch=[Diagnostics.Stopwatch]::StartNew()
            & $executable -NoLogo -NoProfile -Command 'exit 0'
            $watch.Stop(); if ($i -gt 1) { $baseline += $watch.Elapsed.TotalMilliseconds }
            $watch.Restart()
            & $executable -NoLogo -NoProfile -Command ". '$profileScript'"
            if ($LASTEXITCODE -ne 0) { throw 'Fixture profile startup failed' }
            $watch.Stop(); if ($i -gt 1) { $configured += $watch.Elapsed.TotalMilliseconds }
        }
        $baseMedian=($baseline | Sort-Object)[5]; $configMedian=($configured | Sort-Object)[5]
        Write-Host ('PowerShell warm median: baseline {0:N0}ms; configured {1:N0}ms; overhead {2:N0}ms' -f $baseMedian,$configMedian,($configMedian-$baseMedian))
    }
} finally {
    $env:Path = $originalPath
    if ($fontRegistry) {
        foreach ($font in (Get-ChildItem -LiteralPath (Join-Path $testRoot fonts) -Filter '*.ttf' -ErrorAction SilentlyContinue)) {
            if ('Dotfiles.NativeFonts' -as [type]) { [Dotfiles.NativeFonts]::RemoveFontResource($font.FullName) | Out-Null }
        }
        if ($fontRegistry -notmatch '^HKCU:\\Software\\wsl\.dotfiles\.tests\\[a-f0-9]{32}$') { throw 'Unexpected font test key' }
        if (Test-Path -LiteralPath $fontRegistry) { Remove-Item -LiteralPath $fontRegistry -Recurse -Force }
        $scratchParent = 'HKCU:\Software\wsl.dotfiles.tests'
        if ((Test-Path -LiteralPath $scratchParent) -and @(Get-ChildItem -LiteralPath $scratchParent).Count -eq 0) { Remove-Item -LiteralPath $scratchParent }
    }
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $expected = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\dotfiles-fixtures-'
    if (-not $resolved.StartsWith($expected,[StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing unexpected cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
