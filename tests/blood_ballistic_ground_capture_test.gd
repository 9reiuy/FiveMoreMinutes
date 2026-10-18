extends SceneTree
## Reproduce the dormant ground carrier using real GPU SubViewport textures.
class SleepingGroundBlood extends BlackBloodEffect:
	func _notify_bridge_dirty() -> void: pass
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count := 3) -> void:
	for index in count: await RenderingServer.frame_post_draw
func fixture(legacy: bool) -> void:
	var scene := Node3D.new(); root.add_child(scene)
	var camera := Camera3D.new(); scene.add_child(camera)
	camera.position=Vector3(0,8,8); camera.look_at(Vector3.ZERO)
	var pool=preload("res://scripts/dream/blood_ground_capture_pool.gd").new(); scene.add_child(pool)
	var blood: BlackBloodEffect=SleepingGroundBlood.new() if legacy else BlackBloodEffect.new()
	scene.add_child(blood); blood.add_to_group(&"black_blood_stains"); blood.set_process(false)
	blood.ballistic_death_spray=true; blood.set_meta(&"blood_ground_capture_extent",112)
	blood.airborne_pixels=[
		{"position":Vector2.ZERO,"velocity":Vector2(100,0),"height":2.0,"vertical":0.0,"size":2.0,"splash_radius":2.0,"splash_seed":1},
		{"position":Vector2.ZERO,"velocity":Vector2(140,0),"height":20.0,"vertical":40.0,"size":2.0,"splash_radius":3.0,"splash_seed":2}]
	var bridge=pool.acquire(blood,camera,.01)
	await frames()
	check(bridge.static_visual_frozen,"Air-only ground carrier sleeps without ongoing capture work")
	check(not bridge.render_viewport.get_texture().get_image().get_used_rect().has_area(),"Ground texture is empty while all droplets are airborne")
	blood._process(.1)
	await frames()
	check(blood.landed_death_droplets==1 and blood.airborne_pixels.size()==1,"First real touchdown leaves the higher droplet flying")
	var early_visible: bool=bridge.render_viewport.get_texture().get_image().get_used_rect().has_area()
	if legacy:
		check(not early_visible and bridge.clone_roots[0].ground_pixels.is_empty(),"Old missing wake reproduces invisible early touchdown")
	else:
		check(early_visible,"First touchdown is actually present in the GPU texture before final settling")
		check(bridge.clone_roots[0].ground_pixels==blood.ground_pixels,"Dormant ground replica receives the current touchdown cells")
		var saved_image: PackedByteArray=bridge.render_viewport.get_texture().get_image().get_data()
		var saved_version := blood.content_version
		blood._process(.03); await frames()
		check(blood.content_version==saved_version and bridge.static_visual_frozen,"Air-only motion does not wake or version static ground")
		check(bridge.render_viewport.get_texture().get_image().get_data()==saved_image,"No touchdown leaves the captured texture unchanged")
		blood._process(.4); await frames()
		check(blood.settled and blood.landed_death_droplets==2,"Remaining droplet lands independently")
		check(bridge.clone_roots[0].ground_pixels==blood.ground_pixels,"Last touchdown is copied before the carrier freezes")
		check(bridge.render_viewport.get_texture().get_image().get_data()!=saved_image,"Later touchdown changes actual captured GPU pixels")
		check(bridge.clone_roots[0].airborne_pixels.is_empty(),"Ground texture never duplicates flying particles")
	scene.free(); await frames()
func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Real GPU texture validation required"); quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true)
	await fixture(true); await fixture(false)
	print("BLOOD_BALLISTIC_GROUND_CAPTURE_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
