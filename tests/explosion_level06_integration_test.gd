extends SceneTree
const TRAIN := preload("res://scripts/testing/metro_station/train_chapter.gd")
var display: Control
var world: Node3D
var output := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for index in count:await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)

func run() -> void:
	create_timer(70.0,true,false,true).timeout.connect(func() -> void:quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifact-dir="):output=arg.trim_prefix("--artifact-dir=")
	AudioServer.set_bus_mute(0,true)
	preload("res://tests/support/background_gpu.gd").start(self)
	Engine.max_fps=60
	display=load("res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn").instantiate()
	root.add_child(display)
	current_scene=display
	world=display.world
	await world.begin_train_chapter(true)
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	var train: TRAIN=world._train
	check(RenderingServer.get_current_rendering_method()=="forward_plus","0-6 uses the project Forward+ renderer")
	check(train.crews[0].is_empty(),"Original empty tail carriage retained")
	world.player.set_physics_process(false)
	world.player.set_process(true)
	world.player.global_position=train._pixels(Vector2(TRAIN.CONSIST.center(1),0))
	world.player.dash_invulnerability_left=1000.0
	for enemy in world.enemy_root.get_children():enemy.set_physics_process(false)
	world._update_camera_and_actor_projection(10.0)
	world.set_process(false)
	world.set_physics_process(false)
	train.derailment.effects.set_process(false)
	train.derailment.advance(20.0)
	check(train.derailment.next_car==1 and train.derailment.retired.has(0),"Actual 20-second deadline retires the original tail carriage")
	check(not world.player.dead,"Player in the next carriage survives the unchanged hazard")
	var effects: Node3D=train.derailment.effects
	check(effects.explosion.bursts.size()==1 and effects.explosion.pool.size()==8,"Real derailment starts one coupling blast in the shared bounded pool")
	var coupling := train.art.player_train.root.to_global(Vector3(TRAIN.CONSIST.joint(0),TRAIN.CONSIST.DECK_OFFSET+.65,0))
	var blast: Vector3=effects.to_global(effects.explosion.bursts[0].at)
	check(blast.is_equal_approx(coupling),"Explosion originates at the coupling, outside the passenger cabin")
	check(effects.lights.size()==4,"Real train retains the four-light budget")
	check(effects.explosion.find_children("*","CollisionObject3D",true,false).is_empty(),"Train gas presentation adds no collision bodies")
	var car: Node3D=train.derailment.wrecks[0].node
	var base: Transform3D=car.transform
	var travel_start: float=train.travel
	# Keep the game's ride angle and lens; center the real Camera on the wreck
	# for this evidence clip so the remote tail explosion remains visible.
	world.camera_rig.position=world.to_local(car.global_position)
	await frames(3)
	var movie_dir := output.path_join("frames")
	DirAccess.make_dir_recursive_absolute(movie_dir)
	for index in 105:
		if index>0:
			effects.step(1.0/30.0)
			train.travel=travel_start+float(index)/30.0*TRAIN.ROLL_SPEED
			train.present()
			check_once_motion(index,car,base,float(index)/30.0*TRAIN.ROLL_SPEED,effects,travel_start)
		await frames(2)
		await RenderingServer.frame_post_draw
		var img: Image=display.world_viewport.get_texture().get_image()
		if index==0:check(img.get_size()==Vector2i(1280,720),"Actual 0-6 Camera keeps native resolution")
		img.save_png(movie_dir.path_join("frame_%04d.png" % index))
		if index in [4,10,30]:img.save_png(output.path_join("level06_%04d.png" % index))
	check(effects.explosion.bursts.is_empty(),"Real train gas expires after its complete tail")
	check(effects.lights.all(func(light: OmniLight3D)->bool:return not light.visible),"Train flash lights leave no residue")
	check(is_instance_valid(car) and car.visible,"Retired carriage stays intact until well beyond the Camera")
	train.travel=travel_start+train.derailment.RETIRE_DISTANCE
	train.present()
	await frames(2)
	check(not is_instance_valid(car) and train.derailment.wrecks.is_empty(),"Offscreen carriage is freed after scenery carries it away")
	var old: WeakRef=weakref(effects.explosion)
	world.regenerate(world.seed)
	await frames(5)
	check(old.get_ref()==null and world._train==null,"Reset unloads old train, gas pool and wrecks")
	await world.begin_train_chapter(true)
	train=world._train
	train.derailment.advance(20.0)
	check(world.player.dead and world.player.last_damage_source==&"train_derailment","Staying in the tail retains the original real hazard death")
	# Death defers weapon projection to the next frame, as in normal play.
	# Let that finish before the public restart replaces the floor actors.
	await frames(3)
	check(world.restart_current_floor_after_death(),"Public death restart still succeeds")
	await frames(5)
	check(not world.player.dead and world._train==null,"Death restart clears the retired train and explosion pool")
	display.free()
	await frames(5)
	var file := FileAccess.open(output.path_join("validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Actual 0-6 world: coupling-only blast, fixed-height scenery-synchronized rearward retirement, offscreen cleanup, preserved 20s hazard death, reset and public death restart. Deterministic actual Camera clip; readbacks excluded from performance. Not full campaign certification."},"\t"))
	print("LEVEL06_EXPLOSION checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)


func check_once_motion(index: int,car: Node3D,base: Transform3D,behind: float,effects: Node3D,travel_start: float) -> void:
	if index not in [15,60,104]:return
	check(is_equal_approx(car.position.x,base.origin.x-behind) and is_equal_approx(car.position.y,base.origin.y) and is_equal_approx(car.position.z,base.origin.z) and car.basis.is_equal_approx(base.basis),"Retired carriage follows scenery without sinking or rolling at frame %d" % index)
	check(is_equal_approx(effects.position.x,-travel_start-behind),"Coupling fire and smoke share the scenery's travel at frame %d" % index)
