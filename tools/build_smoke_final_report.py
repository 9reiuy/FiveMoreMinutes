"""Final self-contained report for the two smoke systems."""
import base64
from pathlib import Path

BASE = Path(r'E:\GameProjects\FiveMinuteMore\.runtime\smoke_ab_20261023')
OUT = BASE / 'delivery'


def b64(path):
    return base64.b64encode(Path(path).read_bytes()).decode('ascii')


def figure(name, tag, caption, kind='png'):
    return f'''
  <figure>
    <figcaption><span class="tag">{tag}</span>{caption}</figcaption>
    <img alt="{caption}" src="data:image/{kind};base64,{b64(OUT / name)}">
  </figure>'''


def main():
    walk_gif = figure('gif_prod_pal.gif', '动态', '走路烟尘：改版前 vs 现在（默认调色板）', 'gif')
    walk_sheet = figure('sheet_prod_pal.png', '静帧', '走路烟尘：同一房间同一相机，前后对照')
    muzzle = figure('muzzle_scatter.png', '序列', '枪口烟：0.60s → 0.89s，沿弹道散开、非共线')

    html = f'''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>烟雾系统改造报告 — 走路扬尘 + 枪口烟</title>
<style>
  :root {{ --bg:#0a0d11; --panel:#141a21; --line:#242d38; --ink:#e9e7dd; --dim:#8d97a6; --hot:#ffb454; --cool:#9fb3cc; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink); font:15px/1.75 "Segoe UI","Microsoft YaHei",sans-serif; }}
  header {{ padding:38px 44px 26px; border-bottom:1px solid var(--line); background:linear-gradient(180deg,#10161d,#0a0d11); }}
  h1 {{ margin:0 0 8px; font-size:26px; letter-spacing:.4px; }}
  .sub {{ color:var(--dim); font-size:14px; }}
  main {{ padding:26px 44px 70px; max-width:1560px; }}
  h2 {{ font-size:18px; margin:36px 0 12px; padding-left:10px; border-left:3px solid var(--hot); }}
  h3 {{ font-size:15px; margin:22px 0 8px; color:#c6d0dc; }}
  p, li {{ color:#cfd5de; }}
  table {{ border-collapse:collapse; width:100%; margin:14px 0; font-size:13.5px; }}
  th,td {{ border:1px solid var(--line); padding:8px 11px; text-align:left; vertical-align:top; }}
  th {{ background:#1a222c; color:#b9c3d1; font-weight:600; }}
  code {{ background:#1a222c; padding:1px 6px; border-radius:4px; font-size:13px; color:#9fd0ff; }}
  figure {{ margin:16px 0 30px; }}
  figcaption {{ color:var(--dim); font-size:13px; margin-bottom:8px; }}
  .tag {{ display:inline-block; margin-right:8px; padding:1px 8px; border-radius:999px; background:#1f2a36; color:var(--cool); font-size:12px; }}
  img {{ width:100%; border-radius:6px; border:1px solid var(--line); display:block; }}
  .box {{ margin:18px 0; padding:16px 20px; background:var(--panel); border:1px solid var(--line); border-radius:8px; }}
  .warn {{ border-color:#4a3a22; background:#1e1a16; }}
  .warn b {{ color:#ff9d6b; }}
  .ok b {{ color:#8fd6a0; }}
</style></head><body>
<header>
  <h1>烟雾系统改造报告 — 走路扬尘 + 枪口烟</h1>
  <div class="sub">Five Minutes More · 全部数据来自真实 Main 入口 · 真实生成办公室 · 后台最小化渲染 1920×1080</div>
</header>
<main>

  <div class="box ok">
    <b>一句话结论：</b>走路扬尘已换成与原版同构的「多圆合并云团 + 一像素描边」；枪口烟按原版结构做成
    <b>沿弹道散开的暗色暖调云团</b>，并通过色板语义分支保住了它在 16 色冷色板下的颜色。
  </div>

  <h2>1. 走路扬尘</h2>
  <p>原版解包的 <code>dust</code> 对象有 21 个动画，走路用的是 <code>walk</code>：13×13 画布里一个 11×9 阶梯圆，
     全部像素同一个色 <code>#D9CCBF</code>，贴图里没有描边 —— 黑边来自图层效果的 <code>onePixelOutline</code>。
     所以我们改用<b>三圆合并、只对并集描一圈边的云团</b>，6 个变体随机取，每步 2 团，0.12 秒长到满，45% 后淡出。</p>
  {walk_gif}
  {walk_sheet}

  <h2>2. 枪口烟</h2>
  <p>按你给的实机效果重做：不是枪口一个点爆开，而是<b>沿弹道铺开</b>；云团大小不齐、间距不均、整条有蜿蜒和扇形散开。
     颜色走「橙 → 暗绛 → 灰梅 → 暗紫 → 近墨」，随时间冷却。</p>
  {muzzle}

  <h3>怎么破的「同一行」</h3>
  <ul>
    <li>每次开火掷一个随机相位 <code>0..2π</code> 和频率 <code>2.2–3.4</code>，横向偏移按正弦走 → 整条蛇行</li>
    <li>每颗云团各自从枪口方向偏转 <code>±0.06–0.13</code> 弧度 → 散成松锥形，且速度方向也各自不同</li>
    <li>间距抖动 <code>±0.16</code>、18–30% 概率跳过中间某团、尺寸再乘 <code>0.80–1.25</code> 随机</li>
  </ul>

  <h2>3. 色板语义分支（关键）</h2>
  <p>项目默认开启 16 色<b>纯冷色</b>色板（<code>#05060A</code> → <code>#EDF2FF</code>，一个暖色都没有），
     任何橙红紫都会被量化成蓝色 —— 实测枪口区域暖色像素为 <b>0</b>。照项目里「血」「敌人蓄力」的既有做法，
     给色板加了 5 个保留标记色（纯红 + 蓝通道 0.02×k），shader 认出后直接输出指定暖色。加完后暖色像素峰值 <b>1827</b>。</p>
  <table>
    <tr><th>档</th><th>输出色</th><th>观感</th></tr>
    <tr><td>1</td><td><code>#A65E28</code></td><td>橙（枪口刚出）</td></tr>
    <tr><td>2</td><td><code>#6E2A2E</code></td><td>暗绛</td></tr>
    <tr><td>3</td><td><code>#5A2B44</code></td><td>灰梅</td></tr>
    <tr><td>4</td><td><code>#432A52</code></td><td>暗紫</td></tr>
    <tr><td>5</td><td><code>#2E2836</code></td><td>近墨（溶进暗部）</td></tr>
  </table>

  <h2>4. 改动清单</h2>
  <table>
    <tr><th>文件</th><th>改动</th></tr>
    <tr><td><code>assets/art/vfx/smoke_cluster/cluster_0..5.png</code></td><td>新增：走路用合并云团（<code>#D0D9EF</code> 填充 + <code>#131333</code> 边）</td></tr>
    <tr><td><code>assets/art/vfx/muzzle_smoke/puff_0..5.png</code></td><td>新增：枪口用白填充云团（供 modulate 上色）</td></tr>
    <tr><td><code>scripts/dream/nyangeon_footstep_smoke.gd</code></td><td>默认 <code>cluster=2</code>、<code>grow_time=.12</code>、<code>fade_start=.45</code>、<code>pixel_size=1/28</code>、装载 6 变体</td></tr>
    <tr><td><code>scripts/dream/muzzle_smoke.gd</code></td><td>新增：枪口烟池（48 个 Sprite3D），沿弹道散开 + 标记色驱动</td></tr>
    <tr><td><code>scripts/dream/dream_3d_random_dungeon.gd</code></td><td><code>spawn_weapon_muzzle()</code> 内挂 <code>_muzzle_smoke().burst(...)</code>（仅像素战斗 VFX 路径）</td></tr>
    <tr><td><code>shaders/palette_quantize.gdshader</code></td><td>新增枪口烟语义分支（5 标记 → 5 暗化暖色输出）</td></tr>
    <tr><td><code>tests/smoke_ab_capture.gd</code></td><td>采集脚本：<code>default</code> 档、参数开关、alpha 采样、角色屏幕坐标</td></tr>
    <tr><td><code>tests/nyangeon_vfx_sample_test.gd</code></td><td><b>改了两处断言</b>：<code>emitted==1</code> → <code>==cluster</code>（每步现在 2 团）；贴地判定改为 ±0.25 的界（散布会移动云团）</td></tr>
  </table>

  <div class="box warn">
    <b>需要你知道的两处取舍：</b>
    <ul>
      <li><b>淡出只能放最后一档。</b>标记色一旦与背景混合就认不出来，所以 alpha 必须保持 1 直到最后一档（出力已接近暗部）。视觉上是"整体散开后溶进暗部"，不是全程渐隐。</li>
      <li><b>枪口烟是画面里唯一的暖色。</b>色板本身纯冷蓝，暖烟靠语义分支穿过去。它读起来像"枪口打亮的暖光"而不是贴上去的霓虹，但和场景色温确实不同源。真要同源得改场景光照，那是另一个工程。</li>
    </ul>
  </div>

  <h2>5. 验证</h2>
  <table>
    <tr><th>项目</th><th>结果</th></tr>
    <tr><td>启动（<code>--quit-after 140</code>）</td><td>退出码 0，脚本/解析错误 <b>0</b></td></tr>
    <tr><td><code>unit_presentation_rules_test</code></td><td><b>52 / 0</b></td></tr>
    <tr><td><code>pixel_combat_vfx_rollout_test</code></td><td><b>25 / 0</b></td></tr>
    <tr><td><code>nyangeon_vfx_sample_test</code></td><td><b>21 / 0</b>（修断言后）</td></tr>
    <tr><td>实机采集自检</td><td>每次 7 项、零失败；全部同一间 <code>open_office</code></td></tr>
  </table>

  <h2>6. 还没做的</h2>
  <ul>
    <li>枪口烟的真实参数（每步粒子数 / 衰减曲线 / 颜色过渡）仍然<b>不可静态解出</b>：Particles 对象全部运行时 spawn，参数在事件动作里。
        现在这版是按观感调的近似，不是数值复刻。</li>
    <li>射击的<b>火光</b>（橙→红→紫的亮部闪光）没动，只做了烟。</li>
    <li>帧时间没采样。枪口烟最多同时 48 个 Sprite3D，走路烟池上限 72，都远低于场景负载。</li>
  </ul>

</main></body></html>'''
    path = OUT / 'smoke_final_report.html'
    path.write_text(html, encoding='utf-8')
    print('REPORT', path, len(html) // 1024, 'KB')


if __name__ == '__main__':
    main()
