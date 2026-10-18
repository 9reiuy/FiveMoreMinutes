extends SceneTree
const ADAPTER = preload("res://scripts/dream/preview/office_skeleton_adapter.gd")
const WORLD = preload("res://scripts/dream/preview/office_skeleton_world.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for type in ["A1","B2","C3","V3"]:
		for seed in range(1001,1011):
			var path := "res://data/office_skeleton_preview/%s-%d.json" % [type,seed]
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var layout: Dictionary = ADAPTER.compile(data)
			check(not layout.is_empty(),path+" compiled")
			var world := WORLD.new()
			world.furniture_root = Node2D.new()
			world.skeleton_type = type
			check(world.generate_layout_only(seed),path+" validates in gameplay topology")
			check(world.rooms[world.spawn_room_id].grid_rect.size == Vector2i(14,10),path+" 14x10 reception")
			check(world.rooms.all(func(r: Dictionary) -> bool: return not bool(r.authored_sample)),path+" no fake sample")
			check(not world.rooms.any(func(r: Dictionary) -> bool: return String(r.sample_key) == "lift"),path+" no floor cab")
			check(world.glass_runs.size() >= 2,path+" glass frontages")
			check(world._validate_door_sides(),path+" direction-consistent doors")
			check(world.rooms.all(func(r: Dictionary) -> bool: return world.floor_cells.has(r.center_cell)),path+" true nonrectangular centers")
			for room in world.rooms:
				var plan: Dictionary = world._plan_otxo_room_layout(room.id)
				check(preload("res://scripts/dream/otxo_room_layout_planner.gd")._office_wide_routes(room.shape_cells,plan.get("furniture_placements",[]),world._get_room_doors(room.id),32),"%s-%d actual 3-cell routes %s" % [type,seed,room.sample_key])
				for item in plan.get("furniture_placements",[]):
					var furniture: Node2D = item.scene.instantiate()
					ADAPTER.CATALOG.configure(furniture,item.office_kind)
					furniture.position = item.position
					furniture.rotation = item.rotation
					check(world._furniture_placement_is_clear(furniture,room.id),"%s-%d furniture %s room %s" % [type,seed,item.office_kind,room.sample_key])
					furniture.set_meta(&"dream_room_id",room.id)
					world.furniture_root.add_child(furniture)
			world.furniture_root.free()
			world.free()
	print("SKELETON PLAYABLE checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
