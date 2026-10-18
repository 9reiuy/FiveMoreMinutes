# Destruction material lifetime — 2026-10-07

## Scope and diagnosis

Compatibility, Godot 4.7.1, RTX 5070 Ti. Presentation resource lifetime only;
no changes to gameplay, physics, AI, fragment count, geometry, RNG order,
movement, shadows, opacity, fading or blood. No geometry batching/downsampling.

`tests/random_combat_perf.gd --controlled-start --bounded-route --stable-identities --resource-profile`
adds test-only node-event/net-renderer-memory correlation. Resolved viewport
queries may lag; node events/net memory are not native allocation or compile
timers. The modern pipeline compilation counters are not used as proof of no
Compatibility shader compilation.

Before fix, `.runtime/combat_resource_profile.log`: 3770 measured frames,
14 initial enemies, 3 enemy shooters, 385 enemy/428 player shots, 10 s warm-up
and 60 s sample, 2560x1440 output / 640x360 world. Median 15.474, P95 21.251,
P99 26.929, max 116.065 ms; exit 0, no diagnostic failures. All five intervals
above 100 ms coincided with creating 8 glass or 6 furniture meshes. This was
a correlation, not sufficient causal evidence.

## Controlled reproducer and retained change

`tests/destruction_mesh_profile.gd` uses the actual formal floor/camera and actual
production glass/furniture destruction functions. Gameplay is paused. Each
burst is drawn, destroyed, and followed by several empty frames. Thirty-two
glass samples and 24 samples per furniture group, all muted.

Sharing only box geometry did not eliminate the glass stalls: first-draw medians
91.952 / 91.578 / 96.668 ms (`destruction_mesh_gpu.log`, 114 checks/0, exit 0).
This geometry change was **not** installed.

Holding an actually rendered material alive removed recurring stalls. Releasing
that reference restored them: glass 95.614 / 2.708 / 96.809 ms
(`destruction_material_release_gpu.log`). The original-repeat image differed in
18 pixels after shader lifetime reset, so that initial strict three-image test
failed 1/114; it is not presented as passing visual acceptance. Original versus
retained-material images in that run matched exactly. Subsequent final fixture
has an explicit release-control mode, never silently relaxing original/candidate
pixel checks.

Final implementation retains one actual glass material and at most two actual
furniture material variants (textured/non-textured). **Every burst still creates
its own material**, preserving original transparent material ordering and
independent furniture alpha. Retainers contain no nodes. Geometry and animation
are unchanged. Test-only metadata exposes the prior lifetime policy.

Production-function benchmark (`destruction_material_isolated_visual.log`):

| Carrier | Original median | Retained median | Repeat control |
| --- | ---: | ---: | ---: |
| Glass | 99.611 ms | 3.160 ms | 2.881 ms (retainer still alive) |
| Furniture, no texture | 98.471 ms | 2.685 ms | 96.386 ms (retainer cleared) |
| Furniture, textured | 95.107 ms | 2.563 ms | 98.794 ms (retainer cleared) |

First use remains slow: retained groups still had one 90–108 ms interval.
Glass warm original control also benefits from the surviving shader resource;
it is explicitly **not** an independent cold original bracket. This establishes
the resource-lifetime effect, not an overall FPS multiplier.

## Visual and animation checks — limits kept explicit

Default pixelation + Palette 1: seeded shard count, dimensions, pose, initial
camera pixels and warm-repeat camera pixels match. The unextended production
benchmark passed 450/0 (`destruction_material_final_gpu.log`, exit 0), including
independent furniture fade/texture/count assertions; later glass policy keeps
per-burst materials rather than sharing draw materials.

Extended matrix covers pixelation on/off and Palette on/off, four glass tween
poses, and furniture seeded motion/fade with/without a texture. Exact byte
checks: **530 checks, 19 failures**, exit 1, with final retained implementation
(`destruction_material_isolated_visual.log`). An explicit **original versus
original** control reproduces the **same 19 failing cases**, exit 1
(`destruction_material_original_visual_control.log`). Most furniture differences
are 1 channel value before Palette; Palette can amplify a threshold crossing.
Full-resolution transparent glass also has baseline recreation differences.
The original/candidate geometry and kinematic-state checks pass. These baseline
pixel failures were not hidden or converted to passes; exact four-mode visual
acceptance remains incomplete. A shared-draw-material intermediate was withdrawn;
the final code only retains resource lifetime.

## Live result and remaining work

Resource-instrumented live run after initial retention fix:
`combat_retained_destruction_materials.log`, exit 0, 4013 frames, 14 initial
enemies/3 shooters, 286 enemy/428 player shots. Median 14.506 / P95 20.480 /
P99 25.955 / max 115.171 ms. Three measured glass creation events took
17.837 / 15.706 / 14.362 ms; the first furniture destruction still took
115.171 ms. Lower overall median/P95 cannot be assigned solely to this fix:
enemy shot counts and destruction timing differ from the earlier live sample.

Final per-burst-material normal live sample (no resource/render instrumentation):
`combat_destruction_material_final_normal.log`, exit 0, 3800 frames,
14 initial enemies / 2 enemy shooters, 310 enemy / 428 player shots,
same 10 s warm-up / 60 s sample, RTX 5070 Ti, 2560x1440 / 640x360.
Median **15.452**, P95 **21.423**, P99 **26.575**, max **113.127 ms**;
no diagnostic failures. This is the current workload result, not a matched
old/new FPS gain claim.

Sustained 60 fps, P95 <=16.7 ms and absence of all
long frames remain **unverified**. First-use destruction and other 40–66 ms
intervals remain investigation targets. No midrange GPU measurements exist.

## Rejected hidden capture warm-up

`capture_first_use_profile.gd`: 32 real floor-object sources / 80 fresh slots
per sample, frozen formal world, 8 measured samples per group. One hidden
load-time 2D draw versus existing CPU precreation: first-draw medians
5.718 / 5.742 / 5.365 ms; CPU acquire .907 / .939 / .914 ms.
`capture_first_use_gpu.log`: 2436/0, exit 0, nonempty actual captures and exact
camera pixels. No meaningful benefit; no production warm-up change installed.

Certificate-store and exit-resource messages are separated from assertion and
parse results. Existing unrelated working-tree changes are preserved.

## Regression closeout

Muted headless runs, each exit 0:

- Material lifetime/overlapping fades/three destroyed floor roots: **59/0**.
- Glass cutaway/shatter/collision contract: **26/0**.
- Formal 3D combat parity: **79/0**.
- Random floor lifecycle, transient clearing and failure rollback: **729/0**.

Total **893 checks / 0 failures** in these suites, separately from the
explicit extended visual matrix baseline **530 checks / 19 failures** above.
The new seed metadata is diagnostic only; normal furniture RNG still randomizes.
The bounded retainers hold resources, never previous floor nodes.

## Follow-up: door fragments and rejected warm-up (2026-10-08)

Only the door fragment material lifetime change below is newly adopted.
Materials remain fresh per burst; two bounded resource references (wood/metal)
keep shader variants alive without retaining doors, floor nodes or tweens.
Fragment count, RNG sequence, geometry, color, shadows and animation are unchanged.

`door_shard_material_profile.log`, formal frozen Camera, RTX 5070 Ti,
24 samples each original / retained / original-release:

| Fragment | Original median | Retained median | Release median |
|---|---:|---:|---:|
| Wood | 3.060 ms | 3.083 ms | 3.169 ms |
| Metal | 14.588 ms | 3.125 ms | 15.238 ms |

151 checks / 0 failures, exit 0: exact formal-camera pixels, seeded poses,
dimensions, color and specular state. Metal cold-start maximum 238.220 ms,
retained-group maximum 16.385 ms; initial-use cost is NOT eliminated.
Three-floor resource lifetime suite now 74/0, exit 0.
These are destruction-only measurements, not total gameplay FPS gains.

### Warm-up experiments: no formal entrypoint adoption

- Isolated warm-up: 450 checks / 2 pixel failures (54 changed bytes in glass,
  also in warmed-original repeat), exit 1. First-draw frozen-scene samples fell
  to 4–6 ms, but visual acceptance is incomplete.
- Simple load-time warm-up in live combat: loading 1395.647 ms;
  median 18.756 / P95 25.547 / max 101.254 ms; 14 enemies / 2 shooters,
  324 enemy and 420 player shots, exit 0. Furniture destruction still stalled.
- 27 combinations of absent/unshadowed/shadowed directional/omni/spot lights:
  loading 4058.641 ms; median 20.668 / P95 27.574 / max 88.864 ms;
  14 enemies / 3 shooters, 421 enemy and 420 player shots, exit 0.
  The 88.864-ms interval coincided with six furniture fragments and seven removed
  meshes. Added loading cost without removing the stall: rejected for production.
- Native shader inspection found matching shader RID/code and material properties
  for warmed anchor and actual furniture bursts. This diagnostic forces shader
  update and is NOT a performance acceptance run. Godot's exact installed source
  [GLES3 scene renderer](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/drivers/gles3/rasterizer_scene_gles3.cpp)
  binds additional lighting/shadow specialization constants; equal base shader RID
  alone therefore does not establish equal compiled GL programs. This remains a
  hypothesis, not a measured compiler attribution.
- One control run stopped producing progress and was explicitly cancelled (exit 1),
  not counted as a benchmark. Watchdog control completed but had only one enemy
  shooter and failed the workload gate: exit 1, no performance acceptance claim.

Formal combat, sustained 60 fps and all first-use stalls remain separate open gates.

Door follow-up regression closeout (muted headless): lifetime 74/0,
hinge/cutaway 19/0, combat parity 79/0, floor lifecycle 729/0; each exit 0.
Topology 25 checks / 8 failures, door leaf 120 / 1 failure, each exit 1:
re-running with the newly added material retention code removed produced the
same counts and the same leaf assertion (`covered rectangle rooms`). These are
baseline failures, not waived passes. Dummy-renderer material warnings and exit
resource warnings remain separately recorded in the logs. Editor parse exit 0.

First normal-combat follow-up: median 17.532 / P95 28.045 / max 110.956 ms,
14 enemies / 4 shooters, 383 enemy / 422 player shots, exit 0. Headless regressions
were concurrently active for part of this run; it is not a clean standalone
FPS acceptance measurement and does not establish an overall gain.

Standalone instrumented follow-up `combat_door_material_final_profile.log`:
10 s warm-up / 60 s sample, RTX 5070 Ti, 2560x1440 / 640x360;
3169 frames, 14 initial enemies / 4 shooters, 274 enemy / 423 player shots.
Median 16.813 / P95 30.701 / P99 38.168 / max 143.504 ms, exit 0.
No ten-mesh door-fragment event occurred in this route, so this run does NOT
verify the door change under live destruction. The 143.504-ms interval adds six
furniture fragments and removes seven furniture meshes; another 67.628-ms
interval follows five samples later. Instrumented render CPU/GPU median
5.160/1.907 ms for world rendering is not the complete frame cost.
Remaining priority: actual furniture destruction transition, not a claim that
GPU shading alone is the bottleneck. The overall performance goal is still open.

## Transition isolation (continued investigation)

New diagnostic `furniture_destruction_transition_profile.gd`: six actual catalog
types, 8 samples/type/action, frozen populated 41001 floor; spawn only / remove
only / combined. Initial fixture used invalid catalog names for two types and
was corrected; that initial exit-0 run contained script errors and is NOT valid.
The next fixture drew outside the formal rotated display parent, and is also
not sufficient evidence about the gameplay transition.

Corrected `furniture_transition_formal_parent.log` uses the actual
`_spawn_furniture_presentation` path (including dressing), actual rotated
`actor_depth_bridges_root`, and camera in the normal combat fixture room.
Spawn-only first use reached 155.131 ms; removal-only maxima 5–6 ms;
later combined maxima 5–8 ms. Native creation CPU maxima below 1 ms.
This separates the first new debris render from destroying the old model.
Exit 0, no script errors; retained exit-resource warnings are recorded separately.

Test-only shared-World3D warm-up: 83 one-voxel meshes / 11 room views in a
temporary 64x36 viewport with its own camera; gameplay camera not moved.
`furniture_transition_actual_warm.log`: loading 2275.552 ms, subsequent first
spawn maximum 8.730 ms. No production entrypoint integration.
Live `combat_actual_world_warm.log`: loading 2392.410 ms;
14 enemies / 2 shooters, 369 enemy / 420 player shots, exit 0;
median 21.270 / P95 27.303 / max 145.961 ms. A six-fragment interval still
reached 105.688 ms; another 145.961-ms interval had no fragment event.
Therefore this warm-up does NOT solve the overall stutter and is not adopted.
Location diagnostics identify chairs and workstations in the actual combat room.

Shared-world all-unshadowed/all-shadowed trial (`combat_actual_shadow_warm.log`):
loading 5517.938 ms, 83 meshes / 11 views; median 20.022 / P95 25.024 /
max 126.338 ms, 14 initial enemies / ONLY ONE shooter, 321 enemy / 421 player
shots, exit 1 (workload gate). Not FPS acceptance. Only furniture burst was
50.829 ms; the maximum had bullet/shell/muzzle additions but no furniture.
This diagnostic temporarily alters light shadow states, restoring the original
enabled/opacity/visibility values before gameplay; it is NOT production code.

Mixed-shadow shared-world trial (`combat_actual_mixed_shadow_warm.log`):
loading 5646.961 ms; 14 enemies / 3 shooters, 318 enemy / 424 player shots,
2837 frames, exit 0. Median 20.494 / P95 26.597 / max 65.583 ms.
Three furniture bursts: 65.583 / 23.534 / 23.387 ms. This is a promising
long-frame investigation result but is not a matched overall-FPS improvement
claim, nor proof that stutter is gone. 5.6-second loading cost is substantial;
no formal entrypoint integration, visual acceptance or complete lifecycle proof.

### Fresh script profile, not FPS acceptance

Local collector connections in the restricted launcher failed (no frames),
so those runs are not results. Same-machine diagnostic connection outside that
restriction succeeded; collector `destruction_followup_engine_verified` gathered
2524 frames and exited successfully. Game run had only one shooter and failed
the workload gate, so its FPS is NOT acceptance evidence. Profiling itself adds
overhead; script attribution is used only to choose the next investigation.

Recorded script-time median 12.748 ms (P95 17.306), process median 17.043,
physics median 4.196. Leading script functions:

| Function | Self ms/frame | Inclusive ms/frame | Calls/frame |
|---|---:|---:|---:|
| Actor bridge `_process` | .699 | 4.932 | 51.4 |
| Capture tree `_sync_node` | .928 | 2.221 | 176.1 |
| Furniture `_sync_transform` | .701 | .846 | 200.2 |
| Cutout snapshot | .486 | 1.007 | 1.0 |
| Wall visibility intersection | .484 | .541 | 6.0 |

Inclusive rows overlap; they must NOT be summed as independent costs.
Next focus is actor capture-tree synchronization plus cutout/transform work,
not another unproven increase in hidden loading time. No shader warm-up was
installed into the formal game in this investigation turn.

## Capture synchronization investigation

Child-order direct lookup + leaf shortcut prototype: 14 actual formal actors,
24 samples/group, 20 repeated synchronizations/sample, original / candidate /
original CPU medians .66875 / .58610 / .66605 ms. About .08 ms saved per full
actor set: too small for the overall goal. Prototype production changes and its
temporary test were removed; evidence retained in `capture_tree_sync_profile.log`.
Initial prototype parse/array-type errors were corrected before measurement;
those initial runs are not passing evidence.

`actor_capture_cost_profile.gd`, actual frozen formal Camera/GPU, 14 actors,
24 samples/group: full .9592 / repeat .9701 ms; tree-only .6720;
snapshot .0557; planes .0648; volume shadow .3163 ms. Suboperations overlap and
some force work for offscreen actors that full processing skips; do not add
these numbers or substitute this static case for live combat.

Temporary live timing wrapper (removed after measurement),
`capture_cpu_live.log`, RTX 5070 Ti, 3994 sampled frames, 14 initial enemies /
2 shooters, 310 enemy / 430 player shots, exit 0:
capture CPU ms/render frame: enemies 1.6224, player .5322, projectiles .5535,
shells .3813, pickups .1092, muzzle .0635, blood .0041.
Normal workload frame median 15.079 / P95 17.880 / max 101.453 ms.
This is attribution with instrumentation, not a matched improvement claim.
It distinguishes the live moving/dead actor workload from the static fixture.
No generic capture-tree cache, synchronization cadence reduction or timer
wrapper is retained in production.

Tiny private-world mixed-light prototype (`combat_tiny_mixed_light_warm.log`):
32x32 viewport, one opaque caster, one actual fragment material, two directional
lights (one shadowed with formal sun split mode), mixed shadowed/unshadowed
spot/omni lights. This covers light combinations absent from earlier probes.
Loading 2599.413 ms, 16 states, temporary viewport released. Live 41001 trial,
14 initial enemies / 2 shooters, 403 enemy / 426 player shots, 3579 frames,
RTX 5070 Ti, exit 0: median 16.605 / P95 20.309 / max 26.196 ms.
Three furniture bursts: 17.903 / 18.322 / 20.406 ms. Promising removal of the
first-use furniture stall in this workload, not a proven total-FPS increase or
sustained 60 fps. Prototype remains test-only pending matched repeat, visual
parity, cleanup and loading-cost evaluation.

In-process original / tiny-warm / original repeat
(`combat_tiny_mixed_light_ab.log`):

| Group | Median | P95 | Max | Enemy shots / shooters |
|---|---:|---:|---:|---:|
| Original | 15.763 | 19.774 | 95.967 | 333 / 2 |
| Warm | 16.171 | 20.786 | 53.688 | 355 / 3 |
| Original repeat | 14.793 | 18.159 | 41.434 | 234 / 2 |

Warm-up inside this already-running process cost 679.592 ms, not the 2599.413-ms
cold-process cost above. Native/driver shader caching can persist across the
groups; clearing the material anchor does not establish a cold driver reset.
Enemy firing-load min/max ratio 234/355=.659 is below the .8 requirement.
The running script was launched before the new warm-AB workload gate was added;
its exit 0 is NOT performance acceptance. No overall FPS gain demonstrated.
The current fixture includes warm-AB in the standard workload gate for future
runs. Individual destruction spikes are promising but require isolated cold
comparison and visual/lifecycle proof; production warm-up remains uninstalled.

### Staged loading budget and pixel parity (2026-10-08)

`destruction_warm_transition_budget.gd` uses the formal GPU display, full random
content and actual `_regenerate_staged` over three floors. Gameplay is frozen
only for deterministic pixel comparison; these are not live combat timings.
RTX 5070 Ti, Compatibility, muted; 21 checks / 0 failures, exit 0.
Formal world pixels before/after warming are identical on all three floors;
formal camera, environment and sun are unchanged. Private viewport is freed,
with no accumulation (floor viewport counts 351 / 332 / 338).

| Floor | Staged generation | Warm | Combined | Extra ride time due to warm |
|---|---:|---:|---:|---:|
| Initial | not measured | 963.093 ms | n/a | n/a |
| 2 | 2717.605 ms | 205.158 ms | 2922.763 ms | 205.158 ms |
| 3 | 1665.620 ms | 205.488 ms | 1871.108 ms | 0 ms |

Actual minimum cab ride is **2000 ms**, not 3000 ms. Incremental loading cost
is `max(2000, generation + warm) - max(2000, generation)`; time beyond the
minimum alone is not all attributable to warming. This diagnostic does not
run actual cab animation or verify a cold driver cache. Earlier cold-process
warm cost was 2599.413 ms, so 963.093 ms is not a guaranteed startup bound.
Even the hot probe extends an already-long floor generation in floor 2;
do not integrate it under a claim of zero added wait. Production unchanged.
Exit ObjectDB/resource warnings are separately recorded, not failed assertions.

Confirmed run after correcting incremental-wait reporting and restoring test
settings (`destruction_warm_transition_budget_confirmed.log`): 21/0, exit 0;
all three images still byte-identical. Initial warm 1075.807 ms; staged floor 2
2758.314 + 206.978 = 2965.292 ms, incremental wait 206.978 ms; staged floor 3
1536.341 + 206.923 = 1743.264 ms, incremental wait 0. Editor parse exit 0,
no parse errors; scoped diff whitespace check clean.

Controlled initial-state ABA (`combat_tiny_mixed_light_controlled_ab.log`),
41001, bounded movement route, 10-second warm-up plus 60-second sampling per
group, resource/render instrumentation enabled:

| Group | Median | P95 | Max | Enemy shots / shooters |
|---|---:|---:|---:|---:|
| Original | 22.078 | 28.345 | 117.499 | 421 / 4 |
| Warm | 22.501 | 28.604 | 38.759 | 337 / 2 |
| Original repeat | 21.738 | 27.670 | 62.924 | 288 / 1 |

All three starting-state fingerprints matched. Yet live firing load did not:
288/421=.684 < .8, and original repeat had only one shooter. Exit 1, two actual
workload assertions failed (not warning noise). No overall performance claim
is valid. Warm cost 808.825 ms; driver caching persists across groups. Reduced
maximum stall remains a hypothesis, while median/P95 show no improvement even
before considering the rejected workload. Resource instrumentation is present
in every group, so do not compare these absolute frame times to uninstrumented
previous runs. Production warm-up remains uninstalled.

### Small CPU candidates rejected (2026-10-08)

No candidates below remain enabled or present in production. Temporary test
scripts were removed after measurement; logs retain the evidence.

- Exact unchanged-state furniture submission skip, 83 formal furniture visuals,
  original/new/original CPU per full batch: .12335 / .07215 / .12345 ms;
  saving ~.051 ms per batch is too small for the overall stutter objective.
- Native door-tree enumeration, exact ordered list of 50 live visuals matched,
  frozen formal-camera snapshot .4605 / .3795 / .4509 ms. Full cutout update
  1.1557 / .9420 / .9623 ms: original repeat is nearly the candidate, so no
  stable large overall gain. Query cadence and production traversal unchanged.
- Direct RGBA8 tracer writes: first implementation failed all 128 parity cases
  and was slower. Cause: Color.TRANSPARENT has white RGB, not zero RGB; the
  pixel buffer must preserve those channels as well as float32 alpha truncation.
  Corrected version passed 128 exact texture-byte/anchor checks, exit 0, but
  18-projectile CPU original/new/original 2.0862 / 1.9978 / 1.9932 ms proves no
  stable saving. Do not accept parity alone as an optimization. Restored original.

GPU probes used RTX 5070 Ti; batch timings are not live-combat FPS. A read-only
process inventory after the probes found no other Godot instance running.
