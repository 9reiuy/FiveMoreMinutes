extends "res://tests/h06_forklift_flicker_post_comparison.gd"
## Reproduce an actual lethal vehicle impact before inspecting local blood decals.
const LAYERS := preload("res://scripts/dream/render_layer_mask.gd")
var ram_target: EmployeeEnemy
var ram_done := false
var layer_snapshot: Array[Dictionary] = []
var decal_hooked := false
var ram_surface_meshes := false


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	diagnostic_case = "all_decals"
	diagnostic_title = "隐藏附着血迹"
	print("RAM_BLOOD_COMPARISON_PID ", OS.get_process_id())
	call_deferred("run")


func trace_case(label: String, count: int, fire := false, pointer_pan := false) -> void:
	if label == "before_boarding":
		world.office_art_root.get_node("SurfaceBlood").set_surface_meshes(ram_surface_meshes)
		for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	if label == "in_middle_driving": await kill_by_ramming()
	# Do not add gunshot deaths to this reproduction.
	await super.trace_case(label, count, false, pointer_pan)


func kill_by_ramming() -> void:
	var ahead: Vector2 = lift.global_position/32.0 + lift.get_forward_direction()*3.0
	ram_target = world._spawn_regular_employee(0,ahead*32.0,&"employee",false,"")
	ram_target.set_room_runtime_active(true)
	ram_target.set_physics_process(false)
	ram_target.global_position += ahead*32.0 - ram_target.get_node("CollisionShape2D").global_position
	ram_target.maximum_health = 10.0
	ram_target.current_health = 10.0
	lift.reset_motion()
	await frames(3)
	lift.speed = lift.FORWARD_SPEED
	Input.action_press("move_up")
	for i in 90:
		await physics_frame
		if ram_target.dead: break
	Input.action_release("move_up")
	lift.reset_motion()
	check(ram_target.dead and ram_target.impact_blood_spawned, "real vehicle contact kills the target and emits the impact blood")
	ram_done = ram_target.dead
	await frames(90)
	write_blood_snapshot("after-ram")


func vehicle_decals() -> Array[Node]:
	return lift.visual.find_children("*","Decal",true,false)


func write_blood_snapshot(label: String) -> void:
	var surface: Node = world.office_art_root.get_node_or_null("SurfaceBlood")
	var entries: Array[Dictionary] = []
	for decal: Decal in world.find_children("*","Decal",true,false):
		if decal.name != &"AttachedOrangeBlood": continue
		entries.append({"path":str(world.get_path_to(decal)),"on_vehicle":lift.visual.is_ancestor_of(decal),
			"position":decal.global_position,"size":decal.size,"transform":decal.global_transform,"visible":decal.visible})
	FileAccess.open(evidence.path_join(label+".json"),FileAccess.WRITE).store_string(JSON.stringify({"ram_kill":ram_done,
		"vehicle_decals":vehicle_decals().size(),"blood":surface.stats() if surface != null else {},"decals":entries},"\t"))


func check_comparison_mode(mode: int) -> bool:
	return ram_done and vehicle_decals().all(func(d: Node) -> bool: return d.visible == (mode == 0))


func apply_comparison() -> void:
	if not decal_hooked:
		node_added.connect(_new_decal)
		decal_hooked = true
	world.get_viewport().use_taa = false
	var active := comparison_mode != 0
	for decal: Decal in world.find_children("*","Decal",true,false):
		if decal.name != &"AttachedOrangeBlood": continue
		var on_vehicle := lift.visual.is_ancestor_of(decal)
		decal.visible = not (active and (diagnostic_case == "all_decals" or (diagnostic_case == "vehicle_decals" and on_vehicle)))
	comparison_label.text = "F6 切换对照　·　" + ("B "+diagnostic_title if active else "A 撞死敌人后的画面") + "　·　请左右移动视角"
	comparison_trace.append({"case":diagnostic_case,"mode":comparison_mode,"time_usec":Time.get_ticks_usec(),"vehicle_decals":vehicle_decals().size()})
	FileAccess.open(evidence.path_join("switches.json"),FileAccess.WRITE).store_string(JSON.stringify(comparison_trace,"\t"))
	write_blood_snapshot("current-state")


func _new_decal(node: Node) -> void:
	if comparison_mode == 0 or not node is Decal or node.name != &"AttachedOrangeBlood": return
	if diagnostic_case == "all_decals" or lift.visual.is_ancestor_of(node): node.hide()


func align_comparison_camera() -> void:
	var now := Time.get_ticks_usec()
	if comparison_mode != 0:
		for decal: Decal in world.find_children("*","Decal",true,false):
			if decal.name == &"AttachedOrangeBlood" and (diagnostic_case == "all_decals" or lift.visual.is_ancestor_of(decal)): decal.hide()
	if now - config_check_usec < 250000: return
	config_check_usec = now
	var path := evidence.path_join("diagnostic_case.json")
	if not FileAccess.file_exists(path): return
	var text_value := FileAccess.get_file_as_string(path)
	if text_value == config_text: return
	var config: Variant = JSON.parse_string(text_value)
	if not config is Dictionary or config.get("case", "") not in ["vehicle_decals","all_decals"]: return
	config_text = text_value
	diagnostic_case = config["case"]
	diagnostic_title = config.get("title",diagnostic_case)
	comparison_mode = 0
	apply_comparison()
