extends Node
## Test-only preparation task; can overlap the existing yielded floor generation.
var finished := false
var result: Dictionary = {}
func begin(world: Node3D) -> void:
	var probe: Script=preload("res://tests/support/destruction_parallel_variant_probe.gd") if "--parallel-variants" in OS.get_cmdline_user_args() else preload("res://tests/support/destruction_mixed_light_probe.gd")
	result = await probe.run(get_tree(),world)
	finished = true
