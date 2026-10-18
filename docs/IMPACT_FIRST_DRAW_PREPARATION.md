# Formal impact first-draw preparation — 2026-10-11

Muted, serial GPU runs: Godot 4.7.1 Compatibility, RTX 5070 Ti,
actual GPU image 1920x1080; formal pixelated world 640x360. No reduction of
furniture, lights, shadows, city geometry, enemy AI or effects.

## Investigation and measured boundary

Formal random floor seed 41001, controlled initial state, canonical steering
IDs, normal AI/physics/weapons, 10-second warmup and 60-second sample:

| Before this change | Player / enemy shots | Shooters | Median / P95 | Max |
| --- | --- | --- | --- | --- |
| Phase-only trace | 435 / 327 | 3 | 12.366 / 16.507 ms | 93.312 ms |
| Event/context trace | 432 / 394 | 3 | 14.545 / 19.821 ms | 68.034 ms |

The latter's 67.943-ms phase sample included a new impact carrier and CPU
particle emitter: drawing 55.520 ms. Coincidence does not establish that
particles caused all these stalls. Context/event instrumentation and
real-time gameplay produce different workloads; these are not matched A/B
FPS results.

## Targeted first-use evidence

`tests/impact_first_draw_probe.gd` freezes the actual generated floor and
camera; no gameplay advances. Twelve submissions use formal solid, metal,
glass and soft impact constructors, fixed particle seeds and a 0.07-second
presentation seek. All twelve change actual GPU pixels, exit 0.

| Preparation | First solid submission | Later submissions |
| --- | --- | --- |
| None | 22.235 ms | 1.224–1.896 ms |
| Private 64x64 mesh/particle prototype | 16.555 ms | 1.666–2.812 ms |
| Actual world, diagnostic-only preparation | 2.073 ms | 1.420–2.179 ms |
| Integrated formal loading preparation | 2.547 ms | 2.174–2.767 ms |

These times delimit creation-to-next-frame submission, not pure GPU timing.
The private particle prototype was withdrawn. Its historical log remains;
the private destruction helper is unchanged and does not prepare particles.
This is not the previously rejected persistent emitter pool.

## Production integration and lifecycle

`firearm_render_preparation.gd` submits four deterministic, presentation-only
carriers through the actual world while normal loading covers the frame and
gameplay is paused. They reuse the formal immutable particle mesh. There are
no collision hits, damage, physics simulation or added light slots. After
two draws the existing firearm preparation continues. All seven owned
temporary sources (four impacts plus projectile/muzzle/shell) are removed.
Invalidated floor tokens and freed worlds cancel and release owned carriers.

GPU three-floor lifecycle/cancellation/freeing test: 37 checks, zero failures,
exit 0. Frozen world image bytes, player position, content RNG, light state
and source/viewport counts are restored. Actual Main entry: 20 checks, zero
failures, exit 0; covered/frozen preparation, enemy timers/ammo/run clock
unchanged; initial elevator exit completes; first real rifle shot 6.017 ms.
Main loading 10497.562 ms includes the whole entry, not just added work.

Logs: `.runtime/impact_first_draw_probe.log`,
`impact_first_draw_prepared.log`, `impact_first_draw_formal_prepared.log`,
`impact_first_draw_production_prepared.log`,
`impact_preparation_lifecycle.log`, `impact_preparation_main_entry.log`.
Certificate-store and exit-resource warnings remain separate from assertions.
No midrange GPU measurement or whole-game stutter-complete claim is made.

## Subsequent live check (not a sustained-performance success)

Same seed/route/1080p, event/context instrumentation, 10 seconds warmup plus
60 seconds: 430 player / 363 enemy shots, three shooters, 14 initial enemies,
draw-call median 2074, frame median 15.437 ms / P95 21.995 ms, max 59.904 ms,
zero assertions failed / exit 0. No impact creation appears in the three
recorded >=40-ms samples. One coincides with ten projectiles/two muzzle
carriers, one has no node events, and one spends 36.596 ms between process
completion and drawing. This changes the next investigation; it does not
prove the impact caused the earlier spike or that all stalls are fixed.

Compared with the pre-change event trace, sustained median/P95 are worse;
different live trajectories/load prevent causal attribution, and no sustained
gain is claimed. Only the separately measured first-impact improvement is
accepted. Log: `.runtime/random_1080_impact_prepared_live.log`.

Final engineering checks: muted editor parse exit 0, no script/parse errors;
firearm impact 28 checks / zero failures; immutable mesh/emitter parity 210
checks / zero failures; both exit 0. Scoped diff and new-file whitespace
checks clean. Existing unrelated art/outline failures were not retested or
declared fixed. The rejected transform-guard test and its generated UID are
removed; production furniture transform updates remain unchanged.
