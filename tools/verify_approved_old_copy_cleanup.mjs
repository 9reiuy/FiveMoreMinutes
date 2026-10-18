import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const manifest=JSON.parse(fs.readFileSync('docs/cleanup/approved-old-copies-manifest-2026-10-13.json','utf8'));
const summary=JSON.parse(fs.readFileSync('docs/cleanup/approved-old-copies-summary-2026-10-13.json','utf8'));
const changed=manifest.preserved.filter(item=>!fs.existsSync(item.relative)||crypto.createHash('sha256').update(fs.readFileSync(item.relative)).digest('hex')!==item.sha256).map(item=>item.relative);
// The desktop agent can recreate its empty coordination folder between calls.
const regeneratedEmpty=[];
if(fs.existsSync('.codex')){const s=fs.lstatSync('.codex');if(s.isDirectory()&&!s.isSymbolicLink()&&!fs.readdirSync('.codex').length){fs.rmdirSync('.codex');regeneratedEmpty.push('.codex');}}
const empty=[],foreign=[],links=[];
const foreignNames=new Set(['.codex','.workbuddy','__pycache__','node_modules','.venv','venv','.pytest_cache','.mypy_cache','.ruff_cache','GPUCache','Code Cache']);
function walk(dir){for(const name of fs.readdirSync(dir)){const full=path.join(dir,name),relative=path.relative(process.cwd(),full).split(path.sep).join('/');if(relative==='.git')continue;const s=fs.lstatSync(full);if(s.isSymbolicLink()){links.push(relative);continue;}if(s.isDirectory()){if(foreignNames.has(name))foreign.push(relative);if(fs.readdirSync(full).length===0)empty.push(relative);walk(full);}}}
walk(process.cwd());
const result={preserved_files_checked:manifest.preserved.length,changed_preserved_files:changed,remaining_old_roots:manifest.targets.filter(f=>fs.existsSync(f)),main_git_preserved:fs.existsSync('.git'),remaining_empty_directories_excluding_main_git:empty,foreign_directories:foreign,regenerated_empty_directories_removed:regeneratedEmpty,links,runtime_tested:false};
fs.writeFileSync('docs/cleanup/approved-old-copies-verification-2026-10-13.json',JSON.stringify(result,null,2));
fs.writeFileSync('docs/cleanup/旧副本与空目录清理结果-2026-10-13.md',`# 清理结果\n\n永久删除旧副本及独立旧仓库文件 ${summary.removed_files} 个，${(summary.removed_bytes/1024**3).toFixed(2)} GiB；旧副本目录 ${summary.old_copy_directories} 个，其他空目录 ${summary.additional_empty_directories.length} 个。无备份、未经过回收站。\n\n保留当前工程主 .git、游戏源码、设置、有效缓存、原始素材与许可文件。未引用游戏素材保留，已对 ${result.preserved_files_checked} 个素材、导入文件及关键文件进行前后 SHA-256 核对，变化 ${changed.length} 个。\n\n剩余旧副本根目录 ${result.remaining_old_roots.length} 个；主仓库外剩余空目录 ${empty.length} 个；常见其他软件目录 ${foreign.length} 个。游戏开发文档、测试源码和工具仍属于项目，不作为其他软件删除。\n\n本轮未启动游戏或进行性能测试。详细删除清单及验证数据保存在同目录。\n`);
console.log(JSON.stringify(result,null,2));
if(changed.length||result.remaining_old_roots.length||!result.main_git_preserved||empty.length||foreign.length)process.exitCode=1;
