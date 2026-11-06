"""Build the final local R2 review from raw Camera PNGs and verified records."""
import base64
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def esc(value):
    return html.escape(str(value))


def image_data(path):
    path = Path(path)
    if path.suffix.lower() != '.png':
        raise ValueError('Use original runtime PNG evidence')
    return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode('ascii')


def table(headers, rows):
    return '<div class="table-wrap"><table><thead><tr>' + ''.join('<th>' + esc(x) + '</th>' for x in headers) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td>' + esc(x) + '</td>' for x in row) + '</tr>' for row in rows) + '</tbody></table></div>'


def main():
    data = json.loads((ROOT / 'review.json').read_text(encoding='utf-8'))
    scene_data = [{**scene, 'images': {key: image_data(path) for key, path in scene['images'].items()}} for scene in data['scenes']]
    scenes = ''.join(f'<button type="button" data-scene="{i}" aria-pressed="{str(i == 0).lower()}">{esc(s["name"])}</button>' for i, s in enumerate(scene_data))
    statuses = ''.join(f'<li><strong>{esc(row["item"])}</strong>：{esc(row["result"])}</li>' for row in data['status'])
    changes = ''.join('<li>' + esc(x) + '</li>' for x in data['changes'])
    notes = ''.join('<li>' + esc(x) + '</li>' for x in data['limits'])
    evidence = ''.join(f'<li><a href="{Path(row["path"]).as_uri()}">{esc(row["label"])}</a></li>' for row in data['evidence'])
    metrics = table(data['performance']['headers'], data['performance']['rows'])
    contrast = table(data['contrast']['headers'], data['contrast']['rows'])
    payload = json.dumps(scene_data, ensure_ascii=False).replace('<', '\\u003c')
    text = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>5MinMore · 中央顶灯与渲染修复复核</title><style>
:root{color-scheme:dark;--bg:#10151d;--panel:#19212d;--border:#334054;--text:#e8edf5;--muted:#acbbce;--accent:#6dd6b3}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.75 "Microsoft YaHei","Segoe UI",sans-serif}main{max-width:1380px;margin:auto;padding:32px 26px 64px}h1{font-size:30px;line-height:1.4;margin:8px 0 18px}h2{font-size:23px;margin:32px 0 12px}p{margin:10px 0}.muted,small{color:var(--muted)}a{color:#a8cdff}.panel{background:var(--panel);border:1px solid var(--border);border-radius:10px;padding:18px;margin:15px 0}.controls{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}button{border:1px solid #52637b;background:#202c3c;border-radius:6px;color:var(--text);padding:8px 13px;font:inherit;cursor:pointer}button[aria-pressed=true]{border-color:var(--accent);background:#204337}.viewport{overflow:auto;max-width:100%;background:#080b11;border:1px solid var(--border)}#camera{display:block;width:640px;height:360px;max-width:none;image-rendering:pixelated}.caption{min-height:48px}.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%;font-size:14px;white-space:nowrap}td,th{padding:10px 13px;text-align:right;border-bottom:1px solid var(--border)}td:first-child,th:first-child{text-align:left}th{background:#202c3c}li{margin:7px 0}ul{padding-left:24px}.callout{padding:10px 17px;border-left:3px solid var(--accent);background:#6dd6b30a}details{margin-top:24px}summary{cursor:pointer;color:#a8cdff}@media(max-width:700px){main{padding:20px 14px}h1{font-size:25px}.panel{padding:12px}}
</style></head><body><main>'''
    text += f'<div class="muted">5MINMORE / 顾问统一复核 / {esc(data["date"])}</div><h1>室内照明、摩尔纹与特效颜色修复</h1><p class="callout">{esc(data["summary"])}</p><ul>{statuses}</ul>'
    text += f'<p>仍使用同一个 <a href="{Path(data["entry"]).as_uri()}">试玩入口</a>。{esc(data["integration"])}</p><h2>实际 Camera 对照</h2><div class="panel"><p class="muted">A 是旧 Compatibility 参照，B0 是早期 Forward+ 修复版，本次候选为中央顶灯版。最新目标是每房整体够亮；A 的强亮斑不再是验收目标。图片原始字节未修改；使用整数倍查看，窄窗口可横向滚动，避免非整数缩放制造额外干涉。</p><div class="controls">{scenes}</div><div class="controls" id="variants"><button type="button" data-variant="A" aria-pressed="false">A · 原方案</button><button type="button" data-variant="B0" aria-pressed="false">B0 · 修改前</button><button type="button" data-variant="C" aria-pressed="true">修复后</button></div><div class="controls"><button type="button" data-zoom="1" aria-pressed="true">原始 1 倍</button><button type="button" data-zoom="2" aria-pressed="false">整数 2 倍</button></div><p id="picture-label" class="muted"></p><div class="viewport"><img id="camera" width="640" height="360" alt="实际游戏 Camera 原图"></div><p id="caption" class="caption"></p></div>'
    text += f'<h2>固定位置亮度参考</h2>{contrast}<p class="muted">固定同机位小区域的 RGB8 编码亮度，只辅助判断画面层次，不代表物理光能，也不是逐像素一致的保证。中央顶灯需要覆盖整间房，旧亮斑与阴影区域的差值减小是本次布局的预期变化；墙体、家具遮挡和建筑内外仍保留层次。</p>'
    text += f'<h2>本轮性能回归</h2><p>{esc(data["performance"]["conditions"])}</p>{metrics}<p class="muted">{esc(data["performance"]["interpretation"])}</p><h2>本轮修改</h2><ul>{changes}</ul><h2>仍有的限制</h2><ul>{notes}</ul><details><summary>原始图像、动态证据和记录</summary><ul>{evidence}</ul><p><a href="review.json">复核清单</a></p></details>'
    text += '</main><script>const scenes=' + payload + ''';
let sceneIndex=0,variant='C',zoom=1;
const names={A:'A · 原方案',B0:'B0 · 修改前',C:'本次修复后'};
function render(){const s=scenes[sceneIndex],im=document.getElementById('camera');im.src=s.images[variant];im.style.width=(640*zoom)+'px';im.style.height=(360*zoom)+'px';im.alt=s.name+' '+names[variant];document.getElementById('picture-label').textContent=s.name+' / '+names[variant]+' / '+zoom+'倍';document.getElementById('caption').textContent=s.caption;document.querySelectorAll('[data-scene]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.scene)===sceneIndex)));document.querySelectorAll('[data-variant]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.variant===variant)));document.querySelectorAll('[data-zoom]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.zoom)===zoom)));}
document.querySelectorAll('[data-scene]').forEach(b=>b.addEventListener('click',()=>{sceneIndex=Number(b.dataset.scene);render();}));document.querySelectorAll('[data-variant]').forEach(b=>b.addEventListener('click',()=>{variant=b.dataset.variant;render();}));document.querySelectorAll('[data-zoom]').forEach(b=>b.addEventListener('click',()=>{zoom=Number(b.dataset.zoom);render();}));render();
</script></body></html>'''
    (ROOT / 'index.html').write_text(text, encoding='utf-8')
    print('Wrote review with', len(scene_data), 'matched Camera scenes')


if __name__ == '__main__':
    main()
