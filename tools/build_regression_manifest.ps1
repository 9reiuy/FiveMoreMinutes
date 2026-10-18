param([string]$ProjectPath=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath $ProjectPath).Path
$directRefs=@{}
$resourceFiles=@(Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Include '*.tres','*.tscn','*.gdshader' | Where-Object FullName -NotMatch '\\(?:\.runtime|\.godot|\.git)\\')
function Get-DirectReferences([string]$path) {
    if ($directRefs.ContainsKey($path)) { return $directRefs[$path] }
    $source=Get-Content -LiteralPath $path -Raw
    $references=[System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($source, '(?:preload|load)\s*\(\s*["''](res://[^"'']+)["'']|path\s*=\s*"(res://[^"]+)"|extends\s+["''](res://[^"'']+)["'']')) {
        $ref=if($match.Groups[1].Success){$match.Groups[1].Value}elseif($match.Groups[2].Success){$match.Groups[2].Value}else{$match.Groups[3].Value}
        # Godot resolves moved ext_resources by UID before their old path.
        if(-not(Test-Path -LiteralPath (Join-Path $projectRoot $ref.Substring(6)))){
            $line=($source -split '\n' | Where-Object {$_ -like ('*path="'+$ref+'"*')} | Select-Object -First 1)
            if($line -match 'uid="(uid://[^"]+)"'){
                $uid=$Matches[1]
                foreach($candidate in $resourceFiles | Where-Object Name -EQ ([IO.Path]::GetFileName($ref))){
                    $header=Get-Content -LiteralPath $candidate.FullName -TotalCount 1
                    if($header.Contains($uid)){$ref='res://'+$candidate.FullName.Substring($projectRoot.Length+1).Replace('\','/');break}
                }
            }
        }
        if($ref -notmatch '%|\{|\}'){$references.Add($ref)}
    }
    $directRefs[$path]=@($references)
    return $directRefs[$path]
}
function Test-SceneTreeBase([string]$source,[int]$depth=0){
    if($source -match '(?m)^extends SceneTree\s*$'){return $true}
    if($depth -gt 12){return $false}
    if($source -match '(?m)^extends ["''](res://[^"'']+)["'']'){
        $basePath=Join-Path $projectRoot $Matches[1].Substring(6)
        if(Test-Path -LiteralPath $basePath){return Test-SceneTreeBase (Get-Content -LiteralPath $basePath -Raw) ($depth+1)}
    }
    return $false
}
function Find-MissingDependencies([string]$path,[System.Collections.Generic.HashSet[string]]$seen) {
    if(-not $seen.Add($path)){return}
    foreach($ref in @(Get-DirectReferences $path)){
        $target=Join-Path $projectRoot $ref.Substring(6)
        if(-not(Test-Path -LiteralPath $target)){$ref;continue}
        if([IO.Path]::GetExtension($target) -in @('.gd','.tscn','.tres','.gdshader')) { Find-MissingDependencies $target $seen }
    }
}
$rows=[System.Collections.Generic.List[object]]::new()
foreach($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*.gd' | Sort-Object Name){
    $source=Get-Content -LiteralPath $file.FullName -Raw
    $name=$file.BaseName
    $classification='diagnostic';$reason='Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite.'
    $entry='res://tests/'+$file.Name;$entryKind='script';$timeout=120
    $isTest=$name -match '(^test_|_test$|_validation$|_smoke$)' -and $name -notmatch '^(scratch_|tmp_|probe_|debug_)'
    $missing=@()
    if($isTest){
        $missing=@(Find-MissingDependencies $file.FullName ([System.Collections.Generic.HashSet[string]]::new()) | Sort-Object -Unique)
        $classification='headless';$reason='Assertion regression using engine logic/physics; no required rendered frame wait.'
        $needsGPU=$source -match 'frame_post_draw|get_texture\(\)\.get_image\(|viewport_get_measured_render_time|GPU gun|GPU.*pixel|count_body\('
        $headlessGuard=$source -match 'DisplayServer\.get_name\(\)\s*(==|!=)\s*"headless"'
        $headlessRefusal=$source -match '(?s)if DisplayServer\.get_name\(\)=="headless":\s*(?:push_error\([^\r\n]*\);\s*)?quit\(|if DisplayServer\.get_name\(\)\s*==\s*"headless":\s*\r?\n\s*quit\('
        if($needsGPU){
            if($headlessGuard -and -not $headlessRefusal -and $source -notmatch 'await RenderingServer.frame_post_draw'){
                $classification='headless+gpu';$reason='Headless assertions plus optional actual GPU image assertions; run both modes.'
            }else{$classification='gpu';$reason='Requires rendered frame/image or explicit headless refusal; GPU must run serially.'}
        }
        if($name -in @('actor_volume_shadow_pose_parity_test','bridge_transform_sync_test','native_generator_candidate_parity_test')){$classification='headless';$reason='New CPU/native parity regression; no GPU frame wait.'}
        if($name -eq 'approved_art_texture_cache_test'){$classification='gpu';$reason='Texture byte readback explicitly refuses a headless renderer.'}
        if($name -in @('character_projection_world_test','character_weapon_projection_test')){$classification='headless+gpu';$reason='Logic assertions plus actual Camera capture; both modes required.'}
        if(-not(Test-SceneTreeBase $source)){
            $scene=Join-Path $file.DirectoryName ($file.BaseName+'.tscn')
            if(Test-Path -LiteralPath $scene){$entry='res://tests/'+$file.BaseName+'.tscn';$entryKind='scene'}
            else{$classification='skip_entry_missing';$reason='Node-based test has no corresponding standalone test scene; needs an authored runner, cannot count as passed.'}
        }
        if($missing.Count -gt 0){$classification='skip_missing';$reason='Missing transitive literal load/preload/ext_resource dependencies; retired 2D references are not restored or counted as passed.'}
        if($name -match 'lifecycle|integration|full_runtime|runtime_walk|elevator|loading|floor_capture|art_test|generation_clear'){$timeout=240}
        if($name -match 'skeleton_native|ceiling_light_rule|night_layout|seed_test|task014_update|floor_path|shared_goal|office_skeleton_layout'){$timeout=300}
        if($classification -eq 'gpu'){$timeout=[Math]::Max($timeout,180)}
    }
    $userArgs=@()
    if($name -eq 'firearm_loading_main_entry_test'){$userArgs=@('--output-1080','--cross-floor-shadow-trace','--force-loading-failure','--capture-floor-exit')}
    $rows.Add([pscustomobject][ordered]@{name=$name;entry=$entry;entry_kind=$entryKind;classification=$classification;timeout_seconds=$timeout;user_args=$userArgs;reason=$reason;missing_references=@($missing)})
}
$manifestPath=Join-Path $projectRoot 'tools/regression_manifest_20261013.json'
@($rows) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8
$markdown=[System.Collections.Generic.List[string]]::new()
$markdown.Add('# 回归清单 2026-10-13')
$markdown.Add('')
$markdown.Add('静态逐项检查入口、直接及传递的 literal load/preload/ext_resource。清单不是测试通过证明。GPU 全部串行；headless+gpu 必须分别运行，Headless 结果不能证明画面。skip_missing / skip_entry_missing 不计 PASS。纯 capture、profilers 和 previews 单列，不自动排入断言回归。')
$markdown.Add('')
foreach($group in $rows | Group-Object classification){$markdown.Add(('- '+$group.Name+': '+$group.Count))}
$markdown.Add('')
$markdown.Add('| Test | 分类 | 超时秒 | 依据 / 缺失引用 |')
$markdown.Add('|---|---|---:|---|')
foreach($row in $rows){$detail=$row.reason;if($row.missing_references.Count -gt 0){$detail+=' '+($row.missing_references -join ', ')};$markdown.Add('| '+$row.name+' | '+$row.classification+' | '+$row.timeout_seconds+' | '+$detail+' |')}
$markdown | Set-Content -LiteralPath (Join-Path $projectRoot 'docs/regression_manifest_20261013.md') -Encoding utf8
$rows | Group-Object classification | Select-Object Name,Count | Format-Table
