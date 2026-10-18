// Read-only comparison, without Git or walking imported art/engine caches.
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
const root=fs.realpathSync(process.cwd());
const prefixes=['scripts','scenes','data','materials','resources','shaders'];
const current=new Map();let bytes=0,visited=0;
function inventory(base) {
 const out=[];
 function walk(relative) {
  const folder=path.join(base,relative);if(!fs.existsSync(folder)) return;
  for(const item of fs.readdirSync(folder,{withFileTypes:true})) {
   if(++visited>60000) throw Error('Metadata budget');
   const file=path.posix.join(relative,item.name);
   if(item.isSymbolicLink()) throw Error('Link in source tree: '+file);
   if(item.isDirectory()) walk(file);else if(/\.(gd|tscn|tres|json|cfg|gdshader|gdshaderinc)$/.test(file)) out.push(file);
  }
 }
 for(const prefix of prefixes) walk(prefix);
 for(const file of ['project.godot','export_presets.cfg']) if(fs.existsSync(path.join(base,file))) out.push(file);
 return out;
}
function hash(file) {
 const stat=fs.statSync(file);bytes+=stat.size;
 if(stat.size>8*1024*1024||bytes>256*1024*1024) throw Error('Read budget');
 return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}
for(const file of inventory(root)) current.set(file,hash(path.join(root,file)));
const results=[];
for(const parent of ['.codex-worktrees','.codex-worktrees-real','5min more/.codex-worktrees']) {
 if(!fs.existsSync(parent)) continue;
 for(const item of fs.readdirSync(parent,{withFileTypes:true})) {
  if(!item.isDirectory()||item.isSymbolicLink()||item.name==='repo.git') continue;
  const relative=path.posix.join(parent,item.name),base=path.join(root,relative);
  const same=[],different=[],unique=[];
  for(const file of inventory(base)) {
   const digest=hash(path.join(base,file));
   if(!current.has(file)) unique.push(file);
   else if(current.get(file)!==digest) different.push(file);else same.push(file);
  }
  results.push({directory:relative,identical:same.length,different_count:different.length,unique_count:unique.length,different,unique,conclusion:'Do not delete: comparison does not establish merge/history status.'});
 }
}
fs.writeFileSync('docs/cleanup/old-worktree-source-audit-2026-10-13.json',JSON.stringify({root,bytes_read:bytes,scope:prefixes,results},null,2));
console.log(JSON.stringify(results.map(item=>({directory:item.directory,identical:item.identical,different:item.different_count,unique:item.unique_count,examples:[...item.unique,...item.different].slice(0,4)})),null,2));
