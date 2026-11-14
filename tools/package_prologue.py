"""Bundle the verified six-level Windows export with instructions and notices."""
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / "build/Prologue_0-1_0-6_Windows"
evidence = root / ".runtime/prologue_export_20261111"
assert (folder / "FiveMinuteMore_Prologue.exe").is_file()
assert (folder / "FiveMinuteMore_Prologue.pck").is_file()
readme = """再多五分钟 · 序章试玩（Windows 64 位）
2026-11-11 光效修正版

开始游玩
1. 把整个压缩包解压到一个文件夹。
2. 双击 FiveMinuteMore_Prologue.exe。
3. EXE 和 PCK 必须放在同一文件夹；无需安装 Godot 或下载工程。

包含的关卡
0-1 维修通道 → 0-2 地下车库 → 0-3 仓储区 → 0-4 地下通道
→ 0-5 下港站台 → 0-6 末班列车、列车 Boss 战与最终到站。
各区域清敌后才可前往下一关；连接处为单向通行，旧区域会卸载。
0-5 清敌后等待下一辆车，只有尾部的门可上车。
0-6 通关后可选择“再玩一次”或“退出试玩”。

操作
WASD / 方向键：移动        鼠标：瞄准
鼠标左键：攻击            鼠标右键：投掷手中武器
E：拾取 / 替换附近武器    R：换弹（死亡后重试）
空格：翻滚                Shift：冲刺
F：踢击                   T：切换慢动作
Esc：暂停 / 设置 / 退出试玩
F5：重新开始整个序章（回到 0-1）
0-1 开场只有海报；先处理第一个敌人，再拾取武器继续战斗。

画面与系统
Windows 10 / 11 64 位；显卡和驱动需支持 Vulkan。
使用 Forward+ / Vulkan，默认原生窗口渲染，未启用全屏像素化。
已接入正式游戏的灯管光晕、灯下立体薄雾与随光源显现的镜头污渍。
默认窗口 1280×720，保留角色像素画和最近邻材质采样。
按 Esc 可调整音量、阴影及相关设置。未进行其他电脑的性能认证。
设置单独保存在 %APPDATA%\\FiveMinuteMorePrologue，不影响正式工程的设置。
这是六关独立试玩版；退出后再次启动从 0-1 开始，没有关卡进度存档。

资源与许可
请保留 Licenses 文件夹及 AssetAttributions.txt。
引擎、字体和第三方资源许可见随包文件；游戏角色与其他项目资源不随引擎许可授权。
"""
(folder / "游玩说明.txt").write_text(readme, encoding="utf-8-sig")
licenses = folder / "Licenses"
licenses.mkdir(exist_ok=True)
shutil.copy2(evidence / "Godot-LICENSES.txt", licenses / "Godot-LICENSES.txt")
for source, name in [
    ("assets/fonts/boutique_bitmap/OFL-9x9.txt", "BoutiqueBitmap9x9-OFL.txt"),
    ("assets/fonts/boutique_bitmap/OFL-7x7.txt", "BoutiqueBitmap7x7-OFL.txt"),
    ("assets/fonts/fusion_pixel/OFL.txt", "FusionPixel-OFL.txt"),
    ("art/Dream/office_lowpoly/kenney/License.txt", "Kenney-Furniture.txt"),
    ("art/preview/screen_wall/cc0/Kenney-LICENSE.txt", "Kenney-ScreenWall.txt"),
    ("art/Dream/ReceptionLobby/keith333_red_carpet/ATTRIBUTION.txt", "RedCarpet-Attribution.txt"),
]:
    shutil.copy2(root / source, licenses / name)
shutil.copy2(root / "data/asset_attributions.txt", folder / "AssetAttributions.txt")
manifest = {"name": "FiveMinuteMore Prologue", "build": "2026-11-11-optics", "platform": "Windows x86_64",
            "renderer": "Forward+ / Vulkan", "levels": [f"0-{i}" for i in range(1, 7)], "files": {}}
for file in sorted(folder.rglob("*")):
    if file.is_file() and file.name != "BuildManifest.json":
        assert file.suffix.lower() not in {".tmp", ".log", ".cfg"}, f"Unexpected development/test file: {file}"
        manifest["files"][file.relative_to(folder).as_posix()] = {"bytes": file.stat().st_size, "sha256": hashlib.sha256(file.read_bytes()).hexdigest()}
(folder / "BuildManifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
archive = root / "build/FiveMinuteMore_Prologue_0-1_0-6_Windows_x64_Optics.zip"
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    for file in sorted(folder.rglob("*")):
        if file.is_file():
            bundle.write(file, folder.name + "/" + file.relative_to(folder).as_posix())
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None, "ZIP integrity check failed"
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(".zip.sha256.txt").write_text(digest + "  " + archive.name + "\n", encoding="ascii")
print(json.dumps({"archive": str(archive), "zip_bytes": archive.stat().st_size, "unpacked_bytes": sum(v["bytes"] for v in manifest["files"].values()), "sha256": digest}, ensure_ascii=False))
