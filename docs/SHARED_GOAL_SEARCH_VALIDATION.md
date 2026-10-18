# Shared-goal navigation — 2026-10-07

## Evidence and scope

The previous live diagnostic (`navigation_incremental_engine_frames.jsonl`) still had eight searches totaling 18.818 ms in one frame. This candidate addresses repeated floor traversal, not AI cadence, enemy count, steering, collision, damage or visuals.

Supported formal floor edges are undirected. Reverse BFS from the destination supplies shortest distances. At each step, selecting the first original cardinal neighbor whose distance is one less reconstructs the same lexicographically first shortest path as forward BFS. Distances are not used to choose a different route.

The reverse frontier expands only until the requested start is discovered; subsequent starts resume that frontier. At most four destinations are retained (least-recently-used eviction). Floor/wall key changes clear all frontiers immediately; existing incremental adjacency refresh is retained. Generation and rollback reset data. Unknown derived edge policies use the original dynamic query fallback.

`test_legacy_floor_path` remains the original string-edge BFS. `test_legacy_goal_search` isolates the previous adjacency/head-queue implementation for diagnostics. These are test metadata, not settings or gameplay options.

## Exactness and local timing

- `shared_goal_initial_parity.log`: original BFS vs candidate, 666 checks / 0.
- `shared_goal_search_test.log`: all four skeleton types, two seeds each, shared targets and distinct starts, disconnected island, closing/reopening an edge, destination eviction and mutation of returned arrays: 4231 checks / 0.
- Eight distinct starts to one goal, cold frontier cleared before each measured batch, old/new/old median **3276 / 642 / 3327 us**, P95 **3525 / 735 / 4339 us**. This is a complete cold batch against the already optimized adjacency implementation, not eight copies of a cached identical path and not a total-frame claim.
- Lifecycle: 716 checks / 0, including populated old-floor frontiers, three staged floors and forced rollback. Old sources and transient captures remain covered.

Godot runs are muted; certificate-store warnings are separate from assertions. Overall performance requires actual live combat measurements, not this synthetic batch alone.

Combat/ballistics/projectile history: 79 / 98 / 19 checks, all 0 failures and exit 0. Combined with both path suites and lifecycle: **5809 checks / 0 failures** (performance comparability checks are separate).

## Ordinary live old/new/old — not comparable

`.runtime/shared_goal_normal_aba.log`, RTX 5070 Ti, output 2560x1440, world 640x360, pixelation + Palette 1, each group 10 s warm-up + 60 s sample, 14 enemies initially, same starting-state fingerprint / bounded route / identity fixture. Median 13.878 / 14.627 / 15.114 ms; P95 20.351 / 19.952 / 22.850 ms. Enemy shots 285 / 413 / 338, shooters 2 / 3 / 1, player shots 427 / 430 / 428. Candidate had more live fire and blood than baseline, but this does not establish a causal overall frame-time gain.

The fixture exited **1** with two explicit verification failures: final old group had only one enemy shooter (insufficient workload), and shot-count ratio 285/413 was below the 0.8 matching threshold. Do not count this as a passed benchmark or infer a global FPS percentage. Do not relax the gate or reroll seeds to obtain a favorable comparison. Runtime search timing needs a separate debugger diagnostic; overall stutter remains incomplete.

## Live diagnostic and remaining hotspots

`shared_goal_engine_game.log`, `shared_goal_engine_summary.json`, `shared_goal_engine_frames.jsonl`: Compatibility / RTX 5070 Ti, same output and world settings, 10 s warm-up + 60 s sample, 14 initial enemies, 2 shooters / 304 enemy shots, player 420 shots, 2885 frames. Collector and game exited 0. Median 19.850 ms / P95 27.215 ms includes debugger overhead, not the ordinary game result.

Maximum per-frame `find_floor_path` total in this run: **2.782 ms** (one query); shared reverse search itself 2.049 ms; maximum adjacency work 1.296 ms (three queries). The previous diagnostic had 18.818 ms for eight queries, but this run did not reproduce that exact burst, so the maxima are not a paired overall-performance comparison. The controlled eight-distinct-starts test establishes the ~80% batch saving; this live run establishes that the formal AI uses the new path implementation.

Remaining slow frames point elsewhere: frame 626 dropped-weapon presentation spends 5.352 ms in `_drop_held_weapon`, with two `_spawn_depth_bridge` calls totaling 8.059 ms; frame 707 has two blood merges totaling 12.523 ms; frame 635 death-pool setup 10.982 ms; frame 2057 furniture damage/debris creates two bridges totaling 6.057 ms. Native/parent timings overlap and must not be added together. These are next investigation targets, not solved issues. The physical solver still contributes little relative to script/capture setup.

Final editor parse and scoped whitespace check passed. Corridor suite remains 45 checks / 5 known pursuit-state failures, exit 1; not included among the 5809 passing checks. No new assertion category occurred. Overall stutter repair / sustained 60 FPS remain unproven.
