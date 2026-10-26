#requires -Version 5.1
# Creates and removes only a uniquely named disposable distro.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'windows\Bootstrap.psm1') -Force -DisableNameChecking
$id = [guid]::NewGuid().ToString('N')
$distribution = 'dotfiles-test-' + $id.Substring(0,8)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "wsl-dotfiles-integration-$id"
$disk = Join-Path $testRoot disk
$imported = $false
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
function Invoke-TestWsl {
    param([string[]]$Arguments)
    & wsl.exe --distribution $distribution @Arguments
    if ($LASTEXITCODE -ne 0) { throw "WSL test command failed ($LASTEXITCODE): $($Arguments -join ' ')" }
}
try {
    $assets = Get-Content -Raw (Join-Path $repo 'windows\assets.lock.json') | ConvertFrom-Json
    $cache = Join-Path ([IO.Path]::GetTempPath()) 'wsl-dotfiles-artifacts'
    $rootfs = Get-VerifiedDownload $assets.rootfs.url $assets.rootfs.sha256 (Join-Path $cache 'debian13.tar.gz')
    & wsl.exe --import $distribution $disk $rootfs --version 2
    if ($LASTEXITCODE -ne 0) { throw 'Disposable distro import failed' }
    $imported=$true
    $source = (Invoke-TestWsl @('-u','root','--exec','wslpath','-u',$repo) | Out-String).Trim()
    Write-Host "Provisioning disposable $distribution"
    Invoke-TestWsl @('-u','root','--exec','bash',"$source/windows/provision.sh",'developer') *> (Join-Path $testRoot 'provision.log')
    & wsl.exe --terminate $distribution | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Distro restart failed' }
    $copy = 'set -euo pipefail; mkdir -p /home/developer/.dotfiles; tar -C "$1" --exclude=.git -cf - . | tar -C /home/developer/.dotfiles -xf -; chown -R developer:developer /home/developer/.dotfiles; find /home/developer/.dotfiles -type f \( -name "*.sh" -o -name setup -o -name docker-wsl -o -name wslview \) -exec chmod +x {} +'
    Invoke-TestWsl @('-u','root','--exec','bash','-c',$copy,'_',$source)
    Invoke-TestWsl @('-u','root','--exec','bash','/home/developer/.dotfiles/windows/run-setup.sh','developer','install','--non-interactive','--git-name','Fixture Developer','--git-email','fixture@example.invalid','--tools','minimal') *> (Join-Path $testRoot 'install.log')
    $installLog = Get-Content -Raw (Join-Path $testRoot 'install.log')
    if ($installLog -notmatch 'Docker Engine verified with sudo' -or $installLog -notmatch 'Complete\. Open a new shell\.') { throw 'First Linux installation did not complete with pending Docker group membership' }
    Invoke-TestWsl @('-u','developer','--exec','bash','/home/developer/.dotfiles/scripts/test-linux.sh')
    Invoke-TestWsl @('-u','developer','--exec','bash','-c','test "$(cat /proc/1/comm)" = systemd; test ! -e /etc/sudoers.d/dotfiles-bootstrap-developer; if sudo -n true 2>/dev/null; then exit 1; fi')
    $sizes = @(Invoke-TestWsl @('-u','root','--exec','du','-sxB1','/usr','/var','/home','/etc'))
    $bytes = ($sizes | ForEach-Object { [long](($_ -split '\s+')[0]) } | Measure-Object -Sum).Sum
    Write-Host ('Core install before images: {0:N1} MiB (/usr + /var + /home + /etc)' -f ($bytes / 1MB))
    & wsl.exe --terminate $distribution | Out-Null
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-TestWsl @('-u','developer','--exec','/usr/local/bin/dotfiles-docker','version') *> (Join-Path $testRoot 'docker-version.log')
    $timer.Stop()
    Write-Host ('Cold WSL + Docker readiness: {0:N2}s' -f $timer.Elapsed.TotalSeconds)
    Invoke-TestWsl @('-u','developer','--exec','docker','compose','version')
    Invoke-TestWsl @('-u','developer','--exec','docker','buildx','version')
    $project = Join-Path $testRoot 'project with spaces'
    [IO.Directory]::CreateDirectory($project) | Out-Null
    Write-Utf8File (Join-Path $project 'message.txt') 'windows-bind-ok'
    Write-Utf8File (Join-Path $project 'Dockerfile') (@('FROM busybox:1.37.0','COPY message.txt /message.txt') -join [Environment]::NewLine)
    $image = "dotfiles-fixture:$id"
    $compose = @('services:','  check:',"    image: $image",'    command: ["cat", "/work/message.txt"]','    volumes:','      - "./:/work:ro"') -join [Environment]::NewLine
    Write-Utf8File (Join-Path $project 'compose.yaml') $compose
    $bin = Join-Path $testRoot bin
    Install-DockerLauncher $bin $distribution
    $launcher = Join-Path $bin docker.cmd
    Push-Location $project
    try {
        & $launcher build -t $image . *> (Join-Path $testRoot 'build.log')
        if ($LASTEXITCODE -ne 0) { throw 'Windows docker build failed' }
        $output = (& $launcher run --rm -v ($project + ':/work:ro') $image cat /work/message.txt | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $output -ne 'windows-bind-ok') { throw 'Windows bind mount failed' }
        & $launcher compose -f (Join-Path $project 'compose.yaml') -p fixture up --abort-on-container-exit --exit-code-from check *> (Join-Path $testRoot 'compose.log')
        if ($LASTEXITCODE -ne 0) { throw 'Windows Compose failed' }
        & $launcher run --rm $image sh -c 'exit 37'
        if ($LASTEXITCODE -ne 37) { throw 'Docker exit status not preserved' }
        $profileRoot = Join-Path $testRoot profile
        $profileParameters = @{
            ConfigRoot=$profileRoot;Documents=(Join-Path $testRoot documents)
            Source=(Join-Path $repo 'windows\profile.ps1');Distribution=$distribution
            Integrations=@();StarshipConfig=(Join-Path $repo 'starship\starship.toml')
        }
        Install-PowerShellProfile @profileParameters
        foreach ($shell in @('powershell.exe','pwsh.exe')) {
            if (Get-Command $shell -ErrorAction SilentlyContinue) {
                & $shell -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'scripts\test-docker-client.ps1') -ProfileScript (Join-Path $profileRoot 'profile.ps1') -Image $image -Project $project
                if ($LASTEXITCODE -ne 0) { throw "$shell Docker integration failed" }
            }
        }
    } finally { Pop-Location }
    Invoke-TestWsl @('-u','developer','--cd','~','--exec','bash','-c','set -e; TIMEFORMAT=%R; for i in {1..10}; do time zsh -ic exit; done')
    Write-Host 'PASS: disposable WSL, Docker, Windows cmd launcher, paths with spaces, mounts, Compose, exit codes'
} catch {
    foreach ($log in (Get-ChildItem -LiteralPath $testRoot -Filter '*.log' -ErrorAction SilentlyContinue)) {
        Write-Host "--- $($log.Name) ---"; Get-Content -LiteralPath $log.FullName -Tail 18 | Out-Host
    }
    throw
} finally {
    if ($imported) {
        $registration = @(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' | Get-ItemProperty | Where-Object DistributionName -eq $distribution)
        if ($registration.Count -ne 1 -or ($registration[0].BasePath -replace '^\\\\\?\\','').TrimEnd('\') -ine $disk.TrimEnd('\')) { throw 'Refusing cleanup of unexpected distro registration' }
        & wsl.exe --unregister $distribution | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not remove test distro $distribution" }
    }
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $expected = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\wsl-dotfiles-integration-'
    if (-not $resolved.StartsWith($expected,[StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing unexpected cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
