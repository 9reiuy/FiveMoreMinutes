param(
    [string[]]$ResultPaths,
    [string]$ProjectPath=(Split-Path $PSScriptRoot -Parent),
    [string]$OutputDirectory=''
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath $ProjectPath).Path
if(-not $ResultPaths){$ResultPaths=@((Join-Path $projectRoot '.runtime/perf_delivery_20261013/full_headless/results.json'),(Join-Path $projectRoot '.runtime/perf_delivery_20261013/remaining_headless/results.json'))}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $projectRoot '.runtime/perf_delivery_20261013/headless_review'}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$pattern='(?im)^\s*(?:FAIL(?:[: ]|$)|\[FAIL\]|\[FAILED\]|SCRIPT ERROR:)|Assertion failed|Parse Error|failures\s*[=: ]\s*[1-9][0-9]*|"failures"\s*:\s*[1-9][0-9]*|\b[1-9][0-9]*\s+failures\b(?!\s*[=:]?\s*[0-9])'
$latest=[ordered]@{}
$all=[System.Collections.Generic.List[object]]::new()
foreach($path in $ResultPaths){
    if(-not(Test-Path -LiteralPath $path)){continue}
    foreach($row in Get-Content -LiteralPath $path -Raw | ConvertFrom-Json){
        if($row.status -eq 'SKIP'){$latest[$row.name]=$row;continue}
        $stdout=Get-Content -LiteralPath $row.stdout -Raw -ErrorAction SilentlyContinue
        $stderr=Get-Content -LiteralPath $row.stderr -Raw -ErrorAction SilentlyContinue
        $text=$stdout+[Environment]::NewLine+$stderr
        $checkMatches=@([regex]::Matches($text,'(?i)checks\s*[=:]\s*([0-9]+)|"checks"\s*:\s*([0-9]+)|\b([0-9]+)\s+checks\b') | ForEach-Object {if($_.Groups[1].Success){[int]$_.Groups[1].Value}elseif($_.Groups[2].Success){[int]$_.Groups[2].Value}else{[int]$_.Groups[3].Value}})
        if($checkMatches.Count -gt 0){$row.assertions=($checkMatches | Measure-Object -Maximum).Maximum}
        $evidence=@([regex]::Matches($text,$pattern) | ForEach-Object Value)
        $status=if($row.timed_out){'TIMEOUT'}elseif($row.exit_code -ne 0 -or $evidence.Count -gt 0){'FAIL'}else{'PASS'}
        $firstErrors=@($text -split '\r?\n' | Where-Object {$_ -match '^SCRIPT ERROR:|^ERROR:|^FAIL(?:[: ]|$)|\[FAIL\]'} | Select-Object -First 5)
        $category='passed'
        if($status -ne 'PASS'){
            if($text -match 'real renderer|headless.*unsupported|GPU test cannot run'){$category='requires_renderer_not_headless'}
            elseif($text -match 'Identifier not found: SettingsManager|Identifier not found: PauseManager'){$category='entry_compile_autoload_scope'}
            elseif($text -match 'get_layout_signature' -and $text -match 'property or key'){$category='production_signature_schema_incompatibility'}
            elseif($text -match "property or key '(multimesh|is_large|source_actor)'|Node not found: .LeftLeg|Nonexistent 'float' constructor"){$category='legacy_test_schema_or_carrier_assumption_candidate'}
            elseif($text -match 'SCRIPT ERROR:|Parse Error'){$category='runtime_or_compile_error_needs_review'}
            else{$category='functional_assertion_needs_review'}
        }
        $corrected=[pscustomobject]@{name=$row.name;status=$status;original_status=$row.status;status_corrected=($status -ne $row.status);exit_code=$row.exit_code;timed_out=$row.timed_out;assertions=$row.assertions;category=$category;evidence=$firstErrors;failure_matches=$evidence;stdout=$row.stdout;stderr=$row.stderr;result_source=$path;classification_is_provisional=($status -ne 'PASS')}
        $latest[$row.name]=$corrected;$all.Add($corrected)
    }
}
$rows=@($latest.Values)
$summary=[ordered]@{unique_executed=$rows.Count;passed=@($rows | Where-Object status -EQ 'PASS').Count;failed=@($rows | Where-Object status -EQ 'FAIL').Count;timed_out=@($rows | Where-Object status -EQ 'TIMEOUT').Count;skipped=@($rows | Where-Object status -EQ 'SKIP').Count;false_status_corrections=@($all | Where-Object status_corrected).Count;reported_assertions=($rows | Measure-Object assertions -Sum).Sum;scope='Latest named result wins; original logs retained. Failure category is provisional, not proof that a production behavior should change.'}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'summary.json') -Encoding utf8
$rows | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'results_reviewed.json') -Encoding utf8
$all | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'all_runs_reviewed.json') -Encoding utf8
$manifest=Get-Content -LiteralPath (Join-Path $projectRoot 'tools/regression_manifest_20261013.json') -Raw | ConvertFrom-Json
$eligible=@($manifest | Where-Object {$_.classification -in @('headless','headless+gpu')})
$current=@($rows | Where-Object {$_.name -in @($eligible.name)})
$coverage=[ordered]@{eligible=$eligible.Count;executed=$current.Count;pass=@($current | Where-Object status -EQ 'PASS').Count;fail=@($current | Where-Object status -EQ 'FAIL').Count;timeout=@($current | Where-Object status -EQ 'TIMEOUT').Count;missing=@($eligible | Where-Object {$_.name -notin @($current.name)}).Count;skipped_missing=@($manifest | Where-Object classification -EQ 'skip_missing').Count;reported_assertions=($current | Measure-Object assertions -Sum).Sum}
$current | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'current_manifest_results.json') -Encoding utf8
$coverage | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'coverage_current_manifest.json') -Encoding utf8
@($manifest | Where-Object {$_.classification -in @('headless','headless+gpu') -and $_.name -notin @($rows.name)} | Select-Object name,entry,timeout_seconds) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'not_executed.json') -Encoding utf8
$summary | ConvertTo-Json
