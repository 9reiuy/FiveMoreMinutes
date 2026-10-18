param(
    [string]$GodotExecutable = "E:\Godot\Godot_v4.7.1-stable_win64_console.exe",
    [ValidateSet('A1','B2','C3','V3')][string]$Type = 'A1',
    [uint32]$Seed = 1001,
    [string]$NodePath = ''
)
$ErrorActionPreference = "Stop"
$skeletonProjectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot executable not found. Pass -GodotExecutable with its full path."
}
$skeletonArguments = @("--skeleton-type=$Type", "--skeleton-seed=$Seed")
if ($Seed -lt 1001 -or $Seed -gt 1010) {
    if (-not $NodePath) {
        $skeletonNodeCommand = Get-Command node -ErrorAction SilentlyContinue
        if ($skeletonNodeCommand) { $NodePath = $skeletonNodeCommand.Source }
        else { $NodePath = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' }
    }
    $skeletonOutput = Join-Path $skeletonProjectPath ".runtime\skeleton_custom\$Seed"
    & $NodePath (Join-Path $PSScriptRoot 'office_skeleton_preview\export_playable.mjs') $skeletonOutput $Seed 1
    if ($LASTEXITCODE -ne 0) { throw 'Skeleton generation failed; no alternate layout was loaded.' }
    $skeletonArguments += "--skeleton-layout=$(Join-Path $skeletonOutput "$Type-$Seed.json")"
}
& $GodotExecutable --path $skeletonProjectPath --audio-driver Dummy --log-file "$skeletonProjectPath\.runtime\skeleton_play.log" "res://scenes/dream/preview/OfficeSkeletonPreview.tscn" -- @skeletonArguments
exit $LASTEXITCODE
