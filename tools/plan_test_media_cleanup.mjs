// Plan only the previously reviewed, now explicitly authorized test-media group.
import fs from 'node:fs';
import path from 'node:path';
const root=fs.realpathSync(process.cwd());
const old=JSON.parse(fs.readFileSync('docs/cleanup/followup-audit-2026-10-12.json','utf8'));
const fresh=JSON.parse(fs.readFileSync('docs/cleanup/followup-audit-2026-10-13.json','utf8'));
if(old.root!==root||fresh.root!==root) throw Error('Root mismatch');
const current=new Map(fresh.test_media.map(item=>[item.file,item]));
const approved=old.test_media.filter(item=>!item.sources.length);
const uids=new Map();
for(const item of approved) if(fs.existsSync(item.file+'.import')) {
 const text=fs.readFileSync(item.file+'.import','utf8');
 for(const match of text.matchAll(/uid:\/\/[a-z0-9]+/g)) uids.set(match[0],item.file);
}
const uidReferences=new Map();let scanned=0,bytes=0;
function walk(dir) {
 if(!fs.existsSync(dir)) return;
 for(const item of fs.readdirSync(dir,{withFileTypes:true})) {
  if(item.isSymbolicLink()) continue;
  const file=path.posix.join(dir,item.name);
  if(++scanned>40000) throw Error('Scan budget exceeded');
  if(item.isDirectory()) {if(file!=='docs/cleanup') walk(file);continue;}
  if(!/\.(gd|tscn|tres|gdshader|gdshaderinc|json|cfg|mjs|js|ps1|py|cs|gltf|obj|mtl|html|md|txt|godot)$/.test(file)) continue;
  const size=fs.statSync(file).size;bytes+=size;
  if(size>8*1024*1024||bytes>128*1024*1024) throw Error('Read budget exceeded');
  const text=fs.readFileSync(file,'utf8');
  for(const match of text.matchAll(/uid:\/\/[a-z0-9]+/g)) if(uids.has(match[0])) {
   const owner=uids.get(match[0]);if(!uidReferences.has(owner)) uidReferences.set(owner,[]);uidReferences.get(owner).push(file);
  }
 }
}
for(const dir of ['scripts','scenes','resources','materials','shaders','data','art','assets','tests','tools','docs']) walk(dir);
const files=[],skipped=[];
for(const item of approved) {
 if(!item.file.startsWith('tests/')||! /\.(png|jpg|gif|mp4|avi|log|err)$/i.test(item.file)) throw Error('Scope mismatch');
 const latest=current.get(item.file);
 if(!latest||latest.sources.length||latest.bytes!==item.bytes||uidReferences.has(item.file)) {skipped.push({file:item.file,reason:'missing_changed_or_referenced',uid_sources:uidReferences.get(item.file)||[]});continue;}
 const stat=fs.lstatSync(item.file);
 if(stat.isSymbolicLink()||!stat.isFile()) throw Error('Invalid file target');
 files.push({relative:item.file,bytes:stat.size,modified_ms:stat.mtimeMs,reason:'authorized_unreferenced_test_media'});
}
const manifest={root,original_group_count:approved.length,files,bytes:files.reduce((sum,item)=>sum+item.bytes,0),skipped,excluded:'all game assets, scripts, .import sidecars, caches, source art, and specifically referenced test media'};
fs.writeFileSync('docs/cleanup/test-media-delete-2026-10-13.json',JSON.stringify(manifest,null,2));
console.log(JSON.stringify({files:files.length,bytes:manifest.bytes,skipped},null,2));
