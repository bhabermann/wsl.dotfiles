param([string]$ProfileScript, [string]$Image, [string]$Project)
$ErrorActionPreference = 'Stop'
. $ProfileScript
$expected = @('<a "b">','<>','<C:\directory with spaces\>','<a & b>')
$actual = @(docker run --rm $Image printf '<%s>\n' 'a "b"' '' 'C:\directory with spaces\' 'a & b')
if ($LASTEXITCODE -ne 0 -or ($actual -join '|') -ne ($expected -join '|')) { throw "Argument roundtrip failed: $($actual -join '|')" }
$piped = ('stdin-ok' | docker run --rm -i $Image cat | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $piped -ne 'stdin-ok') { throw 'Pipeline stdin was not forwarded' }
$mounted = (docker run --rm --mount "type=bind,source=$Project,target=/work" $Image cat /work/message.txt | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $mounted -ne 'windows-bind-ok') { throw 'PowerShell bind mount failed' }
docker run --rm $Image sh -c 'exit 37'
if ($LASTEXITCODE -ne 37) { throw 'PowerShell exit code was not preserved' }
Write-Host "PASS: PowerShell $($PSVersionTable.PSVersion) Docker arguments, stdin, mounts, exit codes"
exit 0
