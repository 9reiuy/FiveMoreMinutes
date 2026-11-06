extends SceneTree
## Actual scene/Camera ablations prove light, shadow, bloom and air contribution.
const OUT := "res://.runtime/coast_spatial_lighting_20261030/validation"
var checks := 0
var failures := 0
var display: Control
var coast: Node3D
var measurements: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	print("PASS " if ok else "FAIL ", label)
func draw(label: String) -> Image:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = display.view.get_texture().get_image()
	image.save_png(OUT + "/" + label + ".png")
	return image
func difference(a: Image, b: Image, limit: float = .003) -> Dictionary:
	var pixels := 0; var max_delta := 0.; var total := 0.
	for y in 360:
		for x in 640:
			var ca := a.get_pixel(x,y); var cb := b.get_pixel(x,y)
			var delta := maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))
			if delta > limit: pixels += 1
			max_delta = maxf(max_delta,delta); total += delta
	return {"changed_pixels":pixels,"max_delta":max_delta,"mean_delta":total/(640.*360.)}
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps = 60
	create_timer(120.,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	display = load("res://scripts/story/chapter_coast.gd").new(); root.add_child(display)
	coast = display.coast; coast.external_step = true
	for i in 60: coast.advance(.1)
	coast.player_position = Vector3(-3,0,23); coast._place_character(); coast.update_camera(0.,true)
	coast.clock = 19.5; coast._update_light()
	var owner_ok := true
	for node in coast.find_children("*","",true,false):
		if node.owner != coast and not node.name in ["CoastWalker"] and node.get_parent() != coast.get_node("WalkerCapture"):
			# Walker's existing runtime-only rig is not an authored lighting node.
			if str(node.get_path()).contains("SpatialLighting"): owner_ok = false
	check(owner_ok,"lighting nodes remain editable and owned by saved coast")
	check(coast.spatial_lighting.lights.size()==7,"seven added light sources bind to shared scene clock")
	var on := await draw("all_on")
	var lamps: Array = coast.spatial_lighting.lights.filter(func(light): return light is SpotLight3D or (light is OmniLight3D and str(light.get_path()).contains("ShoreWorklight")))
	for lamp in lamps: lamp.visible = false
	var no_warm := await draw("warm_off")
	measurements.warm_lighting = difference(on,no_warm)
	check(measurements.warm_lighting.changed_pixels>100,"real warm lights alter surfaces around their fixtures")
	for lamp in lamps: lamp.visible = true
	coast.moon_light.shadow_enabled = false
	var no_shadow := await draw("moon_shadow_off")
	measurements.shadows = difference(on,no_shadow)
	check(measurements.shadows.changed_pixels>200,"actual geometry casts moon shadows")
	coast.moon_light.shadow_enabled = true
	var environment: Environment = coast.get_node("CoastEnvironment").environment
	environment.glow_enabled = false
	var no_bloom := await draw("bloom_off")
	measurements.bloom = difference(on,no_bloom,.0001)
	check(measurements.bloom.changed_pixels>0,"native Compatibility bloom contributes to actual Camera output")
	check(measurements.bloom.mean_delta<.015,"bloom remains restrained across the image")
	environment.glow_enabled = true
	var volumes: Array[Node] = coast.spatial_lighting.find_children("LocalAirScattering","MeshInstance3D",true,false)
	for volume in volumes: volume.visible = false
	var no_air := await draw("air_off")
	measurements.local_air = difference(on,no_air,.0001)
	check(measurements.local_air.changed_pixels>0,"local depth-clipped air volumes contribute visible scattering")
	check(measurements.local_air.mean_delta<.015,"air scattering stays local and low contrast")
	for volume in volumes: volume.visible = true
	for step in 360:
		if coast.visibility_at(step*.1)<.0001:
			coast.clock = step*.1; break
	coast._update_light()
	var dark := await draw("moon_covered")
	check(coast.moon_light.light_energy<.01,"clouds still remove the direct moon light")
	check(coast.spatial_lighting.lights[0].light_energy>0.,"weak cool fill joins dark regions after cover")
	coast.player_position = Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.,true)
	for step in 360:
		if coast.visibility_at(step*.1)<.0001:
			coast.clock = step*.1; break
	coast._update_light()
	var horizon := await draw("signal_reading")
	var visible_signals := 0
	for node in coast.atmosphere.signal_nodes:
		if not node.visible: continue
		var point: Vector2 = coast.camera.unproject_position(node.global_position)
		var found := false
		for y in range(maxi(0,int(point.y)-4),mini(360,int(point.y)+5)):
			for x in range(maxi(0,int(point.x)-8),mini(640,int(point.x)+9)):
				var color := horizon.get_pixel(x,y)
				if color.r>.1 and color.g>.1 and color.g>color.b*1.03: found = true
		if found: visible_signals += 1
	check(visible_signals==3,"all three chapter Morse lights remain readable under cloud cover")
	var time: float = coast.clock
	coast.paused = true; coast.advance(.5)
	check(coast.clock==time,"pause keeps lighting and scene clocks together")
	check(coast.water_material.shader.resource_path=="res://shaders/preview/night_coast_water.gdshader","water retains the restored shared shader")
	var result := {"checks":checks,"failures":failures,"measurements":measurements,"gpu":RenderingServer.get_video_adapter_name(),"scope":"actual 640x360 chapter Camera; no FPS or dynamic GI claim"}
	FileAccess.open(OUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("COAST_SPATIAL_LIGHTING ",JSON.stringify(result))
	display.queue_free()
	for i in 6: await process_frame
	quit(1 if failures else 0)
