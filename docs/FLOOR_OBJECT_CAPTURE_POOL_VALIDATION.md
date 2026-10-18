# Floor-object passive capture pool — 2026-10-07

## Scope and diagnosis

`shared_goal_engine_frames.jsonl`: death/drop frame 626 had two bridge creations totaling 8.059 ms (weapon drop parent 5.352 ms); furniture/debris frame 2057 had two bridge creations totaling 6.057 ms. Nested/native costs overlap and cannot be summed.

Reuse passive 128px display carriers for standard debris, weapon pickups and their existing separate ground-shadow capture. Actual `EnvironmentDebris` / `WorldWeaponPickup` bodies stay fresh: IDs, collisions, velocities, throw height, RNG, pickup ownership, shine phase and fade/tweens are not pooled or altered. No fragment quantity or lifetime reduction.

Floor-local prewarm counts **64 debris / 8 weapon / 8 shadow**; idle caps **96 / 24 / 24**. Active requests have no new cap; overflow creates a new passive carrier, never steals a live one. Released carriers hide and disable capture; staging/rollback restores both primary and companion bindings. Only exact script + projection contracts use the pool; unusual projections retain the original path. Material policy changes reject incompatible idle slots. Existing dynamic-light/shadow policy and capture sizes are retained.

The initial 16-debris prewarm was exhausted during actual combat. The diagnostic trace recorded up to two fresh carriers / 4.453 ms in one frame after exhaustion. Raising prewarm to the existing default single-room debris budget (64) changes presentation capacity only, not the gameplay debris cap, lifetime or amount. Creation/parity measurements below initially used 16 prewarmed debris; the final lifecycle checks use 64.

## Creation and GPU parity

`floor_object_capture_verified.log`: same 24 live sources (16 debris + 8 weapon), 32 display carriers, old/new/old median creation **67.774 / 1.251 / 72.202 ms**. Ten samples after two warm iterations per group. This is burst creation only, with gameplay paused; not sustained FPS.

Four pixelation/Palette combinations (`floor_object_matrix_0..3.log`), each compared original/reused/original formal-camera image bytes at birth, fake-height pose and shrink/fade/rotation pose; all **24 image comparisons identical**. Same-frame old/new 2D weapon captures with live time-driven shine also matched for all eight pickups per combination (32 comparisons); shine was disabled only for serial whole-world byte comparisons to avoid comparing different shader TIME values. World RNG state unchanged.

All 24 object captures are nonempty in every group. The eight separate top-level Shadow captures are empty in the original implementation at this fixture position, and remain empty in the pooled version. The initial fixture incorrectly required 32 nonempty captures and failed three checks; after inspecting the equal baseline and six identical formal-camera comparisons, the gate was corrected to require all 24 actual objects. This does **not** prove shadow imagery works at every coordinate, and no new shadow was invented or deleted here.

An initial missing bool type declaration prevented script compilation; fixed before successful validation. A rollback check then exposed a missing companion metadata key; restore now respects absent companions rather than inventing them. Neither initial run is counted as successful.

## Lifecycle

- `floor_object_final_floor_object_pool_lifecycle_test.log`: **1372 checks / 0**, exit 0. Overflow 120 debris + 40 weapons, all 200 live carriers uniquely bound, idle caps respected, missing freed slots rebuilt; source ID, velocity, fake height, ownership and shine phase preserved; released captures hidden/disabled; nonstandard projection bypassed.
- `floor_object_final_random_floor_lifecycle_test.log`: **729 checks / 0**, exit 0, three successful staged floors and forced failure rollback, 64/8/8 staged prewarm verified, both weapon/shadow and debris bindings restored; other existing blood/projectile/transient checks retained.

Runtime combat, parser and broader regression results must be recorded separately. Stable 60 FPS / overall stutter repair are not yet established by these burst and image tests.

## Regression and baseline failures

Combat parity 79 / 0, ballistics 98 / 0, trail history 19 / 0, all exit 0. Together with the two final lifecycle suites: **2297 checks / 0**; GPU comparisons are reported separately above.

`dream3d_effects_test.gd` initially stalled on a decorative wall child without `edge` metadata. The fixture now skips non-wall-segment children, and a diagnostic flag allows the old object capture path. Original/new both completed **2381 checks / 154 failures**, exit 1; identical categories/counts: 8 old wall-blood coordinate/normal assertions, 1 fake-height/local-Y assumption, 1 actor-scale assumption and 144 furniture-bridge assumptions (3D furniture is not required to have a sprite capture). These assertions were not weakened or declared fixed; the whole suite is not a pass. The debris cap and legal spray-origin checks did not fail in either run. Dummy-renderer material warnings are separate from assertions.

An ordinary GPU sample was started while that stalled headless test still existed; both specific process handles were terminated and the overlapping sample discarded. The subsequent isolated normal sample (`floor_object_isolated_normal_combat.log`) had 14 initial enemies but only one actual shooter / 318 shots, so the existing multiple-shooter gate correctly failed (exit 1). Median 14.016 ms / P95 19.901 ms / P99 23.677 ms / max 114.315 ms, 2560x1440 output / 640x360 world, RTX 5070 Ti, 10 s warm-up + 60 s sample. It is **not** a valid multiplayer-combat performance acceptance or proof of repair. P99/max reporting was added to expose rare long frames rather than hiding them behind the median.

The final 64-debris ordinary run (`floor_object_64_normal_combat.log`) passed its load gate: 14 initial enemies, 2 enemy shooters / 340 enemy shots, 423 player shots, 3660 frames, exit 0. On RTX 5070 Ti at 2560x1440 output / 640x360 world, after 10 s warm-up and 60 s sampling: median **15.711 ms**, P95 **22.202 ms**, P99 **30.974 ms**, maximum **136.792 ms**; median draw calls 2134. This is a valid current-scene measurement, **not** a matched causal A/B or stable-60 acceptance. Rare long frames and the overall stutter issue remain unresolved.

Final-policy GPU repeat (`floor_object_final_gpu.log`), pixelation/Palette enabled: original/reused/original burst median **63.557 / 1.090 / 65.146 ms**; all six whole-world image comparisons and same-frame shine checks passed, exit 0. The other three matrix combinations were verified before changing only the prewarm/retention counts.

Final-policy engine diagnostic (`floor_object_64_engine_*`) completed collector/game exit 0: 3128 frames, 2 enemy shooters / 83 enemy shots, 420 player shots. **No `floor_object_capture_pool._create` calls** occurred in the recorded sample. This confirms the selected scene no longer paid the overflow creation cost; it does not establish all seeds fit that reserve. Debugger-instrumented median 18.249 ms / P95 25.842 ms / max 129.198 ms is not comparable to ordinary-run FPS. Three largest debugger frames were 128.394 / 124.520 / 121.602 ms with respective aggregate script costs 20.599 / 24.204 / 17.454 ms. Exact 2D physics solver P95 was 0.155 ms. The remaining long-frame cause is not established by this script trace; render timestamp investigation is required rather than blaming gameplay physics or claiming the pool solved overall stutter.

Render-timestamp diagnostic (`floor_object_64_render.log`) passed its load gate/exit 0: 3 shooters / 251 enemy shots, 432 player shots, 4168 frames. Median 13.830 / P95 19.671 / P99 27.169 / max 162.909 ms. World viewport render CPU median/P95 4.164/5.507 ms; GPU 1.527/2.501 ms; root GPU 0.213/0.471 ms. Slow display frames and two neighbours on either side are now recorded by the test. A resolved world GPU query reached 74.339 ms at sample 1455 after long display intervals near 1450, demonstrating that aggregate median/P95 alone hides exceptional rendering stalls. Query results may lag by multiple frames: neither the query nor the one-second maximum process monitor identifies the cause or the exact slow-frame pass. This run does not prove a lighting/shadow bottleneck, and its lower P95 is not a causal comparison to earlier runs with different combat load. The unresolved rare stalls need broader timing correlation; no visual features were disabled to hide them.

Final close-out checks: editor parse exit 0 (no script/parse errors); scoped `git diff --check` exit 0; repeat five closest suites (`floor_object_close_*.log`) **2297 checks / 0 failures**, all exit 0. Certificate-store warnings were classified separately. The older comprehensive effects suite's 154 identical baseline failures remain as disclosed above, not included in the passing total. The overall performance goal remains active.
