# Dense blood draw fast path — 2026-10-07

## Change and limits

The dense PIXEL_CELL stamp is already a final one-pixel square. `_draw()` nevertheless calculated the coordinate-based shape hash for every cell; only the other stamp types use that hash. The retained path skips those unused integer operations and makes the **same** `draw_rect(Rect2(p, Vector2.ONE), #D96B18)` call. Position scaling/rounding, growth gates and bounds checks still run before it. CORE_SPLAT, SATELLITE_DOT, WALL_DRIP, default drops and airborne rendering retain the original path. Simulation, collisions, count, colour, growth/merge curve, draw order and lifetime are unchanged. `test_legacy_pixel_draw_hash` is diagnostic-only.

No texture raster replacement, row union, MultiMesh approximation, lower resolution or blood reduction was introduced. This is draw-command CPU optimization, not proof that overall stutter is solved.

## Measurement and camera parity

`tests/blood_pixel_draw_profile.gd` uses an inherited timer around the real `_draw()` inside Godot's actual drawing callback. A fresh passive carrier is required: the production pool intentionally retains its original BlackBloodEffect replica type. The initial fixture incorrectly attempted to cast that pooled replica to the timer subclass, produced a script error and stalled; its exact process was stopped. That first run is **not** a pass or a measurement. The corrected fixture uses the standard unpooled display constructor for its diagnostic subclass; both comparison paths use that same carrier/source/world.

Initial corrected run: 7213 dense cells, old/new/old CPU draw medians **1.901 / 1.161 / 2.275 ms**, P95 **2.661 / 1.836 / 3.177 ms**. Fixed-frame medians **4.476 / 3.637 / 4.941 ms**. 120 samples after 20 warm draws, one forced redraw per frame, gameplay paused. This is a large-stain local/fixed-scene measurement, not normal combat FPS.

Final four pixelation/Palette combinations (`blood_pixel_draw_matrix_0..3.log`), all **10 checks / 0**, all exit 0, total **40 / 0**. Each verifies nonempty capture and an actual formal-camera contribution, then exact camera image equality old/new/old for the dense stain plus five mixed-stamp/scaling/clipping/growth cases. Draw medians old/new/old:

| Pixelation | Palette | Draw CPU median (ms) |
|---|---|---|
| on | on | 1.895 / 1.315 / 2.179 |
| on | off | 1.912 / 1.249 / 2.429 |
| off | on | 1.854 / 1.219 / 1.874 |
| off | off | 1.940 / 1.200 / 1.974 |

All measured on RTX 5070 Ti, Compatibility, 2560x1440 application output; nearest low-resolution world when pixelation is enabled. Improvements in this same-source draw test are repeatable; they cannot be applied to every full frame since settled blood is normally captured once and changing blood amounts vary. Exit-resource warnings were separate from assertion failures.

## Normal combat and regression close-out

`blood_pixel_draw_normal_combat.log`, normal production path, exit 0: 14 initial enemies, 3 enemy shooters / 362 shots, 427 player shots, 3896 frames. RTX 5070 Ti, 2560x1440 output / 640x360 world, 10 s warm-up + 60 s measurement: median **14.939**, P95 **19.956**, P99 **28.347**, maximum **136.245 ms**, median draw calls 2189. This is a valid current-scene sample, not a matched causal full-game A/B. The remaining rare long frames and P95 above 16.7 ms mean overall stable-60/stutter completion is **not** established.

Final suites, all exit 0: blood revision 27/0; cross-room blood 11/0; ground replica copy 6/0; GPU ground-redraw/actual formal-camera test 48/0; existing character capture cache 9/0; three-floor/rollback lifecycle 729/0. These six numbered suites total **830 / 0**, separate from the 40 camera-matrix checks. OTXO blood's six named checks passed; pool-merge test reported its fixed-grid/mask/transform/deduplication/growth success sentinel, exit 0 (no numeric total was invented).

Ground-redraw test was initially misclassified as headless-compatible; it waits for rendered frame callbacks. That still-live exact process was stopped, then rerun with normal GPU output and `--formal-pixels`, producing the 48/0 result above. The incomplete headless log is not a pass. Final editor parse and scoped difference checks exit 0; no script/parse errors. Certificate-store and exit-resource warnings remain separate from assertions. Rejected body-cache candidate is absent from production/test code; existing display behavior and previous pool optimizations are preserved. Overall goal remains active.
