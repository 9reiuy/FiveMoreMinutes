$ErrorActionPreference='Stop'
$temporaryRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$manifest=Get-Content -LiteralPath (Join-Path $temporaryRoot 'docs\cleanup\empty-temporary-directories-2026-10-13.json') -Raw | ConvertFrom-Json
if ($manifest.root -ne $temporaryRoot) {throw 'Root mismatch'}
$removed=[Collections.Generic.List[string]]::new();$preserved=[Collections.Generic.List[object]]::new()
foreach ($relative in $manifest.dirs) {
 if ($relative -notmatch '^(\.runtime|tmp|\.godot_cli_user|\.godot-test-user|\.godot_runtime_check|\.godot_runtime_latest|\.godot_user_lighting2?|\.godot_user_ui_render|\.godot_user_ui_shape)(/|$)' -or $relative -match '^\.runtime/(appdata|localappdata|kenney_furniture_20260921)(/|$)') {throw 'Unapproved directory'}
 $target=[IO.Path]::GetFullPath((Join-Path $temporaryRoot $relative))
 if (-not $target.StartsWith($temporaryRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Outside workspace'}
 try {
  $info=Get-Item -LiteralPath $target -Force
  if (-not $info.PSIsContainer) {throw 'Not a directory'}
  $ancestor=$info
  while ($ancestor.FullName -ne $temporaryRoot) {
   if (($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {throw 'Link target or ancestor'}
   $ancestor=$ancestor.Parent
   if ($null -eq $ancestor) {throw 'Invalid ancestor'}
  }
  if (@(Get-ChildItem -LiteralPath $target -Force).Count) {throw 'Nonempty directory preserved'}
  [IO.Directory]::Delete($target,$false)
  $removed.Add($relative)
 } catch {$preserved.Add(@{relative=$relative;reason=$_.Exception.Message})}
}
$result=@{removed_count=$removed.Count;removed=$removed.ToArray();preserved=$preserved.ToArray()}
[IO.File]::WriteAllText((Join-Path $temporaryRoot 'docs\cleanup\empty-directory-result-2026-10-13.json'),($result|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
@{removed_count=$removed.Count;preserved_count=$preserved.Count}|ConvertTo-Json
if ($preserved.Count) {exit 1}
