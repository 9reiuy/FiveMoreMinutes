extends SceneTree
const GENERATOR = preload("res://scripts/dream/office_skeleton_generator.gd")
const ADAPTER = preload("res://scripts/dream/office_skeleton_layout_adapter.gd")
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func run() -> void:
	var old_area := 0
	var new_area := 0
	var old_occupied := 0
	var new_occupied := 0
	for type in GENERATOR.TYPES:
		for seed in range(1,11):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var old := GENERATOR.generate(rng,{"type":type,"seed":seed})
			rng.seed = seed
			var compact := GENERATOR.generate(rng,{"type":type,"seed":seed,"compact":true})
			check(not compact.is_empty(),type+"/"+str(seed)+" compact generation")
			if compact.is_empty():
				quit(1)
				return
			var layout := ADAPTER.compile(compact)
			check(GENERATOR._validate(layout),"actual footprint and wide routes")
			check(layout.rooms[layout.spawn_room_id].grid_rect.size == Vector2i(14,10),"reception unchanged")
			check(compact.rooms.size() == old.rooms.size(),"room count unchanged")
			for room in compact.rooms:
				if room.id == "entry":
					for door in compact.doors:
						if door.a == "entry" or door.b == "entry":
							check(not door.vertical and int(door.line) == int(room.bounds.y),"reception connects only opposite elevator")
				if GENERATOR.SAMPLE_SIZES.has(room.id):
					var target: Vector2i = GENERATOR.SAMPLE_SIZES.get(String(room.kind),GENERATOR.SAMPLE_SIZES[room.id])
					var size := Vector2i(int(room.bounds.w),int(room.bounds.h))
					check((size.x <= target.x and size.y <= target.y) or (size.x <= target.y and size.y <= target.x),"sample-scale ordinary room " + String(room.id))
			for room in old.rooms:
				if not ADAPTER.HALLS.has(room.id) and room.id != "entry": old_area += room.cells.size()
			for room in compact.rooms:
				if not ADAPTER.HALLS.has(room.id) and room.id != "entry": new_area += room.cells.size()
			for item in old.furniture:
				if item.room != "entry": old_occupied += int(item.w)*int(item.h)
			for item in compact.furniture:
				if item.room != "entry": new_occupied += int(item.w)*int(item.h)
			print("COMPACT ",type,"/",seed," attempts=",compact.native_attempts)
	check(float(new_area)/old_area < .85,"combat space reduced at least 15 percent")
	var density_ratio := (float(new_occupied)/new_area)/(float(old_occupied)/old_area)
	check(density_ratio > 1.15,"furniture footprint density increases at least 15 percent")
	print("COMPACT checks=",checks," failures=",failures," combat_area_ratio=",float(new_area)/old_area)
	print("FURNITURE footprint_density_ratio=",density_ratio)
	quit(0 if failures == 0 else 1)
