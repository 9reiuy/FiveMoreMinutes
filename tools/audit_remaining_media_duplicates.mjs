// Evidence only; never delete source art based solely on matching file content.
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
const root=fs.realpathSync(process.cwd());
const audit=JSON.parse(fs.readFileSync('docs/cleanup/followup-final-scope-audit-2026-10-13.json','utf8'));
const candidates=new Set(audit.additional_candidates.map(item=>item.file));
const groups=new Map();let entries=0,readBytes=0;
function walk(dir) {
 for(const item of fs.readdirSync(dir,{withFileTypes:true})) {
  if(++entries>40000) throw Error('Inventory budget exceeded');
  if(item.isSymbolicLink()) continue;
  const file=path.posix.join(dir,item.name);
  if(item.isDirectory()) walk(file);
  else if(/\.(png|wav|ogg|mp3|glb|jpg|jpeg|gif|bmp|webp)$/i.test(file)) {
   const size=fs.statSync(file).size;
   if(!groups.has(size)) groups.set(size,[]);groups.get(size).push(file);
  }
 }
}
for(const dir of ['art','assets','sfx']) if(fs.existsSync(dir)) walk(dir);
const matches=[];
for(const [size,files] of groups) {
 if(files.length<2||!files.some(file=>candidates.has(file))) continue;
 const hashes=new Map();
 for(const file of files) {
  readBytes+=size;if(readBytes>256*1024*1024) throw Error('Read budget exceeded');
  const digest=crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  if(!hashes.has(digest)) hashes.set(digest,[]);hashes.get(digest).push(file);
 }
 for(const [digest,copies] of hashes) if(copies.length>1&&copies.some(file=>candidates.has(file))) matches.push({sha256:digest,bytes_each:size,candidates:copies.filter(file=>candidates.has(file)),other_copies:copies.filter(file=>!candidates.has(file)),note:'Identical content does not prove ownership, unused status, or deletion authority.'});
}
fs.writeFileSync('docs/cleanup/remaining-media-duplicates-2026-10-13.json',JSON.stringify({root,read_bytes:readBytes,matches},null,2));
console.log(JSON.stringify({groups:matches.length,candidates_with_other_copy:matches.filter(item=>item.other_copies.length).reduce((n,item)=>n+item.candidates.length,0),examples:matches.slice(0,8)},null,2));
