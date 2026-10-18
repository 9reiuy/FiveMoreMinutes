extends SceneTree
const GENERATOR = preload("res://scripts/dream/office_skeleton_generator.gd")
const WORLD = preload("res://scripts/dream/office_skeleton_world_base.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool,description: String) -> void:
	checks += 1
	if not ok: failures.append(description); print("FAIL ",description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_msec()
	var selection: Dictionary = {}
	# The exact production uniform draw; retries must not redraw skeleton type.
	for candidate_seed in 1000:
		var rng := RandomNumberGenerator.new()
		rng.seed=candidate_seed
		var selected: String = GENERATOR.TYPES[rng.randi_range(0,3)]
		selection[selected]=int(selection.get(selected,0))+1
	for type in GENERATOR.TYPES:
		check(int(selection.get(type,0))>150 and int(selection.get(type,0))<350,"uniform type coverage "+type)
	for type in GENERATOR.TYPES:
		for seed in range(1,11):
			var world := WORLD.new()
			world.native_skeleton_type=type
			check(world.generate_layout_only(seed),"%s/%d native floor" % [type,seed])
			if world.skeleton_source.is_empty(): world.free(); continue
			var signature := JSON.stringify(world.skeleton_source)
			check(world.generate_layout_only(seed),"%s/%d repeat" % [type,seed])
			check(signature == JSON.stringify(world.skeleton_source),"%s/%d deterministic" % [type,seed])
			check(world.rooms[world.spawn_room_id].grid_rect.size == Vector2i(14,10),"%s/%d reception" % [type,seed])
			check(world._validate_door_sides(),"%s/%d doors" % [type,seed])
			check(world.glass_runs.size()>1,"%s/%d glass" % [type,seed])
			check(world.rooms.filter(func(r: Dictionary) -> bool: return r.sample_key == "smoking").size()<=1,"%s/%d smoking max one" % [type,seed])
			world.free()
			print("NATIVE seed ",type,"/",seed," elapsed_ms=",Time.get_ticks_msec()-started)
	var fallback := WORLD.new()
	fallback.use_native_office_skeletons=false
	check(fallback.generate_layout_only(98765),"legacy generator remains usable")
	check(fallback.skeleton_source.is_empty(),"legacy mode has no skeleton presentation")
	fallback.free()
	print("NATIVE RESULT checks=",checks," failures=",failures.size()," elapsed_ms=",Time.get_ticks_msec()-started)
	quit(0 if failures.is_empty() else 1)
