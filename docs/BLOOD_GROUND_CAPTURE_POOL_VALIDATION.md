# Floor-owned ground blood capture reuse — 2026-10-07

## Production contract

Every blood source remains a newly created authoritative BlackBloodEffect. Only its passive ground display carrier is pooled. Airborne geometry, wall/door stains, RNG, amount, colour, expansion, merge selection, real collision and floor membership are unchanged. Custom blood scripts use their old bridge path.

Two bins preserve the old capture sizes: 128x128 for impact/trail marks, 224x224 for death pools. Prewarm 18 small / 6 large before normal and staged floor control; retain at most 48 small / 16 large **idle** carriers. Active carriers are not evicted or reused. Overflow creates an extra display carrier rather than dropping a blood effect. A small mark consolidated into a large capture returns to the large bin.

Rebinding explicitly resets static-capture state and requests fresh pixels. Source exit hides the Sprite3D, disables the viewport, removes source ownership and returns the slot. Rollback restores exact original source bindings, including retained and destroyed overflow slots and enlarged captures. Pools belong to their floor and are destroyed across successful floor transitions.

## Creation evidence

`blood_ground_capture_production_profile.log`: same 24 live source objects across old/new/old groups, including all five stamp types and both capture sizes; fixed formal camera / frozen gameplay. 12 iterations per group / two warm-up iterations, no timed overlap with other test processes. All 24 captures are nonempty and world image differs from the no-blood image; exact formal-camera bytes match old/new/old.

Creation-only median **52.242 / 0.760 / 51.233 ms**, max 60.349 / 1.109 / 62.437 ms. The initial candidate repeat was 48.152 / 0.763 / 49.034 ms. This is a display-carrier creation-burst result, not full-combat FPS proof. Initial candidate had a GDScript type-inference parse error, was explicitly terminated, corrected, then rerun successfully.

## Visual and lifecycle checks

- `blood_carrier_camera_0..3.log`: actual world death-pool creation, old/new/old display path, four cumulative growth times, pixelation on/off × Palette 1/off. Exact nonempty camera pixels and growth data parity, 30 / 0 each, 120 total, exits 0. No manually reviewed gameplay video claim.
- `blood_carrier_final_lifecycle.log`: **701 / 0**, exits 0. Three floors, failed-generation rollback, 80-source overflow, 48/16 retention caps, unique active bindings, merged capture promotion and restored 224x224 extent. Also exhaust the large bin, destroy a promoted slot, and recover its original enlarged extent from source-owned metadata when reconstructing it.
- `blood_carrier_revision_fixed.log`: **27 / 0**, exit 0. One earlier assertion expected absorbed display bridges to be destroyed (24 / 1). Replaced that obsolete allocation requirement with stronger ownership/visibility checks: absorbed authority must be freed; retained carrier must have no owner, be hidden/disabled and belong to the idle pool. Initial failure is not concealed.
- `blood_carrier_office_blood_cross_room_test.log`: 11 / 0, exit 0.
- Final combat parity 79 / 0, ballistics 98 / 0, projectile history 19 / 0, query batch 26 / 0 and cutout lifetime 11 / 0, exits 0. Fixed-grid merge built-in asserts pass. Counted lifecycle/integration/visual/regression checks: **1092 / 0**, excluding uncounted creation-fixture image checks and built-in asserts. Editor parse and scoped diff check exit 0. Certificate-store and existing exit-resource warnings are recorded separately, not classified as assertion failures.

## Current sustained combat measurement

`blood_carrier_normal_combat.log`: actual current production, 10 s warm-up + 60 s sample, seed 41001, controlled initial state, bounded movement, no frozen AI and no concurrent diagnostic collector/test process. Compatibility / RTX 5070 Ti, 2560x1440 output / 640x360 world, pixelation + Palette 1, Dummy audio. 14 initial enemies, 2 enemy shooters / 337 enemy shots, 427 player shots, peak 13 simultaneous projectiles, 3904 sampled frames. Median **14.711 ms**, P95 **22.039 ms**, median draw calls 2110. Godot exit 0, fixture failures 0.

This is the current absolute workload result, not a matched old/new FPS comparison. Prior runs have different AI/death/load distributions. Creation spike reduction is proven; an overall FPS percentage is not. P95 still exceeds 16.7 ms, so overall stutter / sustained stable 60 FPS remain incomplete.
