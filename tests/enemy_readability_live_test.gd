extends SceneTree

const OUTPUT := "res://.runtime/enemy_readability_20261022"
var main: Node

func _init() -> void: call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func ready_main() -> void:
	var deadline := Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(20)

func run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
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
	var world: Node = main._supported_dream_world
	if world == null:
		push_error("Formal Dream world unavailable")
		quit(2)
		return
	var deadline := Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	var player: Node = world.player
	# Static acceptance fixture: keep the formal renderer/camera and gameplay
	# objects, but stop AI before placing the camera so A/B is the same pose.
	for existing in world.enemy_root.get_children():
		existing.set_physics_process(false)
		existing.set_process(false)
	player.set_physics_process(false)
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
	player.maximum_health = 1000000.0
	player.current_health = 1000000.0
	await frames(40)
	var fixtures: Array[Node] = []
	for offset in [Vector2(45,-20),Vector2(-40,-20),Vector2(0,-55)]:
		var enemy: Node = world._spawn_regular_employee(world.current_room_id,player.global_position+offset,&"employee",false,"luger")
		enemy.set_physics_process(false)
		enemy.set_process(false)
		fixtures.append(enemy)
	await frames(10)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var settings: Node = root.get_node("SettingsManager")
	for pixel in [false,true]:
		settings.set_setting(&"pixelation_enabled",pixel)
		for palette in [false,true]:
			settings.set_palette_enabled(palette)
			await frames(8)
			for enabled in [false,true]:
				for enemy in fixtures:
					var bridge: Node = enemy.get_meta(&"depth_visual_bridge").get_ref()
					bridge.lit_material.set_shader_parameter("enemy_rim_enabled",enabled)
				await frames(4)
				await RenderingServer.frame_post_draw
				var name := "formal_pixel_%d_palette_%d_rim_%d.png" % [int(pixel),int(palette),int(enabled)]
				root.get_texture().get_image().save_png(OUTPUT+"/"+name)
	var victim: Node = fixtures[0]
	victim.take_damage(999,Vector2.RIGHT,50,&"rifle")
	await frames(6)
	var dead_bridge: Node = victim.get_meta(&"depth_visual_bridge").get_ref()
	dead_bridge._process(0.0)
	var death_ok := not bool(dead_bridge.lit_material.get_shader_parameter("enemy_rim_enabled"))
	print("ENEMY_READABILITY_FORMAL fixtures=",fixtures.size()," clear_office=",found," death_removed=",death_ok," gpu=",RenderingServer.get_video_adapter_name())
	main.free()
	await frames(5)
	quit(0 if found and death_ok else 1)
