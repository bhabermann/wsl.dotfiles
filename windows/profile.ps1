# Shared user profile. Refresh cached integrations by rerunning setup/update.
if (Get-Variable DotfilesWindowsProfileLoaded -Scope Global -ValueOnly -ErrorAction SilentlyContinue) { return }
# DOTFILES_GENERATED_CONFIG
if (-not (Get-Variable __dfConfig -ValueOnly -ErrorAction SilentlyContinue)) { return }
$global:DotfilesWindowsProfileLoaded = $true
$global:DotfilesDockerDistribution = $__dfConfig.distribution
function global:docker {
    $directory = if ($PWD.Provider.Name -eq 'FileSystem') { $PWD.ProviderPath } else { $env:USERPROFILE }
    $dockerArguments = @($args)
    if ($PSVersionTable.PSVersion -lt [version]'7.3' -or (Get-Variable PSNativeCommandArgumentPassing -ValueOnly -ErrorAction SilentlyContinue) -eq 'Legacy') {
        $dockerArguments = @($dockerArguments | ForEach-Object {
            if ($_ -eq '') { '""' } else {
                $value = [regex]::Replace([string]$_, '(\\*)"', '$1$1\"')
                if ($value -match '\s') { $value = [regex]::Replace($value, '(\\+)$', '$1$1') }
                $value
            }
        })
    }
    if ($MyInvocation.ExpectingInput) {
        $input | & "$env:SystemRoot\System32\wsl.exe" --distribution $global:DotfilesDockerDistribution --cd $directory --exec /usr/local/bin/dotfiles-docker @dockerArguments
    } else {
        & "$env:SystemRoot\System32\wsl.exe" --distribution $global:DotfilesDockerDistribution --cd $directory --exec /usr/local/bin/dotfiles-docker @dockerArguments
    }
}
# Avoid prompt hooks and terminal-only features in redirected/script hosts.
$__dfInteractive = $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected -and $env:TERM -ne 'dumb'
# Setup embeds cached mise/zoxide/Starship scripts here, avoiding separate file
# loads and native initialization processes at startup.
# DOTFILES_GENERATED_INTEGRATIONS
if ($__dfInteractive -and (Get-Module PSReadLine)) {
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        try { Set-PSReadLineOption -PredictionSource History -ErrorAction Stop } catch { }
    }
}
Remove-Variable -Name '__df*' -ErrorAction SilentlyContinue
