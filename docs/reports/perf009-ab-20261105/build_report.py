"""Build an offline comparison from measured JSON and untouched Camera PNGs."""
import base64
import html
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COLORS = {"A": "#91a6c4", "B": "#6dd6b3"}
LABELS = {"A": "原方案 · Compatibility", "B": "当前修复版 · Forward+"}


def esc(value):
    return html.escape(str(value))


def number(value, digits=2):
    return "—" if value is None else f"{value:,.{digits}f}"


def data_image(path):
    path = Path(path)
    if path.suffix.lower() != ".png":
        raise ValueError("Camera comparison must use the original PNG files")
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def change(a, b, lower=True):
    if not a:
        return "—"
    delta = (b - a) / a * 100
    good = delta <= 0 if lower else delta >= 0
    word = "减少" if delta < 0 else "增加"
    return f'<span class="{"good" if good else "warn"}">{word} {abs(delta):.1f}%</span>'


def bar_chart(data, metric, title, unit, threshold=None):
    groups = ["stationary", "movement", "combat_on"]
    labels = ["静止观察", "连续走动", "通电战斗"]
    values = [data["aggregate"][s][g][metric[0]].get(metric[1], 0)
              for g in groups for s in ["A", "B"]]
    top = max(values + ([threshold] if threshold else [0])) * 1.15
    top = max(top, 1)
    left, right, width, height = 120, 620, 760, 264
    scale = (right - left) / top
    parts = [f'<svg viewBox="0 0 {width} {height}" role="img" aria-label="{esc(title)}">',
             f'<title>{esc(title)}</title>']
    for i in range(5):
        x = left + (right-left) * i / 4
        value = top * i / 4
        parts += [f'<line x1="{x}" y1="25" x2="{x}" y2="225" class="grid"/>',
                  f'<text x="{x}" y="247" text-anchor="middle" class="axis">{value:.1f}</text>']
    if threshold:
        x = left + threshold * scale
        parts += [f'<line x1="{x}" y1="15" x2="{x}" y2="225" class="threshold"/>',
                  f'<text x="{x+5}" y="15" class="axis">60 帧预算</text>']
    for i, (group, label) in enumerate(zip(groups, labels)):
        y = 38 + i * 67
        parts.append(f'<text x="103" y="{y+24}" text-anchor="end" class="plotlabel">{label}</text>')
        for j, scheme in enumerate(["A", "B"]):
            value = data["aggregate"][scheme][group][metric[0]].get(metric[1], 0)
            yy = y + j * 23
            parts += [f'<rect x="{left}" y="{yy}" width="{value*scale:.2f}" height="17" rx="3" fill="{COLORS[scheme]}"/>',
                      f'<text x="{left+value*scale+7:.2f}" y="{yy+13}" class="plotlabel">{value:.2f} {unit}</text>']
    parts.append('</svg>')
    return ''.join(parts)


def tables(data):
    rows = []
    for group in ["all_live", "stationary", "movement", "combat_on", "power_off", "power_on"]:
        for scheme in ["A", "B"]:
            g = data["aggregate"][scheme][group]
            f = g["frame"]
            st = g["slow_streak"]["longest_by_frames"]
            rows.append('<tr>' + ''.join(f'<td>{x}</td>' for x in [
                esc(data["group_labels"][group]), f'<span class="tag {scheme}">{scheme}</span>',
                number(f.get("average_fps")), number(f.get("one_percent_low_fps")),
                number(f.get("p95_ms")), number(f.get("p99_ms")), number(f.get("max_ms")),
                str(f.get("over80", "—")), f'{st["frames"]} 帧 / {st["ms"]:.1f} ms',
            ]) + '</tr>')
    header = ['场景', '方案', '平均 FPS ↑', '1% Low ↑', 'P95 ms ↓', 'P99 ms ↓', '最慢 ms ↓', '>80ms 次数 ↓', '最长连续 >20ms']
    main = '<div class="scroll"><table><thead><tr>' + ''.join(f'<th>{h}</th>' for h in header) + '</tr></thead><tbody>' + ''.join(rows) + '</tbody></table></div>'
    costs = []
    for group in ["stationary", "movement", "combat_on"]:
        a, b = [data["aggregate"][s][group] for s in ["A", "B"]]
        for key, label in [("draw_span", "绘制阶段"), ("main_cpu", "主画面 CPU"),
                           ("main_gpu", "主画面 GPU"), ("mirror_cpu", "镜像 CPU"),
                           ("mirror_gpu", "镜像 GPU")]:
            av, bv = a[key].get("p50_ms"), b[key].get("p50_ms")
            costs.append(f'<tr><td>{esc(data["group_labels"][group])}</td><td>{label}</td><td>{number(av,3)}</td><td>{number(bv,3)}</td><td>{change(av,bv) if bv is not None else "—"}</td></tr>')
    detail = '<div class="scroll"><table><thead><tr><th>场景</th><th>耗时项目</th><th>A 中位 ms</th><th>B 中位 ms</th><th>B 相对 A</th></tr></thead><tbody>' + ''.join(costs) + '</tbody></table></div>'
    return main, detail


def run_table(data):
    rows = []
    for run in data["runs"]:
        f = run["groups"]["all_live"]["frame"]
        mem = run["memory_engine_allocations_peak"]
        full = run['all_after_reveal']['slow_streak']['longest_by_frames']
        rows.append('<tr>'+''.join(f'<td>{x}</td>' for x in [
            esc(run["id"]), number(f.get("average_fps")), number(f.get("p99_ms")),
            number(f.get("max_ms")), str(f.get("over80", "—")),
            number(run.get("cover_to_control_ms") / 1000 if run.get("cover_to_control_ms") is not None else None),
            number(mem.get("texture_bytes",0)/1048576,1), number(mem.get("buffer_bytes",0)/1048576,1),
            f'{full["frames"]} 帧 / {full["ms"]:.1f} ms',
            esc(', '.join(run["validation_notes"]) or '记录完整'),
        ])+'</tr>')
    headers = ['批次', '平均FPS', 'P99 ms', '最慢 ms', '>80ms', '遮挡至控制 s', '纹理分配 MiB', '缓冲分配 MiB', '揭幕后最长连续 >20ms', '记录检查']
    return '<div class="scroll"><table><thead><tr>'+''.join(f'<th>{h}</th>' for h in headers)+'</tr></thead><tbody>'+''.join(rows)+'</tbody></table></div>'


def visuals(data):
    sections = []
    for i, item in enumerate(data["manifest"]["visuals"]):
        a, b = data_image(item["A"]), data_image(item["B"])
        sections.append(f'''<section class="visual"><h3>{esc(item['title'])}</h3>
<p class="muted">{esc(item.get('caption',''))}</p>
<div class="pair"><figure><figcaption><b class="A">A</b> {LABELS['A']}</figcaption><img src="{a}" alt="{esc(item['title'])} 原方案"></figure>
<figure><figcaption><b class="B">B</b> {LABELS['B']}</figcaption><img src="{b}" alt="{esc(item['title'])} 当前修复版"></figure></div>
<details><summary>拖动查看同位置差异</summary><div class="wipe" id="wipe{i}"><img src="{a}" alt="A"><img src="{b}" class="above" alt="B"></div>
<label class="sliderlabel">A / B 分界 <input type="range" min="0" max="100" value="50" data-wipe="wipe{i}"></label></details></section>''')
    return ''.join(sections)


def main():
    data = json.loads((ROOT / 'comparison.json').read_text(encoding='utf-8'))
    m = data['manifest']
    main_table, costs = tables(data)
    notes = ''.join(f'<li>{esc(t)}</li>' for t in m['limits'])
    summary = ''.join(f'<p>{esc(t)}</p>' for t in m['summary'])
    proscons = []
    for s in ['A','B']:
        good = ''.join(f'<li>{esc(t)}</li>' for t in m['advantages'][s])
        bad = ''.join(f'<li>{esc(t)}</li>' for t in m['disadvantages'][s])
        proscons.append(f'<article class="panel"><h3><span class="tag {s}">{s}</span> {LABELS[s]}</h3><h4>优势</h4><ul>{good}</ul><h4>不足与风险</h4><ul>{bad}</ul></article>')
    evidence = ''.join(f'<li><a href="{Path(r["path"]).as_uri()}">{esc(r["id"])} 原始记录</a> · trace SHA256 <code>{r["trace_sha256"]}</code></li>' for r in data['runs'])
    text = f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>5MinMore · 两套渲染方案实测对比</title><style>
:root{{--bg:#10151d;--panel:#19212d;--line:#334054;--text:#e8edf5;--muted:#aab8cc;--a:{COLORS['A']};--b:{COLORS['B']}}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:16px/1.7 "Microsoft YaHei","Segoe UI",sans-serif}}main{{max-width:1420px;margin:auto;padding:42px 30px 70px}}h1{{font-size:34px;line-height:1.35;margin:8px 0 18px}}h2{{font-size:25px;margin:44px 0 16px}}h3{{font-size:19px;margin:0 0 8px}}h4{{margin:20px 0 5px}}p{{margin:10px 0}}.muted,.eyebrow{{color:var(--muted)}}.eyebrow{{font-size:13px;letter-spacing:.09em}}a{{color:#9ec9ff}}.intro{{max-width:1000px}}.panel,.visual{{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:22px;margin-top:16px}}.pair,.twocol{{display:grid;grid-template-columns:1fr 1fr;gap:18px}}figure{{margin:0}}figcaption{{margin-bottom:9px}}img{{width:100%;height:auto;display:block;image-rendering:pixelated}}.A{{color:var(--a)}}.B{{color:var(--b)}}.tag{{display:inline-flex;align-items:center;justify-content:center;width:26px;height:26px;border:1px solid currentColor;border-radius:6px;margin-right:7px;font-weight:bold}}.legend{{display:flex;gap:24px;flex-wrap:wrap;margin:16px 0}}.legend span::before{{content:"";display:inline-block;width:18px;height:12px;background:currentColor;margin-right:8px;border-radius:2px}}.scroll{{overflow-x:auto}}table{{border-collapse:collapse;width:100%;font-size:14px;white-space:nowrap}}th,td{{padding:12px 13px;border-bottom:1px solid var(--line);text-align:right}}th:first-child,td:first-child{{text-align:left}}th{{background:#202b3a;color:#b9c7da}}tbody tr:nth-child(2n){{background:#ffffff03}}.good{{color:var(--b)}}.warn{{color:#f4ba82}}ul{{padding-left:22px}}li{{margin:7px 0}}.plotlabel{{fill:var(--text);font:14px "Microsoft YaHei",sans-serif}}.axis{{fill:var(--muted);font:12px "Microsoft YaHei",sans-serif}}.grid{{stroke:#344053;stroke-width:1}}.threshold{{stroke:#e0b88d;stroke-width:1;stroke-dasharray:4 4}}svg{{display:block;width:100%;height:auto}}details{{margin-top:18px}}summary{{cursor:pointer;color:#b8d6ff}}.wipe{{position:relative;max-width:100%;margin-top:14px;--split:50%}}.wipe .above{{position:absolute;inset:0;clip-path:inset(0 0 0 var(--split))}}.sliderlabel{{display:flex;align-items:center;gap:20px;margin:12px 0}}input[type=range]{{flex:1;accent-color:var(--b)}}.callout{{border-left:3px solid var(--b);padding:6px 20px;background:#6dd6b30a}}code{{font:12px/1.5 Consolas,monospace;overflow-wrap:anywhere;white-space:normal}}.small{{font-size:13px;color:var(--muted)}}@media(max-width:850px){{main{{padding:24px 14px}}h1{{font-size:27px}}.pair,.twocol{{grid-template-columns:1fr}}.panel,.visual{{padding:15px}}}}@media print{{body{{background:white;color:#14191f}}main{{padding:0}}.panel,.visual{{background:white;border-color:#aaa;break-inside:avoid}}.muted,.small{{color:#555}}details{{display:none}}th{{background:#eee;color:#222}}td,th{{border-color:#ddd}}a{{color:#245f96}}}}
</style></head><body><main>
<div class="eyebrow">5MINMORE / 同场景实测 / {esc(m['date'])}</div><h1>两套渲染方案，画面与性能一起比较</h1>
<div class="intro">{summary}</div><div class="legend"><span class="A">{LABELS['A']}</span><span class="B">{LABELS['B']}</span></div>
<div class="callout">{esc(m['test_conditions'])}</div>
<p class="small">A 是同一小样的原 N3 Compatibility / OpenGL 方案；B 是用户认可的 R1 Forward+ / Vulkan 方案，包含八份局部修复及适配。比较的是这两套完整方案，不是只切换渲染器开关的单变量实验，也不是与删减灯光后的正式版本比较。</p>
<h2>帧率与卡顿</h2><p class="muted">相同的 60 FPS 上限。平均帧率看整体速度，1% Low 看最慢 1% 帧的体验；最慢帧和连续慢帧保留，不用平均数遮住尖峰。</p>
{main_table}<div class="twocol"><div class="panel"><h3>平均帧率 · 越高越好</h3>{bar_chart(data,('frame','average_fps'),'同场景平均帧率','FPS')}</div><div class="panel"><h3>绘制阶段中位耗时 · 越低越好</h3>{bar_chart(data,('draw_span','p50_ms'),'同场景绘制阶段耗时','ms')}</div></div>
<p class="small">绘制阶段包含引擎工作与等待，不能当成纯 GPU 时间，也不能用它的倒数冒充游戏 FPS。主画面及镜像的 CPU/GPU 数据是延迟统计，详表不相加。</p>
<details><summary>展开 CPU / GPU 成本明细</summary>{costs}</details>
<h2 id="visuals">同机位画面对比</h2><p class="muted">直接嵌入游戏 Camera 的原始 640×360 PNG，未调色、未锐化。三组主摄像头、人物位置及姿态完全匹配，截图回合与帧率计时分开；镜像摄像头的同步方式属于两套方案的实现差异。</p>{visuals(data)}
<h2>优势与不足</h2><div class="twocol">{''.join(proscons)}</div>
<p class="small">硬件范围及基础开销的说明来自 <a href="https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html">Godot 4.7 渲染器文档</a>；本机的具体优势以本页实测为准，不能推广为所有设备上同样的提升。</p>
<h2>启动等待、资源与每轮结果</h2>{run_table(data)}
<p class="small">纹理/缓冲是引擎分配计数，不等于整机实际显存或进程总内存。没有进行运行全过程的成对功率测量，启停快照也包含后台负载，所以耗时下降不能写成节电百分比。首用准备和驱动缓存的限制见 <a href="https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html">Godot 管线编译说明</a>。</p>
<h2>结论的适用范围</h2><ul>{notes}</ul>
<details><summary>统计定义与原始证据</summary><p>平均 FPS = 1000 × 采样间隔数 / 间隔总毫秒数。1% Low = 1000 / 最慢 ceil(帧数 × 1%) 帧的平均毫秒数。P95/P99 使用最近秩百分位；严格大于80ms才计尖峰。表中汇总相同 live_* 测量段，加载/准备单列，揭幕后全部帧的独立记录见 JSON。连续慢段不跨接跳过的阶段或不同轮次。帧数和测量时长随实际运行速度不同，未强行删齐样本。</p><ul>{evidence}</ul><p><a href="comparison.json">完整复算 JSON</a> · <a href="comparison_manifest.json">输入、版本与图片清单</a> · <a href="visual_audit.json">画面与恢复核验</a></p></details>
<p class="small">仅同一独立小样；没有替换正式游戏。所有测试以当前冻结版本为准。</p>
</main><script>document.querySelectorAll('[data-wipe]').forEach(el=>el.addEventListener('input',()=>document.getElementById(el.dataset.wipe).style.setProperty('--split',el.value+'%')));</script></body></html>'''
    (ROOT/'index.html').write_text(text, encoding='utf-8')
    print('Wrote', ROOT/'index.html', 'bytes', len(text.encode('utf-8')))
    preview_pairs = []
    for item in m['visuals']:
        preview_pairs.append('<section><h2>'+esc(item['title'])+'</h2><p>'+esc(item['caption'])+'</p><div class="pair">'+''.join(
            f'<figure><figcaption>{s} · {LABELS[s]}</figcaption><img src="{data_image(item[s])}" alt="{s}"></figure>' for s in ['A','B'])+'</div></section>')
    preview = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>5MinMore 同机位画面对比</title><style>
*{box-sizing:border-box}body{margin:0;background:#10151d;color:#e8edf5;font:16px/1.6 "Microsoft YaHei",sans-serif}main{width:1384px;margin:auto;padding:24px 28px}h1{margin:0;font-size:27px}header p{margin:5px 0 15px;color:#aab8cc}section{padding:14px 15px 18px;background:#19212d;border:1px solid #334054;border-radius:10px;margin:14px 0}h2{margin:0;font-size:20px}section p{margin:5px 0 9px;color:#aab8cc;font-size:14px}.pair{display:grid;grid-template-columns:640px 640px;gap:16px}figure{margin:0}figcaption{margin-bottom:6px;font-size:14px}figure:first-child figcaption{color:#91a6c4}figure:last-child figcaption{color:#6dd6b3}img{width:640px;height:360px;display:block;image-rendering:pixelated}
</style><main><header><h1>5MinMore · 同机位画面对比</h1><p>左：原 N3 Compatibility　｜　右：当前 R1 Forward+　｜　实际 Camera 原图，人物与场景匹配</p></header>'''+''.join(preview_pairs)+'</main></html>'
    (ROOT/'comparison-preview.html').write_text(preview, encoding='utf-8')


if __name__ == '__main__':
    main()
