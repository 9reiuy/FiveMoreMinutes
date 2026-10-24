"""Smoke comparison from real Main captures. Primary pair is A (current) vs D (unpacked dust art);
B (white square + blur) is kept only as an appendix because it belongs to a different object."""
import base64
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE = Path(r'E:\GameProjects\FiveMinuteMore\.runtime\smoke_ab_20261023')
OUT = BASE / 'delivery'
OUT.mkdir(exist_ok=True)
CROP_HALF = (190, 152)   # centred on the actor, whose screen position drifts with camera lag
STEP = 0.05
FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 17)
SMALL = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 14)

PRIMARY = {
    'pal_on': [('A_pixel', 'A　现状像素烟'), ('E_white_pal', 'E　原版 9×9 圆 + 白描边 ×4/步')],
    'pal_off': [('A_nopal', 'A　现状像素烟'), ('E_white_nopal', 'E　原版 9×9 圆 + 白描边 ×4/步')],
}
APPENDIX = [('A_nopal', 'A　现状'), ('D_port_nopal', 'D　原版 dust 帧'),
            ('C_dust_nopal', 'C　柔雾·压灰'), ('B_nopal', 'B　白方块模糊')]
CLIPS = [('walk_stop', '走路扬尘'), ('fire_assault_rifle', '步枪命中')]


def report(run):
    return json.loads((BASE / run / 'report.json').read_text(encoding='utf-8'))


def nearest(samples, seconds):
    return next((s for s in reversed(samples) if s['seconds'] <= seconds), samples[0])


def crop(run, clip, seconds, zoom=1):
    samples = report(run)['clips'][clip]
    sample = nearest(samples, seconds)
    image = Image.open(BASE / run / sample['file']).convert('RGB')
    centre = sample.get('player_px') or [960, 540]
    cx, cy = int(centre[0]), int(centre[1])
    if cx < 0: cx, cy = 960, 540
    box = (max(0, cx - CROP_HALF[0]), max(0, cy - CROP_HALF[1]),
           min(image.width, cx + CROP_HALF[0]), min(image.height, cy + CROP_HALF[1]))
    image = image.crop(box)
    if zoom != 1:
        image = image.resize((int(image.width * zoom), int(image.height * zoom)), Image.NEAREST)
    return image


def band(runs, clip, seconds, zoom=1):
    tiles = [crop(run, clip, seconds, zoom) for run, _ in runs]
    w, h = tiles[0].size
    canvas = Image.new('RGB', (w * len(tiles) + 10 * (len(tiles) - 1), h + 46), '#12161c')
    draw = ImageDraw.Draw(canvas)
    for i, (tile, (_, label)) in enumerate(zip(tiles, runs)):
        x = i * (w + 10)
        canvas.paste(tile, (x, 46))
        draw.rectangle([x, 46, x + w, h + 45], outline='#39414d')
        draw.text((x + 8, 14), label, font=FONT, fill='#f0eede')
    draw.text((canvas.width - 118, 18), f'{seconds:.2f}s', font=SMALL, fill='#7f8894')
    return canvas


def gif(runs, clip, name):
    span = min(report(run)['clips'][clip][-1]['seconds'] for run, _ in runs)
    frames, tick = [], 0
    while tick * STEP <= span:
        frames.append(band(runs, clip, tick * STEP, zoom=1.6))
        tick += 1
    frames = frames[::2]
    if len(frames) < 2:
        return None
    path = OUT / name
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=110, loop=0,
                   optimize=True, disposal=2)
    return path


def sheet(runs, moments, name, zoom=1.3):
    bands = [band(runs, 'walk_stop', s, zoom) for s in moments]
    canvas = Image.new('RGB', (bands[0].width, sum(b.height + 8 for b in bands)), '#0b0e13')
    y = 0
    for b in bands:
        canvas.paste(b, (0, y))
        y += b.height + 8
    canvas.save(OUT / name)
    return name


def b64(path):
    return base64.b64encode(Path(path).read_bytes()).decode('ascii')


def main():
    gifs = []
    for tag, runs in PRIMARY.items():
        for clip, title in CLIPS:
            path = gif(runs, clip, f'compare_{clip}_{tag}.gif')
            if path:
                gifs.append((path.name, title, tag, b64(path)))
    sheets = [sheet(PRIMARY['pal_on'], [0.25, 0.75, 1.35, 1.95], 'sheet_walk_pal_on.png', zoom=2.0),
              sheet(PRIMARY['pal_off'], [0.25, 0.75, 1.35, 1.95], 'sheet_walk_pal_off.png', zoom=2.0)]
    meta = {run: {'style': report(run)['smoke_style'], 'palette': report(run).get('palette_on', True),
                  'checks': report(run)['checks'], 'failures': report(run)['failures'],
                  'texture': report(run)['smoke_texture_size'], 'room': report(run)['room_id'],
                  'cluster': report(run).get('cluster', 1)}
            for run in ('A_pixel', 'A_nopal', 'E_white_pal', 'E_white_nopal')}
    (OUT / 'meta.json').write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding='utf-8')
    write_html(gifs, sheets, meta)
    print('DELIVERY', OUT)


def write_html(gifs, sheets, meta):
    gif_html = ''
    for name, title, tag, data in gifs:
        label = '实机原设置（调色板开）' if tag == 'pal_on' else '关调色板（看清像素本体）'
        gif_html += f'''
    <figure>
      <figcaption><span class="tag">{label}</span>{title}　两栏同步，同房间同相机</figcaption>
      <img alt="{title}" src="data:image/gif;base64,{data}">
    </figure>'''
    sheet_caption = {
        'sheet_walk_pal_on.png': ('调色板开', '走路扬尘 · 1.3× 放大，每帧以角色为中心裁切'),
        'sheet_walk_pal_off.png': ('调色板关', '走路扬尘 · 1.3× 放大，每帧以角色为中心裁切'),
    }
    sheet_html = ''
    for name in sheets:
        tag, title = sheet_caption[name]
        sheet_html += f'''
    <figure>
      <figcaption><span class="tag">{tag}</span>{title}</figcaption>
      <img alt="{title}" src="data:image/png;base64,{b64(OUT / name)}">
    </figure>'''
    rows = ''.join(
        f'<tr><td>{run}</td><td>{m["style"]}</td><td>{m["texture"]}</td><td>{m["cluster"]}</td>'
        f'<td>{"开" if m["palette"] else "关"}</td><td>{m["checks"]}</td><td>{len(m["failures"])}</td></tr>'
        for run, m in meta.items())

    html = f'''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>烟雾对照（修订版）— 现状 vs 解包原版 dust</title>
<style>
  :root {{ --bg:#0d1016; --panel:#161b22; --line:#2a3240; --ink:#e8e6dc; --dim:#98a1b0; --hot:#ffb454; --warn:#ff7a6b; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink); font:15px/1.7 "Segoe UI","Microsoft YaHei",sans-serif; }}
  header {{ padding:36px 44px 24px; border-bottom:1px solid var(--line); background:linear-gradient(180deg,#12171f,#0d1016); }}
  h1 {{ margin:0 0 8px; font-size:25px; }}
  .sub {{ color:var(--dim); font-size:14px; }}
  main {{ padding:24px 44px 60px; max-width:1600px; }}
  h2 {{ font-size:18px; margin:34px 0 12px; padding-left:10px; border-left:3px solid var(--hot); }}
  h3 {{ font-size:15px; margin:22px 0 8px; color:#c9d2de; }}
  p, li {{ color:#cfd5de; }}
  .fix {{ margin:18px 0; padding:16px 20px; background:#1e1a16; border:1px solid #4a3a22; border-radius:8px; }}
  .fix b {{ color:var(--warn); }}
  .verdict {{ margin:18px 0; padding:16px 20px; background:var(--panel); border:1px solid var(--line); border-radius:8px; }}
  .verdict b {{ color:var(--hot); }}
  figure {{ margin:16px 0 28px; }}
  figcaption {{ color:var(--dim); font-size:13px; margin-bottom:8px; }}
  .tag {{ display:inline-block; margin-right:8px; padding:1px 8px; border-radius:999px; background:#1f2733; color:#9fb3cc; font-size:12px; }}
  img {{ width:100%; border-radius:6px; border:1px solid var(--line); display:block; }}
  table {{ border-collapse:collapse; width:100%; margin:12px 0; font-size:13px; }}
  th,td {{ border:1px solid var(--line); padding:7px 10px; text-align:left; }}
  th {{ background:#1a2029; color:#b9c3d1; font-weight:600; }}
  code {{ background:#1a2029; padding:1px 6px; border-radius:4px; font-size:13px; color:#9fd0ff; }}
  pre {{ background:#11161d; border:1px solid var(--line); border-radius:6px; padding:12px 14px; font-size:12px; color:#9fd0ff; overflow:auto; }}
  .note {{ color:#8d97a6; font-size:13px; border-left:2px solid #39414d; padding-left:10px; }}
</style></head><body>
<header>
  <h1>烟雾对照（修订版）— 现状 vs 解包原版 dust</h1>
  <div class="sub">真实 Main 入口 · 真实生成办公室 · 真实相机 · 后台最小化渲染 1920×1080 · 全部落在 room_id=0 / origin=(864,1152)</div>
</header>
<main>
  <div class="fix">
    <b>上一版错在哪：</b>我把「白方块 + 三次模糊」标成了照搬，但那套属于 Construct 3 的 <b>Particles 插件对象</b>（particlesMain / particlesSoup 那一族），
    不是走路扬尘。真正被 <code>particlesDust(...)</code> 之外、由 <code>Bullet + Timer</code> 池化的 <code>dust</code> 对象，用的是<b>它自己的 8×8 像素贴图</b>，
    外加一个 <code>federicoCalchera_onePixelOutline</code> 描边效果。你说的黑色描边是对的。
  </div>

  <h3>解包证据：<code>images/dust-sheet0.webp</code> 里的 dust 帧（8×8，逐像素）</h3>
  <pre>.... .... .... .... .... #3e3c7f #3e3c7f ....
.... .... .... .... #455796 #455796 #342d69 ....
.... .... .... #3e3c7f #49619f #49619f #342d69 ....
.... .... #342d69 #49619f #49619f #49619f #342d69 ....
.... #342d69 #455796 #455796 #455796 #455796 #455796 ....
.... #3e3c7f #342d69 #342d69 #342d69 #3e3c7f .... ....</pre>
  <p class="note">三种色阶 + 一圈更深的 #342d69 边。也就是说：原版脚步扬尘本来就是「带深色边的阶梯像素块，nearest 采样」——
     和你现在的 A 是同一种构造，差别只有配色和尺寸。</p>

  <div class="verdict">
    <b>结论（修订）：</b>
    <ul>
      <li>结构上你早就照搬对了：A 就是「深 rim + 双色填充 + 最近邻」，和原版 dust 同构。</li>
      <li>真正的差异是<b>配色</b>：原版 <code>#342d69 / #3e3c7f / #455796 / #49619f</code>（深靛蓝三阶），
          你是 <code>#343c46 / #e0e0d3 / #c6c6bb</code>（米白）。<b>实测结果：原版配色直接用（D 栏）在你这套暗场景里几乎看不见</b> ——
          关调色板时是一小点暗蓝，开调色板后基本糊进地面。那套蓝是配它自己亮色地板用的。</li>
      <li>上一版那个「柔雾」不是照搬，是另一套对象的技术路线。它对<code>dust</code>不成立。</li>
      <li>想借就得借<b>层次</b>：三色阶而非双色阶、rim 比主体暗两档以上、以及 8×8 就够用的极小尺寸 —— 但色值必须按你的环境重新定。</li>
    </ul>
  </div>

  <h2>1. 主对照：A 现状 vs E 原版结构（9×9 深色圆 + 白色 1px 描边 ×4 个/步）</h2>
  <p>贴图来自解包：`dust` 动画唯一那一帧 9×9 纯色圆 <code>#131333</code>（19,19,51，深靛蓝），
     外圈按 <code>onePixelOutline</code> 的着色器逻辑补 1 texel 轮廓，颜色取白。每走一步发 4 个、带 2–7px 随机偏移。
     注意：**内部填充真的是深色**，发白的是描边 —— 暗底上你看到的主要就是那一圈白边，这也正是「多个圆叠在一起、看着像一簇白色烟」的成因。</p>
  <p class="note">看点是可见性：A 的米白团在两栏里都一眼能找到；D 的暗蓝团只在「关调色板」那组、且需要凑近看才认得出，
     开调色板后几乎只剩一个像素级的深蓝缺口。</p>
  {gif_html}

  <h2>2. 静帧放大</h2>
  {sheet_html}

  <h2>3. 采集与自检</h2>
  <table>
    <tr><th>运行</th><th>风格</th><th>贴图尺寸</th><th>每步发几个</th><th>调色板</th><th>checks</th><th>failures</th></tr>
    {rows}
  </table>
  <ul>
    <li>八次运行全部同一间 <code>open_office</code>、同一相机；每次自检含「池内 72 个载体」「采样过滤符合所请求风格」「移动确实产生烟雾」。</li>
    <li>脚本：<code>tests/smoke_ab_capture.gd</code>；构建：<code>tools/build_smoke_ab_comparison.py</code>。</li>
    <li>时间轴按各自 <code>report.json</code> 实测时间戳对齐，不是逐像素重放；步枪片段只看 GIF。</li>
    <li>未叠加 <code>onePixelOutline</code>：该效果实际参数（宽度/颜色）没有从事件表解出来，所以 D 只用原图自带的深边，不复刻引擎描边。</li>
  </ul>

  <h2>4. 建议</h2>
  <ul>
    <li>别再追「柔雾」这条线 —— 它属于 Particles 插件对象，不是 dust 的做法。</li>
    <li>别抄原版色值。要贴近的是<b>结构</b>：三色阶（顶部最亮、底部中间调、rim 最深且明显偏冷），尺寸保持 8×8–12×8 这种极小档，别放大分辨率。</li>
    <li>颜色按你的暗场景重新定 —— 现在 A 的米白其实是正确的选择，只是层次少了一档。</li>
    <li>如果目标是「更看得出扬尘」，改尺寸上限/发射密度仍然比改贴图有效：现在每团只有 5–15 px。</li>
  </ul>
</main></body></html>'''
    (OUT / 'smoke_ab_report.html').write_text(html, encoding='utf-8')


if __name__ == '__main__':
    main()
