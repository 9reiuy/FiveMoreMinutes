// Read-only dependency audit. Deletion is handled separately with explicit paths.
import fs from 'node:fs';
import path from 'node:path';
const root=fs.realpathSync(process.cwd());
const inventory=[]; const skippedLinks=[];
function walk(dir) {
 if(!fs.existsSync(dir)) return;
 for(const entry of fs.readdirSync(dir,{withFileTypes:true})) {
  const file=path.posix.join(dir,entry.name);
  if(entry.isSymbolicLink()){skippedLinks.push(file);continue;}
  if(entry.isDirectory()) {if(!['.git','.godot','node_modules'].includes(entry.name)) walk(file);}
  else inventory.push(file);
  if(inventory.length>40000) throw Error('Inventory budget exceeded');
 }
}
for(const dir of ['art','assets','sfx','scripts','scenes','materials','resources','shaders','data','tests','tools','docs','script_templates','text_editor_themes','feature_profiles']) walk(dir);
for(const entry of fs.readdirSync('.',{withFileTypes:true})) if(entry.isFile()) inventory.push(entry.name);
const allFiles=new Set(inventory);
const uidOwners=new Map();
for(const file of inventory) {
 if(!/\.(import|uid)$/.test(file)) continue;
 const content=fs.readFileSync(file,'utf8');
 for(const match of content.matchAll(/uid:\/\/[a-z0-9]+/g)) uidOwners.set(match[0],file.replace(/\.(import|uid)$/,''));
}
const direct=new Map(); const dynamic=[]; const basenames=new Set(); const missing=[]; const artifactInputs=new Set();
let sourceBytes=0;
function addReference(target,source) {
 target=target.replaceAll('\\','/');
 if(target.includes('%')||target.includes('{')||target.includes('*')) {
  const marker=target.search(/[%{*]/); const slash=target.lastIndexOf('/',marker);
  if(slash>=0) dynamic.push({prefix:target.slice(0,slash+1),source,pattern:target});
  return;
 }
 if(target.endsWith('/')) {dynamic.push({prefix:target,source,pattern:target});return;}
 if(!direct.has(target)) direct.set(target,new Set()); direct.get(target).add(source);
}
for(const file of inventory) {
 if(!/\.(gd|tscn|tres|gdshader|gdshaderinc|json|cfg|mjs|js|ps1|py|cs|gltf|obj|mtl|html|csv|ini|toml|md|txt|godot|bat)$/.test(file)) continue;
 if(file==='tools/audit_project_cleanup.mjs'||file.startsWith('docs/cleanup/')) continue;
 const size=fs.statSync(file).size;
 if(size>8*1024*1024) throw Error('Text file exceeds budget: '+file);
 sourceBytes+=size; if(sourceBytes>128*1024*1024) throw Error('Source read budget exceeded');
 const text=fs.readFileSync(file,'utf8');
 for(const match of text.matchAll(/(["'])(\.runtime\/.*?)\1/g)) if(fs.existsSync(match[2])&&fs.statSync(match[2]).isFile()) artifactInputs.add(match[2]);
 for(const match of text.matchAll(/(["'])res:\/\/(.*?)\1/g)) addReference(match[2],file);
 for(const match of text.matchAll(/uid:\/\/[a-z0-9]+/g)) if(uidOwners.has(match[0])) addReference(uidOwners.get(match[0]),file);
 // Bare filenames, including sound catalog values and relative OBJ/MTL images.
 for(const match of text.matchAll(/([^\s"'<>\[\],=;()\\/]+\.(?:png|bmp|jpg|jpeg|gif|webp|wav|ogg|mp3|ttf|otf|glb|exr))\b/gi)) basenames.add(match[1]);
}
// A literal directory may later be concatenated with a selected filename.
for(const [ref,owners] of direct) if(fs.existsSync(ref)&&fs.statSync(ref).isDirectory()) {
 for(const source of owners) dynamic.push({prefix:ref.replace(/\/$/,'')+'/',source,pattern:ref});
}
const originals=/^art\/Dream\/(LoafbrrAssets|Post Apoc - Office 32x32 Grid|Post Apoc - Shelter 32x32 Grid)\//;
const candidates=[]; const preserved=[];
for(const file of inventory) {
 if(!/^(art|assets|sfx)\//.test(file)||! /\.(png|bmp|jpg|jpeg|gif|webp|wav|ogg|mp3|ttf|otf|glb|exr)$/i.test(file)) continue;
 let reason=null;
 if(originals.test(file)||file.startsWith('assets/fonts/')) reason='preserved_original_source_or_font';
 else if(file==='assets/ui/products/brainstem_icon.png') reason='documented_old_save_compatibility_asset';
 else if(allFiles.has(file.replace(/\.[^.]+$/,'.aseprite'))||allFiles.has(file.replace(/\.[^.]+$/,'.psd'))) reason='editable_original_companion';
 else if(direct.has(file)) reason='direct_or_uid_reference';
 else if(basenames.has(path.posix.basename(file))) reason='bare_filename_reference';
 else if(dynamic.some(item=>file.startsWith(item.prefix))) reason='dynamic_directory_reference';
 if(reason) preserved.push({file,reason});
 else {
  candidates.push({relative:file,bytes:fs.statSync(file).size,reason:'no_static_uid_filename_or_dynamic_directory_reference'});
  if(allFiles.has(file+'.import')) candidates.push({relative:file+'.import',bytes:fs.statSync(file+'.import').size,reason:'removed_asset_import_sidecar'});
 }
}
for(const [target,owners] of direct) {
 if(/^(\.runtime|\.godot|build|tmp)\//.test(target)) continue;
 if(target && !fs.existsSync(target)) missing.push({target,sources:[...owners].slice(0,4)});
}
const proposed=new Map(candidates.map(item=>[item.relative,item]));
function propose(file,reason) {
 const resolved=path.resolve(file);
 if(!resolved.startsWith(root+path.sep)) throw Error('Outside workspace: '+file);
 const stat=fs.lstatSync(file);
 if(stat.isSymbolicLink()||!stat.isFile()) return;
 proposed.set(file,{relative:file,bytes:stat.size,reason});
}
const extraImports=[]; let visited=0;
const protectedRuntime=['.runtime/media_tools','.runtime/kenney_furniture_20260921','.runtime/nyangeon_reference','.runtime/face_art'];
function artifacts(dir) {
 if(!fs.existsSync(dir)) return;
 for(const entry of fs.readdirSync(dir,{withFileTypes:true})) {
  const file=path.posix.join(dir,entry.name);
  if(++visited>80000) throw Error('Artifact inventory budget exceeded');
  if(entry.isSymbolicLink()) {skippedLinks.push(file);continue;}
  if(entry.isDirectory()) {
   if(['.git','.codex','.codex-worktrees','node_modules','appdata','localappdata','app_userdata','user_data','user_data_current'].includes(entry.name)) continue;
   if(protectedRuntime.some(prefix=>file===prefix)) continue;
   artifacts(file); continue;
  }
  if(file.endsWith('.import')) extraImports.push(file);
  if(artifactInputs.has(file)||direct.has(file)) continue;
  if(file.startsWith('.runtime/crash_diagnostics/')) {propose(file,'retired_diagnostic_temporary_file');continue;}
  if(/\.(log|err|png|jpg|jpeg|gif|avi|mp4|webm|json|jsonl|html|csv|zip|dmp|pdb)$/i.test(file)) propose(file,'generated_test_or_capture_artifact');
 }
}
for(const dir of ['.runtime','tmp','.godot_runtime_check','.godot_runtime_latest','.godot_user_lighting','.godot_user_lighting2','.godot_user_ui_render','.godot_user_ui_shape']) artifacts(dir);
for(const dir of ['.','5min more','.godot']) if(fs.existsSync(dir)) for(const entry of fs.readdirSync(dir,{withFileTypes:true})) {
 if(!entry.isFile()) continue;
 const file=dir==='.'?entry.name:path.posix.join(dir,entry.name);
 if(entry.name.endsWith('.log')) propose(file,'root_or_cache_test_log');
 if(entry.name==='screen_capture.png' && !direct.has(file)) propose(file,'temporary_screen_capture');
 if(entry.name.endsWith('.gd.uid') && !fs.existsSync(file.slice(0,-4)) && !direct.has(file.slice(0,-4))) propose(file,'unreferenced_orphan_script_uid');
}
for(const file of ['bf1_classic.rar','bf1_real.rar','build/FiveMoreMinutes-v0.4.7.3.exe','build/FiveMoreMinutes-v0.4.7.4.exe']) if(fs.existsSync(file)) propose(file,'unused_download_or_obsolete_build');
for(const file of [...proposed.keys()]) if(fs.existsSync(file+'.import')) propose(file+'.import','removed_artifact_import_sidecar');
// Preserve every current import destination (and its MD5) before pruning stale cache.
const liveCache=new Set();
for(const file of [...inventory.filter(f=>f.endsWith('.import')),...extraImports]) {
 if(proposed.has(file)||!fs.existsSync(file.slice(0,-7))) continue;
 const text=fs.readFileSync(file,'utf8');
 for(const match of text.matchAll(/res:\/\/(\.godot\/imported\/[^"\r\n]+)/g)) {
  liveCache.add(match[1]); liveCache.add(match[1].replace(/\.[^.]+$/,'.md5'));
 }
}
if(fs.existsSync('.godot/imported')) for(const entry of fs.readdirSync('.godot/imported',{withFileTypes:true})) {
 const file='.godot/imported/'+entry.name;
 if(entry.isFile()&&!liveCache.has(file)&&!entry.name.startsWith('.')) propose(file,'orphaned_import_cache');
}
const allCandidates=[...proposed.values()].map(item=>({...item,modified_ms:fs.statSync(item.relative).mtimeMs})).sort((a,b)=>a.relative.localeCompare(b.relative));
const report={root,inventory_count:inventory.length,source_bytes:sourceBytes,files:allCandidates,bytes:allCandidates.reduce((n,f)=>n+f.bytes,0),dynamic,preserved,missing,skippedLinks,artifact_inputs:[...artifactInputs]};
if(process.argv.includes('--verify-cleanup')) {
 const baseline=JSON.parse(fs.readFileSync('docs/cleanup/asset-audit-2026-10-12.json','utf8'));
 const priorMissing=new Set(baseline.missing.map(item=>JSON.stringify(item)));
 const remainingTargets=baseline.files.filter(item=>fs.existsSync(item.relative)).map(item=>item.relative);
 const newMissing=missing.filter(item=>!priorMissing.has(JSON.stringify(item)));
 const required=['project.godot','scenes/app/main.tscn','scenes/dream/Dream3D_TutorialRoom.tscn','art/Dream/dream_chr_32x32.png','assets/fonts/pixel_theme.tres','assets/ui/products/brainstem_icon.png','build/FiveMoreMinutes-v0.5.exe'];
 const missingRequired=required.filter(file=>!fs.existsSync(file));
 const removedPaths=new Set(baseline.files.map(item=>item.relative));
 const removedLiveImports=[...liveCache].filter(file=>removedPaths.has(file));
 const verification={approved_files:baseline.files.length,remaining_targets:remainingTargets,new_missing_references:newMissing,missing_required:missingRequired,removed_live_imports:removedLiveImports,baseline_missing_references:baseline.missing.length,current_missing_references:missing.length,live_import_paths:liveCache.size,game_runtime_tested:false};
 fs.writeFileSync('docs/cleanup/verification-2026-10-12.json',JSON.stringify(verification,null,2));
 console.log(JSON.stringify(verification,null,2));
 if(remainingTargets.length||newMissing.length||missingRequired.length||removedLiveImports.length) process.exitCode=1;
}
if(process.argv.includes('--write')) {
 fs.mkdirSync('docs/cleanup',{recursive:true});
 const outputIndex=process.argv.indexOf('--output');
 const output=outputIndex>=0?process.argv[outputIndex+1]:'docs/cleanup/asset-audit-2026-10-12.json';
 if(!output||!output.startsWith('docs/cleanup/')||!path.resolve(output).startsWith(root+path.sep)) throw Error('Invalid output path');
 fs.writeFileSync(output,JSON.stringify(report,null,2));
}
console.log(JSON.stringify({inventory_count:report.inventory_count,candidate_files:allCandidates.length,candidate_bytes:report.bytes,dynamic_rules:dynamic.length,missing_references:missing.length,skipped_links:skippedLinks,groups:Object.fromEntries([...new Set(allCandidates.map(c=>c.reason))].map(reason=>[reason,allCandidates.filter(c=>c.reason===reason).length]))},null,2));
