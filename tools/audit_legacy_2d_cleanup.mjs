// Conservative retirement audit: keep anything referenced outside the legacy set.
import fs from 'node:fs';
import path from 'node:path';
const root = process.cwd();
const files = [];
function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const e of fs.readdirSync(dir, {withFileTypes:true})) {
    const p = `${dir}/${e.name}`;
    if (e.isDirectory()) walk(p);
    else files.push(p);
  }
}
for (const dir of ['scripts','scenes','assets','art','resources','materials','shaders','data','tests']) walk(dir);
const sources = new Map();
const refs = new Map();
for (const f of files) {
  if (!/\.(gd|tscn|tres|gdshader|json|cfg)$/.test(f)) continue;
  const text = fs.readFileSync(f,'utf8');
  sources.set(f,text);
  refs.set(f,[...text.matchAll(/res:\/\/([^"'\s)]+)/g)].map(m=>m[1]));
}
const roots = ['scenes/dream/dream_world.tscn','scripts/dream/dream_world.gd',
  'scripts/dream/dream_map_builder.gd','scripts/dream/dream_room_manager.gd',
  'scripts/dream/dream_room_template.gd'];
roots.push(...files.filter(f=>/^scenes\/dream\/rooms\/room_.*\.tscn$/.test(f)));
const legacy = new Set(roots);
for (const [f,text] of sources) if (f.startsWith('tests/') &&
  (/res:\/\/(scenes\/dream\/dream_world.tscn|scripts\/dream\/dream_world.gd|scenes\/dream\/rooms\/room_)/.test(text) || /\bDreamRoom(?:Manager|Template)\b/.test(text))) legacy.add(f);
for (const [f,rr] of refs) if(f.startsWith('tests/') && rr.some(r=>legacy.has(r))) legacy.add(f);
const candidates = new Set(legacy);
function addDeps(f) {
  for (const ref of refs.get(f)??[]) if (fs.existsSync(ref) && fs.statSync(ref).isFile() && !candidates.has(ref)) {candidates.add(ref);addDeps(ref);}
}
for (const f of legacy) addDeps(f);
for (const f of files) if (f.startsWith('assets/art/dream/crawling_depths/')) candidates.add(f);
const keep = new Set();
const reasons = {};
for (const [f,rr] of refs) if (!candidates.has(f)) {
  for (const r of rr) for (const c of candidates) if (c===r || (r.endsWith('/') && c.startsWith(r))) {
    keep.add(c); (reasons[c]??=[]).push(f);
  }
}
// Class-name references can be dependencies even without a resource path.
for (const [f,text] of sources) if (!candidates.has(f)) {
  for (const c of candidates) {
    const cls = sources.get(c)?.match(/^class_name\s+(\w+)/m)?.[1];
    if (cls && new RegExp(`\\b${cls}\\b`).test(text)) {keep.add(c);(reasons[c]??=[]).push(f);}
  }
}
function retainDeps(f) {for (const r of refs.get(f)??[]) if (candidates.has(r)&&!legacy.has(r)&&!keep.has(r)) {keep.add(r);retainDeps(r);}}
for (const f of keep) retainDeps(f);
for (const f of legacy) keep.delete(f);
// Only remove dependencies exclusive to the retired graph; source imports/UIDs follow their owner.
const removed = [...candidates].filter(f=>!keep.has(f)&&!f.endsWith('.import')).sort();
for (const f of [...removed]) for (const suffix of ['.uid','.import']) if(fs.existsSync(f+suffix)) removed.push(f+suffix);
const unique = [...new Set(removed)].sort();
const blockers = [];
for(const [f,rr] of refs) if(!unique.includes(f)) for(const r of rr) if(unique.includes(r)) blockers.push({source:f,target:r});
if(process.argv.includes('--verify')) {
  const present = roots.filter(f=>fs.existsSync(f));
  const manifest = JSON.parse(fs.readFileSync('.runtime/legacy_2d_cleanup_20261001/manifest.json','utf8').replace(/^\uFEFF/,''));
  const targets = new Set(manifest.map(f=>f.relative));
  const residualRefs = [];
  for(const [f,rr] of refs) for(const r of rr) if(targets.has(r)) residualRefs.push({source:f,target:r});
  console.log(JSON.stringify({legacyRootsStillPresent:present,remainingDeletedFiles:manifest.filter(f=>fs.existsSync(f.relative)),residualRefs},null,2));
  process.exitCode=present.length||residualRefs.length||manifest.some(f=>fs.existsSync(f.relative))?1:0;
} else {
  const report = {root,files:unique.filter(f=>fs.existsSync(f)),bytes:unique.reduce((n,f)=>n+(fs.existsSync(f)?fs.statSync(f).size:0),0),blockers,preserved:[...keep].sort(),reasons};
  console.log(JSON.stringify(report,null,2));
}
