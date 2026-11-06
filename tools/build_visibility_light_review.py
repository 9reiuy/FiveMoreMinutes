"""Build a local review from unmodified main-Camera captures and raw metrics."""
from pathlib import Path
import html
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".runtime/hellkind_purple_sample_20261103/volume_shadow_revision"


def build():
    result = json.loads((OUT / "result.json").read_text(encoding="utf-8-sig"))
    perf_path = OUT / "performance/summary.json"
    perf = json.loads(perf_path.read_text(encoding="utf-8-sig")) if perf_path.exists() else None
    status = "尚未完成性能测试"
    rows = []
    names = {"on_stationary": "视野光源 · 静止", "on_navigation": "视野光源 · 四房间移动", "on_doors": "视野光源 · 门开合", "off_native_mixed": "关闭遮挡 · 混合战斗", "on_mixed": "视野光源 · 混合战斗"}
    if perf:
        status = "本轮帧时间通过" if perf["passed"] else "稳定 60 帧尚未通过"
        for phase in perf["phases"]:
            if phase["label"] not in names:
                continue
            stat = phase["summary"]["all_sampled"]
            rows.append("<tr><td>" + names[phase["label"]] + "</td>" + "".join(f"<td>{html.escape(str(stat.get(key, '—')))}</td>" for key in ["frames", "p50_ms", "p95_ms", "p99_ms", "max_ms", "over_16_667"]) + "</tr>")
        audit_path = sorted(OUT.glob("Performance-*.audit.json"))[-1]
        audit = json.loads(audit_path.read_text(encoding="utf-8-sig"))
        log_name = audit_path.name.replace(".audit.json", ".stderr.txt")
        markdown_rows = ["| 负载 | 帧数 | P50 ms | P95 ms | P99 ms | 最大 ms | 超预算帧 |", "|---|---:|---:|---:|---:|---:|---:|"]
        for phase in perf["phases"]:
            if phase["label"] not in names:
                continue
            stat = phase["summary"]["all_sampled"]
            markdown_rows.append("| " + names[phase["label"]] + " | " + " | ".join(str(stat[key]) for key in ["frames", "p50_ms", "p95_ms", "p99_ms", "max_ms", "over_16_667"]) + " |")
        block = "\n**稳定 60 帧未通过。** 每帧门槛为 16.667 ms，保留全部尖峰。\n\n" + "\n".join(markdown_rows)
        block += "\n\n最终混合负载中，视野数据更新 CPU 峰值为 **1.454 ms**，与整帧耗时分别记录。原生碎片生成仍单独耗时约 17.5–24 ms；关闭视野遮挡的战斗对照也超出帧预算。这是已定位的一项瓶颈，不代表已解释全部尖峰。\n\n"
        block += f"本轮核对了 {audit['source_files']} 个共享源文件，运行期间未发生源码变更。四房间实际采样房间号为 3、0、1、2。正常功能重建日志为空；**混合战斗之后的重建/退出仍触发引擎灯光索引清理错误**，压力生命周期未通过。\n\n"
        block += f"[完整帧数据汇总](../../.runtime/hellkind_purple_sample_20261103/volume_shadow_revision/performance/summary.json) · [本轮源码核对](../../.runtime/hellkind_purple_sample_20261103/volume_shadow_revision/{audit_path.name}) · [压力测试错误日志](../../.runtime/hellkind_purple_sample_20261103/volume_shadow_revision/{log_name})。\n"
        report_path = ROOT / "docs/reports/player-visibility-light-20261104.md"
        report = report_path.read_text(encoding="utf-8")
        start, remainder = report.split("<!-- PERFORMANCE -->", 1)
        _, end = remainder.split("<!-- /PERFORMANCE -->", 1)
        report_path.write_text(start + "<!-- PERFORMANCE -->" + block + "<!-- /PERFORMANCE -->" + end, encoding="utf-8")
    checks = result["checks"]
    passed = checks - len(result["failures"])
    text = """<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>视野光源 · 实机对照</title><style>
*{box-sizing:border-box}body{margin:0;background:#10101a;color:#e6e2fa;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1100px;margin:auto;padding:38px 24px 64px}h1{font-size:38px;line-height:1.25;margin:12px 0}h2{margin-top:42px}p{color:#bcb7d4;max-width:900px}.tag{color:#bb9fff;font-size:13px;letter-spacing:.1em}.badges{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}.badge,button{background:#242033;border:1px solid #4a3a64;border-radius:7px;color:inherit;padding:8px 14px}button{cursor:pointer}button.active{background:#6547b5}.compare{position:relative;aspect-ratio:16/9;background:#000;overflow:hidden}.compare img{width:100%;height:100%;position:absolute;image-rendering:pixelated}.compare .after{clip-path:inset(0 0 0 50%)}.label{position:absolute;top:12px;background:#000a;padding:3px 9px;font-size:13px}.left{left:12px}.right{right:12px}.divider{position:absolute;left:50%;height:100%;border-left:2px solid white;pointer-events:none}input{width:100%;accent-color:#b08afc}nav{display:flex;gap:8px;margin:16px 0}img.camera{width:100%;image-rendering:pixelated;background:#000}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}.card{background:#191725;border:1px solid #332d49;padding:14px;border-radius:10px}table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:right;padding:9px;border-bottom:1px solid #342b46}th:first-child,td:first-child{text-align:left}a{color:#bd9aff}small{color:#9993b0}.status{color:#ffbd80}.tablewrap{overflow:auto}@media(max-width:700px){.grid{grid-template-columns:1fr}h1{font-size:28px}main{padding:24px 14px}}
</style><main><div class="tag">FIVE MINUTE MORE / 独立小样</div><h1>让整片墙体共同决定视野</h1>
<p>玩家的位置作为一个视野光源。静态墙体合成完整遮挡几何，由同一张三维深度阴影图判断哪里可见；门叶、墙侧、转角和真实洞口都参与。原有场景灯光照常工作。</p>
<div class="badges"><span class="badge">640 × 360</span><span class="badge">完整约 32 像素人物</span><span class="badge">浓紫 + 橙血</span><span class="badge">功能 __CHECKS__</span></div>
<nav id="rooms"></nav><div class="compare"><img id="off" src="room_0_off.png" alt="关闭视野遮挡"><img class="after" id="on" src="room_0_volume.png" alt="开启三维视野光源"><span class="label left">关闭遮挡</span><span class="label right">三维视野光源</span><div class="divider"></div></div>
<input id="split" type="range" min="0" max="100" value="50" aria-label="拖动比较遮挡开关"><small>同一个实际游戏镜头。图片未经修图；网页按最近邻放大原始 640×360 画面。</small>
<h2>移动、门与破墙</h2><div class="grid"><div class="card"><img class="camera" id="walk" src="walk_00.png" alt="实际行走帧"><p>实际按键行走的连续 12 帧。移动光源时不重建静态墙体。</p></div><div class="card"><img class="camera" src="after_breach_volume.png" alt="真实破墙之后"><p>破墙改变真实拓扑后，统一遮挡几何更新，洞口后方随即可见。</p></div></div>
<h2>橙血与墙后隐藏</h2><div class="grid"><div class="card"><img class="camera" src="behind_wall_blood_off.png" alt="关闭遮挡的橙血"><p>关闭遮挡，可以看到真实生成在墙后的血迹。</p></div><div class="card"><img class="camera" src="behind_wall_blood_volume.png" alt="开启遮挡的橙血"><p>开启遮挡，墙后血迹被覆盖，玩家眼前的血迹保持橙色。</p></div></div>
<h2>验证范围</h2><p>四房间 768 个采样点与独立三角形视线判定一致；包含墙的各个面、窗台高度、门转动、原生破墙、行走和重建退出。测试不增加人物覆盖层。</p>
<p class="status">__STATUS__</p><div class="tablewrap"><table><thead><tr><th>负载</th><th>帧数</th><th>P50 ms</th><th>P95 ms</th><th>P99 ms</th><th>最大 ms</th><th>超 16.667 ms</th></tr></thead><tbody>__ROWS__</tbody></table></div>
<p>性能记录包含所有采样尖峰，未把平均帧率当作稳定 60 帧。仅针对本机独立四房间小样，不代表正式游戏验收。混合战斗后的重建/退出仍有引擎灯光索引清理报错，压力生命周期也未通过。</p><p><a href="result.json">功能原始结果</a> · <a href="performance/summary.json">性能原始结果</a></p>
<p>启动：工程根目录 <strong>Run_Visibility_Light_Sample.cmd</strong>。WASD 移动，F9 开关遮挡，F2 换房，F1 说明。</p>
</main><script>const off=document.getElementById('off'),on=document.getElementById('on');for(let i=0;i<4;i++){const b=document.createElement('button');b.textContent='房间 '+(i+1);b.className=i===0?'active':'';b.onclick=()=>{off.src='room_'+i+'_off.png';on.src='room_'+i+'_volume.png';document.querySelectorAll('nav button').forEach(x=>x.className='');b.className='active'};document.getElementById('rooms').appendChild(b)}document.getElementById('split').oninput=e=>{on.style.clipPath='inset(0 0 0 '+e.target.value+'%)';document.querySelector('.divider').style.left=e.target.value+'%'};let frame=0;setInterval(()=>{frame=(frame+1)%12;document.getElementById('walk').src='walk_'+String(frame).padStart(2,'0')+'.png'},180);</script></html>"""
    text = text.replace("__CHECKS__", f"{passed}/{checks}").replace("__STATUS__", status).replace("__ROWS__", "".join(rows))
    (OUT / "review.html").write_text(text, encoding="utf-8")
    print(OUT / "review.html")


if __name__ == "__main__":
    build()
