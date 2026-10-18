// Second-pass inventory only. No deletion and no changes to the approved manifest.
import fs from 'node:fs';
import path from 'node:path';
const root=fs.realpathSync(process.cwd());
const files=[];
function walk(dir) {
 if(!fs.existsSync(dir)) return;
 for(const item of fs.readdirSync(dir,{withFileTypes:true})) {
  if(item.isSymbolicLink()) continue;
  const file=path.posix.join(dir,item.name);
  if(item.isDirectory()) walk(file); else files.push(file);
  if(files.length>40000) throw Error('Bounded inventory exceeded');
 }
}
for(const dir of ['art','assets','sfx','scripts','scenes','materials','resources','shaders','data','tests','tools','docs']) walk(dir);
const texts=[];
for(const file of files) {
 if(!/\.(gd|tscn|tres|gdshader|gdshaderinc|json|cfg|mjs|js|ps1|py|cs|gltf|obj|mtl|html|csv|ini|toml|md|txt)$/.test(file)) continue;
 if(file.startsWith('docs/cleanup/')||file.startsWith('tools/audit_cleanup')||file==='tools/audit_project_cleanup.mjs') continue;
 if(fs.statSync(file).size>8*1024*1024) throw Error('Oversized source: '+file);
 texts.push({file,text:fs.readFileSync(file,'utf8'),runtime:/^(scripts|scenes|materials|resources|shaders|data|art|assets|sfx)\//.test(file)});
}
for(const file of ['project.godot','export_presets.cfg']) texts.push({file,text:fs.readFileSync(file,'utf8'),runtime:true});
let sourceBytes=texts.reduce((sum,item)=>sum+Buffer.byteLength(item.text),0);
if(sourceBytes>128*1024*1024) throw Error('Source budget exceeded');
const refs=new Map(),patterns=[];
function add(key,source) {if(!refs.has(key)) refs.set(key,[]);refs.get(key).push(source);}
for(const source of texts) {
 for(const match of source.text.matchAll(/(["'`])res:\/\/(.*?)\1/g)) {
  const target=match[2];
  if(/[%{*]/.test(target)) {
   let pattern=target.replace(/[.+?^$()|[\]\\]/g,'\\$&').replace(/%0?\d*d/g,'[0-9]+').replace(/%s/g,'[^/]+').replace(/\{[^}]*\}/g,'[^/]+').replace(/\*/g,'.*');
   try {patterns.push({pattern:target,regex:new RegExp('^'+pattern+'$'),source});} catch {}
  } else add(target,source);
 }
 for(const match of source.text.matchAll(/([^\s"'`<>\[\],=;()\\/]+\.(?:png|bmp|jpg|jpeg|gif|webp|wav|ogg|mp3|ttf|otf|glb|exr))\b/gi)) add(path.posix.basename(match[1]),source);
}
function references(file,includeDirectories=true) {
 const owners=[...(refs.get(file)||[]),...(refs.get(path.posix.basename(file))||[])];
 for(const item of patterns) if(item.regex.test(file)) owners.push(item.source);
 // Literal catalog directories may be concatenated with an unknown filename.
 if(includeDirectories) for(const [key,sources] of refs) {
  const prefix=key.replace(/\/$/,'')+'/';
  if(file.startsWith(prefix)&&fs.existsSync(key)&&fs.statSync(key).isDirectory()) owners.push(...sources);
 }
 return [...new Map(owners.map(item=>[item.file,item])).values()];
}
const prior=JSON.parse(fs.readFileSync('docs/cleanup/asset-audit-2026-10-12.json','utf8'));
const preserved=new Map(prior.preserved.map(item=>[item.file,item.reason]));
const candidates=[],developmentOnly=[],protectedSource=[];
for(const file of files.filter(file=>/^(art|assets|sfx)\//.test(file)&&/\.(png|bmp|jpg|jpeg|gif|webp|wav|ogg|mp3|ttf|otf|glb|exr)$/i.test(file))) {
 const owners=references(file),record={file,bytes:fs.statSync(file).size,sources:owners.map(item=>item.file),previous_reason:preserved.get(file)||null};
 if(owners.some(item=>item.runtime)) continue;
 if(file.includes('_2d_source.')||['preserved_original_source_or_font','editable_original_companion','documented_old_save_compatibility_asset'].includes(record.previous_reason)) {protectedSource.push(record);continue;}
 if(record.previous_reason==='direct_or_uid_reference'&&!owners.length) {record.note='UID or unsupported reference needs manual verification';developmentOnly.push(record);continue;}
 if(owners.length) developmentOnly.push(record); else candidates.push(record);
}
const outputs=files.filter(file=>file.startsWith('tests/')&&/\.(png|jpg|gif|mp4|avi|log|err)$/i.test(file)).map(file=>({file,bytes:fs.statSync(file).size,sources:references(file,false).map(item=>item.file)}));
const rootText=['out.txt','test_results.txt'].filter(file=>fs.existsSync(file)).map(file=>({file,bytes:fs.statSync(file).size,preview:fs.readFileSync(file,'utf8').slice(0,350)}));
const summary={root,scope:'read-only second pass; candidates require individual review',source_bytes:sourceBytes,additional_candidates:candidates,development_only:developmentOnly,protected_originals_without_found_runtime_reference:protectedSource,test_media:outputs,root_text:rootText};
const outputIndex=process.argv.indexOf('--output');
const output=outputIndex>=0?process.argv[outputIndex+1]:'docs/cleanup/followup-audit-2026-10-12.json';
if(!output||!output.startsWith('docs/cleanup/')||path.resolve(output).startsWith(root+path.sep)===false) throw Error('Invalid report destination');
fs.writeFileSync(output,JSON.stringify(summary,null,2));
console.log(JSON.stringify({additional_candidates:candidates.length,candidate_bytes:candidates.reduce((n,item)=>n+item.bytes,0),development_only:developmentOnly.length,protected_originals:protectedSource.length,test_media:outputs.length,test_media_bytes:outputs.reduce((n,item)=>n+item.bytes,0),test_media_without_specific_reference:outputs.filter(item=>!item.sources.length).length,root_text:rootText,candidate_preview:candidates.slice(0,8)},null,2));
