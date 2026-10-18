# Rejected: skip identical furniture transform setters

Godot 4.7 Node3D setters propagate dirtiness even for identical values:
[official source](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/scene/3d/node_3d.cpp),
`set_position` and `set_rotation`. This suggested a possible native rendering
cost, but mechanism is not proof of a meaningful game-performance improvement.

Prototype compared float32 Vector3 values exactly, without approximate motion
thresholds. Furniture, contact shadows and swivel seats only wrote changed
transforms. Both formal physics/display callbacks and all source state reads
were retained. No geometry, light, collision or gameplay was removed.

Formal random floor seed 42001, muted Compatibility, RTX 5070 Ti / NVIDIA
610.74. 20 checks / 0 failures / exit 0: actual GPU parity for four source
translation/rotation/height poses and all four pixelation/Palette combinations.
Frozen-floor A/B/A benchmark, 240 frames per arm, 856 draw calls unchanged:

| Arm | Median | P95 | Passive observer transform notifications |
| --- | ---: | ---: | ---: |
| Original | 2.762 ms | 3.352 ms | 22560 |
| Guarded | 2.696 ms | 3.514 ms | 0 |
| Original repeat | 3.003 ms | 3.846 ms | 22560 |

The first median difference is only 0.066 ms and P95 does not establish a
repeatable improvement. Eliminated counters are not sufficient grounds for
shipping the extra comparisons. Following the user's instruction to skip
small impacts, the production edit and prototype test were removed. Original
furniture synchronization is restored. Evidence is retained in
`.runtime/furniture_transform_guard_gpu.log`; no live-combat FPS gain is claimed.
