# Impact mesh reuse and formal-world first-use preparation investigation

Scope: SOLO, Compatibility, RTX 5070 Ti / NVIDIA 610.74, muted tests. Preserve
particle counts, colors, trajectories, lighting/shadow settings and combat.
No claim of overall stable60 or completed stutter repair.

## Production change: immutable impact resource reuse

`firearm_impact_visual_3d.gd` now retains one shared QuadMesh/StandardMaterial.
Each hit still creates an independent CPUParticles3D emitter and owns its
color, normal, velocity, gravity, amount and 0.34s carrier lifetime. The mesh
holds no source/floor references. No emitter or simulation is shared.

Actual burst constructor GPU fixtures, 12 post-birth draws per burst to cover
the first particle physics step (not simply setup timing):

| Factory | Initial peak ms | Repeat 1 ms | Repeat 2 ms |
| --- | ---: | ---: | ---: |
| Exact former factory subclass | 29.817 | 8.652 | 8.947 |
| Shared factory | 31.766 | 4.421 | 3.287 |

These are separate fixed-world runs, not a matched live-FPS comparison. The
first compilation cost is NOT eliminated. Follow-up shared run: 28.240 /
2.719 / 2.930ms. Same frozen emitter with fresh versus shared mesh: image bytes
equal; hiding that emitter changes pixels, so comparison is not of invisible
particles (`impact_mesh_visible_pixel_parity.log`, exit 0). Particle count six
is retained. Cross-process particle images are not claimed identical.

`impact_mesh_reuse_regression_fixed.log`: 210 checks / 0 failures, exit 0,
four surface types through three floors, independent emitter parameter parity,
original mesh/material flags and no retained floor nodes. The first test
attempt had a typed-variable parse failure; its log is not a green result.
`shared_impact_collision_regression.log`: 28 checks / 0 failures, exit 0.

Actual live sample `shared_impact_live_combat.log`: 14 enemies initially, 2
shooters, 220 enemy / 425 player shots, exit 0 / failures 0, 10s warm-up then
60s measurement. Median 17.708 / P95 25.016 / max 104.905ms. Workload differs
from previous runs: no causal whole-game speed claim. Large stalls remain.

## Larger first-use costs: diagnosis and preparation prototype

`firearm_first_use_probe.gd`: each mode runs in a separate process, actual
formal world/stock constructors, paused gameplay and no enemies. Results are
NOT normal Main-entry loading times or sustained FPS.

| First-use mode | Birth draw ms | Subsequent burst birth draws ms |
| --- | ---: | --- |
| Projectile | 27.770 | 3.556 / 3.571 |
| Muzzle flash without lighting | 2.910 | 3.004 / 3.299 |
| Muzzle shadow light only | 575.335 | 3.022 / 3.178 |
| Shell | 201.901 | 2.629 / 2.528 |
| Full stock rifle shot | 617.680 | 4.533 / 3.960 |

The isolated light birth creates no sources; setup is 0.027ms. This changes
the next action: investigate first light/capture rendering, not just short
particle source allocation. Backend pipeline counters are still unsupported
as evidence; timings do not themselves identify a native compiler function.

Test-only `muzzle_light_first_use_probe.gd` primes the existing formal-world
light, restores all six light slots/internal scheduling fields and checks
pixels after restoration. Light-only prep: 428.719ms, next pulse 4.236ms;
pixel bytes equal. Full visual prep adds a disabled zero-damage projectile,
stock flash and stock shell, restores content RNG, releases local projectile
light and deletes only its three owned sources. Full prep: 621.889ms, following
stock shot 4.880ms / subsequent-frame max 4.365ms. RNG, source count and frozen
formal image bytes restored exactly (`firearm_full_primed.log`, exit 0).

This moves work rather than removing it. The current implementation integrates
the firearm-only worker into normal Main loading while the fade/loading overlay
covers the world and gameplay is paused. It prepares the existing shadow budget
at completed opacity, then restores the original fade; the corridor landing
receiver set is rendered without moving the player or camera. Cross-floor
loading does not automatically invoke it yet. Do not claim all rooms/material/
light combinations are covered by the initial pulses.

Normal Main entry, seed 120, separate serial GPU processes:

| Case | Measured preparation ms | Total loading ms | First stock shot ms |
| --- | ---: | ---: | ---: |
| Preparation skipped diagnostic | 0 | 7829.388 | 662.874 |
| Shadow fade prepared, no landing pulse | 1654.217 | 8579.935 | 86.314 |
| Completed shadow fade plus landing pulse | 1849.444 | 9109.414 | 6.493 |
| Final repeat, same candidate | 1830.659 | 8763.740 | 6.069 |

This is RTX 5070 Ti / Compatibility / NVIDIA 610.74, not midrange-device proof.
The total loading difference includes run-to-run generation variation; only
the worker timer directly measures preparation. Each Main fixture passed 18
checks, exit 0: real overlay covers the world, initial elevator exit is deferred,
player/enemy positions and timers, ammo, RNG and run clock remain unchanged,
temporary sources and light assignments are released, and control returns.
Main teardown still emits texture/resource warnings also present in the skipped
baseline; these are not silently classified as clean teardown.

`firearm_preparation_lifecycle.log`: 29 checks / 0 failures, exit 0, three actual
staged floors across pixelation and Palette settings. Frozen GPU world images
match byte-for-byte, source counts/RNG/player/light state restore exactly;
floor-token replacement and world destruction cancel safely. Initial fixture
attempts had three image failures: pausing before generation left player capture
unsynchronized (the player bridge is not a child of the generated bridge root).
The fixture now synchronizes the actual frozen presentation before taking its
baseline; the image equality assertion remains exact. Before/after PNGs are
retained in `.runtime/preparation_{before,after}_{0,1,2}.png`.

Follow-up `prepared_firearm_live_combat.log` (direct random-floor fixture invokes
the same worker, not Main): preparation 2205.549ms, 10s warm-up then 60s sample,
14 initial enemies / 3 shooters / 350 enemy shots / 428 player shots. Median
17.160, P95 22.135, P99 26.456, max 96.770ms, median 2161 draws; 2560x1440 output,
640x360 world, exit 0 / failures 0. Canonical identity flag was misspelled in this
run, so identities were process-native; workload differs from the earlier
2-shooter run. No causal P95 improvement is claimed. Cold first ten gameplay
seconds still peaked at 526.549ms (first deferred pause/settings UI construction
plus shot), with further impact/blood/light stalls. These remain unresolved;
normal Main already constructs UI during loading, so that fixture peak is not
presented as a measured normal-Main first-control stall.

One priming fixture initially had a typed-image parse failure and remained
live; it was explicitly interrupted. An overlapping full-shot run is excluded
from timing evidence. The corrected light and full-shot results above were
run serially after verifying both prior handles terminal.

Integration checks: `shared_impact_floor_lifecycle.log` 729 checks / 0 failures,
exit 0, including three-floor cleanup and failed-generation rollback.
`shared_impact_editor_parse.log` editor parsing exit 0 with no parse/script
errors. Scoped diff check plus explicit trailing-whitespace checks for new
untracked files passed for that earlier validation batch. Immutable impact mesh
reuse and normal Main-entry first-shot preparation are now integrated. Continued
live-combat timing remains necessary; first-shot latency is not sustained FPS.

Current headless batch: editor parse exit 0, no parse/script errors; impact reuse
210/0, impact collision 28/0, floor lifecycle 729/0, managed shadows 73/0, all
exit 0. Office shadow integration exits 1 with 47 checks / 3 failures: the
all-furniture-mesh outline assertion fails once per floor (130/257, 197/413,
and 134/269). It never invokes preparation; no outline
production logic was changed here. This is an unresolved outline-contract issue,
not reported as a passed regression. Dummy material warnings are separate.
Scoped tracked-file diff check and untracked-file whitespace checks pass. Whole
worktree diff check reports a pre-existing extra EOF blank line in
`scenes/ui/dream_hud.tscn`, outside this change; it was not edited to hide it.
