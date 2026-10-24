extends SceneTree
const OUTPUT := "res://.runtime/melee_crescent_20261022"
var main: Node
var world: Node
var captures := {"melee":0,"dash":0}
var stage := "melee"
var output := OUTPUT+"/pixel_palette"
var probed := false
func _init() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func ready_main() -> void:
	var deadline := Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(20)
func target(direction: Vector2) -> Node:
	var enemy: Node = world._spawn_regular_employee(world.current_room_id,world.player.global_position+direction*45.0,&"employee",false,"luger")
	enemy.maximum_health = 100.0
	enemy.current_health = 100.0
	enemy.set_physics_process(false)
	enemy.set_process(false)
	return enemy
func capture() -> void:
	if int(captures[stage])>=6: return
	for effect in get_nodes_in_group(&"melee_crescent_hits"):
		if not is_instance_valid(effect) or effect.is_queued_for_deletion() or effect.elapsed>.13: continue
		root.get_texture().get_image().save_png(output+"/formal_%s_%02d.png" % [stage,int(captures[stage])])
		captures[stage] += 1
		break
func probe_lines(effect: Node3D) -> void:
	var previous: int = world.process_mode
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var original_count: int = effect.material.get_shader_parameter("line_count")
	var original_progress: float = effect.material.get_shader_parameter("progress")
	print("CRESCENT_MATERIAL same=",effect.mesh.material_override==effect.material," cuts=",effect.cuts," shader=",effect.mesh.material_override.shader.resource_path)
	effect.material.set_shader_parameter("progress",.35)
	for count in [0,3]:
		effect.material.set_shader_parameter("line_count",count)
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/line_probe_%d.png" % count)
	effect.material.set_shader_parameter("line_count",original_count)
	effect.material.set_shader_parameter("progress",original_progress)
	world.process_mode = previous
func run() -> void:
	var diagnostic := root.get_node_or_null("_DroneGameDiag")
	if diagnostic != null: diagnostic.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2); return
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	output = OUTPUT+("/native" if "--native" in OS.get_cmdline_user_args() else "/pixel")+("_original" if "--palette-off" in OS.get_cmdline_user_args() else "_palette")
	if "--probe-lines" in OS.get_cmdline_user_args(): output += "/line_probe_run"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var settings: Node = root.get_node("SettingsManager")
	settings.set_palette_enabled(not "--palette-off" in OS.get_cmdline_user_args())
	settings.set_setting(&"pixelation_enabled",not "--native" in OS.get_cmdline_user_args())
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state.tutorial_completed = true
	seed(120)
	main._show_dream("lucille")
	await ready_main()
	world = main._supported_dream_world
	var deadline := Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	for existing in world.enemy_root.get_children():
		existing.set_process(false)
		existing.set_physics_process(false)
	var player: Node = world.player
	var found := false
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point := Vector2(cell)*32.0
			if world._content_position_is_clear(point,85.0):
				player.global_position = point
				world.activate_room(int(room.id))
				found = true
				break
		if found: break
	if not found: push_error("No office camera fixture"); main.free(); quit(2); return
	player.maximum_health = 1000000.0
	player.current_health = 1000000.0
	await frames(35)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size*.5+Vector2(100,0)
	Input.parse_input_event(motion)
	await frames(3)
	var direction: Vector2 = player.global_position.direction_to(player.get_constrained_aim_position())
	var victim := target(direction)
	await frames(3)
	RenderingServer.frame_post_draw.connect(capture)
	var button := InputEventMouseButton.new()
	button.position = motion.position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	Input.parse_input_event(button)
	var melee_began := false
	for i in 100:
		await process_frame
		melee_began = melee_began or bool(player.lucille_weapon.melee_action_active)
		if not probed and "--probe-lines" in OS.get_cmdline_user_args():
			var live := get_nodes_in_group(&"melee_crescent_hits")
			if not live.is_empty():
				probed = true
				await probe_lines(live[0])
		if i==15:
			button = button.duplicate()
			button.pressed = false
			Input.parse_input_event(button)
		if captures.melee>=6 and i>20: break
	if is_instance_valid(victim): victim.queue_free()
	for effect in get_nodes_in_group(&"melee_crescent_hits"): effect.queue_free()
	await frames(20)
	stage = "dash"
	motion = motion.duplicate()
	motion.position = root.get_visible_rect().size*.5+Vector2(100,0)
	Input.parse_input_event(motion)
	await frames(3)
	direction = player.global_position.direction_to(player.get_constrained_aim_position())
	victim = target(direction)
	await frames(3)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	var dash_began := false
	for i in 100:
		await process_frame
		dash_began = dash_began or bool(player.is_phase_dash_active())
		if i==15:
			key = key.duplicate()
			key.pressed = false
			Input.parse_input_event(key)
		if captures.dash>=6 and i>20: break
	RenderingServer.frame_post_draw.disconnect(capture)
	var ok := melee_began and dash_began and int(captures.melee)>0 and int(captures.dash)>0
	print("MELEE_CRESCENT_LIVE melee_input=",melee_began," dash_input=",dash_began," captures=",captures," gpu=",RenderingServer.get_video_adapter_name())
	main.free()
	await frames(5)
	quit(0 if ok else 1)
