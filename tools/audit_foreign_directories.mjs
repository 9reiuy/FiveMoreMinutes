// Directory metadata audit: no deletions, no Git, no symlink traversal.
import fs from 'node:fs';
import path from 'node:path';
const root=fs.realpathSync(process.cwd());
const skipped=[],findings=[],inventory=[];let visited=0;
const exclude=new Set(['.git','.codex-worktrees','.codex-worktrees-real']);
const cacheNames=new Set(['node_modules','__pycache__','.pytest_cache','.mypy_cache','.ruff_cache','.npm','.cache','Cache','Code Cache','GPUCache','DawnCache','pip','venv','.venv']);
function walk(dir) {
 let count=0,bytes=0;
 for(const item of fs.readdirSync(dir,{withFileTypes:true})) {
  const file=dir==='.'?item.name:path.posix.join(dir,item.name);
  if(++visited>70000) throw Error('Directory inventory limit');
  if(item.isSymbolicLink()) {skipped.push({path:file,reason:'link_not_followed'});continue;}
  if(item.isDirectory()) {
   if(exclude.has(item.name)) {skipped.push({path:file,reason:'version_control_or_worktree_not_traversed',children:fs.readdirSync(file).slice(0,10)});continue;}
   const totals=walk(file);count+=totals.files;bytes+=totals.bytes;
   if(cacheNames.has(item.name)) findings.push({path:file,kind:'tool_cache_or_dependency',...totals});
   if(file.startsWith('.runtime/')&&file.split('/').length===2||!file.includes('/')) inventory.push({path:file,...totals});
  } else {count++;bytes+=fs.statSync(file).size;}
 }
 return {files:count,bytes};
}
const total=walk('.');
const report={root,total,metadata_entries:visited,cache_findings:findings,top_directories:inventory,skipped,scope:'All non-worktree directories; names and sizes only. No source or saved-data content read.'};
fs.writeFileSync('docs/cleanup/foreign-directory-audit-2026-10-13.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({total,findings,selected_directories:inventory.filter(item=>/^\.(runtime|workbuddy|codex)|^(Godot|runtime_user|export_templates|5min more)$/.test(item.path)),skipped},null,2));
