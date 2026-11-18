param([string]$Godot='', [switch]$CheckOnly, [switch]$Reference)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $Godot) {
    $Godot='E:/Godot/Godot_v4.7.1-stable_win64.exe'
    if (-not (Test-Path -LiteralPath $Godot)) {
        $command=Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $Godot=$command.Source }
    }
}
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot executable not found. Pass -Godot with its path.' }
$sampleData=Join-Path $projectPath '.runtime/interactive_gas_play/appdata'
if ($CheckOnly) { Write-Output "Engine $Godot"; Write-Output "Scene $projectPath/scenes/testing/InteractiveGasWhitebox.tscn"; exit 0 }
New-Item -ItemType Directory -Force -Path $sampleData | Out-Null
$previousAppData=$env:APPDATA
try {
    $env:APPDATA=$sampleData
    $gasLaunchArgs=@('--path',('"'+$projectPath+'"'),'--resolution','1280x720','res://scenes/testing/InteractiveGasWhitebox.tscn')
    if ($Reference) { $gasLaunchArgs+=@('--','--smoke-reference') }
    Start-Process -FilePath $Godot -WorkingDirectory $projectPath -ArgumentList $gasLaunchArgs
} finally { $env:APPDATA=$previousAppData }
