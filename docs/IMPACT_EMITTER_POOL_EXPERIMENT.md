# Hit emitter reuse experiment — 2026-10-09

Not installed. RTX 5070 Ti / Compatibility / Godot 4.7.1, muted, serial GPU runs.
Floor-owned prototype retains 24 separate emitters per solid/metal/glass/soft
family. Geometry, amount, direction, colors, lifetime and depth remain formal.
Fixed-seed seek at 0.07s uses `CPUParticles3D.request_particles_process` only in
the visual fixture. All four types actually have visible pixels and original /
reused GPU world output is byte-exact. 16 checks / 0 failures, exit 0, floor
regeneration clears the pool. Script-resource exit warnings remain separate.
Initial fixture failed because a display preload ran before autoload setup;
the corrected fixture dynamically loads it. That failed attempt is not a pass.

Live sample runs each warm 10s and measure 60s, actual furniture-review scene,
camera movement, normal AI/shooting and city lights. Diagnostic canonical
steering IDs, enemy seeds and initial timers match; real-time input and physics
are still not bit-identical replays, and shot workload must be reported.

| Run | Player/enemy shots | Enemy shooters | Median / P95 | Max slow frame |
| --- | --- | --- | --- | --- |
| Original | 430 / 382 | 4 | 14.210 / 21.258ms | 99.631ms |
| Reuse | 429 / 349 | 3 | 14.657 / 21.485ms | 102.861ms |

No meaningful gain, even with slightly lighter candidate enemy workload.
The prototype, its in-memory scene override and GPU fixture were removed;
no disk scene, material or production emitter was changed. Logs and PNGs
remain in `.runtime/impact_pool_*` and `.runtime/city_impact_pool_live_*`.
Diagnostic identity flag remains in the optional sample performance test.

Both largest slow frames coincide with furniture destruction: original
99.631ms (drawing 91.247ms), reuse 102.861ms (drawing 93.515ms), each creates
one furniture debris carrier and six meshes while removing furniture meshes.
This changes the next investigation to first rendering of destruction
materials. It does not prove all stutter is shader compilation.

Particle seek / seed API reference:
https://docs.godotengine.org/en/4.7/classes/class_cpuparticles3d.html
