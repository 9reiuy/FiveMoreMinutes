extends SceneTree
const OUTPUT := "res://.runtime/office_low_cover_20261022"
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
	main._show_dream("basic")
	await ready_main()
	var world: Node = main._supported_dream_world
	var deadline := Time.get_ticks_msec()+90000
	while world.floor_transition_in_progress and Time.get_ticks_msec()<deadline: await process_frame
	for existing in world.enemy_root.get_children():
		existing.set_physics_process(false)
		existing.set_process(false)
	var player: Node2D = world.player
	player.set_physics_process(false)
	player.maximum_health = 1000000.0
	player.current_health = 1000000.0
	var found := false
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point := Vector2(cell)*32.0
			if world._content_position_is_clear(point,85.0):
				player.global_position = point-Vector2(40,0)
				world.activate_room(int(room.id))
				found = true
				break
		if found: break
	if not found:
		push_error("No clear office camera fixture")
		main.free()
		quit(2)
		return
	await frames(35)
	var start: Vector2 = player.get_projectile_origin()
	var prop: Node2D = load("res://scenes/dream/props/desk.tscn").instantiate()
	preload("res://scripts/dream/office_furniture_catalog.gd").configure(prop,"coffee_table")
	prop.set_meta(&"office_visual_style","approved_room")
	world.furniture_root.add_child(prop)
	prop.global_position = start+Vector2(55,0)
	prop.freeze = true
	world._spawn_furniture_presentation(prop)
	var enemy: Node = world._spawn_regular_employee(world.current_room_id,start+Vector2(115,28),&"employee",false,"luger")
	enemy.set_physics_process(false)
	enemy.set_process(false)
	await frames(5)
	var hp: float = prop.hp
	var shot: Node2D = load("res://scenes/entities/basic_projectile.tscn").instantiate()
	shot.position = start
	shot.setup(Vector2.RIGHT,10.0,400.0,1500.0,&"player",player)
	shot.penetration_chance = 0.0
	world.add_projectile(shot,player)
	var hit_table := false
	var crossed := false
	var captures := 0
	for i in 18:
		await process_frame
		if prop.hp < hp: hit_table = true
		if is_instance_valid(shot) and shot.global_position.x>prop.global_position.x+20: crossed = true
		if hit_table and captures<6:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT+"/formal_contact_%02d.png" % captures)
			captures += 1
	print("LOW_COVER_FORMAL hit_table=",hit_table," crossed=",crossed," captures=",captures," gpu=",RenderingServer.get_video_adapter_name())
	main.free()
	await frames(5)
	quit(0 if hit_table and crossed else 1)
