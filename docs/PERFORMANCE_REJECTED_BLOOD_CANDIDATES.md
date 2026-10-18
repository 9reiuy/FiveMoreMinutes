# Blood performance follow-up — 2026-10-07

No production optimization from this experiment was retained. Existing capture pools and single-pass blood merging remain intact. Blood amount, colour, growth curve and physical clipping are unchanged.

## Rejected candidates

- Native packed-array raster transforms (2026-10-07 follow-up): 607 exact ordered-cell/merge checks passed. Dense raster median 908/576/911 us old/new/old, but complete merge 2936/2701/3014 us and P95 3073/3729/3197 us. About 0.24 ms local gain with worse P95 is not a meaningful combat repair; branch and temporary test removed. Logs: `.runtime/blood_raster_batch_test.log`, `.runtime/blood_raster_batch_full_test.log`. No transform or blood appearance change retained.
- Merge adjacent one-pixel draw commands: 7085-cell fixture old/new/old median 1652/1216/1670 us, image bytes identical. Insufficient gain.
- Incremental row cache: stationary redraw 1671/114/1666 us, but scattered growth median 1006/1149 us (worse), and real large-pool growth 789/570 us. All 24 growth images identical in each case. Static repeated redraw is not a representative performance result; reject rather than add a cache maintenance system for ~0.2 ms.
- Precompute immutable maximum-pool radial geometry: 100 ordered-cell/RNG comparisons passed, but complete no-world setup median 12904/12652/13490 us. Too small and not a real floor proof; reverted.
- Subdivide unsafe 16-pixel visibility blocks to 4-pixel convex hulls: 24 wall-aware ordered-cell/RNG comparisons passed, median 11237/11607 us (worse). Reverted. Actual thin-wall checks remain unchanged.

Temporary candidate scripts were removed, diagnostic logs remain under `.runtime`. Initial grid test had a signature parse error, repaired before reporting the successful result. No candidate was visually accepted for production.

## Current full-combat diagnosis

`post_merge_engine_game.log`, `post_merge_engine_summary.json`, `post_merge_engine_frames.jsonl`: muted Compatibility / RTX 5070 Ti, 2560x1440 output, 640x360 world, pixelation + Palette 1, 10 s warm-up + 60 s sample; 2389 frames, player 418 shots, enemies 185 shots / 2 shooters. Collector and game exited 0. Median 24.028 ms / P95 33.963 ms. Debug profiler overhead is included; this is diagnosis, not a release FPS claim. Enemy load differs from prior runs, so do not claim an A/B FPS improvement.

Frame 1685: measured script profiler setup_death_pool total 43.085 ms, _setup_pixel_pool 42.999 ms, _is_pool_cell_allowed 33.402 ms / 5893 calls, _raycast_environment 12.667 ms / 5898 calls. Native Object.call attribution overlaps nested script cost and must not be summed. A death near blocked geometry can trigger thousands of per-point floor/ray checks when conservative hull caching cannot prove a block clear. The next meaningful candidate is operation-local query-parameter reuse / batched context, with exact collider/floor/RNG/pixel parity—not fewer blood pixels or relaxed wall tests.

Daily display synchronization also remains a recurrent cost: bridge _process ~4.68 ms total, _sync_node ~2.29 ms nested. Average physics solvers are small (~0.067 ms 2D / 0.001 ms 3D); do not mistake the whole script physics phase for the solver.

Overall stutter repair and stable 60 FPS remain uncompleted.
