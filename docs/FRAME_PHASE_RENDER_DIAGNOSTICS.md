# Live frame phases and render-category isolation

Diagnostic only; no production graphics, combat or AI changes in this iteration.
The furniture sleeping repair remains enabled in normal tests. All runs muted.

## Live formal random combat

`.runtime/live_frame_phase_profile.log`: Godot 4.7.1/a13da4feb, Compatibility,
RTX 5070 Ti, output 2560x1440, world 640x360, seed 41001, pixelation and Palette
enabled. Ten seconds warm-up, sixty seconds measured; normal AI, collision and
effects, bounded movement/wall-directed shooting. Fourteen enemies initially,
three shooters, 224 enemy and 427 player shots. Exit 0, failures 0.

Frame median 14.232 ms, P95 22.524 ms, P99 30.368 ms, max 54.181 ms, 3992 frames.
Median draw calls 2270. The optional `--phase-profile` adds a diagnostic node;
it does not enable native engine/script profiling or GPU timing queries.

| Public-signal-delimited phase | Median ms | P95 ms |
|---|---:|---:|
| Physics callbacks (sum per display frame) | 1.518 | 3.378 |
| Residual before process, excluding timed physics callbacks | 1.126 | 2.320 |
| Process callbacks | 4.794 | 7.221 |
| After process before drawing | .603 | 1.542 |
| Drawing CPU elapsed | 6.279 | 8.458 |

Residual includes native physics, queries, input, scheduling/OS and signal
boundaries; it is NOT pure physics. Drawing is CPU wall-clock elapsed, NOT GPU
execution duration. Independent medians cannot be added. This is a current-state
diagnostic, not an A/B speed improvement or proof of stable 60 FPS.

## Frozen-camera category isolation

`tests/render_category_cost_probe.gd`, `.runtime/render_category_cost_probe.log`:
same formal seed/display, ten-second warm-up, frozen gameplay, two-second settle
and eight-second samples. Test-only visibility/shadow switches restored at exit;
no production hook. Five positional shadow lights, 587 wall visible meshes,
587 wall shadow meshes and 464 other shadow-only meshes in the whole floor.

| Disabled only during diagnostic | Draw calls | Frame median/P95 ms | Drawing median ms |
|---|---:|---:|---:|
| None, original | 1376 | 4.226 / 5.481 | 3.849 |
| Visible wall meshes | 1307 | 3.851 / 5.266 | 3.532 |
| Wall shadow meshes | 1145 | 3.691 / 4.690 | 3.397 |
| Other shadow-only meshes | 1235 | 3.781 / 4.980 | 3.480 |
| Positional shadows | 763 | 2.451 / 3.138 | 2.181 |
| None, original repeat | 1376 | 3.598 / 4.363 | 3.331 |

Exit 0 and explicit restoration marker. Original/repeat drift is substantial;
individual wall changes do not establish a worthwhile improvement. Category
switches change the picture and are NOT acceptable production optimizations.
Positional shadows are the larger rendering contributor in this camera, but
their removal is outside the approved scope. Frozen results do not characterize
moving combat, and do not explain the entire live P95.

## Rejected hypothesis and next boundary

The manager submits `shadow_opacity` during fades and after reaching its target.
In the exact engine revision, GLES3 LightStorage::light_set_param returns early
for equal values; opacity is not among the parameters that increment shadow
version. Therefore repeated equal opacity is not a shadow-map invalidation root
cause; no speculative production guard was added.

Source: https://github.com/godotengine/godot/blob/a13da4feb/drivers/gles3/storage/light_storage.cpp#L134-L164

Whole-game target remains open. Prior small CPU prototypes and wall shadow
batching remain rejected. Next useful work must address meaningful live render
submission/effect cost or script cost while retaining lights, shadows, visual
coverage and gameplay cadence, with matched workload and actual Camera output.

Editor parse: `.runtime/frame_phase_editor_parse.log`, exit 0, no parse/script
errors. Known nested-project scan warning is unrelated. Scoped diff whitespace
check clean. All owned GPU/editor processes ended normally. No new production
change means this iteration does not replace the previous gameplay/lifecycle
regression evidence, nor add a visual-pass or a new overall speed-up claim.

## Follow-up: accumulated combat objects and alternate submission

`--combat-render-categories` now runs a test-only post-combat frozen-state
probe. The initial invocation (`combat_render_categories.log`) reached the
inventory but stalled during the paused diagnostic; explicitly interrupted,
exit 1, not accepted. Setting the probe's process mode to ALWAYS let the retry
finish. Do not interpret the stalled run as an optimization result.

`combat_render_categories_retry.log`: controlled start/stable identities/bounded
route/`--aim-wall`, 10/60-second live warm-up/sample. 395 enemy shots/3 shooters,
414 player shots, live median 23.478/P95 32.319/max 99.354 ms. Different runtime
firing load from the previous live sample: no paired speed comparison permitted.
Inventory: 163 floor object sprites, 27 casings, 6 blood and 5 transient sprites,
23 enabled capture viewports. Frozen samples below include 1-second settle and
6-second measurement, not live combat timing.

| Disabled in test | Draw calls | Frame median/P95 ms |
|---|---:|---:|
| None | 1343 | 6.077 / 7.468 |
| Capture viewports | 1324 | 5.184 / 6.956 |
| Shell sprites | 1217 | 5.711 / 7.794 |
| Blood sprites | 1337 | 5.829 / 7.666 |
| Floor object sprites | 1054 | 5.086 / 6.609 |
| Transient sprites | 1338 | 5.851 / 7.338 |
| None, repeat | 1343 | 4.782 / 6.756 |

Exit 0, failures 0, explicit restoration. Significant baseline drift means the
category costs alone cannot prove a useful optimization. Exit-resource warnings
are recorded separately from workload checks. No shipping visibility switch.

### Separate render thread: rejected

Tested only via `--render-thread separate`, no project setting edit. Exact
engine warns experimental/crash risk; VSync switching also warned unsupported.
`combat_render_thread_separate.log` terminated with fatal CowData index 0 on
empty array, exit 1 before warm-up/sample completed. Not adopted and no perf
result. The precise crash cause was not isolated.

Official caveat: https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html#rendering

### Direct source atlas/MultiMesh ground debris: promising but NOT accepted

Tests `environment_debris_atlas_candidate.gd` and `environment_debris_atlas_perf.gd`
are test-only. 84 actual source instances, all 42 atlas frames, four quarter-turn
rotations, same world/display/shadow proxies, frozen Camera. No source physics,
RNG, lighting, count or texture edits. Candidate bypasses the per-item captured
texture for the visible mesh; existing shadow proxies are retained. It has no
cross-floor/lifecycle or moving/breaking-source contract and is not connected to
the formal floor. No production fallback mechanism was added.

All versions reduce draw calls 1058 -> 775 (26.7%), original repeats retain 1058.
Image repeats are stable (zero pixels different). Early direct RGB version had
3649 changed pixels; keeping the original carrier colour encoding reduces the
difference to 278. Matching its 128px capture sampling grid reduces it to 238;
sorting instances by camera depth yields 286 instead, so sorting is not a fix.
Most latest differences are one channel unit (260 pixels), but 19 pixels have
delta >5, up to 255. Therefore NOT a visual pass and no shipping change.

Best capture-grid frozen timings (`debris_direct_atlas_capture_grid.log`):
original median/P95 2.967/4.012 ms; candidate 2.192/2.913; original repeat
2.854/3.987. Sorting version (`debris_direct_atlas_sorted.log`): 2.908/3.955,
2.322/3.124, 3.095/4.218. These are local frozen 84-object measurements, not full
combat FPS. Each version exits 1 for the single image-equality gate. Raw snapshots
at `.runtime/furniture_face_review/debris_direct_{0,1,2}.png` are overwritten by
each run (currently sorted variant); earlier numeric records remain in logs.

Next boundary: resolve raster/overlap/lighting assignment differences, or reject
the batch while keeping graphics. Do not silently relax the image gate or treat
lower draw-call counts as goal completion. Overall live stutter remains open.

Follow-up editor parse (`combat_category_editor_parse.log`) exited 0, no parse
or script errors; scoped diff whitespace check clean. No production file or
project configuration changed in this follow-up. All owned runs are terminal;
the separate-thread crash and interrupted first diagnostic are not green tests.

### Follow-up: exact native geometry and shared textures (not shipping)

Native Sprite3D mesh arrays, identity-world transforms and original colour encoding
still differ by 200 pixels (`debris_native_mesh_identity.log`); raw native vertex
and attribute bytes differ by 209 (`debris_native_raw_mesh.log`). Separate native
mesh instances instead of MultiMesh differ by 255 pixels, all maximum channel
delta 1 (`debris_direct_individual.log`). Thus instancing alone does not explain
every remaining difference. No verified root cause yet.

The shared-texture candidate retains the actual original Sprite3D nodes and
shader, only switching padded atlas textures and a shared material. One run
stalled before fixture output, explicitly interrupted; both verified test PIDs
were absent afterwards. A staged retry completed in 9.34 seconds and differed
by 7 pixels, original repeat zero (`debris_shared_stage.log`). Exit 1 for the
unchanged image gate. Not adopted; no shared-texture timing claim. Snapshot
filenames now represent this shared-texture retry, not the older sorted batch.

### Follow-up: per-method CPU timing, test-only

**2026-10-11 correction:** the old world method probe inherited the generic
base instead of `office_skeleton_world_base.gd`. Its `super` calls preserved
generic behavior, not the formal four-skeleton generator. The world/bridge
measurements below that used `--world-method-profile` cannot certify the
formal random floor, regardless of their workload gate. The probe now
inherits the exact formal scene script, and its caller verifies the base
script chain before running. Historical measurements remain raw evidence,
not current formal-floor performance claims.

`--world-method-profile` uses an inherited test world script with the scene's
exported values preserved. Super calls keep gameplay cadence and behavior.
Warm-up 10s/sample 60s, seed 41001, RTX 5070 Ti. World callback median/P95
1.106/1.532 ms, of which cutouts 0.852/1.199; camera 0.030/0.044 and weapon
interaction 0.027/0.044. Other measured world steps have medians <=0.019 ms.
Overall process callbacks 4.486/5.828 ms, frame 13.364/17.299 ms.
BUT only one enemy shooter: workload gate failed, exit 1. These are diagnostic
method timings, not a valid multi-shooter acceptance or an improvement claim.
Next measurement aggregates actual bridge callbacks by source type, with no
shipping instrumentation or disabled effects.

Bridge aggregate retry (`bridge_method_profile.log`), seed 42001, inherited
test bridge script preserving source fields: 3 shooters, 1207 enemy/442 player
shots, exit 0/failures 0. Per-active-frame median/P95: living characters
0.681/1.131 ms; dead 0.221/1.007; shells 0.202/0.355; other 0.201/0.576;
projectiles 0.138/0.745. World cutouts 0.619/1.031, total world 0.782/1.251.
Frame median/P95 8.257/12.709, max 101.573 ms. Different start location/enemy
count/load from other runs, so NOT an A/B improvement or all-floor acceptance.

### Captured long frame at furniture destruction

`live_stall_resource_phase.log`: original production world/bridge scripts;
test-only phase and renderer-resource probes. Seed 42001, 10s warm-up/60s
sample, RTX 5070 Ti, 13 initial enemies, 2 shooters, 47 enemy/438 player shots.
Exit 0/failures 0; frame median/P95 10.578/14.096, max 88.692 ms. Again not a
paired comparison. Exit ObjectDB/resource warnings remain separate.

Frame phase sample 533 (frame interval sample 534 due signal boundary) is
88.678 ms: drawing 80.015, process 5.177, physics 1.889, residual .955,
after-process .642. Resource interval 534 adds one Furniture3DDebris with six
MeshInstances and three EnvironmentDebris sources while removing one furniture
visual. Net buffers +872 bytes/textures +2536 bytes relative previous frame.
Last-resolved world GPU timestamp spikes to 76.429 ms six samples later
(CPU renderer query 78.489); neighbours otherwise ~0.75-1.4 GPU ms.

This is a concrete destruction/draw-stall correlation, not proof of native
shader compilation: asynchronous query lag, drivers and render submission
prevent assigning the entire interval to a specific compile/allocation call.
Do not fix with reduced particle counts, removed lighting or an unmeasured
loading delay. Prior rejected warm-up variants remain rejected. Next priority
is the first destruction rendering path, not tiny camera/interaction caches.
