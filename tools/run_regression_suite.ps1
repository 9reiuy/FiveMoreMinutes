param(
    [ValidateSet('Headless','GPU')][string]$Mode='Headless',
    [string]$GodotExecutable='E:\Godot\Godot_v4.7.1-stable_win64_console.exe',
    [string]$ProjectPath=(Split-Path $PSScriptRoot -Parent),
    [string]$ManifestPath=(Join-Path $PSScriptRoot 'regression_manifest_20261013.json'),
    [string[]]$Names=@(),
    [string[]]$UserArgs=@(),
    [string]$OutputDirectory='',
    [string]$PauseFile=''
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath $ProjectPath).Path
$manifest=Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
foreach($selectedName in $Names){if($selectedName -notin @($manifest.name)){throw "Unknown test name: $selectedName"}}
if(-not(Test-Path -LiteralPath $GodotExecutable)){throw 'Godot executable missing.'}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $projectRoot ('.runtime/perf_delivery_20261013/regression_'+$Mode+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8))}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputRoot=(Resolve-Path -LiteralPath $OutputDirectory).Path
if(-not $PauseFile){$PauseFile=Join-Path $outputRoot 'pause.request'}
$pausedByRequest=$false
$results=[System.Collections.Generic.List[object]]::new()
$previousAppData=$env:APPDATA;$previousLocalAppData=$env:LOCALAPPDATA
$env:APPDATA=Join-Path $outputRoot 'appdata';$env:LOCALAPPDATA=Join-Path $outputRoot 'localappdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
function Quote-ProcessArgument([string]$value){
    if($value -notmatch '[\s"]'){return $value}
    return '"'+([regex]::Replace([regex]::Replace($value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1'))+'"'
}
try {
    $allowed=if($Mode -eq 'Headless'){@('headless','headless+gpu')}else{@('gpu','headless+gpu')}
    foreach($test in $manifest){
        if(Test-Path -LiteralPath $PauseFile){$pausedByRequest=$true;Write-Host 'Paused between tests by coordination request.';break}
        if($Names.Count -gt 0 -and $test.name -notin $Names){continue}
        if($test.classification -like 'skip*'){
            $results.Add([pscustomobject]@{name=$test.name;mode=$Mode;status='SKIP';reason=$test.reason;missing_references=$test.missing_references;exit_code=$null;assertions=$null})
            continue
        }
        $allowed=if($Mode -eq 'Headless'){@('headless','headless+gpu')}else{@('gpu','headless+gpu')}
        if($test.classification -notin $allowed){continue}
        Write-Host "[$Mode] $($test.name) (timeout $($test.timeout_seconds)s)"
        $testRoot=Join-Path $outputRoot $test.name
        New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
        $stdout=Join-Path $testRoot 'stdout.log';$stderr=Join-Path $testRoot 'stderr.log'
        $arguments=@('--path',$projectRoot,'--audio-driver','Dummy')
        if($Mode -eq 'Headless'){$arguments+='--headless'}
        if($test.entry_kind -eq 'script'){$arguments+=@('--script',$test.entry)}else{$arguments+=$test.entry}
        $arguments+=@('--',"--artifact-dir=$testRoot")
        $arguments+=@($test.user_args)
        $arguments+=$UserArgs
        $argumentLine=(@($arguments | ForEach-Object {Quote-ProcessArgument $_}) -join ' ')
        $began=[DateTime]::UtcNow
        $process=Start-Process -FilePath $GodotExecutable -ArgumentList $argumentLine -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        $completed=$false;$fatalScriptError=$false
        while(([DateTime]::UtcNow-$began).TotalSeconds -lt [int]$test.timeout_seconds){
            if($process.WaitForExit(1000)){$completed=$true;break}
            $currentErrors=Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
            if($currentErrors -match '(?im)^SCRIPT ERROR:|Parse Error|Compilation failed'){
                $fatalScriptError=$true
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                $process.WaitForExit();$completed=$true;break
            }
        }
        $timedOut=-not $completed
        if($timedOut){Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue;$process.WaitForExit()}
        $process.Refresh()
        $exitCode=$process.ExitCode
        $text=(Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue)+[Environment]::NewLine+(Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
        $assertionFailures=@([regex]::Matches($text,'(?im)^\s*(?:FAIL(?:[: ]|$)|\[FAIL\]|\[FAILED\]|SCRIPT ERROR:)|Assertion failed|Parse Error|failures\s*[=: ]\s*[1-9][0-9]*|"failures"\s*:\s*[1-9][0-9]*|\b[1-9][0-9]*\s+failures\b(?!\s*[=:]?\s*[0-9])') | ForEach-Object Value)
        $checkNumbers=@([regex]::Matches($text,'(?i)checks\s*[=:]\s*([0-9]+)|"checks"\s*:\s*([0-9]+)|\b([0-9]+)\s+checks\b') | ForEach-Object {if($_.Groups[1].Success){[int]$_.Groups[1].Value}elseif($_.Groups[2].Success){[int]$_.Groups[2].Value}else{[int]$_.Groups[3].Value}})
        $assertionCount=$null
        if($checkNumbers.Count -gt 0){$assertionCount=($checkNumbers | Measure-Object -Maximum).Maximum}
        $status=if($timedOut){'TIMEOUT'}elseif($fatalScriptError -or $exitCode -ne 0 -or $assertionFailures.Count -gt 0){'FAIL'}else{'PASS'}
        $row=[pscustomobject]@{name=$test.name;mode=$Mode;status=$status;exit_code=$exitCode;timed_out=$timedOut;terminated_after_script_error=$fatalScriptError;elapsed_seconds=([DateTime]::UtcNow-$began).TotalSeconds;assertions=$assertionCount;assertion_failure_evidence=$assertionFailures;stdout=$stdout;stderr=$stderr;timeout_seconds=$test.timeout_seconds}
        $results.Add($row)
        @($results) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputRoot 'results.json') -Encoding utf8
        Write-Host "$status $($test.name) exit=$exitCode assertions=$assertionCount"
    }
    $notRun=@($manifest | Where-Object {($Names.Count -eq 0 -or $_.name -in $Names) -and $_.classification -in $allowed -and $_.name -notin @($results.name)} | Select-Object name,entry,timeout_seconds)
    $notRun | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'not_executed.json') -Encoding utf8
    $summary=[ordered]@{mode=$Mode;passed=@($results | Where-Object status -EQ 'PASS').Count;failed=@($results | Where-Object status -EQ 'FAIL').Count;timed_out=@($results | Where-Object status -EQ 'TIMEOUT').Count;skipped=@($results | Where-Object status -EQ 'SKIP').Count;not_executed=$notRun.Count;paused_by_request=$pausedByRequest;pause_request_file=$PauseFile;reported_assertions=($results | Measure-Object assertions -Sum).Sum;scope='Manifest-selected assertion regression only. GPU serial. SKIP and diagnostics are not PASS.';output=$outputRoot}
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'summary.json') -Encoding utf8
    @($results) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputRoot 'results.json') -Encoding utf8
    $summary | ConvertTo-Json
    if($summary.failed -gt 0 -or $summary.timed_out -gt 0){exit 1}
}finally{
    $env:APPDATA=$previousAppData;$env:LOCALAPPDATA=$previousLocalAppData
}
