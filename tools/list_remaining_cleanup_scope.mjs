// Inventory/report only. No deletion, no Git commands, no binary content reads.
import fs from 'node:fs';
import path from 'node:path';
const root=fs.realpathSync(process.cwd());
const media=JSON.parse(fs.readFileSync('docs/cleanup/listing-current-media-2026-10-13.json','utf8'));
const unreferenced=new Set(media.additional_candidates.map(item=>item.file));
const developmentOnly=new Set(media.development_only.map(item=>item.file));
const files=[],directories=[],links=[];let visited=0;
const worktreePrefixes=['.codex-worktrees/','.codex-worktrees-real/','5min more/.codex-worktrees/'];
const cacheNames=new Set(['__pycache__','node_modules','.venv','venv','.pytest_cache','.mypy_cache','.ruff_cache','GPUCache','Code Cache','.npm']);
function category(file) {
 const parts=file.split('/');
 if(parts.includes('.workbuddy')) return 'other_software_records';
 if(parts.some(part=>cacheNames.has(part))) return 'other_software_cache_or_dependencies';
 if(file.startsWith('.codex-worktrees-real/repo.git/')) return 'old_independent_repository_history';
 if(worktreePrefixes.some(prefix=>file.startsWith(prefix))) return 'old_workspace_game_copy';
 if(file.startsWith('.git/')) return 'main_repository_preserve';
 if(file.startsWith('.codex/')) return 'other_software_management';
 if(file.startsWith('5min more/')) return 'nested_project_metadata_or_management';
 if(unreferenced.has(file)) return 'unreferenced_game_media_review_not_proven_unrelated';
 if(file.endsWith('.import')&&unreferenced.has(file.slice(0,-7))) return 'metadata_for_unreferenced_game_media';
 if(developmentOnly.has(file)) return 'developer_referenced_game_media_preserve';
 if(file.startsWith('.runtime/appdata/')||file.startsWith('.runtime/localappdata/')||file.startsWith('Godot/')||file.startsWith('runtime_user/')||/^\.godot[_-]/.test(file)) return 'game_engine_user_or_test_data_preserve';
 if(file.startsWith('.runtime/kenney_furniture_20260921/')) return 'game_art_supplier_original_preserve';
 if(file.startsWith('.runtime/')) return 'game_developer_temporary_or_test_data_review';
 if(file.startsWith('.godot/')) return 'active_game_engine_cache_preserve';
 if(file.startsWith('tests/')||file.startsWith('tools/')||file.startsWith('docs/')) return 'project_development_tests_documents_preserve';
 if(file.startsWith('art/')||file.startsWith('assets/')||file.startsWith('sfx/')) return 'game_resource_or_source_art_preserve';
 if(file.startsWith('build/')) return 'game_build_preserve';
 if(file.startsWith('scripts/')||file.startsWith('scenes/')||file.startsWith('materials/')||file.startsWith('resources/')||file.startsWith('shaders/')||file.startsWith('data/')) return 'game_source_preserve';
 if(file.startsWith('tmp/')) return 'temporary_directory_content_review';
 return 'project_configuration_or_unclassified_review';
}
function walk(dir) {
 let totalFiles=0,totalBytes=0;
 const entries=fs.readdirSync(dir,{withFileTypes:true});
 for(const item of entries) {
  if(++visited>200000) throw Error('Metadata inventory budget exceeded');
  const relative=dir==='.'?item.name:path.posix.join(dir,item.name);
  if(item.isSymbolicLink()) {links.push(relative);continue;}
  if(item.isDirectory()) {
   const totals=walk(relative);
   totalFiles+=totals.files;totalBytes+=totals.bytes;
   directories.push({path:relative,files:totals.files,bytes:totals.bytes,empty:totals.files===0&&fs.readdirSync(relative).length===0});
  } else {
   const stat=fs.lstatSync(relative);
   if(!stat.isFile()) {links.push(relative);continue;}
   files.push({path:relative,bytes:stat.size,category:category(relative)});
   totalFiles++;totalBytes+=stat.size;
  }
 }
 return {files:totalFiles,bytes:totalBytes};
}
const total=walk('.');
const buckets={};for(const file of files) {
 if(!buckets[file.category]) buckets[file.category]={files:0,bytes:0};
 buckets[file.category].files++;buckets[file.category].bytes+=file.bytes;
}
const exactCategories=new Set(['other_software_records','other_software_cache_or_dependencies','other_software_management','old_independent_repository_history','old_workspace_game_copy','nested_project_metadata_or_management']);
const reviewCategories=new Set(['unreferenced_game_media_review_not_proven_unrelated','metadata_for_unreferenced_game_media','game_developer_temporary_or_test_data_review','temporary_directory_content_review']);
const report={root,date:'2026-10-13',mode:'list_only',scope:'All regular files including old worktrees and repository metadata; no link traversal or file content reads',total,buckets,links,directories,files};
fs.writeFileSync('docs/cleanup/remaining-resources-full-inventory-2026-10-13.json',JSON.stringify(report,null,2));
function list(categories,label,output) {
 const selected=files.filter(file=>categories.has(file.category)).sort((a,b)=>a.path.localeCompare(b.path));
 fs.writeFileSync(output,'\ufeff'+label+'\r\n项目：'+root+'\r\n日期：2026-10-13；本轮只列出，不删除。\r\n数量：'+selected.length+'\r\n每行：分类 | 字节 | 相对路径\r\n\r\n'+selected.map(file=>file.category+' | '+file.bytes+' | '+file.path).join('\r\n'));
 return selected.length;
}
const nongameCount=list(exactCategories,'非正式游戏内容：软件记录、旧副本和独立旧仓库。此清单不是删除授权。','docs/cleanup/其他软件与旧副本-完整文件清单-2026-10-13.txt');
const reviewCount=list(reviewCategories,'待确认：未引用游戏素材及开发临时/测试数据，不等于与游戏无关。','docs/cleanup/未引用素材与待确认数据-完整文件清单-2026-10-13.txt');
const selectedRoots=directories.filter(item=>['.codex','.codex-worktrees','.codex-worktrees-real','.codex-worktrees-real/repo.git','5min more','5min more/.codex-worktrees'].includes(item.path));
const nestedSoftware=directories.filter(item=>item.path.split('/').some(part=>part==='.workbuddy'||cacheNames.has(part)));
const mib=n=>(n/1048576).toFixed(2),gib=n=>(n/1073741824).toFixed(2);
const softwareFiles=files.filter(item=>item.category==='other_software_records');
const codexDirs=directories.filter(item=>path.posix.basename(item.path)==='.codex');
const workspaceRoots=selectedRoots.filter(item=>['.codex-worktrees','.codex-worktrees-real','5min more/.codex-worktrees'].includes(item.path));
const groups=new Map();
for(const item of media.additional_candidates) {
 const key=item.file.split('/').slice(0,2).join('/');
 if(!groups.has(key)) groups.set(key,{files:0,bytes:0});
 const group=groups.get(key);group.files++;group.bytes+=item.bytes;
}
const details=[
 '# 当前剩余非运行内容与待确认资源完整清单 · 2026-10-13',
 '',
 '本轮只列出，不删除。扫描当前整个项目，包括旧工作树和仓库元数据；未调用 Git，未跟随链接。',
 '',
 `扫描快照：${total.files.toLocaleString('en-US')} 个文件、${gib(total.bytes)} GiB。分类合计与总量一致。`,
 '',
 '## 一、可以确认属于其他软件的记录/目录',
 '',
 `旧副本内部还存在 ${softwareFiles.length} 个 Workbuddy 记录文件，总计 ${mib(softwareFiles.reduce((n,item)=>n+item.bytes,0))} MiB；不属于游戏运行资源。逐文件如下：`,
 '',
 ...softwareFiles.map(item=>`- \`${item.path}\`（${item.bytes} 字节）`),
 '',
 `还存在 ${codexDirs.length} 处空 Codex 管理目录，全部 0 字节：`,
 '',
 ...codexDirs.map(item=>`- \`${item.path}\``),
 '',
 '全目录扫描未发现 node_modules、Python __pycache__、venv、常见浏览器缓存等目录。根目录已清理的 Workbuddy/FFmpeg 不重复列入当前清单；上述 Workbuddy 是旧副本里另存的记录。',
 '',
 '## 二、正式入口不使用的旧工程副本与旧仓库',
 '',
 '这些内容与游戏开发有关，不能称为“与游戏毫无关系”；但属于额外旧工作区，不是当前正式游戏文件。包含差异代码和旧历史，不能凭清单自动删除。',
 '',
 '| 范围 | 文件数 | 大小 |',
 '| --- | ---: | ---: |',
 ...workspaceRoots.map(item=>`| \`${item.path}\` | ${item.files.toLocaleString('en-US')} | ${gib(item.bytes)} GiB |`),
 '',
 `三个范围合计 ${gib(workspaceRoots.reduce((n,item)=>n+item.bytes,0))} GiB。Workbuddy 记录已包含其中，不能重复计算体积。`,
 '',
 '子目录包括 corridor、door、pillar（嵌套副本只有 corridor、door）。独立 `.codex-worktrees-real/repo.git` 含 5,437 个文件、464,701,491 字节，已包含在对应上级体积中。',
 '',
 '嵌套 `5min more/` 根部还留着 4 份旧工程元数据：',
 '',
 ...files.filter(item=>item.category==='nested_project_metadata_or_management').map(item=>`- \`${item.path}\`（${item.bytes} 字节）`),
 '',
 '当前正式入口是项目根目录 `project.godot` 中的 `res://scenes/app/main.tscn`；并不以嵌套旧工程配置启动。',
 '',
 '上述软件记录、旧副本、独立旧仓库和嵌套元数据的所有文件路径见 `其他软件与旧副本-完整文件清单-2026-10-13.txt`，共 '+nongameCount.toLocaleString('en-US')+' 行。',
 '',
 '## 三、未检出引用的游戏素材：不是已证明无关',
 '',
 `共 ${media.additional_candidates.length.toLocaleString('en-US')} 个媒体文件、${mib(media.additional_candidates.reduce((n,item)=>n+item.bytes,0))} MiB，以及对应 2,208 个导入描述。静态/具体模式扫描没有找到引用，不证明所有运行期拼接、UID 或历史存档都不使用。`,
 '',
 '| 分组 | 媒体数 | 大小 |',
 '| --- | ---: | ---: |',
 ...[...groups].map(([key,item])=>`| \`${key}\` | ${item.files} | ${mib(item.bytes)} MiB |`),
 '',
 '包含备用 BGM、图标、特效帧、旧角色动作、壁纸和武器图。用户自绘源图与供应商包有保留边界；未引用不等于与游戏无关。逐文件见 `未引用素材与待确认数据-完整文件清单-2026-10-13.txt`。',
 '',
 '## 四、项目相关但不直接进入正式画面的数据',
 '',
 '- `.runtime` 中 40 个开发临时/测试输入输出，约 '+mib(buckets.game_developer_temporary_or_test_data_review?.bytes||0)+' MiB，逐文件已纳入待确认清单。',
 '- `tmp/macro_debug.gd`、`tmp/macro_debug.gd.uid`：临时调试脚本，非正式游戏入口。',
 '- `tests`、`tools`、`docs`：项目测试、开发与文档；不能把“不是游戏画面资源”视为“与项目无关”。',
 '- `.git`：当前主仓库，约 '+gib(buckets.main_repository_preserve?.bytes||0)+' GiB；不是第三方软件垃圾。',
 '- `.godot`、Godot 用户及测试数据：有效导入、着色器缓存和设置，不列为无关资源。',
 '- `.runtime/kenney_furniture_20260921`、字体、许可证及素材原稿：项目相关源资料，保留。',
 '- `build/FiveMoreMinutes-v0.5.exe`：当前游戏构建，保留。',
 '',
 '## 五、交付与边界',
 '',
 '- 总览：本文件。',
 '- 软件/旧副本逐文件清单：`其他软件与旧副本-完整文件清单-2026-10-13.txt`。',
 '- 未引用媒体/开发数据逐文件清单：`未引用素材与待确认数据-完整文件清单-2026-10-13.txt`。',
 '- 全目录分类与大小：`remaining-resources-full-inventory-2026-10-13.json`，包含保留项，不是删除清单。',
 '',
 '本轮未删除、搬移文件，未启动游戏或执行压力测试。没有将待确认项目冒充已证明无关，也没有把列清单视为删除授权。',
 ''
];
fs.writeFileSync('docs/cleanup/剩余资源分类总览-2026-10-13.md',details.join('\n'));
console.log(JSON.stringify({total,buckets,links,selected_roots:selectedRoots,nested_software_roots:nestedSoftware.filter(item=>item.path.endsWith('/.workbuddy')||cacheNames.has(path.posix.basename(item.path))),nongame_list_files:nongameCount,review_list_files:reviewCount,unclassified:files.filter(item=>item.category==='project_configuration_or_unclassified_review').map(item=>item.path)},null,2));
