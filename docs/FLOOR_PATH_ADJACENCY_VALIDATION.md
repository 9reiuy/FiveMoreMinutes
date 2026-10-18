# Floor-path query reuse — 2026-10-07

## Scope

Reuse exact cardinal adjacency for the base random dungeon and the formal four-skeleton scene, which inherits the same wall-membership edge policy. Each search still builds its own BFS tree; original cardinal order, tie-breaking and reconstruction are unchanged. A queue head avoids shifting the queue for each visited cell.

Every query compares native floor/wall key arrays exactly, detecting same-size replacements and broken glass immediately. There is no approximate hash, stale time-based result, lower AI update rate or changed enemy count. Unknown derived scripts retain dynamic edge queries and the lock argument. Generation resets the graph; successful/staged floors prebuild before control; rollback rebuilds the restored topology.

The initial candidate rebuilt the full adjacency graph on every wall change. A live diagnostic exposed a 23.139 ms rebuild after destruction; this was not accepted as the final implementation. The final implementation compares wall membership and recomputes only the changed edges' two endpoints. A changed floor still rebuilds the complete graph, as it does during generation before control resumes.

## Diagnosis

`post_blood_pool_engine_frames.jsonl`: individual slow frames had two searches totaling 14.066 ms, or four totaling 22.672 ms, repeatedly rebuilding string edge keys. Physics solver cost was small. Debug profiler output is diagnostic and includes overhead, not a release FPS benchmark.

## Initial validation

Synthetic wall/floor mutations plus five formal skeleton seeds compare exact ordered old/new paths. Local synthetic old/new/old median 2729/576/2714 us, P95 2797/614/2860 us. This is query timing, not total frame time.

Final tests: 666 path checks including real wall removal and unknown derivative lock-policy fallback, 709 lifecycle checks, 79 combat parity, 98 ballistics and 19 projectile-history checks; 1571 / 0 failures, every Godot process exited 0. Final query timing 2781/590/2764 us median, 2878/642/2955 us P95. Certificate-store messages are environment noise, not assertions.

Intermediate normal live combat (before incremental wall refresh): RTX 5070 Ti, 2560x1440 output / 640x360 world, pixelation + Palette 1, 10 s warm-up / 60 s sample, 14 enemies initially, 3 enemy shooters / 306 shots, player 424 shots. Median 15.060 ms, P95 22.735 ms, exit 0. Different enemy load prevents a causal overall-FPS comparison with previous runs. This was not the final implementation's performance sample.

The first post-adjacency debugger run accidentally used a resolution override that resulted in a 10240x5760 root output, confirmed in its log. It is useful only for locating the graph-rebuild hitch; its overall frame times are excluded from resolution-matched comparisons. Final debugger runs omit this override.

Cross-three-floor and forced rollback test: 709 checks / 0 failures. An initial four failures exposed an overly narrow script allowlist: the formal scene uses `office_skeleton_world_base.gd`, not the base script. The allowlist was corrected after checking it does not override the edge policy, then the full lifecycle suite passed.

Corridor enemy transit remains a known failing suite: 45 checks / 6 failures in this run (five pursuit-state checks, one maximum-step check at 19.22). Prior baseline was 7 failures in these categories; do not claim AI pursuit is repaired from a changing failure count.

Overall stable 60 FPS is not yet verified. Runtime performance and final regression results are reported separately.

## Final live diagnostic

`.runtime/navigation_incremental_engine_game.log` and corresponding collector/summary/raw frames: actual output 2560x1440, world 640x360, RTX 5070 Ti, 14 enemies initially, 2 shooters / 302 enemy shots, 420 player shots, 10 s warm-up + 60 s sample. Both processes exited 0. Diagnostic median 20.026 ms / P95 28.324 ms includes debugger overhead and is not the ordinary game result.

Across this sample, maximum per-frame adjacency work was 1.402 ms (eight queries), not the intermediate 23.139 ms full rebuild. Worst search total was still 18.818 ms with eight searches in one frame. Hence repeated BFS can still be expensive; do not assert all navigation spikes or overall stutter are eliminated. Different encounter load means the earlier 14–23 ms search frames are not a paired causal FPS measurement.

## Final ordinary combat (no debug collector)

`.runtime/navigation_final_normal_combat.log`: same 2560x1440 / 640x360 settings, RTX 5070 Ti, 10 s warm-up / 60 s sample, initial 14 enemies, 2 enemy shooters / 361 shots, player 429 shots, peak eight projectiles, 3853 measured frames. Median **14.921 ms**, P95 **21.004 ms**, median draw calls 2062. Game assertions 0 failures, exit 0. This is the final implementation's live sample, not an old/new paired replay and not proof of sustained 60 FPS. Exit resource-leak warnings remain separate from assertions and are not silently declared fixed.

Final editor parse and scoped whitespace check passed. Final corridor re-run: 45 checks / 5 failures, exit 1; all five are the already recorded pursuit-state category. The earlier max-step failures did not recur in this run, but changing timing/identity makes that insufficient evidence of a repair. This suite is explicitly not counted among the 1571 passing checks.
