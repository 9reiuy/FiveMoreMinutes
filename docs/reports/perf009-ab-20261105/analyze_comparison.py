"""Independent analysis of explicit PERF009 A/B recordings; never launches Godot."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

GROUPS = {
    "all_live": "全部游玩测量段",
    "stationary": "静止观察",
    "movement": "连续走动",
    "combat": "全部战斗",
    "combat_on": "通电战斗",
    "power_off": "断电战斗",
    "power_on": "恢复供电",
}


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def distribution(values):
    values = sorted(v for v in values if isinstance(v, (int, float)) and math.isfinite(v) and v > 0)
    if not values:
        return {"n": 0}
    n = len(values)
    percentile = lambda p: values[max(0, math.ceil(n * p) - 1)]
    tail = values[-max(1, math.ceil(n * .01)):]
    return {
        "n": n, "sum_ms": sum(values), "mean_ms": sum(values) / n,
        "p50_ms": percentile(.5), "p95_ms": percentile(.95), "p99_ms": percentile(.99),
        "max_ms": values[-1], "average_fps": 1000 * n / sum(values),
        "one_percent_low_fps": 1000 * len(tail) / sum(tail),
        "over16_667": sum(v > 1000 / 60 for v in values),
        "over20": sum(v > 20 for v in values), "over80": sum(v > 80 for v in values),
        "over80_per_minute": sum(v > 80 for v in values) * 60000 / sum(values),
    }


def consecutive(rows):
    longest_count = {"frames": 0, "ms": 0.0}
    longest_time = dict(longest_count)
    count, elapsed, previous = 0, 0.0, None

    def flush():
        nonlocal longest_count, longest_time, count, elapsed
        item = {"frames": count, "ms": elapsed}
        if count > longest_count["frames"]:
            longest_count = item
        if elapsed > longest_time["ms"]:
            longest_time = item
        count, elapsed = 0, 0.0

    for row in rows:
        marker = (row["_run"], row["_index"])
        if previous is not None and (marker[0] != previous[0] or marker[1] != previous[1] + 1):
            flush()
        value = row.get("post_interval_ms")
        if isinstance(value, (int, float)) and value > 20:
            count += 1
            elapsed += value
        else:
            flush()
        previous = marker
    flush()
    return {"longest_by_frames": longest_count, "longest_by_duration": longest_time}


def selected(row, group):
    stage = row["_stage"]
    return {
        "all_live": stage.startswith("live_"),
        "stationary": stage == "live_stationary",
        "movement": stage == "live_native_movement",
        "combat": stage.startswith("live_combat_"),
        "combat_on": stage == "live_combat_initial_powered",
        "power_off": stage.startswith("live_combat_poweroff_"),
        "power_on": stage.startswith("live_combat_poweron_"),
    }[group]


def summarize(rows):
    result = {
        "frame": distribution([r.get("post_interval_ms") for r in rows]),
        "draw_span": distribution([r.get("draw_span_ms") for r in rows]),
        "slow_streak": consecutive(rows),
        "focused_frames": sum(bool(r.get("focused")) for r in rows),
        "unfocused_frames": sum(not r.get("focused") for r in rows),
    }
    # Viewport timings describe a prior render. First five samples of each
    # stage are omitted only here; frame/FPS/long-frame metrics retain them.
    eligible = [r for r in rows if r["_stage_sample"] >= 5]
    for key, label in [("main", "main"), ("mirror_new_request_readback", "mirror")]:
        for i, field in enumerate(["cpu", "gpu"]):
            result[f"{label}_{field}"] = distribution([
                r[key][i] for r in eligible if isinstance(r.get(key), list)
                and len(r[key]) > i and isinstance(r[key][i], (int, float))
            ])
    result["hitches"] = [{"frame": r.get("process_frame"), "stage": r["_stage"],
                          "ms": r["post_interval_ms"], "focused": r.get("focused")}
                         for r in rows if isinstance(r.get("post_interval_ms"), (int, float))
                         and r["post_interval_ms"] > 80]
    return result


def analyze(entry):
    folder = Path(entry["path"])
    trace = read(folder / "trace.json")
    receipt = read(folder / "run.json")
    config = trace.get("configuration", {})
    rows, counts = [], {}
    for index, raw in enumerate(trace["rows"]):
        row = dict(zip(trace["columns"], raw))
        stage_id = row["stage_id"]
        row.update(_run=entry["id"], _index=index,
                   _stage=trace["stages"][stage_id]["name"],
                   _stage_sample=counts.get(stage_id, 0))
        counts[stage_id] = counts.get(stage_id, 0) + 1
        rows.append(row)
    reveal_id = next((i for i, s in enumerate(trace["stages"]) if s["name"] == "firstuse_reveal"), None)
    visible = [r for r in rows if r["stage_id"] >= reveal_id] if reveal_id is not None else []
    cover = next((e for e in trace.get("events", []) if e.get("type") == "firstuse_cover_presented"), None)
    prep = config.get("firstuse_loading", {})
    fields = ["renderer", "driver", "seed", "rooms", "furniture_actual", "enemy_roots_actual",
              "requested_enemies", "office_spots", "indoor_shadows", "world_viewport", "reflection_resolution",
              "reflection_every_draw", "fps_cap", "audio_driver", "test_master_bus_muted",
              "video_adapter", "enemy_ai", "weapon", "vsync_mode"]
    result = {
        **entry, "trace_sha256": sha(folder / "trace.json"), "receipt": receipt,
        "configuration": {k: config.get(k) for k in fields}, "coverage": trace.get("coverage"),
        "outcome": trace.get("outcome"), "image_writes": trace.get("image_writes"),
        "preparation_ms": prep.get("elapsed_ms"),
        "cover_to_control_ms": ((prep["control_released_usec"] - cover["usec"]) / 1000
                                if cover and "control_released_usec" in prep else None),
        "state_mismatch": prep.get("state_mismatch"),
        "groups": {g: summarize([r for r in rows if selected(r, g)]) for g in GROUPS},
        "all_after_reveal": summarize(visible),
        "all_stages": {s["name"]: summarize([r for r in rows if r["_stage"] == s["name"]])
                       for s in trace["stages"]},
    }
    counter_fields = trace.get("counter_columns", [])
    result["memory_engine_allocations_peak"] = {}
    for key in ["texture_bytes", "buffer_bytes"]:
        if key in counter_fields:
            i = counter_fields.index(key)
            values = [r["counters_post_draw"][i] for r in rows
                      if len(r.get("counters_post_draw", [])) > i]
            result["memory_engine_allocations_peak"][key] = max(values) if values else None
    result["validation_notes"] = []
    for condition, note in [
        (receipt.get("exit_code") != 0, "nonzero_exit"),
        (bool(receipt.get("engine_errors")), "engine_errors"),
        (bool(receipt.get("source_drift")), "source_drift"),
        (bool(trace.get("image_writes")), "image_readbacks_present"),
        (config.get("firstuse_probe") is not None, "observer_present"),
        (config.get("runtime_cost_scope") is not None, "diagnostic_instrumentation"),
        (result["groups"]["all_live"]["unfocused_frames"] > 0, "unfocused_frames_present"),
    ]:
        if condition:
            result["validation_notes"].append(note)
    return result, rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--out", type=Path, default=Path(__file__).with_name("comparison.json"))
    args = parser.parse_args()
    manifest = read(args.manifest)
    runs, by_scheme = [], {"A": [], "B": []}
    for entry in manifest["runs"]:
        result, rows = analyze(entry)
        runs.append(result)
        if entry.get("include_in_aggregate", True):
            by_scheme[entry["scheme"]].extend(rows)
    combined = {scheme: {g: summarize([r for r in rows if selected(r, g)]) for g in GROUPS}
                for scheme, rows in by_scheme.items()}
    output = {"manifest": manifest, "runs": runs, "aggregate": combined,
              "group_labels": GROUPS,
              "method": {
                  "average_fps": "1000 * sampled interval count / sum(interval_ms)",
                  "one_percent_low_fps": "1000 / mean(slowest ceil(0.01*n) frame intervals)",
                  "percentiles": "nearest rank ceil(p*n)-1; all valid positive intervals",
                  "threshold": "strictly greater than 80ms, exactly 80ms excluded",
                  "all_live": "common live_* stages; covered preparation and fixture setup reported separately",
                  "all_after_reveal": "all stages from firstuse_reveal onward, no boundary removal",
                  "streaks": "never join nonadjacent rows or separate runs",
                  "view_timing": "delayed samples, omit first five per stage only for viewport cost; do not add CPU/GPU/view durations",
                  "memory": "engine texture/buffer allocations, not whole-process RAM or physical VRAM",
                  "scope": "same controlled scenario, not deterministic AI replay or whole-game certification; no watts measured",
              }}
    args.out.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    with args.out.with_suffix('.csv').open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['run', 'scheme', 'group', 'frames', 'average_fps', 'one_percent_low_fps',
                         'p50_ms', 'p95_ms', 'p99_ms', 'max_ms', 'strict_over80',
                         'draw_span_p50_ms', 'main_cpu_p50_ms', 'main_gpu_p50_ms',
                         'mirror_cpu_p50_ms', 'mirror_gpu_p50_ms', 'cover_to_control_ms'])
        for run in runs:
            for group, value in run['groups'].items():
                f = value['frame']
                writer.writerow([run['id'], run['scheme'], group,
                    *[f.get(k) for k in ['n', 'average_fps', 'one_percent_low_fps', 'p50_ms',
                                         'p95_ms', 'p99_ms', 'max_ms', 'over80']],
                    *[value[k].get('p50_ms') for k in ['draw_span', 'main_cpu', 'main_gpu', 'mirror_cpu', 'mirror_gpu']],
                    run.get('cover_to_control_ms')])
    for run in runs:
        frame = run["groups"]["all_live"]["frame"]
        print(run["id"], frame.get("n"), frame.get("average_fps"), frame.get("over80"), run["validation_notes"])


if __name__ == "__main__":
    main()
