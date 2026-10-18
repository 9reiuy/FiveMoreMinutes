param([switch]$Apply)
$ErrorActionPreference='Stop'
$cleanupRoot=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$manifest=Get-Content -LiteralPath (Join-Path $cleanupRoot 'docs/cleanup/approved-old-copies-manifest-2026-10-13.json') -Raw | ConvertFrom-Json
if($manifest.root -ne $cleanupRoot){throw 'Root mismatch'}
$allowed=@('.codex-worktrees','.codex-worktrees-real','5min more','.codex')
$epoch=[DateTime]::SpecifyKind([DateTime]'1970-01-01',[DateTimeKind]::Utc)
$validatedDirs=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Resolve-Approved([string]$relative) {
 if(-not @($allowed | Where-Object {$relative -eq $_ -or $relative.StartsWith($_+'/',[StringComparison]::Ordinal)}).Count){throw 'Unapproved target'}
 $full=[IO.Path]::GetFullPath((Join-Path $cleanupRoot $relative))
 if(-not $full.StartsWith($cleanupRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Outside project'}
 $info=Get-Item -LiteralPath $full -Force
 if(($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Link target'}
 $ancestor=if($info.PSIsContainer){$info.Parent}else{$info.Directory}
 while($ancestor.FullName -ne $cleanupRoot){
  if(($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Link ancestor'}
  $ancestor=$ancestor.Parent
  if($null -eq $ancestor){throw 'Invalid ancestor'}
 }
 return $info
}
foreach($record in $manifest.files){
 $info=Resolve-Approved $record.relative
 if($info.PSIsContainer -or $info.Length -ne $record.bytes -or [math]::Abs(($info.LastWriteTimeUtc-$epoch).TotalMilliseconds-$record.modified_ms) -gt 2){throw ('Changed file '+$record.relative)}
}
foreach($relative in $manifest.dirs){$null=Resolve-Approved $relative}
if(-not $Apply){'Validated '+$manifest.files.Count+' files; no deletion';exit}
if(@(Get-Process -Name 'Godot*','git' -ErrorAction SilentlyContinue).Count){throw 'Godot or Git active; no deletion'}
$removed=0;$bytes=0L;$removedDirs=0;$empty=[Collections.Generic.List[string]]::new();$errors=[Collections.Generic.List[object]]::new()
$writer=[IO.StreamWriter]::new((Join-Path $cleanupRoot 'docs/cleanup/approved-old-copies-deletion-2026-10-13.jsonl'),$false,[Text.UTF8Encoding]::new($false))
try {
 foreach($record in $manifest.files){
  try{
   $info=Resolve-Approved $record.relative
   if($info.Length -ne $record.bytes -or [math]::Abs(($info.LastWriteTimeUtc-$epoch).TotalMilliseconds-$record.modified_ms) -gt 2){throw 'Changed file'}
   Remove-Item -LiteralPath $info.FullName -Force
   $removed++;$bytes+=$record.bytes
   $writer.WriteLine(($record.relative|ConvertTo-Json -Compress))
   if($removed % 5000 -eq 0){$writer.Flush();'Removed '+$removed+' files'}
  }catch{$errors.Add(@{relative=$record.relative;error=$_.Exception.Message})}
 }
 foreach($relative in $manifest.dirs){try{$info=Resolve-Approved $relative;[IO.Directory]::Delete($info.FullName,$false);$removedDirs++}catch{$errors.Add(@{relative=$relative;error=$_.Exception.Message})}}
}finally{$writer.Dispose()}
function Prune-Empty([string]$dir) {
 foreach($entry in @(Get-ChildItem -LiteralPath $dir -Force)){
  if(-not $entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){continue}
  if($entry.FullName -eq (Join-Path $cleanupRoot '.git')){continue}
  Prune-Empty $entry.FullName
  if(-not @(Get-ChildItem -LiteralPath $entry.FullName -Force).Count){
   [IO.Directory]::Delete($entry.FullName,$false)
   $empty.Add($entry.FullName.Substring($cleanupRoot.Length+1))
  }
 }
}
Prune-Empty $cleanupRoot
$remaining=@($allowed|Where-Object{Test-Path -LiteralPath (Join-Path $cleanupRoot $_)})
$result=@{removed_files=$removed;removed_bytes=$bytes;old_copy_directories=$removedDirs;additional_empty_directories=$empty.ToArray();errors=$errors.ToArray();remaining_roots=$remaining;main_git_preserved=(Test-Path -LiteralPath (Join-Path $cleanupRoot '.git'))}
[IO.File]::WriteAllText((Join-Path $cleanupRoot 'docs/cleanup/approved-old-copies-summary-2026-10-13.json'),($result|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
@{removed_files=$removed;removed_bytes=$bytes;old_copy_directories=$removedDirs;additional_empty_directories=$empty.Count;errors=$errors.Count;remaining_roots=$remaining}|ConvertTo-Json
if($errors.Count -or $remaining.Count){exit 1}
