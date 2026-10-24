extends SceneTree

var checks := 0
var failures := 0
const OUTPUT := "res://.runtime/enemy_readability_20261022"

func _init() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func frames(count: int) -> void:
	for i in count: await process_frame

func draw() -> Image:
	await frames(4)
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func bright_count(image: Image) -> int:
	var count := 0
	for y in range(90,270):
		for x in range(220,420):
			var color := image.get_pixel(x,y)
			if minf(color.r,minf(color.g,color.b)) > 0.45: count += 1
	return count

func gpu_probe() -> void:
	root.size = Vector2i(640,360)
	var arena := Node3D.new()
	root.add_child(arena)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.position = Vector3(0,0,5)
	arena.add_child(camera)
	camera.current = true
	var pixels := Image.create(32,32,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	pixels.fill_rect(Rect2i(12,8,8,16),Color(.08,.1,.13))
	var sprite := Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(pixels)
	sprite.pixel_size = .0625
	var ink := ShaderMaterial.new()
	ink.shader = load("res://shaders/dream3d/lit_pixel_carrier.gdshader")
	ink.set_shader_parameter("capture_texture",sprite.texture)
	sprite.material_override = ink
	arena.add_child(sprite)
	var plain := await draw()
	var baseline := bright_count(plain)
	ink.set_shader_parameter("enemy_rim_enabled",true)
	var rim := await draw()
	var visible := bright_count(rim)
	check(visible > baseline+100,"GPU: warm hard rim visible against dark background")
	rim.save_png(OUTPUT+"/probe_rim.png")
	check(rim.get_pixel(320,180).r < .2,"GPU: body interior remains dark, not a glowing silhouette")
	check(rim.get_pixel(230,100).r < .2,"GPU: transparent capture padding stays transparent")
	var layer := CanvasLayer.new()
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var palette := ShaderMaterial.new()
	palette.shader = load("res://shaders/palette_quantize.gdshader")
	rect.material = palette
	layer.add_child(rect)
	root.add_child(layer)
	var filtered := await draw()
	check(bright_count(filtered)>100,"GPU: rim remains readable through palette 1")
	filtered.save_png(OUTPUT+"/probe_palette.png")
	layer.free()
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3,3,.1)
	wall.mesh = box
	wall.position.z = .5
	var wall_ink := StandardMaterial3D.new()
	wall_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_ink.albedo_color = Color(.03,.04,.07)
	wall.material_override = wall_ink
	arena.add_child(wall)
	var hidden := await draw()
	check(bright_count(hidden)==0,"GPU: solid foreground wall hides entire rim")
	wall.hide()
	ink.set_shader_parameter("enemy_rim_enabled",false)
	check(bright_count(await draw())==baseline,"GPU: disabling rim restores original rendering")
	arena.free()
	await frames(3)

func run() -> void:
	var diagnostic:=root.get_node_or_null("_DroneGameDiag")
	if diagnostic!=null: diagnostic.free()
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"):
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var gpu := DisplayServer.get_name()!="headless"
	if gpu:
		preload("res://tests/support/background_gpu.gd").start(self)
		await gpu_probe()
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.approved_sample_art_enabled = false
	root.add_child(world)
	check(world.regenerate(42001),"Formal random floor generates")
	await frames(5)
	world.player.set_physics_process(false)
	var anchor: Vector2 = world.player.global_position
	var enemy = world._spawn_regular_employee(world.current_room_id,anchor+Vector2(45,-20),&"employee",false,"luger")
	enemy.set_physics_process(false)
	await frames(5)
	var bridge: Node = enemy.get_meta(&"depth_visual_bridge").get_ref()
	var player_bridge: Node = world.player.get_meta(&"depth_visual_bridge").get_ref()
	check(bool(bridge.lit_material.get_shader_parameter("enemy_rim_enabled")),"Living enemy body rim enabled")
	check(bool(player_bridge.lit_material.get_shader_parameter("enemy_rim_enabled")),"Player always has character rim")
	check(player_bridge.lit_material.get_shader_parameter("enemy_rim_color")==Color.WHITE,"Player rim stays white")
	check(not bool(bridge.weapon_material.get_shader_parameter("enemy_rim_enabled")),"Held gun has no detached glow")
	check(not bridge.actor_sprite.no_depth_test,"Enemy keeps normal depth testing")
	check(bridge.actor_sprite.material_override==bridge.lit_material,"Rendered material remains bridge-owned")
	var reflection: Node = load("res://scripts/dream/floor_reflections.gd").new()
	root.add_child(reflection)
	reflection.set_process(false)
	reflection._register_visual(bridge.actor_sprite)
	check(bridge.actor_sprite.material_override==bridge.lit_material,"Reflection wrapping preserves live rim material")
	enemy.take_damage(999,Vector2.RIGHT,50,&"rifle")
	bridge._process(0.0)
	check(not bool(bridge.lit_material.get_shader_parameter("enemy_rim_enabled")),"Death immediately removes rim, including reflection material")
	reflection.restore()
	reflection.free()
	world.free()
	await frames(5)
	print("ENEMY_READABILITY checks=",checks," failures=",failures," gpu=",gpu)
	quit(1 if failures else 0)
