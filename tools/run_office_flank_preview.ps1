param([string]$GodotExecutable = "E:\Godot\Godot_v4.7.1-stable_win64_console.exe")
$ErrorActionPreference = "Stop"
$previewProjectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot executable not found. Pass -GodotExecutable with its full path."
}
& $GodotExecutable --path $previewProjectPath --audio-driver Dummy --log-file "$previewProjectPath\.runtime\flank_play.log" "res://scenes/dream/preview/OfficeFlankPreview.tscn"
exit $LASTEXITCODE
