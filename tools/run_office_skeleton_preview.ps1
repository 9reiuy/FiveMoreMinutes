param(
    [ValidateSet('ALL','A1','B2','C3','V3')][string]$Type = 'ALL',
    [uint32]$Seed = 1001,
    [ValidateRange(1,100)][int]$Count = 10,
    [string]$Output = '',
    [string]$NodePath = ''
)
$ErrorActionPreference = 'Stop'
$previewRepo = Split-Path -Parent $PSScriptRoot
if (-not $NodePath) {
    $previewNodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($previewNodeCommand) { $NodePath = $previewNodeCommand.Source }
    else { $NodePath = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' }
}
if (-not (Test-Path -LiteralPath $NodePath)) { throw '找不到 Node.js；请通过 -NodePath 指定。' }
if (-not $Output) { $Output = Join-Path $previewRepo '.runtime/office_skeleton_preview' }
$previewGenerator = Join-Path $PSScriptRoot 'office_skeleton_preview/generator.mjs'
if ($Type -eq 'ALL') { & $NodePath $previewGenerator --count $Count --seed $Seed --out $Output }
else { & $NodePath $previewGenerator --type $Type --seed $Seed --out (Join-Path $Output "$Type-$Seed.svg") }
if ($LASTEXITCODE -ne 0) { throw "白盒生成失败，退出码 $LASTEXITCODE" }
Write-Host "独立预览已输出：$Output（未接入正式游戏）"
