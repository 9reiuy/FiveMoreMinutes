// Narrow approved batch; no deletion is performed by this audit.
import fs from 'node:fs';
import path from 'node:path';
const inventory=[];
function walk(dir) {
  if(!fs.existsSync(dir)) return;
  for(const e of fs.readdirSync(dir,{withFileTypes:true})) {
    const file=`${dir}/${e.name}`;
    if(e.isDirectory()) walk(file); else inventory.push(file);
  }
}
for(const dir of ['art','assets','sfx','scripts','scenes','materials','resources','data','tests','tools']) walk(dir);
const sources=[];
for(const file of [...inventory,'project.godot','export_presets.cfg']) {
  if(!/\.(gd|tscn|tres|gdshader|gdshaderinc|json|cfg|mjs|js|ps1|py|cs|gltf|obj|mtl|html)$/.test(file)) continue;
  if(file==='tools/audit_unused_asset_batch.mjs') continue;
  sources.push({file,text:fs.readFileSync(file,'utf8')});
}
const candidates=inventory.filter(file=>
  /^(assets\/enemies\/(alarm_clock|mailbox)\/|assets\/art\/enemies\/generated\/).+\.png$/.test(file) ||
  /^sfx\/(audition_candidates|dash_candidates|elevator_candidates)\/.+\.wav$/.test(file));
const removed=[];
const preserved=[];
for(const file of candidates) {
  const meta=fs.existsSync(file+'.import')?fs.readFileSync(file+'.import','utf8'):'';
  const uid=meta.match(/uid="(uid:\/\/[^\"]+)"/)?.[1];
  const parent=file.slice(0,file.lastIndexOf('/')+1);
  const basename=path.posix.basename(file);
  const refs=sources.filter(source=>source.text.includes(file) ||
    (uid&&source.text.includes(uid)) || (file.endsWith('.wav')&&source.text.includes(basename)) ||
    source.text.includes(`"res://${parent}"`) || source.text.includes(`'res://${parent}'`));
  if(refs.length) preserved.push({file,references:refs.map(s=>s.file)});
  else {removed.push(file);if(fs.existsSync(file+'.import')) removed.push(file+'.import');}
}
const normals=inventory.filter(file=>/_Normal_\dK\.png$/.test(file));
const protectedNormals=normals.filter(file=>file.startsWith('art/Dream/LoafbrrAssets/'));
const report={files:removed.sort(),bytes:removed.reduce((n,f)=>n+fs.statSync(f).size,0),
  preserved,protectedNormals,reason:'Original vendor source pack preserved; no other normal map candidates found.'};
if(process.argv.includes('--verify')) {
  const manifest=JSON.parse(fs.readFileSync('.runtime/unused_asset_cleanup_20261002/manifest.json','utf8').replace(/^\uFEFF/,''));
  const targets=new Set(manifest.map(f=>f.relative));
  const refs=[];
  for(const source of sources) for(const target of targets) if(!target.endsWith('.import')&&source.text.includes(`res://${target}`)) refs.push({source:source.file,target});
  const remaining=manifest.filter(f=>fs.existsSync(f.relative)).map(f=>f.relative);
  console.log(JSON.stringify({remaining,refs,protectedNormals},null,2));
  process.exitCode=remaining.length||refs.length?1:0;
} else console.log(JSON.stringify(report,null,2));
