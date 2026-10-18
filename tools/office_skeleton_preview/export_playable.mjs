// Offline compiler. The playable scene consumes JSON, not a Node subprocess.
import fs from 'node:fs';
import path from 'node:path';
import {generate,TYPES} from './generator.mjs';
const out=process.argv[2]||'data/office_skeleton_preview';
const first=Number(process.argv[3]||1001),count=Number(process.argv[4]||10);
fs.mkdirSync(out,{recursive:true});
for(const type of TYPES)for(let seed=first;seed<first+count;seed++){
 const d=generate(type,seed);
 const compact={type,seed,bounds:d.bounds,rooms:d.rooms.map(r=>({id:r.id,kind:r.kind,label:r.label,parent:r.parent,cells:r.cells,bounds:r.bounds})),doors:d.doors,furniture:d.furniture,enemies:d.enemies,anchors:d.anchors,decor:d.decor,corridorSegments:d.corridorSegments,checks:d.checks};
 fs.writeFileSync(path.join(out,`${type}-${seed}.json`),JSON.stringify(compact));
}
console.log(`Exported ${TYPES.length*count} playable layouts to ${out}`);
