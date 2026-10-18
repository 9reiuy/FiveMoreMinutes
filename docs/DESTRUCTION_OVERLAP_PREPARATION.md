# Destruction preparation overlap prototype (not shipping)

RTX 5070 Ti, Compatibility/Godot 4.7.1, muted GPU tests. Retains the original
production debris material, count, fading, lights and camera. Test-only files;
no formal loading integration. The previous turn's 88.7ms furniture-destruction
frame motivates this work, but shader compilation is not proven as its cause.

## Sequential-state preparation overlapped with staged generation

Initial prototype had incorrect accounting: a queued/freed task was tested as
nonnull after cleanup, so combined time fell back to generation+warm durations.
The viewport count also included the intentionally live temporary viewport at
the baseline. `destruction_overlap_budget.log` exits 1, 21 checks/2 failures;
not accepted. Corrected accounting excludes only the explicitly tagged private
test viewport and records completion time before freeing the task.

`destruction_overlap_budget_corrected.log`, 21/0, exit 0:
initial warm 878.943ms; floor 2 generation 2207.642ms, combined 2658.960ms,
451.318ms post-generation additional wait; floor 3 1420.538/1751.872ms,
still within 2000ms ride minimum. Frozen before/after bytes zero on all floors,
camera/environment/sun unchanged, temporary viewports released.

## One private view, 16 simultaneous light feature combinations

`destruction_parallel_variant_probe.gd` builds independently light-masked groups
in one own-world viewport, original untextured furniture-debris material,
copied environment and directional-shadow settings. Sixteen Omni/Spot feature
states are rendered together instead of toggled sequentially for 32 draws.
It does not establish that every native shader/pipeline needed by the formal
game has been covered. Only actual combat measurements can test that hypothesis.

The first parallel-overlap run stalled and was explicitly interrupted, exit 1;
the two verified PIDs were absent afterwards. Adding fixture stage reports and
the existing render watchdog permitted a completed retry. No restart based
solely on an observation timeout. Retry `destruction_parallel_overlap_staged.log`
21/0, exit 0, floor 2 still 214.724ms above the 2000ms minimum.

Final prototype reads back its 64x64 private target after two actual draws, then
schedules deferred deletion instead of awaiting four additional full-floor
process/render frames. A weak reference lets the caller verify actual deletion
after settling; the probe never falsely reports already-freed on return.

`destruction_parallel_readback_budget.log`, 21/0, exit 0:

| Floor | Generation ms | Completion ms since start | Prep elapsed ms | Remaining after generation ms |
|---|---:|---:|---:|---:|
| Initial | not measured | 638.853 | 638.853 | n/a |
| 2 | 2041.925 | 2044.811 | 1061.583 | 2.886 |
| 3 | 1462.902 | 1465.220 | 606.735 | 2.318 |

Both staged jobs finished before generation returned. Do NOT call the last
column total loading overhead: generation/render phases also bear the prep
work, and there is no matched no-prep generation control. Initial warm costs
vary substantially across runs and are not a startup upper bound.

All three frozen image comparisons have zero changed bytes; formal camera,
environment and sun retained; no temporary viewport accumulation. On staged
floors preparation finished before baseline image capture, so those images
alone do not independently prove the private preparation never transiently
altered the formal image. Initial before/after and explicit state/lifetime
checks provide the narrower evidence. ObjectDB/resource exit warnings remain
separate from assertions. Full-game/stable60 objective remains unproven.

## Actual combat result: NOT accepted as a stutter fix

`parallel_destruction_live_probe.log`, original production world/bridges,
prototype prep only: 10s warm-up/60s measurement, 13 enemies initially,
2 shooters/34 enemy shots and 440 player shots, exit 0/failures 0. Prep took
1651.938ms in this run (not the smaller initial fixture number). Frame median
9.805/P95 12.987/max 78.364ms. Different enemy fire and destroyed content from
the original baseline means these median/P95 values are not causal gains.

Long frames remain: 41.184ms (drawing 26.497) and 78.350ms (drawing 69.550).
The latter resource interval adds a Node3D and eight MeshInstances. No
Furniture3DDebris spawn event occurred in this sample, so it provides NO
validation that first furniture destruction is fixed. Eight meshes resemble
the glass-shard path, but counts alone do not identify the family. Added the
optional `--destruction-family-events` test label to preserve GlassShards and
DoorShards parent names; production events and gameplay are unchanged.

Decision: do not integrate this preparation into loading. Next useful action
is family-specific first-destruction coverage (including glass and door
materials), followed by causal, controlled bursts and live verification.

Follow-up editor parse (`destruction_overlap_editor_parse.log`) exit 0, no
parse/script errors. Material lifetime regression (`destruction_overlap_lifetime.log`)
74 checks/0 failures, exit 0; exit resource warnings are not those assertions.
Scoped diff whitespace check clean. All owned runs terminal; two experimental
interruptions and the first fixture's two failed checks remain explicitly
non-green. No production file was changed in this follow-up.

## Family coverage and subsequent live diagnostics

Actual constructors (`tests/destruction_family_first_draw.gd`), RTX 5070 Ti,
muted Compatibility GPU runs: glass first draw was 75.755ms without private
preparation versus 3.899ms after all-family preparation; airborne blood was
26.043ms versus 3.716ms. Eight pieces remain in each burst. These are separate
process-cold runs, not a paired whole-game gain. Private preparation on the
same existing glass/blood meshes passed byte-exact image comparisons and
temporary-viewport release checks. New glass bursts have a small unresolved
first/repeat image variance even without preparation; do not claim first-frame
image equivalence across processes. No formal loading integration is accepted.

All-family live coverage: median 13.507/P95 18.850/max 70.697ms, 3 shooters,
253 enemy/433 player shots, exit 0. With airborne preparation: median
13.439/P95 19.124/max 104.894ms, 3 shooters, 219 enemy/432 player shots, exit 0.
The 104.894ms resource interval contained no added/removed nodes. Therefore
preparing these effects is not a sufficient full-game stutter fix.

`family_glass_counter_probe.log`: actual first draw 80.249ms, repeats
2.293/2.400ms; all five RenderingServer pipeline counters stay zero before and
after. Compatibility counter coverage is unestablished. Zero must NOT be used
as evidence that compilation did not occur; avoid those calls in live sampling.

Added optional read-only `--render-state-profile` snapshots of interior, sun
and visible muzzle shadow state to resource rows. `live_shadow_state_probe.log`
ran to completion but failed the workload gate: only 1 shooter/24 enemy shots,
443 player shots. Its median 8.221/P95 11.854/max 23.471ms is NOT an accepted
improvement. Native exit-resource warnings remain separate from the workload
assertion (exit 1). No shadow-setting changes were made.

`--stable-identities` previously stabilized enemy steering IDs only between
passes in one process. Optional `--canonical-identities` now supplies 10000 +
enemy index for cross-process diagnostics, retaining AI rules and timing
cadences; formal gameplay does not use this flag. This prevents added diagnostic
objects from changing the identity-derived separation side/perception phase.

Canonical seed 42001 full sample also failed its workload gate (0 measured
shooters/0 enemy shots); max 23.551ms is not acceptance. Do not weaken the gate.

Added `--cold-frame-profile`: keep the existing 10s warm-up + 60s sample, but
separately record first-ten-second intervals and >=25ms node/light snapshots.
The first resumed frame includes pending deferred UI/world setup; it is NOT
evidence of the normal Main loading-screen latency or of a specific effect cost.

Canonical seed 41001 ten-second preflights both passed their workload gates:
original 2 shooters/56 enemy/63 player shots; prepared 3 shooters/89 enemy/61
player shots. Original first resumed frame 1278.832ms, subsequent furniture
destruction interval 101.488ms and first airborne interval 70.831ms. Prepared
probe cost 2539.286ms, first resumed frame 1493.056ms, later maxima 94.769 and
84.671ms on shot intervals and first airborne interval 52.196ms. Destruction
spike >=25ms did not recur in that prepared sample, but workload/timeline differ;
this is NOT a paired overall performance gain. No total-stutter solution or
production loading integration is accepted. Next diagnosis must include the
first-use projectile/light/capture paths and separate deferred startup from
gameplay, not just warm-up-excluded medians.

Follow-up validation: `render_state_lifetime_regression.log` 74 checks / 0
failures, exit 0; `render_state_editor_parse.log` editor parsing exit 0 with no
parse/script errors. Scoped diff whitespace check passed. Test-only diagnostic
changes; formal graphics, enemy rules and lighting settings untouched.
