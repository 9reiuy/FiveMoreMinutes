# Operation-local blood query reuse — 2026-10-07

## Retained production change

The formal 3D world supplies a synchronous blood-floor query context. During one `_setup_pixel_pool` operation, reuse one point query, one ray query, the current transform and the relevant direct space states instead of allocating parameters and traversing the world callback for every unsafe pixel. Floor-cell membership, point collision and ray collision are still evaluated at every required pixel. Conservative 16-pixel convex-hull caching is unchanged.

No frame-spanning cache, result approximation, geometry reduction, new deferred work or gameplay change. The context is local to the call, so moving doors, destroyed windows and regenerated floors are checked afresh next operation. Point/ray collision masks and default query flags match their old independent paths. Custom blood subclasses retain their virtual floor/ray validators; contexts without the explicit world batch contract use the original fallback.

## Local evidence

`query_batch_final_blood_query_batch_test.log`: actual generated floor 42001, 16 wall/border origins, source rotation/nonuniform scale cases, old/new/old ordered growth cells, initial stamp arrays and RNG state identical. Tiny 0.2-pixel obstacle between corner rays is still detected; adjacent visible cells retained; moving that obstacle between operations changes the result immediately. Independent operations allocate independent query parameters. Custom subclass virtual-validator call counts and shape remain identical to their old fallback. 26 checks / 0 failures, Godot exit 0.

Final complete synchronous pool setup median old/new/old: **24.711 / 17.775 / 23.600 ms**; P95 28.263 / 18.915 / 27.089 ms. About 5.8–6.9 ms / 25–28% saved for this CPU-only wall-aware setup fixture. Earlier repeat was 21.003 / 15.457 / 21.036 ms, also faster locally. Not total game frame time, not a stable-60 claim.

`blood_query_camera_final_0..3.log`: formal Camera3D, pixelation on/off × Palette 1/off, actual world death-pool creation, four cumulative growth times, old/new/old. Nonempty floor/capture images and exact image bytes plus growth data parity, 30 checks / 0 failures per mode (120 total). No manual dynamic-video acceptance claim.

## Integration

- `query_batch_random_floor_lifecycle_test.log`: 522 / 0, three-floor cleanup and failed-generation rollback.
- `query_batch_office_blood_cross_room_test.log`: 11 / 0, actual opening/solid-wall/void checks.
- `query_batch_final_blood_revision_integration_test.log`: 24 / 0.
- `query_batch_final_blood_pool_merge_test.log`: built-in asserts pass, fixed-grid masks, transforms, thin wall, growth and merge rules retained.
- `query_batch_final_dream3d_combat_parity_test.log`: 79 / 0; ballistics 98 / 0; projectile history 19 / 0.
- `query_batch_parse.log`: editor parse exit 0; scoped diff check exit 0. Counted target/integration/camera assertions total 899 / 0, excluding the uncounted built-in pool assertions and deliberately failed combat workload-matching gate.

## Full-combat boundary

`blood_query_normal_combat_ab.log`: same seed 41001, controlled initial state and bounded route, 10 s warm-up + 60 s per old/new/old group. Compatibility, RTX 5070 Ti, 2560x1440 output / 640x360 world, pixelation + Palette 1, muted.

Median 18.911 / 17.924 / 16.930 ms; P95 29.931 / 28.297 / 25.128 ms. Player shots 417 / 421 / 424, enemy shots **410 / 238 / 220**, three enemy shooters each. Firing-load matching gate failed (required minimum/maximum >= 0.8), fixture reports one failure and deliberately quits 1. This is an invalid overall-performance comparison, not a gameplay assertion failure. The PowerShell wrapper displayed the final log and therefore its outer command exit was 0; use the fixture result/gate as evidence, not that wrapper code.

Do not claim full-combat FPS improvement from this run. The isolated repeated pool-setup gain is retained, but overall stutter and stable 60 FPS remain uncompleted. Prior known corridor-transit baseline (45 checks / 7 failures) was not changed or reclassified by this patch.
