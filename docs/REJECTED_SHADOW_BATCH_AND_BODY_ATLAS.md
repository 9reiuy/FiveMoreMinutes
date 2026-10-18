# Rejected presentation aggregation probes — 2026-10-09

These are diagnostic-only candidates. Formal materials, light counts, shadows,
character capture and gameplay are unchanged. GPU tests were serial, Compatibility
Godot 4.7.1 / RTX 5070 Ti / NVIDIA 610.74, muted. Each group samples 240 draws of
the same frozen formal floor; this is not live-game FPS.

## Shadow blockers

Only invisible `SolidShadowCaster` geometry was baked per rigid assembly,
separating rotating `SeatRoot`, retaining material/layers/normals/transforms.
`shadow_caster_batch_probe.log`: 3 checks / 0 failures, exit 0, byte-exact frozen
GPU image and restoration. Only 8 original blockers could become 4 batches:
draws 911 → 909 → 911, median 2.874 → 3.209 → 2.872ms, P95 3.808 → 4.471 →
3.544ms. Most approved geometry is already combined. No meaningful gain;
candidate and regenerable test files removed, log preserved. Teardown resource
warnings are not the three assertions.

## Shared body capture atlas

15 original 128x128 body captures placed in one 512x512 target, retaining the
same texel size; CanvasLayer offsets preserve original clone global transforms,
Control clipping preserves cell bounds, AtlasTexture preserves Sprite3D size.
No AI or source clone was added. Held weapons/attachments were not changed.

Sparse fixture `character_body_atlas_probe.log`: 3/0, exit 0, image and restoration
byte-exact; median 1.841 → 2.194 → 2.030ms, draws 481 → 485 → 481. Dense fixture
`character_body_atlas_dense.log` puts the same 15 actors in the open office:
3/0, exit 0, exact pixels; median 2.199 → 2.824 → 2.497ms, draws 681 throughout,
P95 2.817 → 3.704 → 4.495ms. No accepted performance gain. Dynamic death,
occlusion and lifecycle acceptance were not pursued for the slower candidate.
The first prototype failed on a null optional outline material and consequent
failed restoration; corrected runs above, not that first log, establish parity.

Neither candidate is installed. Next evidence is the real furniture-review
scene with city/window lights and live AI, not extrapolation from an empty or
frozen random-floor spawn area.

## Character volume MultiMesh

15 actors / 105 shadow-only body pieces become 6 groups by mesh and light layer.
Player flashlight exclusion, original pose and visibility are retained. Frozen
image and restoration are byte-exact: `actor_shadow_multimesh_probe.log`, 3/0,
exit 0. Original / candidate / restored medians: 3.772 / 3.664 / 3.276ms;
P95: 4.708 / 5.102 / 4.190ms. Draws: 1191 / 1093 / 1191. The draw-call saving
did not provide a stable timing gain; candidate files removed, not integrated.

## Actual city sample, live AI

`sample_city_current_phase.log`, 18/0, exit 0. Warm 10s, sample 60s,
7 enemy shooters / 346 enemy shots / 424 player shots, 11870.595px movement,
2560x1440 output / 640x360 world, median 14.961ms / P95 25.446ms,
median 2296 draw calls. Several 105–126ms frames spend 93–116ms between
render pre/post signals. This measures CPU elapsed drawing, not GPU duration
and not proven shader compilation. Other slow frames include process costs.
Native-ID-dependent AI changes across runs; this is not an exact paired gain.

## Whole-world receiver preparation — rejected

An isolated 64x64 World3D renders actual material references under 16 light
feature combinations, using ordinary and instanced meshes. No gameplay,
random state or source count changed; paused formal image is byte-exact and
private viewport released. GPU fixture checks: 21/0, exit 0 in both corrected
runs. Initial attempts had an unexposed material API call and a fixture call
on a non-processing pool; those failed logs are not accepted evidence.

`sample_city_receiver_preparation_full.log`: 304 material representatives,
preparation 22915.598ms; 7 shooters / 601 enemy / 428 player shots,
median 14.997 / P95 24.111ms, max instrumented frame 65.549ms.
`sample_city_receiver_preparation_deduplicated.log`: 72 representatives
(BaseMaterial3D integer/bool state superset, ShaderMaterial shader identity),
preparation 23061.342ms; 7 shooters / 408 enemy / 426 player shots,
median 14.981 / P95 26.026ms, max 72.458ms. Workloads differ; neither proves a
causal whole-game gain. Added loading cost is unacceptable without clear gain.
The test-only preparation helper and entry flag were removed. Existing normal
Main firearm preparation is unchanged; no 23-second preparation is shipped.

Receiver deduplication reference: Godot 4.7 `_compute_key`:
https://github.com/godotengine/godot/blob/4.7-stable/scene/resources/material.h

## Slow-frame lifecycle trace

Added opt-in test-only node-added/removed recording to `frame_phase_probe.gd`.
It watches the tested world, reports script/class counts on slow frames and
captures current shadow selection / camera / effect counts. It does not alter
gameplay or formal rendering. Sampling overhead means separate runs are not
exact causal comparisons.

`sample_city_slow_frame_events.log`: 18/0, exit 0; 10s warm + 60s actual combat,
5 enemy shooters / 602 enemy shots / 430 player shots, median 14.109ms,
P95 21.780ms, median 2372 draws. A 69.694ms frame includes two impact/emitter
creations and one disposal; 60.800ms is drawing. A 50.217ms frame creates nine
projectiles. A 49.917ms frame has no recorded node events, with 39.958ms drawing.
This establishes correlation, not proof that emitter creation causes all stalls.
Next candidate: bounded hit-emitter reuse, with unchanged particle counts and
appearance, accepted only after actual GPU evidence and lifecycle tests.

Post-experiment muted checks: editor parse exit 0, no parse/script errors;
impact mesh reuse 210/0 exit 0; firearm impact 28/0 exit 0; scoped diff whitespace
check exit 0. These are not all-project regression or whole-game performance
acceptance. Previously reported furniture-outline integration failures remain
outside this diagnostic change, not silently counted as passing.
