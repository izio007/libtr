param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$packagePath=(Resolve-Path -LiteralPath $Package).Path
$bash='F:\cygwin64\bin\bash.exe'
$matlab='C:\Program Files\R2025a\bin\matlab.exe'
$marker=Join-Path $root 'runtime\pipeline\stop-server'
$packageMarker=Join-Path $packagePath 'results\stop-server'
if (!(Test-Path $matlab) -or (Test-Path $marker) -or (Test-Path $packageMarker)) {
    throw 'Host prerequisites not satisfied'
}
$ping=& $bash --noprofile --norc -lc 'cd /cygdrive/f/sy/workspace/libtr && PYTHONDONTWRITEBYTECODE=1 python3 tools/filter2win_package_runner.py --ping'
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect live queue' }
$hostInfo=$ping | ConvertFrom-Json
if (!$hostInfo.ok -or $hostInfo.active -or $hostInfo.queued -or !$hostInfo.context_protocol) {
    throw 'Wrong or busy original host'
}
$original=Get-Process -Id $hostInfo.pid
$owner=$null
for ($attempt=0; $attempt -lt 20 -and !$owner; $attempt++) {
    # MATLAB may re-arm the listener asynchronously after the ping disconnects.
    Start-Sleep -Milliseconds 250
    $owner=Get-NetTCPConnection -LocalPort 5555 -State Listen -ErrorAction SilentlyContinue
}
if ($owner.OwningProcess -ne $original.Id) { throw 'Listener ownership mismatch' }
$started=$original.StartTime
$fresh=$null
$oldPath=$env:MATLABPATH
$oldFresh=$env:FILTER2WIN_FRESH_HOST
function Wait-Port([bool]$present) {
    $deadline=(Get-Date).AddSeconds(120)
    do {
        $listener=Get-NetTCPConnection -LocalPort 5555 -State Listen -ErrorAction SilentlyContinue
        if ([bool]$listener -eq $present) { return }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw 'Timed out waiting for port transition'
}
try {
    # Stop the service loop, never terminate the user's MATLAB process.
    New-Item -ItemType File -Path $marker | Out-Null
    Wait-Port $false
    $env:MATLABPATH=''
    $env:FILTER2WIN_FRESH_HOST='1'
    $escaped=$packagePath.Replace("'","''").Replace('\','/')
    $command="cd('$escaped'); restoredefaultpath; addpath(fullfile(pwd,'tools','matlab')); filter2win_package_host"
    $fresh=Start-Process $matlab -ArgumentList @('-wait','-nosplash','-sd',"`"$packagePath`"",'-batch',"`"$command`"") -PassThru
    Wait-Port $true
    $cyg=& $bash --noprofile --norc -c "cygpath -u '$packagePath'"
    & $bash --noprofile --norc -lc "cd '$cyg' && PYTHONDONTWRITEBYTECODE=1 bash tools/runner.sh matlab/tests/configs/package_runner.json"
    if ($LASTEXITCODE -ne 0) { throw 'Fresh package acceptance failed' }
} finally {
    if ($fresh) {
        New-Item -ItemType File -Path $packageMarker -Force | Out-Null
        Wait-Port $false
        if (!$fresh.WaitForExit(60000)) { throw 'Fresh process did not exit; not terminating unknown work' }
        $fresh.Dispose()
        Remove-Item -LiteralPath $packageMarker
    }
    $env:MATLABPATH=$oldPath
    $env:FILTER2WIN_FRESH_HOST=$oldFresh
    if (Test-Path $marker) { Remove-Item -LiteralPath $marker }
    if (!(Get-NetTCPConnection -LocalPort 5555 -State Listen -ErrorAction SilentlyContinue)) {
        $escapedRoot=$root.Replace("'","''").Replace('\','/')
        $command="cd('$escapedRoot'); addpath(fullfile(pwd,'tools','pipeline')); service_pipeline_host(5555)"
        Start-Process $matlab -ArgumentList @('-nosplash','-batch',"`"$command`"") | Out-Null
        Wait-Port $true
    }
    $preserved=Get-Process -Id $original.Id -ErrorAction SilentlyContinue
    if ($preserved -and $preserved.StartTime -ne $started) { throw 'Original process identity changed' }
    if (!$preserved) { Write-Warning 'Original host exited after its service loop returned; restored host has a new PID.' }
}