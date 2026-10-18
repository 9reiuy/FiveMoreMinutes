# Render-stall control and rejected body-cache candidate — 2026-10-07

## Control, not a gameplay benchmark

`tests/render_stall_control.gd`: same Compatibility renderer/application, RTX 5070 Ti, 2560x1440 output and 640x360 3D target, one cube/directional-shadow light, no combat. Cap 120 fps, warm-up 10 s, sample 60 s. `.runtime/render_stall_control.log`, exit 0: 7201 frames, median 8.329 / P95 8.815 / P99 9.244 / max 10.726 ms, no display intervals >=40 ms.

This sample did not reproduce the combat test's 100+ ms stalls. It does **not** prove the OS/driver can never stall, or attribute the cause to a particular gameplay feature. The next investigation remains game-workload-specific, not a speculative system-settings change.

## Body-only pixel cache: withdrawn

Candidate changed only body viewport redraw decisions, with every source/copy/gameplay/shadow still updated normally. Shader/custom draws stayed live. Enemies use the shared sprite-alpha-outline shader, so an exact known-shader/code guard and all eight mutable uniform values were needed to safely cache them. Unknown/TIME shaders fell back to continuous capture.

Initial fixture incorrectly required a nonzero office centre; the approved sample's actual office is centred at (0,0). That invalid gate failed once and was repaired to require a positive room area and actual visible subjects. Initial unrestricted-shader fallback rendered every enemy continuously and did not establish any optimization. These initial runs are not successful acceptance.

Valid representative fixed scene: 14 actual on-camera characters, once-per-frame ordinary update per character and two player-only muzzle snapshot requests. Old/candidate/old, 2 s warm-up + 10 s sampling per group. `.runtime/character_body_capture_valid_gpu.log`: median **5.650 / 5.897 / 6.216 ms**, P95 **7.361 / 8.350 / 8.640 ms**. **45 checks / 0**, exit 0: fixed image and first-rendered-frame pose comparisons matched, including outline/flash uniform mutations and corpse rotations. Unit draw-mode checks were 13/0, exit 0. No reproducible meaningful frame-time gain is established by the bracketing drift; candidate is slower than the first original sample and essentially the bracketing average.

The public UPDATE_ONCE property can remain set after the engine consumes the one draw, so non-disabled mode counts were not presented as actual per-frame redraw counts. Shader uniform verification adds work. Following the instruction to skip insignificant gains, the candidate code, flag and dedicated tests were removed, not installed in production. Existing auxiliary capture caching and all previously retained optimizations remain unchanged. Diagnostic logs and this decision record are preserved; transient test assets are regenerable. Overall combat stutter remains unresolved.
