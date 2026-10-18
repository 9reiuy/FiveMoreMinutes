param([switch]$Apply)
$ErrorActionPreference='Stop'
$foreignRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$manifest=Get-Content -LiteralPath (Join-Path $foreignRoot 'docs\cleanup\foreign-delete-2026-10-13.json') -Raw | ConvertFrom-Json
if ($manifest.root.TrimEnd('\') -ne $foreignRoot) {throw 'Root mismatch'}
$allowed=@('.workbuddy','.runtime/media_tools','scripts/audio/__pycache__')
$epoch=[DateTime]::SpecifyKind([DateTime]'1970-01-01',[DateTimeKind]::Utc)
function Resolve-ApprovedTarget([string]$relative) {
 if (-not (@($allowed | Where-Object {$relative -eq $_ -or $relative.StartsWith($_+'/',[StringComparison]::Ordinal) }).Count)) {throw 'Unapproved target'}
 $target=[IO.Path]::GetFullPath((Join-Path $foreignRoot $relative))
 if (-not $target.StartsWith($foreignRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Outside project'}
 $info=Get-Item -LiteralPath $target -Force
 $ancestor=$info
 while ($ancestor.FullName -ne $foreignRoot) {
  if (($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {throw 'Reparse target or ancestor'}
  $ancestor=if ($ancestor -is [IO.DirectoryInfo]) {$ancestor.Parent} else {$ancestor.Directory}
  if ($null -eq $ancestor) {throw 'Invalid ancestor'}
 }
 return $target
}
$items=@(foreach ($record in $manifest.files) {
 $target=Resolve-ApprovedTarget $record.relative
 $info=Get-Item -LiteralPath $target -Force
 if ($info.PSIsContainer -or $info.Length -ne $record.bytes -or [math]::Abs(($info.LastWriteTimeUtc-$epoch).TotalMilliseconds-$record.modified_ms) -gt 2) {throw ('Changed file '+$record.relative)}
 @{record=$record;target=$target}
})
$directories=@(foreach ($relative in $manifest.dirs) {Resolve-ApprovedTarget $relative})
if (-not $Apply) { 'Validated '+$items.Count+' files and '+$directories.Count+' directories; no deletion.';exit }
if (@(Get-Process -Name 'Godot*','ffmpeg*' -ErrorAction SilentlyContinue).Count) {throw 'Godot or FFmpeg running; no deletion'}
$journal=Join-Path $foreignRoot ('docs\cleanup\foreign-deletion-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'.jsonl')
$writer=[IO.StreamWriter]::new([IO.File]::Open($journal,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read),[Text.UTF8Encoding]::new($false))
$writer.AutoFlush=$true
$removed=0;$removedBytes=0L;$removedDirs=0;$errors=[Collections.Generic.List[object]]::new()
try {
 foreach ($item in $items) {
  try {
   $info=Get-Item -LiteralPath (Resolve-ApprovedTarget $item.record.relative) -Force
   if ($info.Length -ne $item.record.bytes -or [math]::Abs(($info.LastWriteTimeUtc-$epoch).TotalMilliseconds-$item.record.modified_ms) -gt 2) {throw 'File changed after validation'}
   Remove-Item -LiteralPath $item.target -Force
   $removed++;$removedBytes+=$item.record.bytes
   $writer.WriteLine((@{relative=$item.record.relative;status='permanently_removed'}|ConvertTo-Json -Compress))
  } catch {$errors.Add(@{relative=$item.record.relative;error=$_.Exception.Message})}
 }
 foreach ($relative in $manifest.dirs) {
  try {
   $target=Resolve-ApprovedTarget $relative
   if (@(Get-ChildItem -LiteralPath $target -Force).Count) {throw 'Not empty; directory preserved'}
   [IO.Directory]::Delete($target,$false)
   $removedDirs++
  } catch {$errors.Add(@{relative=$relative;error=$_.Exception.Message})}
 }
} finally {$writer.Dispose()}
$remaining=@($manifest.targets | Where-Object {Test-Path -LiteralPath (Join-Path $foreignRoot $_)})
$summary=@{removed_files=$removed;removed_bytes=$removedBytes;removed_directories=$removedDirs;errors=$errors.ToArray();remaining_roots=$remaining;journal=$journal}
[IO.File]::WriteAllText((Join-Path $foreignRoot 'docs\cleanup\foreign-deletion-summary-2026-10-13.json'),($summary|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$summary|ConvertTo-Json -Depth 5
if ($errors.Count -or $remaining.Count) {exit 1}
