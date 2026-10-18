# Formal floor diagnosis and rejected outline merge

Single-agent, muted serial GPU tests; Godot 4.7.1 Compatibility, RTX 5070 Ti.
Actual GPU image 1920x1080, world 640x360, seed 41001, 10-second warmup and
60-second live sample. Instrumentation is test-only, not production.

## Profiler scope repair

The world-method probe previously replaced the native four-skeleton world
with the generic base. Its current-turn attempt failed the workload gate
(exit 1); it is invalid for formal-floor analysis. Previous historical world
timings from that probe are also not formal-generator evidence.

Probe now inherits `office_skeleton_world_base.gd`. Caller checks that its
script chain includes the scene's original script before preserving exports.
Corrected run verifies native C3, 2423 floor cells, 15 rooms, 14 enemies.
3 enemy shooters, 430 player / 205 enemy shots, zero failures, exit 0.

Frame median/P95 13.175/21.902 ms, max 202.121 ms, draw median 2187. These
instrumented values are not an optimization A/B or proof of stable 60 FPS.

| Diagnostic timing | Median / P95 ms |
| --- | --- |
| World render CPU | 4.102 / 5.404 |
| World render GPU | 1.596 / 2.515 |
| World process | 1.539 / 2.114 |
| Occlusion cutout callback | 1.308 / 1.834 |
| Alive character bridge callbacks, per active frame | 1.242 / 2.202 |
| Dead character bridge callbacks | 0.391 / 0.769 |
| Projectile bridge callbacks | 0.394 / 0.816 |

Server timestamp queries may lag frames and do not include all capture
viewports. Nested CPU callback timings are not additive. A long display frame
with small resolved world GPU time does not prove an OS/driver cause.
Log: `.runtime/random_1080_formal_bridge_render_breakdown.log`.

## Withdrawn outline batching experiment

Merged only identical furniture outline overlays into one local triangle
mesh per furniture, retaining normal/base texture meshes, shadow casters,
physics and lights. Four pixelation/Palette combinations had exact GPU byte
parity. Frozen formal camera has 31 eligible merged objects, 31 nominal
passes removed, but only 12 actually visible draw calls saved.

| A/B/A | Draw calls | Frame median / P95 ms |
| --- | --- | --- |
| Original | 1061 | 2.508 / 3.065 |
| Merge | 1049 | 2.522 / 3.167 |
| Original repeat | 1061 | 2.738 / 3.440 |

No meaningful gain; not installed. Experimental test/helper removed.
Source furniture visuals, outline shaders and materials remain unchanged.
Static parity never certified swiveling parts/lifecycle, nor did this frozen
result represent live-combat FPS.

The first attempt had nil-index-array runtime errors; its exit 0 and empty
reports are invalid, not a pass. Corrected diagnostic handled unindexed
surfaces and required at least 20 removed passes. Retained valid log:
`.runtime/furniture_outline_merge_probe_valid.log`; PNGs retained.

Next investigation: detailed occlusion query timing through the actual
formal generator, without changing collision or shader cutout behavior.

## Detailed query result

After ten seconds of normal combat, freeze that exact formal state and call
the existing cutout update 200 times (diagnostic burst, not FPS). Whole
callback median/P95 0.764/1.177 ms. Average per full callback from aggregate
totals: snapshot 0.305 ms, wall queries 0.184 ms, visual-tree/door queries
0.210 ms, furniture queries 0.055 ms. Individual medians are not additive.
This is a modest cost, not evidence that these queries cause the 50–200-ms
stalls. No production spatial-index/occlusion change adopted. The actual
native C3 floor and multi-shooter preflight gate pass; exit 0. Log:
`.runtime/random_1080_occlusion_breakdown.log`.
