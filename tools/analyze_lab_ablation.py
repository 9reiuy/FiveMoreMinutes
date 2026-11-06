"""Offline analysis of the independent lab. Does not launch or edit the game."""
import csv
import json
import math
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.runtime' / 'lab_ablation_20261102'
if len(sys.argv)>1:
    OUT=OUT/sys.argv[1]

def stats(values):
    values = sorted(values)
    if not values:
        return {}
    return {"n": len(values), "mean": statistics.mean(values),
            "p50": values[math.ceil(len(values)*.5)-1],
            "p95": values[math.ceil(len(values)*.95)-1],
            "p99": values[math.ceil(len(values)*.99)-1], "max": values[-1]}

analysis = {}
lines = ['# 独立测试场逐项排除：原始统计摘要', '',
         '帧时间为完整主循环间隔；阶段父子计时重叠，不可相加。峰值保留，首次事件与热态差异需结合事件窗口解释。', '']
for batch in ('canary', 'render', 'events', 'combat'):
    summary_path = OUT / f'{batch}_summary.json'
    if not summary_path.exists():
        continue
    summary = json.loads(summary_path.read_text(encoding='utf-8'))
    audit_path = OUT / f'{batch}_environment.json'
    audit = json.loads(audit_path.read_text(encoding='utf-8-sig')) if audit_path.exists() else {}
    samples = audit.get('environment', [])
    peers = [s for s in samples if s.get('peers')]
    free = [s['free_physical_kib']/1024/1024 for s in samples]
    batch_analysis = {'failures': summary.get('failures'), 'changed': audit.get('changed_during_run'),
                      'foreign_process_samples': peers, 'free_physical_gib': stats(free), 'arms': []}
    lines += [f'## {batch}', '', f'断言失败：{summary.get("failures")}; 运行中审计文件变更：{audit.get("changed_during_run")}; 其他游戏进程采样：{len(peers)}', '',
              '| 序号 / 排除项 | P50 | P95 | P99 | Max | >20ms | 平均绘制 | 枪数 |',
              '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
    results = summary['results']
    for result in results:
        f = result['frame']
        lines.append(f"| {result['index']} {result['name']} | {f['p50_ms']:.3f} | {f['p95_ms']:.3f} | {f['p99_ms']:.3f} | {f['max_ms']:.3f} | {f['over_20']}/{f['frames']} | {result['draw_calls']['mean_ms']:.0f} | {result['shots']} |")
        raw_path = ROOT / result['raw'].removeprefix('res://')
        with raw_path.open(encoding='utf-8', newline='') as file:
            rows = [{k: float(v) for k, v in row.items()} for row in csv.DictReader(file)]
        peaks = sorted(rows, key=lambda row: row['frame_wall_ms'], reverse=True)[:8]
        for peak in peaks:
            peak['nearby_events'] = [e for e in result['events'] + result['inputs'] if abs(e['seconds'] - peak['elapsed_s']) < .12]
        mid = len(rows)//2
        second_half = stats([r['frame_wall_ms'] for r in rows[mid:]])
        # A context-only event window vs pre-event baseline, never dropping its peaks.
        phases = {}
        for name, lo, hi in [('before_event',0,1),('activation',1,2),('active_2_5s',2,5),('late_5s_plus',5,999)]:
            phases[name] = stats([r['frame_wall_ms'] for r in rows if lo <= r['elapsed_s'] < hi])
        arm = {'name': result['name'], 'index': result['index'], 'frame':f, 'phases':phases,
               'second_half_context_only':second_half, 'peaks':peaks,
               'stage_max':result['stage_max_ms'], 'stage_mean_per_frame':{k:v/f['frames'] for k,v in result['stage_total_ms'].items()},
               'event_counts':result['event_counts'], 'smoke_cells':stats([r['smoke_cells'] for r in rows]),
               'smoke_puffs':stats([r['smoke_puffs'] for r in rows]),
               'sink_methods_ms':stats([r['sink_methods_ms'] for r in rows])}
        arm['pre_to_post_wall']=stats([r['draw_wall_ms'] for r in rows])
        arm['physics_steps_observed']=stats([r['physics_steps'] for r in rows])
        arm['preparation_verified']=result.get('preparation',{}).get('render_verified',False)
        # An engine callback interval is not a GPU duration. GPU queries above
        # are delayed independently; never splice them onto these peak rows.
        arm['scope']='Observable interval; pre/post includes later GDScript callbacks, native submission and waits.'
        batch_analysis['arms'].append(arm)
    if batch == 'render':
        lines += ['', '### 与紧邻两次 baseline 对照（正数为减少的毫秒）', '', '| 排除项 | P50 差 | P95 差 | P99 差 | baseline P95 范围 |', '| --- | ---: | ---: | ---: | --- |']
        for i, r in enumerate(results):
            if r['name']=='baseline' or i==0 or i==len(results)-1:continue
            pair = [results[i-1]['frame'],results[i+1]['frame']]
            differences = {k:statistics.mean(b[k] for b in pair)-r['frame'][k] for k in ('p50_ms','p95_ms','p99_ms')}
            lines.append(f"| {r['name']} | {differences['p50_ms']:.3f} | {differences['p95_ms']:.3f} | {differences['p99_ms']:.3f} | {min(b['p95_ms'] for b in pair):.3f}–{max(b['p95_ms'] for b in pair):.3f} |")
            batch_analysis.setdefault('paired_differences', []).append({'name':r['name'],'delta':differences})
    analysis[batch] = batch_analysis
    lines += ['']
(OUT/'analysis.json').write_text(json.dumps(analysis,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'SUMMARY.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('\n'.join(lines))
