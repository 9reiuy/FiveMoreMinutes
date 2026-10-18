extends SceneTree
const FREEZE = preload("res://tests/support/frozen_render_comparison.gd")
var world: Node
var main: Node
var output := "res://.runtime/otxo_blood_investigation/camera"
var legacy := false
var measurements: Array = []
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=").replace("\\","/")
	legacy = "--legacy" in OS.get_cmdline_user_args()
	node_added.connect(func(node: Node) -> void:
		if node is BlackBloodEffect: node.set_meta(&"test_legacy_otxo_morphology",legacy)
		if node is CorpseBloodEmitter and legacy: node.drag_max_segments_per_corpse=0
		if node.get_script()!=null and node.get_script().resource_path=="res://scripts/dream/dream_3d_random_dungeon.gd": node.persist_profile=false
	)
	call_deferred("run")
func frames(count := 5) -> void:
	for index in count: await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	var frozen := FREEZE.freeze(self)
	await frames(4)
	var image := root.get_texture().get_image()
	image.save_png(output+"/"+label+".png")
	FREEZE.restore(self,frozen)
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("GPU Camera required"); quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	if not is_instance_valid(world) or main.transition_running: push_error("Main entry incomplete"); quit(1); return
	var origin: Vector2 = world.player.global_position
	var room_id: int = world.current_room_id
	var found := false
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point := Vector2(cell)*32.0
			if world._content_position_is_clear(point,65.0) and world._content_position_is_clear(point+Vector2(0,80),12.0):
				origin=point; room_id=int(room.id); found=true; break
		if found: break
	if not found: push_error("No open natural office fixture"); quit(1); return
	world.player.global_position=origin+Vector2(0,80)
	world.player.invulnerability_left=3600.0; world.player.movement_enabled=false; world.player.set_attacking_enabled(false)
	world.activate_room(room_id)
	for actor in world.enemy_root.get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	await frames(25)
	await capture("clean")
	world._content_rng.seed=73013
	var started := Time.get_ticks_usec()
	world.spawn_death_blood_pool(origin,room_id,1.0)
	measurements.append({"event":"pool_setup","usec":Time.get_ticks_usec()-started})
	await frames(4); await capture("pool_initial")
	await create_timer(0.35).timeout; await capture("pool_mid")
	await create_timer(1.4).timeout; await capture("pool_final")
	world._content_rng.seed=93013
	world.spawn_black_blood(origin+Vector2(-90,0),Vector2(1,0.3),true,room_id,1.0)
	await create_timer(0.3).timeout; await capture("impact")
	var enemy: EmployeeEnemy
	for actor in world.enemy_root.get_children():
		if actor is EmployeeEnemy and int(actor.get_meta(&"dream_room_id",-1))==room_id:
			enemy=actor; break
	if enemy==null: push_error("No real configured enemy in fixture room"); quit(1); return
	enemy.global_position=origin+Vector2(-50,35)
	enemy.set_process(false); enemy.set_physics_process(false)
	enemy.take_damage(999.0,Vector2.RIGHT,0.0,&"rifle")
	for index in 120:
		if enemy.death_landed: break
		enemy._update_death_presentation(1.0/60.0)
	var emitter: CorpseBloodEmitter
	for scheduler in get_nodes_in_group(&"corpse_blood_emitters"):
		if scheduler.follow_source!=null and scheduler.follow_source.get_ref()==enemy: emitter=scheduler; break
	if emitter==null: push_error("Real corpse has no follow emitter"); quit(1); return
	emitter.set_process(false)
	# Drag after the original 2.2s bleeding period, while the corpse still exists.
	emitter._process(2.6)
	await create_timer(0.1).timeout
	var start: Vector2=enemy.global_position
	for index in 32:
		enemy.global_position=start+Vector2(float(index)*5.0,float(index)*1.5)
		emitter._process(1.0/60.0)
		await frames(1)
	var drag_segments: int=emitter._drag_segments
	if not legacy and drag_segments<10: push_error("Late physical-root path produced insufficient drag samples"); quit(1); return
	await frames(12); await capture("corpse_drag")
	var count := 0; var cells := 0
	for effect in world.world_effects_root.get_children():
		if effect is BlackBloodEffect: count+=1; cells+=effect.ground_pixels.size()
	var report := {"legacy":legacy,"formal_main_entry":true,"gpu":RenderingServer.get_video_adapter_name(),"native_window_minimized":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED,"origin":origin,"room_id":room_id,"resolution":[1920,1080],"setup_measurements":measurements,"stains":count,"cells":cells,"late_drag_segments":drag_segments,"controlled_fixture":true,"manual_corpse_root_path":true,"combat_fps_claim":false}
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t"))
	print("OTXO_CAMERA_CAPTURE ",JSON.stringify(report)); main.free(); quit(0)
