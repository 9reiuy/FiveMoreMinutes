param(
    [string]$GodotExecutable = "E:\Godot\Godot_v4.7.1-stable_win64_console.exe"
)
$ErrorActionPreference = "Stop"
$godotProjectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path


if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot executable not found at: $GodotExecutable"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 《Five Minutes More》TASK-020-B 尖锐碎片侵蚀转场展示窗口 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "操作快捷键：" -ForegroundColor Yellow
Write-Host "  [1] 尖锐碎片侵蚀 · Mask A 边缘断裂 (Edge Fracture - 默认推荐)" -ForegroundColor White
Write-Host "  [2] 尖锐碎片侵蚀 · Mask B 破碎记忆 (Shattered Memory - 异常梦境)" -ForegroundColor White
Write-Host "  [3] 尖锐碎片侵蚀 · Mask C 斜向撕裂 (Diagonal Tear - 战斗切场)" -ForegroundColor White
Write-Host "  [4] Bayer 4x4 像素有序抖动消融 (Dither Dissolve)" -ForegroundColor White
Write-Host "  [5] CRT 关机抽帧惊醒转场 (Death CRT Glitch)" -ForegroundColor White
Write-Host "  [6] 原生普通纯黑淡入淡出 (Baseline 对照组)" -ForegroundColor White
Write-Host "  [SPACE] 直接换景 (卧室 <-> 前台接待区)" -ForegroundColor White
Write-Host ""

& $GodotExecutable --path $godotProjectPath "res://scenes/debug/TransitionShowcase.tscn"
exit $LASTEXITCODE
