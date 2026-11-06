extends SceneTree
## Logic regression for rapid room commits inside the shadow hold/fade interval.
## Uses the actual generated world and fixtures; no synthetic light substitute.
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world); await process_frame
	check(world.regenerate(90210),"actual floor generates")
	world.set_process(false); world.set_physics_process(false)
	var manager: Node3D=world.shadow_manager
	manager.set_process(false)
	var bounces: Array[Light3D]=[]
	for lamp: Light3D in manager.candidates:
		if bool(lamp.get_meta(&"fixture_bounce",false)): bounces.append(lamp)
	check(bounces.size()>=2,"actual floor has multiple reflected fixture sources")
	if bounces.size()<2: world.free(); quit(1); return
	var a: Light3D=bounces[0]; var b: Light3D=bounces[1]
	var room_a:=int(a.get_meta(&"shadow_room_id")); var room_b:=int(b.get_meta(&"shadow_room_id"))
	world.set_current_room_id(room_a)
	world.player.global_position=world._room_bounds_pixels(room_a,0.0).get_center()
	world._update_camera_and_actor_projection(0.0)
	manager.set_suspended(true); manager.set_suspended(false)
	for i in 12: manager._process(0.12)
	check(a.is_visible_in_tree() and a.shadow_enabled and a.shadow_opacity>=0.999 and a.light_energy>0.01,"selected room bounce has full occlusion and useful light")
	# Return before even the next selection tick: active A must be shown again.
	world.set_current_room_id(room_b); manager._process(0.02)
	check(not a.visible,"leaving a room hides its reflected source immediately")
	world.set_current_room_id(room_a); manager._process(0.02)
	check(a.visible and a.light_energy>0.01,"A-B-A within one selection interval restores the existing active source")
	# Return while old A is still retained in the 0.25s fade/hold machinery.
	world.set_current_room_id(room_b); manager._process(0.11)
	world.set_current_room_id(room_a); manager._process(0.11)
	check(a.visible and a.shadow_opacity>=0.999,"A-B-A during shadow fade restores visibility without transparent shadows")
	a.hide(); manager._process(0.02)
	check(not a.visible,"explicitly hidden current-room source is not force-shown every frame")
	manager.set_suspended(true); manager.set_suspended(false); manager.prepare_loading_selection()
	check(a.shadow_opacity>=0.999 and a.light_energy<=0.001,"resume starts reflected energy from zero without fading wall occlusion")
	world.free(); await process_frame
	print("ROOM_BOUNCE_LIFECYCLE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
