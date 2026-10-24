extends SceneTree
var main: Node
var world: Node
var captures := 0
var samples: Array = []
var refresh_events := 0
var OUTPUT := "res://.runtime/phase_dash_20261022/color_live"
func _init() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func ready_main() -> void:
	var deadline := Time.get_ticks_msec()+60000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(30)
func run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	var palette_on := not "--palette-off" in OS.get_cmdline_user_args()
	if not palette_on: OUTPUT += "_palette_off"
	if "--native" in OS.get_cmdline_user_args(): OUTPUT += "_native"
	var kill_case := "--kill" in OS.get_cmdline_user_args()
	if kill_case: OUTPUT += "_kill"
	if "--contact-proof" in OS.get_cmdline_user_args(): OUTPUT += "_contact_fix"
	if "--palette-follow" in OS.get_cmdline_user_args(): OUTPUT += "_palette_follow"
	root.get_node("SettingsManager").set_palette_enabled(palette_on)
	root.get_node("SettingsManager").set_palette_scheme(1)
	root.get_node("SettingsManager").set_setting(&"pixelation_enabled",not "--native" in OS.get_cmdline_user_args())
	preload("res://tests/support/background_gpu.gd").start(self)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ready_main()
	main.persistent_day_state = main._create_initial_state()
	main.persistent_day_state.tutorial_completed = true
	seed(120)
	main._show_dream("lucille")
	await ready_main()
	world = main._supported_dream_world
	if world==null:
		quit(2)
		return
	var deadline := Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	await frames(30)
	var player: Node = world.player
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point := Vector2(cell)*32
			if world._content_position_is_clear(point,90):
				player.global_position = point
				world.activate_room(int(room.id))
				break
		break
	player.maximum_health = 1000000
	player.current_health = 1000000
	await frames(120)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size*.5+Vector2(100,0)
	Input.parse_input_event(motion)
	await frames(2)
	var victim: Node
	if kill_case:
		var enemy: Node = load("res://scenes/entities/employee_enemy.tscn").instantiate()
		victim = enemy
		world.enemy_root.add_child(enemy)
		enemy.global_position = player.global_position+player.global_position.direction_to(player.get_constrained_aim_position())*70.0
		enemy.set_meta("dream_room_id",world.current_room_id)
		enemy.configure(player,world.config.base_enemy_health,0,world._room_bounds_pixels(world.current_room_id,2),world.config.enemy_separation_strength,world.config.enemy_separation_radius,world.config)
		enemy.sky_drop_active = false
		enemy.sky_drop_height = 0
		enemy.set_physics_process(false)
		enemy.set_process(false)
		enemy.set_player_vision_visible(true)
		enemy.defeated.connect(world._on_enemy_defeated)
		world.register_depth_visual(enemy,[^"Shadow",^"CharacterVisual",^"WeaponRoot"])
		await frames(2)
	root.get_node("SFXManager").sfx_played.connect(func(sound: StringName) -> void:
		if sound==&"dash_refresh": refresh_events += 1)
	var start: Vector2 = player.global_position
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	var seen := false
	var mismatch := 0
	var began := Time.get_ticks_msec()
	var capture := func() -> void:
		if captures>=20: return
		if player.is_phase_dash_active() or (is_instance_valid(player.phase_dash) and player.phase_dash.tail_left>0):
			root.get_texture().get_image().save_png(OUTPUT+"/frame_%02d.png" % captures)
			captures += 1
	RenderingServer.frame_post_draw.connect(capture)
	for frame in 100:
		await process_frame
		var active: bool = player.is_phase_dash_active()
		seen = seen or active
		if is_instance_valid(player.phase_dash) and is_instance_valid(player.phase_dash.effect):
			if player.phase_dash.effect.mesh.material_override!=player.phase_dash.effect.material: mismatch += 1
		samples.append({"ms":Time.get_ticks_msec()-began,"active":active,"position":player.global_position,"charges":player.dash_charges,"hits":player.phase_dash.last_result.hits if is_instance_valid(player.phase_dash) else 0})
		if frame==20:
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
		if seen and frame>30: break
	RenderingServer.frame_post_draw.disconnect(capture)
	var distance: float = start.distance_to(player.global_position)
	var file := FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seen_active":seen,"distance":distance,"material_mismatches":mismatch,"captures":captures,"samples":samples,"refresh_events":refresh_events,"last_result":player.phase_dash.last_result},"\t"))
	file.close()
	var kill_ok: bool = not kill_case or (refresh_events==0 and int(player.phase_dash.last_result.kills)>0 and player.dash_charges>0)
	if "--contact-proof" in OS.get_cmdline_user_args() and is_instance_valid(victim) and victim.dead:
		await frames(12)
		if is_instance_valid(victim.corpse_contact) and is_instance_valid(victim.corpse_contact.contact_shape):
			# Diagnostic pose only: after the normal-input dash has already passed,
			# relocate the landed corpse into view to inspect silhouette coverage.
			victim.set_physics_process(false)
			victim.set_process(false)
			victim.global_position = player.global_position+Vector2(48,0)
			await frames(4)
			victim.corpse_contact.sync_pose()
			var points: PackedVector2Array = victim.corpse_contact.contact_shape.shape.points
			var lines := ImmediateMesh.new()
			var ink := StandardMaterial3D.new()
			ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ink.albedo_color = Color.WHITE
			lines.surface_begin(Mesh.PRIMITIVE_LINES,ink)
			for i in points.size():
				for index in [i,(i+1)%points.size()]:
					var point: Vector2 = victim.corpse_contact.to_global(points[index])
					lines.surface_add_vertex(Vector3(point.x/32.0,.06,point.y/32.0))
			lines.surface_end()
			var outline := MeshInstance3D.new()
			outline.mesh = lines
			outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.floor_root.add_child(outline)
			await frames(2)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT+"/corpse_footprint.png")
			print("CORPSE_CONTACT_PROOF projected=",victim.corpse_contact.projected_to_floor," vertices=",points.size())
			outline.queue_free()
	print("PHASE_DASH_LIVE active=",seen," distance=",distance," material_mismatches=",mismatch," captures=",captures," kill_case_ok=",kill_ok)
	main.free()
	await frames(4)
	quit(0 if seen and distance>1 and mismatch==0 and captures>0 and kill_ok else 1)
