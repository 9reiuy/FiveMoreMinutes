# Shadow first-use investigation — not a production fix

All GPU results below use Godot 4.7.1 Compatibility, NVIDIA RTX 5070 Ti,
driver 610.74. Actual output image is checked at 1920×1080; pixelated world
is 640×360. Formal native C3 floor 41001: 2423 cells, 15 rooms, 14 enemies.
Muted tests retain actual AI, combat physics, effects and stock weapon rules.

## Measurement validity repair

The controlled-start diagnostic accidentally resumed gameplay only when
world-method profiling was enabled. Fixed the test indentation and added a
pre-warmup pause guard. The zero-shot run in
`.runtime/random_1080_character_capture_profile.log` is INVALID, despite
its low frame timings; its workload gate failed. Production was unaffected.

The repaired unbounded capture run also failed the multi-shooter workload
gate (one shooter), and is not performance acceptance. The subsequent
bounded stress run passed: 432 player shots, 320 enemy shots, two shooters,
median/P95 13.627/17.702 ms. Character body captures resolved CPU median/P95
0.082/0.239 ms and GPU 0.046/0.143 ms. These are last-resolved timestamp
queries, not exact display-frame costs; disabled/one-shot captures can be
stale. They do not establish capture as the dominant stutter source.
Log: `.runtime/random_1080_sustained_capture_profile.log`.

## Cold activation reproduction

A read-only light-selection trace correlated two long frames with a shadow
candidate replacement: 85.560 ms on enable, 77.197 ms on first nonzero
opacity. Another 51.123-ms frame occurred without a recent replacement.
Correlation does not explain every stall.
Log: `.runtime/random_1080_shadow_selection_trace.log`.

`tests/shadow_first_activation_probe.gd` pauses the actual formal world,
activates four real indoor lights, then repeats the same operation.
Cold activation: 755.605 ms, followed by 4.814 and 3.850 ms.
QA-only full-floor preparation: 3.523, 4.936 and 3.584 ms. The preparation
visits nine views, covers 24 candidates, never exceeds the four-light cap,
and takes 3200.814 ms in this run. Shadow-on output differs from shadow-off;
repeated shadow-on images are byte-identical. This is a first-use fixture,
NOT live-combat FPS acceptance.
Logs: `.runtime/shadow_first_activation_probe.log`,
`.runtime/shadow_first_activation_prepared_probe.log`.

## Live results prevent adoption

Each run warms ten seconds then measures sixty. Real gameplay is not an
exact replay, so varying shot/death counts limit causal comparisons.

| Variant | Median / P95 / max ms | Player / enemy shots | Shooters |
| --- | --- | --- | --- |
| No receiver preparation | 12.777 / 16.742 / 85.663 | 436 / 425 | 4 |
| Receiver preparation | 18.871 / 29.877 / 113.237 | 424 / 470 | 2 |
| No preparation repeat | 15.813 / 21.597 / 85.774 | 427 / 447 | 3 |
| Preparation + diagnostic atlas reset | 17.197 / 23.143 / 75.438 | 426 / 852 | 3 |

Preparation does NOT show a sustained improvement; it remains entirely in
`tests/support`. No production light scheduling, camera, atlas, brightness,
geometry or gameplay change adopted. The atlas-reset experiment nearly
doubles enemy shots and is not a matched-workload comparison. It does not
prove atlas occupancy as a cause. Its parity/lifecycle is not certified.

Logs: `.runtime/random_1080_shadow_receiver_prepared_live.log`,
`.runtime/random_1080_shadow_selection_repeat.log`,
`.runtime/random_1080_shadow_receiver_reset_live.log`.

Optional preparation lifecycle coverage: 50 checks, zero failures, including
three floors, exact camera/schedule restoration, pixelation/Palette images,
and cancellation after generation changes. The owned camera local offset
is restored even on cancellation, without restoring old-floor lights.
Log: `.runtime/shadow_receiver_cancel_lifecycle.log`.

The prepared run additionally exposes CPU-heavy death frames: 27.515-ms
physics plus 20.696-ms process with five blood effects/two emitters, and
27.444-ms process with four effects/corpse emitter/new viewport. Those
events motivate per-call blood creation profiling, not yet a proven cause.

## Follow-up blood timings and rejected shortcut

Actual formal-world method profiler (inherits native generator; calls the
same production methods) measures three death-pool calls at median 6.679 ms,
maximum 8.433 ms. Bridge addition across 25 effects: median 0.111 ms,
maximum 0.197 ms. Four burst calls: median 1.037 ms, maximum 8.671 ms.
Inclusive/nested timings must not be summed. Live run passes the workload
gate, 437 player/147 enemy shots from three shooters; median/P95
12.313/17.283 ms, maximum 87.473 ms. This run establishes a nontrivial CPU
creation cost, not a fix or an exact causal attribution of all long frames.
Log: `.runtime/random_1080_blood_spawn_profile.log`.

Tried checking the existing call-local safe-block proof at the cell loop
before re-entering the validator. Ordered cells, initial stamps, RNG,
thin/moved obstacles and custom validators pass 26 checks. However, the
wall/border A/B/A median is 16.068 / 16.674 / 16.163 ms; candidate is slower,
P95 worsens too. Shortcut and test switch WITHDRAWN. No production blood
shape, color, growth, collision or algorithm change retained.
Log: `.runtime/blood_safe_block_lookup_ab.log`. Initial parse error was a
missing explicit bool annotation, repaired before the valid exit-0 run;
the earlier parse attempt is not a passing result.

## Controlled follow-up and further exclusions

Same paused native floor, same camera and exactly equal world pixels:
before full-floor receiver preparation median/P95 2.549/3.204 ms;
after 2.606/3.627 ms; after diagnostic atlas reset 2.627/3.577 ms.
Three five-second groups, not live FPS. This does not demonstrate an
8-ms sustained preparation overhead; also no speedup. Preparation covers
24 lights in nine views, 1414.807 ms. Actual GPU output 1920×1080.
Log: `.runtime/shadow_preparation_steady_probe.log`, exit 0.

New controlled A/B/A uses identical initial fingerprints, bounded native
movement, actual AI and wall-directed sustained shooting:

| Variant | Median / P95 / max ms | Player / enemy shots | Shooters |
| --- | --- | --- | --- |
| Original | 15.252 / 21.399 / 30.730 | 431 / 307 | 4 |
| Receiver preparation | 16.726 / 22.938 / 41.710 | 426 / 395 | 3 |
| Original repeat | 14.767 / 22.140 / 48.002 | 429 / 302 | 3 |

Enemy-shot minimum/maximum ratio 302/395 = 0.7646 fails the 0.8 matched-load
gate. Exit 1 is that assertion, not a rendering crash. No performance
adoption justified; full-floor receiver preparation remains QA-only.
Log: `.runtime/random_1080_shadow_receiver_controlled_ab.log`.

Another withdrawn blood experiment caches immutable radial geometry only.
Wall/border A/B/A median 16.495 / 15.768 / 16.532 ms; 26 parity checks pass.
Gain is only about 0.7 ms, and original comparison includes diagnostic
branches. Not sufficient for a broad optimization claim. Cache, hook and
switch removed; production blood code restored.
Log: `.runtime/blood_radial_grid_ab.log`, exit 0.

Read-only formal shader inventory finds 13 source-code groups and exactly
13 Shader objects, not large numbers of duplicate identical shaders. Shader
resource deduplication is therefore not a justified next optimization.
This inventory covers geometry materials and next passes, not every Canvas
material. Log: `.runtime/formal_shader_identity_probe.log`, exit 0.

Temporary `override.cfg` disables Godot shader cache for one cold activation
diagnostic. Verified setting false; first activation worsens to 1890.465 ms,
then repeats 5.497/4.474 ms. Pixel-change/repeat checks pass; exit 0. Temporary
file deleted immediately after the owned test terminates. Existing caches,
project.godot and user applications untouched. Cache stays enabled.
Log: `.runtime/shadow_first_activation_no_cache.log`.

Godot 4.7's [Compatibility shader source](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shader_gles3.cpp)
performs compilation/link-status queries synchronously; its renderer source
[initializes persistent shader caching](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/rasterizer_gles3.cpp).
The official [stutter guidance](https://docs.godotengine.org/en/latest/tutorials/rendering/jitter_stutter.html)
recommends actual loading-time draws for Compatibility. These sources plus
the frozen activation result motivate isolating the actual cold shadow
caster material path next, rather than changing the renderer, disabling
shadows or replacing all room artwork. They do not prove every live stall
is shader compilation.

Final headless editor parse exits 0 with no script/parse/compile/load errors;
targeted whitespace checks pass. Log:
`.runtime/shadow_cache_diagnostics_final_parse.log`. No root override file
or experimental blood cache remains. Next material-isolation candidate is
the shared unshaded/cull-disabled StandardMaterial3D used exclusively by
`SolidShadowCaster`, which normal color draws do not exercise; no claim
that it has already been measured or fixed.

## Material-path isolation follow-up

Private shadow-caster material preparation does not remove the formal
first-use stall: 769.627 ms, repeats 4.149/4.035 ms. Private visible receiver
preparation also leaves 691.958 ms, repeats 4.013/4.414 ms. These prototypes
grouped material references, not proven shader pipeline families; the first
prototype's camera did not cover every copied group. They therefore do not
rule out every material/lighting combination. Neither is adopted; helper and
test switches removed. Logs: `.runtime/shadow_first_activation_caster_materials.log`,
`.runtime/shadow_first_activation_receiver_materials.log`.

Formal-view isolation (same paused C3 camera, no floor tour): preparing one
selected light for two draws takes 1174.157 ms and leaves 280.581 ms on first
four-light activation. Preparing all four selected lights takes 1325.574 ms
and leaves only 5.044 ms, then 3.852/3.591 ms. The shadow-on image differs
from off and all repeated shadow-on captures match exactly; both exit 0.
Logs: `.runtime/shadow_first_activation_one_formal.log`,
`.runtime/shadow_first_activation_four_formal.log`.

This is strong local first-use evidence, not a sustained/live or Main-entry
fix. Existing production preparation already raises opacity on initially
active lights, so simply appending four-light preparation would duplicate
work. Next check must establish which light/camera state the real loading
flow prepares and what changes when the floor becomes visible. The render
coordinator sets its formal viewport UPDATE_ALWAYS; an assumed hidden
viewport is not an established cause.

## Normal Main entry and actual cross-floor exit

Normal Main already prepares four selected shadows behind its loading cover.
Initial stock rifle first draw was 6.065 ms (20 checks, zero failures).
The missing hook was subsequent staged floors: preparation did not run before
the floor/landing became visible. Same seed 120, actual Main entry, 1920x1080,
two real elevator transitions, muted RTX 5070 Ti Compatibility measurements:

| Measured scope | Before | Cross-floor preparation |
| --- | ---: | ---: |
| Uncovered EXITING maximum draw interval | 1241.599 ms | 20.665 ms |
| Uncovered IDLE maximum draw interval | 87.934 ms | 12.027 ms |
| Stock rifle first draw after floor 2 | 88.056 ms | 5.984 ms |
| CAB_RIDE maximum draw interval | 1292.927 ms | 1259.988 ms |
| Assertions | 22/0 failures | 26/0 failures |

This candidate moves real first-use work behind a root-output black cover,
pausing simulation while the existing private destruction and formal firearm
preparation run. No camera tour, new lamps, simplified materials, reduced
content, or changed combat values. Per-floor cover durations were 879.205 ms
and 288.127 ms. This deliberately adds covered arrival loading time; it does
not make that work free. Door/walk/control handoff uses the original sequence.
CAB_RIDE generation stalls and sustained live-combat performance are still
unresolved; this is not a total FPS claim. Log intervals measure draw-to-draw
wall time, not isolated GPU execution time.

Logs: `.runtime/main_shadow_cross_floor_trace.log` and
`.runtime/main_shadow_cross_floor_prepared.log`. Reproduce the old exit with
`--baseline-floor-exit` on `tests/firearm_loading_main_entry_test.gd` alongside
`--output-1080 --shadow-flow-trace --cross-floor-shadow-trace`.

Cancellation checks: 17 GPU assertions, zero failures, exit 0; stale floor,
stale transition, freed world, original paused/running state, released cover.
Actual root-output readback is entirely opaque black before floor setup in
all three cancellation cases (`.runtime/floor_exit_cover_gpu_verified.log`).
Headless bypass: 3 assertions, zero failures, exit 0; it executes original
setup without waiting for unavailable draw signals. Floor lifecycle: 729
checks, zero failures, exit 0. Actual three-floor firearm preparation: 37
checks, zero failures, exit 0, including byte-exact before/after frozen world
captures with pixelation/Palette combinations and no retained temporary lights.
Known baseline deferred dither-registration and exit texture messages are
separate from these assertions; they are not treated as successful gameplay
validation or as an established source of sustained stutter.

Repeat after the headless bypass fix: normal Main run exit 0, 26 checks,
zero failures. First stock shot 6.055 ms, uncovered EXITING max 21.103 ms,
but uncovered IDLE still had a 50.457 ms interval. CAB_RIDE max 1202.286 ms.
Thus no claim of eliminating all >40 ms frames. Covers 877.138/303.329 ms.
Log `.runtime/main_shadow_cross_floor_verified.log`; actual 1920x1080 output
captures `.runtime/main_floor_exit_1.png` and `main_floor_exit_2.png`.
The second capture was inspected: floor, furniture, sprite, shadows and HUD
remain visible after control handoff, with no retained arrival cover.
Godot editor headless import/parse exits 0 (`.runtime/floor_exit_parse.log`).

## Cross-floor layout CPU work: local clearance reuse

The actual Main/cab flow with seed 120 was instrumented per synchronous
generation stage (`--generation-stage-trace`, default off, no frame-rate
claim from headless tests). Before the candidate, floor 1/2 layout took
1110.501/1179.844 ms; content 426.626/465.640 ms, final pool/visibility/old
floor cleanup 509.490/501.987 ms. Presentation was 128.205/116.600 ms.
This establishes real CPU stalls independently of initial shadow compilation.

`office_skeleton_generator._place` formerly recalculated full room clearance
for every physically valid furniture candidate. Room/committed occupancy
cannot change within that candidate loop. It now computes a call-local base
once; `_room_clear` copies it and removes the candidate's one-cell halo before
the same door-approach flood fill. No cross-placement cache, reordered candidate
or RNG use, removed route checks, furniture omission or smaller level.

All 12 generated fixtures (four types x seeds 120/41001/73021) match their
before-change full `var_to_bytes` signatures and final master RNG state.
Headless whole-generator median 680.053 -> 520.232 ms; maximum
1146.722 -> 645.766 ms. These timings do not represent live FPS.
600 independent clearance checks compare the cached and original direct
algorithms, including empty results, boundaries, occupied cells, candidate
halos, door approach connectivity and non-mutated local base; all pass.

Actual Main three-floor repeat: exit 0, 26 checks, zero failures. Layout CPU
787.861/752.909 ms (29%/36% less); CAB_RIDE maximum draw interval 856.060 ms,
versus the instrumented before run's >1.1 s intervals. First floor-2 rifle
draw 6.156 ms. No uncovered EXITING/IDLE >40 ms interval in this particular
run; other previous runs did have isolated IDLE spikes. The remaining
~0.4-0.5 s content and ~0.5 s final-stage blocks still need investigation.
Do not declare overall/live-combat stutter solved from loading measurements.

Evidence: `.runtime/floor_generation_stage_trace.log`,
`.runtime/floor_generation_clear_optimized.log`, `.runtime/skeleton_clear_before.log`,
`.runtime/skeleton_clear_after.log`, `.runtime/skeleton_clearance_cache_test.optimized.log`.
Expanded regressions: 600 clearance assertions, 286 native skeleton assertions
and 729 floor lifecycle assertions pass, all exit 0; route-width regression
also reports zero failures/exit 0. The native suite covers all four skeleton
families and repeat generation, not just the two Main-transition fixtures.

## Final generation stage: attribution correction

Further actual Main GPU tracing (`floor_generation_final_stage_trace.log`,
26 assertions, zero failures, exit 0) separates the previously combined
final-stage timing. Floor 1/2 respectively:

| CPU scope | Floor 1 | Floor 2 |
| --- | ---: | ---: |
| Six capture pool prewarms | 434.549 ms | 441.297 ms |
| Path adjacency | 16.363 ms | 25.079 ms |
| Visibility/minimap | 52.529 ms | 62.420 ms |
| Exterior visibility and stash cleanup call | 6.769 ms | 8.633 ms |

The earlier wording "old layer cleanup takes roughly half a second" was
too broad. The synchronous old-layer cleanup call is minor; passive display
pool construction is the substantial CPU work. Deferred object destruction
after queue_free is not included in that call timer and is not ruled out.
Next candidate should budget passive capture construction over loading
frames without changing retained counts, source ownership or render result.
It must explicitly prevent newly generated floor actors from advancing while
additional loading frames are introduced; merely inserting awaits into pool
creation would change enemy state and is not an accepted implementation.

## 2026-10-12: Budget pool preparation under the existing arrival cover

The six pool `prewarm` methods now optionally limit new carriers per call and
return completion; their default synchronous calls, counts and capture sizes
are unchanged. Only actual rendered cab transitions with a guaranteed exit
cover defer stage-6 prewarming. Headless, custom staged callers and baseline
metadata retain the old synchronous path. Existing arrival worker prepares
one carrier at a time up to an 8 ms CPU budget between draws, while the root
output is covered and gameplay paused. An indivisible carrier may exceed
8 ms; the actual peak is reported. Changed token/freed world cancels between
batches, and unpaused calls are rejected. No count reduction or effect drop.

The driver changed from 610.74 to 617.42; use newly measured same-driver
baseline (`--sync-floor-pools`), not historical timings, for this candidate.
First candidate encountered cold rendering and took 4.416/1.058 s behind
the cover; exclude it from a warm-cache comparison rather than concealing it.
Same-driver subsequent synchronous baseline and candidate repeat:

| Scope | Sync baseline floor 1/2 | Budgeted repeat floor 1/2 |
| --- | ---: | ---: |
| Stage-6 pool CPU block | 415.559 / 427.242 ms | deferred |
| Largest pool CPU batch | already warmed | 11.727 / 10.288 ms |
| Paused pool elapsed time | 263.549 / 32.223 ms | 842.395 / 576.527 ms |
| Arrival cover elapsed | 1085.747 / 305.305 ms | 1485.371 / 671.603 ms |
| Prior CAB_RIDE pool block + arrival cover | 1501.306 / 732.547 ms | 1485.371 / 671.603 ms |

The last row is the sum of specifically measured pool/cover scopes, not total
transition elapsed time. Covered arrival is longer; accounting for the moved
work, this scope does not grow. Actual after-floor-2 shot 6.116 -> 6.073 ms.
Both Main runs exit 0 with 26 assertions/zero failures. CAB_RIDE overall max
is still 983.114/989.626 ms (layout remains blocking), and long-frame counts
8/11. Thus no claim of overall cross-floor smoothness or sustained FPS gain.

GPU frozen-world validation: 14 checks/zero failures/exit 0. Exact world image
bytes match before/after cold pool rebuilding. Player position/ammunition,
content RNG, enemy position/health/perception timers and effect source count
remain unchanged. All six capacities match original constants; repeated warmup
does not accumulate carriers; in-progress transition cancellation works.
Headless floor-object lifecycle 1372/0, floor lifecycle 729/0, cover bypass 3/0,
all exit 0. Editor import/parse exits 0; scoped diff whitespace clean.

Logs: `.runtime/floor_capture_budget_candidate.log`,
`floor_capture_budget_sync_baseline.log`, `floor_capture_budget_repeat.log`,
`floor_capture_budget_parity_verified.log`, `floor_capture_budget_parse.log`.
