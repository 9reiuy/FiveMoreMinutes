# Destruction first-use preparation — 2026-10-09

## Installed scope

Normal `Main` Dream loading now invokes `destruction_render_preparation.gd`
before the existing firearm preparation. Gameplay remains paused under the
real loading overlay. No actual furniture is damaged and no weapon is fired.
The 64x64 private World3D renders five formal material families through 16
point/spot shadow feature combinations, with the actual environment and sun
split mode. Its meshes, lights and viewport are destroyed before control is
returned. Permanent material anchors are bounded shared resources, not floor
nodes. It loads no retired 2D scene.

This is initial Main entry preparation, not an added preparation on every floor
and not automatic standalone-editor sample entry. Resident shader anchors
remain shared during the run. Three staged-floor tests exercise explicit
preparation / invalidation, not proof of every live cross-floor scenario.

## Why this path, not an emitter pool

Actual city/furniture sample traces show first furniture destruction spending
91.247ms drawing in a 99.631ms frame. An emitter-pool experiment retained the
same burst pixels but still stalled 102.861ms when furniture broke. It was
withdrawn; see `IMPACT_EMITTER_POOL_EXPERIMENT.md`.

Prototype destruction preparation repeats real 10s warm / 60s combat samples:

- Original: 4 shooters, 382 enemy / 430 player shots, median 14.210ms,
  P95 21.258ms; destruction frame 99.631ms / drawing 91.247ms.
- Prepared repeat: 4 shooters, 360 enemy / 434 player shots, median 13.189ms,
  P95 19.532ms. One real furniture destruction still creates all six meshes,
  removes the original furniture, and takes 12.563ms / drawing 4.930ms.
- The first prepared run: 4 shooters, 370 / 434 shots, median 12.511ms,
  P95 20.363ms, max 63.145ms. It did not yet report all destruction events, so
  that run alone is insufficient evidence of the destruction improvement.

AI identity / RNG seeds and initial timers are diagnostic matched settings;
real-time movement, physics and shots are not bit-identical replays. Do not
attribute the full median/P95 difference exclusively to this change. The
direct first-destruction evidence is the accepted outcome; 60FPS-wide P95
acceptance remains incomplete. RTX 5070 Ti / Compatibility / Godot 4.7.1,
NVIDIA 610.74, 2560x1440 output / 640x360 world; tests muted and serial.

The actual production helper was then rerun with
`--prepare-destruction-materials`: `city_destruction_production_live.log`,
19/0, exit 0. Four shooters / 554 enemy / 427 player shots; median 14.348ms,
P95 22.384ms. Real furniture destruction still creates all six pieces, but
takes 15.633ms / drawing 6.938ms. That confirms the accepted first-destruction
improvement on production code, not a passing prototype substituted for it.
The heavier enemy shot workload and remaining 61ms-class slow frames forbid
a claim that sustained combat or all first-use stalls are fixed.

## Production integration checks

`destruction_integrated_main_entry.log`: 20 checks / 0 failures, exit 0;
actual Main loading overlay, pause, deferred elevator exit and control handoff.
Player/enemy state, ammo, RNG, run clock and source count unchanged; no private
viewport at handoff. Total preparation 3080.812ms, destruction part 2203.715ms;
total entry loading 10067.631ms. First actual rifle shot remains 6.075ms.
Prior firearm-only entry was 8763.740ms / first shot 6.069ms. Loading timings
include generation variation; only reported preparation parts are direct costs.

`destruction_integrated_lifecycle_final.log`: 37/0, exit 0. Three staged floors
cover pixelation on/off and Palette on/off; before/after actual world bytes are
identical, light states/RNG/player/source count restored, viewport counts stable.
Private world released during floor-token replacement and world destruction.
First destruction preparation 1343.416ms; resident repeats 23.256 / 24.813ms.

Exit resource warnings are not clean-log acceptance: normal Main still reports
the same two 6888-byte texture RIDs as the earlier Main baseline. This run also
reports six ObjectDB objects / three resources at shutdown, while lifecycle
does not retain floor/preparation viewports. Do not claim all shutdown warnings
are fixed or all-project regressions are green.

Final muted engineering checks: editor parse exit 0, no script/parse errors;
random-floor lifecycle 729/0, managed light/shadow 73/0, destruction material
lifetime 74/0, each exit 0. The first shadow-suite invocation used a missing
filename (exit 1, no tests run); corrected `managed_light_shadow_test.gd` is the
73/0 result. Material lifetime reports three ObjectDB objects / one resource
at shutdown. Scoped diff whitespace check and owned untracked-file trailing
whitespace scan are clean. Existing unrelated outline integration failures
were not rerun here and are not reclassified as passing.
