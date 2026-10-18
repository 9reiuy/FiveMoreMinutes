import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root=fs.realpathSync(process.cwd());
const targets=['.codex-worktrees','.codex-worktrees-real','5min more','.codex'];
const files=[],dirs=[];
function walk(relative) {
 const full=path.resolve(root,relative),s=fs.lstatSync(full);
 if(!full.startsWith(root+path.sep)||s.isSymbolicLink()) throw Error('Unsafe target '+relative);
 if(s.isDirectory()) {for(const name of fs.readdirSync(full))walk(relative+'/'+name);dirs.push(relative);}
 else if(s.isFile())files.push({relative,bytes:s.size,modified_ms:s.mtimeMs});
 else throw Error('Unsupported entry '+relative);
}
for(const target of targets)if(fs.existsSync(target))walk(target);
const media=JSON.parse(fs.readFileSync('docs/cleanup/listing-current-media-2026-10-13.json','utf8'));
const preservePaths=new Set(['project.godot','art/Dream/dream_chr_32x32.png']);
for(const item of media.additional_candidates){preservePaths.add(item.file);if(fs.existsSync(item.file+'.import'))preservePaths.add(item.file+'.import');}
const preserved=[...preservePaths].map(relative=>({relative,sha256:crypto.createHash('sha256').update(fs.readFileSync(relative)).digest('hex')}));
fs.writeFileSync('docs/cleanup/approved-old-copies-manifest-2026-10-13.json',JSON.stringify({root,targets,files,dirs,preserved},null,2));
console.log(JSON.stringify({files:files.length,bytes:files.reduce((n,f)=>n+f.bytes,0),dirs:dirs.length,preserved:preserved.length}));
