# Furniture redundant wake-up repair

Scope: remove an identical velocity write from the shared furniture physics
callback. No forced sleep, epsilon, changed damping, collision, damage or force
values. The engine's ordinary sleep/wake solver remains authoritative.

Exact engine source (4.7.1/a13da4feb) confirms that direct-state velocity writes
call `body->wakeup()` before setting the velocity:
[Godot direct body state](https://github.com/godotengine/godot/blob/a13da4feb/modules/godot_physics_2d/godot_body_direct_state_2d.cpp#L60-L63).
The source checks equality on the final clamped velocity before submitting it;
changed contact/bounce/max-speed results retain the original write. It does not
reduce furniture, enemy, physics or display update rates.

`furniture_sleep_probe.log`: original remains awake at zero velocity; candidate
sleeps and a real off-centre combat impulse wakes it. Matching velocity,
rotation and displacement: 7 checks / 0 failures, exit 0 (pre-default probe).

RTX 5070 Ti, Compatibility, 83 furniture visuals, seed 41001. Native physics
remains active; player/enemy logic frozen only for isolation. Two-second settle,
eight-second sample per group (`furniture_sleep_idle_perf.log`):

| Group | Active 2D median | Frame median / P95 | Physics window-max median |
|---|---:|---:|---:|
| Original | 80 | 5.112 / 6.896 ms | 1.846 ms |
| Corrected | 0 | 5.068 / 7.739 ms | 1.415 ms |
| Original repeat | 80 | 5.382 / 7.527 ms | 1.907 ms |

Physics monitor is the repeated one-second maximum, NOT a per-step CPU timer.
This proves natural resting-body deactivation and lower local physics monitor
cost; it does not establish overall FPS/P95 improvement.

Live same-initial-state original/corrected/original run, normal AI, collisions,
wall-directed shooting and bounded movement, 10-second warm-up/60-second sample:

| Group | Active 2D median | Frame median / P95 | Enemy shots / shooters |
|---|---:|---:|---:|
| Original | 91 | 15.773 / 21.189 ms | 362 / 2 |
| Corrected | 17 | 19.053 / 27.911 ms | 486 / 3 |
| Original repeat | 89 | 17.961 / 26.607 ms | 180 / 3 |

`furniture_sleep_combat_ab.log`: workload ratio 180/486=.370 < .8, exit 1,
one workload assertion. No paired whole-game speed claim is permitted. The
repair is retained as a small, verified unnecessary-wake-up removal, not as
completion of the overall stutter objective. Existing exit-resource warnings
are separate from assertion failures. The unverified matched-live and overall
frame-time target remain open.

Production default validation (`sleep_repair_*` logs): sleeping/real impulse
wake/translation/body rotation/seat rotation 8/0, combat parity 79/0, three-floor
cleanup and failed-generation rollback 729/0, all exits 0. Furniture rotation
suite passed (it does not print an assertion total). Scoped whitespace check
clean; prior furniture-sync/door-scan/tracer-byte experimental hooks absent.
Editor parsing exited 0 with no parse errors.
