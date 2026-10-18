param([switch]$Apply,[string]$ManifestRelative='docs/cleanup/asset-audit-2026-10-12.json',[string]$SummaryRelative='docs/cleanup/deletion-summary-2026-10-12.json')
$ErrorActionPreference='Stop'
$cleanupRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$manifestPath=[IO.Path]::GetFullPath((Join-Path $cleanupRoot $ManifestRelative))
$summaryPath=[IO.Path]::GetFullPath((Join-Path $cleanupRoot $SummaryRelative))
$reportRoot=Join-Path $cleanupRoot 'docs\cleanup'
if (-not $manifestPath.StartsWith($reportRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $summaryPath.StartsWith($reportRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Reports must remain inside docs/cleanup' }
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.root.TrimEnd('\') -ne $cleanupRoot) { throw 'Manifest workspace mismatch' }
$items=[Collections.Generic.List[object]]::new()
$epoch=[DateTime]::SpecifyKind([DateTime]'1970-01-01',[DateTimeKind]::Utc)
foreach ($record in $manifest.files) {
 $target=[IO.Path]::GetFullPath((Join-Path $cleanupRoot $record.relative))
 if (-not $target.StartsWith($cleanupRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Target outside workspace' }
 if ($record.relative -match '^(\.git|\.codex|\.agents|\.workbuddy|\.codex-worktrees[^/]*)(/|$)') { throw 'Protected management directory' }
 $info=Get-Item -LiteralPath $target -Force
 if ($info.PSIsContainer) { throw 'Only explicit files may be removed' }
 $ancestor=$info
 while ($ancestor.FullName -ne $cleanupRoot) {
  if (($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse point target or ancestor' }
  $ancestor=if ($ancestor -is [IO.DirectoryInfo]) {$ancestor.Parent} else {$ancestor.Directory}
  if ($null -eq $ancestor) { throw 'Invalid ancestor chain' }
 }
 $modifiedMs=($info.LastWriteTimeUtc-$epoch).TotalMilliseconds
 if ($info.Length -ne $record.bytes -or [math]::Abs($modifiedMs-$record.modified_ms) -gt 2) { throw ('Target changed since audit: '+$record.relative) }
 $items.Add(@{record=$record;target=$target})
}
if (-not $Apply) { 'Validated '+$items.Count+' explicit files; no deletion performed.'; exit }
$runningGodot=@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue)
if ($runningGodot.Count -gt 0) { throw 'Godot is running; no files removed.' }
$journalPath=Join-Path $cleanupRoot ('docs\cleanup\deletion-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'.jsonl')
$stream=[IO.File]::Open($journalPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false)); $writer.AutoFlush=$true
$removed=0; $removedBytes=0L; $failures=[Collections.Generic.List[object]]::new()
try {
 foreach ($item in $items) {
  try {
   $current=Get-Item -LiteralPath $item.target -Force
   if ($current.Length -ne $item.record.bytes -or [math]::Abs(($current.LastWriteTimeUtc-$epoch).TotalMilliseconds-$item.record.modified_ms) -gt 2) { throw 'File changed after validation' }
   Remove-Item -LiteralPath $item.target -Force -ErrorAction Stop
   $removed++; $removedBytes+=$item.record.bytes
   $writer.WriteLine((@{relative=$item.record.relative;bytes=$item.record.bytes;status='permanently_removed';reason=$item.record.reason} | ConvertTo-Json -Compress))
  } catch {
   $failure=@{relative=$item.record.relative;status='preserved_error';message=$_.Exception.Message}
   $failures.Add($failure); $writer.WriteLine(($failure | ConvertTo-Json -Compress))
  }
 }
} finally { $writer.Dispose() }
$remaining=@($items | Where-Object { Test-Path -LiteralPath $_.target })
$summary=@{removed_files=$removed;removed_bytes=$removedBytes;remaining_targets=$remaining.Count;failures=$failures.ToArray();journal=$journalPath}
[IO.File]::WriteAllText($summaryPath,($summary | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$summary | ConvertTo-Json -Depth 5
if ($remaining.Count -gt 0) { exit 1 }
