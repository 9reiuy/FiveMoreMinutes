extends Resource
## Immutable CC0 gas frames, shared by all floor-owned explosion instances.
@export var frames: Array[Texture3D] = []
@export var source_frames := PackedInt32Array()
@export var source_fps := 29.97
@export var world_min := Vector3.ZERO
@export var world_size := Vector3.ONE
@export var source_archive_sha256 := ""
@export var attribution := ""
