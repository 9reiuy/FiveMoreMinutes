"""Flag evidence validity without dropping any slow frame from raw results."""
from pathlib import Path
from datetime import datetime
import json

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'.runtime/lab_ablation_20261102'
locations=[BASE,BASE/'verified',BASE/'frozen/.runtime/lab_ablation_20261102/final']
records=[]
for location in locations:
    for summary_path in sorted(location.glob('*_summary.json')):
        batch=summary_path.stem.removesuffix('_summary')
        audit_path=location/f'{batch}_environment.json'
        if not audit_path.exists():continue
        audit=json.loads(audit_path.read_text(encoding='utf-8-sig'))
        summary=json.loads(summary_path.read_text(encoding='utf-8'))
        foreign=[datetime.fromisoformat(s['utc'].replace('Z','+00:00')).timestamp()
                 for s in audit['environment'] if s.get('peers')]
        for r in summary['results']:
            raw=location/f'{batch}_{r["index"]:02d}_{r["name"]}.json'
            finish=r.get('sample_finished_unix',raw.stat().st_mtime)
            start=r.get('sample_started_unix',finish-r['frame']['mean_ms']*r['frame']['frames']/1000)
            reasons=[]
            if audit.get('changed_during_run'):reasons.append('source_changed_during_batch')
            if any(start-6 <= stamp <= finish+6 for stamp in foreign):reasons.append('other_gpu_test_observed_near_window')
            if summary.get('failures') or audit.get('exit_code')!=0:reasons.append('batch_failure')
            if r['name']=='blood_disabled' and r['event_counts'].get('blood_registered',0):reasons.append('exclusion_is_partial_corpse_blood_remains')
            records.append({'path':str(raw.relative_to(ROOT)), 'batch':batch, 'index':r['index'], 'name':r['name'],
                            'frames':r['frame']['frames'],'p95_ms':r['frame']['p95_ms'],'p99_ms':r['frame']['p99_ms'],'max_ms':r['frame']['max_ms'],
                            'preparation_verified':r.get('preparation',{}).get('render_verified',False),
                            'no_observed_confound':not reasons,'reasons':reasons})
output={'scope':'No observed confound is NOT deterministic replay, full OS/GPU isolation, or proof of a causal delta. Peer samples are ~5.5s apart with a 6s guard. Earlier timestamps inferred from export mtime. Pairing requires both adjacent controls to qualify. Source audit coverage is in each environment JSON. Never trim raw slow frames.',
        'runs':len(records),'frames':sum(r['frames'] for r in records),'no_observed_confound_runs':sum(r['no_observed_confound'] for r in records),'records':records}
(BASE/'VALIDITY.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in output.items() if k!='records'},ensure_ascii=False))
