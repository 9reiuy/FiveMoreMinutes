"""Independent frame audit; original gameplay traces remain unchanged."""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
BATCH = PROJECT / '.runtime/visual004_roles_20261104/performance_r2/rendering_path_v1/options_research_20261105'
spec = importlib.util.spec_from_file_location('prior_comparison', ROOT.parent / 'perf009-ab-20261105/analyze_comparison.py')
comparison = importlib.util.module_from_spec(spec)
spec.loader.exec_module(comparison)


def audit(case):
    folder = BATCH / 'PlaySessions' / case
    receipt = comparison.read(folder / 'run.json')
    assert receipt['state'] == 'released', 'Only inspect completed sessions'
    result, rows = comparison.analyze({'id': case, 'path': str(folder), 'scheme': receipt['variant']})
    trace = comparison.read(folder / 'trace.json')
    stages = trace['stages']
    reveal = next(i for i, s in enumerate(stages) if s['name'] == 'firstuse_reveal')
    export = next((i for i, s in enumerate(stages) if s['name'] == 'ab_export_excluded'), len(stages))
    result['all_after_reveal'] = comparison.summarize([r for r in rows if reveal <= r['stage_id'] < export])
    result['receipt'] = {k: receipt.get(k) for k in [
        'state', 'exit_code', 'private_master', 'engine_errors', 'source_drift',
        'candidate_manifest_sha256', 'runner_sha256', 'script_sha256',
        'before', 'after', 'concurrent_authorized', 'strict_gpu_isolation',
        'receipt_io_sha256', 'recovery_sha256', 'launcher_error']}
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('cases', nargs='*', default=['R2_B2_before_ceiling39', 'R2_B3_after_ceiling40'])
    parser.add_argument('--output', default='ceiling_timing_review.json')
    args = parser.parse_args()
    result = {
        'scope': 'Independent central-ceiling regression audit. Same native route and combat command sequence, real nondeterministic AI, concurrent user load retained. Not an isolated renderer attribution.',
        'visible_scope': 'firstuse_reveal through the stage immediately before ab_export_excluded; no reveal, transition, or unfocused frames removed.',
        'long_frame_ms': '> 80, strictly',
        'slow_streak_ms': '> 20 in adjacent recorded frames of the same run; distinct runs never joined.',
        'runs': [audit(case) for case in args.cases],
    }
    (ROOT / args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    for r in result['runs']:
        visible = r['all_after_reveal']
        print(json.dumps({
            'id': r['id'], 'outcome': r['outcome'], 'validation': r['validation_notes'],
            'frame': visible['frame'], 'slow_streak': visible['slow_streak'],
            'groups_fps': {k: v['frame'].get('average_fps') for k, v in r['groups'].items()},
            'coverage': {'reached': r['coverage']['movement']['reached'],
                         'total': r['coverage']['movement']['total'],
                         'regions': r['coverage']['movement']['regions'],
                         'physics_ticks': r['coverage']['dynamic']['physics_ticks']},
            'configuration': r['configuration'],
            'cover_to_control_ms': r['cover_to_control_ms'],
            'memory': r['memory_engine_allocations_peak'],
        }, ensure_ascii=False))


if __name__ == '__main__':
    main()
