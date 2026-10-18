extends SceneTree
## P0 acceptance: cutout hole over an occluder reveals behind content (character/floor), not clear-black.

var log_path := "user://cutout_penetrate_log.txt"

func log_line(t: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_line(t)
	f.close()
	print(t)

func _initialize() -> void:
	call_deferred("run")

func avg(img: Image, cx: int, cy: int, r: int) -> Color:
	if img == null:
		return Color(0, 0, 0, 1)
	var s := Color(0, 0, 0, 0)
	var n := 0
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				s += img.get_pixel(x, y)
				n += 1
	return s / float(maxi(n, 1))

func luma(c: Color) -> float:
	return c.r + c.g + c.b

func capture_root() -> Image:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	return root.get_texture().get_image()

func crop_around(img: Image, cx: int, cy: int, half: int) -> Image:
	var x0 := clampi(cx - half, 0, img.get_width() - 1)
	var y0 := clampi(cy - half, 0, img.get_height() - 1)
	var w := mini(half * 2, img.get_width() - x0)
	var h := mini(half * 2, img.get_height() - y0)
	return img.get_region(Rect2i(x0, y0, w, h))

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-2400, -2400))
	FileAccess.open(log_path, FileAccess.WRITE).close()
	log_line("PENETRATE_START")
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)

	var world: Node3D = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = true
	world.persist_profile = false
	if "enable_game_start_cab_exit" in world:
		world.enable_game_start_cab_exit = false
	root.add_child(world)
	for i in 40:
		await process_frame
		DisplayServer.window_set_position(Vector2i(-2400, -2400))
	world.regenerate(41001)
	for i in 150:
		await process_frame
		if i % 40 == 0:
			DisplayServer.window_set_position(Vector2i(-2400, -2400))

	if "rooms" in world:
		for room in world.rooms:
			if String(room.get("archetype", "")) == "open_office":
				if world.get("player") != null:
					world.player.global_position = Vector2(room.center_cell) * world.CELL_PIXELS
				if world.has_method("activate_room"):
					world.activate_room(int(room.id))
				log_line("activated_open_office id=%s" % str(room.id))
				break
	for i in 45:
		await process_frame

	var behind_vp: SubViewport = world.find_child("CutoutBehindViewport", true, false) as SubViewport
	var cam: Camera3D = world.camera_3d
	var player: Node2D = world.get("player") as Node2D
	if player == null or cam == null:
		log_line("NO_PLAYER_OR_CAM")
		quit(3)
		return
	player.set_physics_process(false)
	world.set_process(false)

	var player_world := Vector3.ZERO
	if world.has_method("get_gameplay_world_position"):
		player_world = world.get_gameplay_world_position(player.global_position, 0.0)
	else:
		player_world = Vector3(player.global_position.x / world.CELL_PIXELS, 0.0, player.global_position.y / world.CELL_PIXELS)
	var head := player_world + Vector3(0, 0.55, 0)
	var sp_player: Vector2 = cam.unproject_position(head)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	log_line("player_sp=%s vp=%s behind=%s wall8=%s" % [
		str(sp_player), str(vp_size), str(behind_vp),
		str((world.find_child("WallMesh", true, false) as MeshInstance3D).layers) if world.find_child("WallMesh", true, false) else "n/a",
	])
	if cam.is_position_behind(head) or not cam.get_viewport().get_visible_rect().has_point(sp_player):
		log_line("PLAYER_OFFSCREEN")
		quit(3)
		return

	# Camera-facing unshaded quad between camera and player (same trick as behind_verify plate).
	var to_player := head - cam.global_position
	var dist := to_player.length()
	var mid := cam.global_position + to_player.normalized() * (dist * 0.55)
	var occluder := MeshInstance3D.new()
	occluder.name = "CutoutTestOccluder"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.8)
	occluder.mesh = quad
	var cut_shader := Shader.new()
	cut_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_disabled;
global uniform vec4 occlusion_cutout_0;
global uniform vec4 occlusion_cutout_1;
global uniform vec4 occlusion_cutout_2;
global uniform vec4 occlusion_cutout_3;
global uniform vec4 occlusion_cutout_4;
global uniform vec4 occlusion_cutout_5;
global uniform vec4 occlusion_cutout_6;
global uniform vec4 occlusion_cutout_7;
global uniform vec2 occlusion_viewport_size;
uniform vec3 albedo_color : source_color = vec3(0.12, 0.14, 0.32);
float cutout_factor(vec2 screen_uv, vec4 slot) {
	if (slot.w < 0.5 || slot.z <= 0.0) { return 1.0; }
	vec2 delta_px = (screen_uv - slot.xy) * occlusion_viewport_size;
	float distance_px = length(delta_px);
	if (distance_px >= slot.z) { return 1.0; }
	float norm_d = distance_px / slot.z;
	if (norm_d < 0.22) { return 0.0; }
	float t = (norm_d - 0.22) / 0.78;
	float density = 1.0 - (t * t * (3.0 - 2.0 * t));
	float dot_spacing = clamp(slot.z * 0.12, 5.0, 8.0);
	vec2 rot_px = vec2(delta_px.x * 0.7071068 - delta_px.y * 0.7071068, delta_px.x * 0.7071068 + delta_px.y * 0.7071068);
	vec2 cell = fract(rot_px / dot_spacing) - vec2(0.5);
	float dist_in_cell = length(cell) * dot_spacing;
	float hole_r = dot_spacing * 0.75 * density;
	float hole_factor = hole_r > 0.05 ? smoothstep(hole_r - 0.75, hole_r + 0.75, dist_in_cell) : 1.0;
	return max(hole_factor, smoothstep(slot.z - 3.0, slot.z, distance_px));
}
float combined_cutout(vec2 screen_uv) {
	float f = cutout_factor(screen_uv, occlusion_cutout_0);
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_1));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_2));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_3));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_4));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_5));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_6));
	f = min(f, cutout_factor(screen_uv, occlusion_cutout_7));
	return f;
}
void fragment() {
	ALBEDO = albedo_color;
	ALPHA = combined_cutout(SCREEN_UV);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = cut_shader
	occluder.material_override = mat
	occluder.layers = 1
	world.add_child(occluder)
	occluder.global_position = mid
	occluder.global_basis = Basis.looking_at((cam.global_position - mid).normalized(), Vector3.UP)
	var sp_occ: Vector2 = cam.unproject_position(mid)
	log_line("occluder_pos=%s sp=%s layers=%d" % [str(occluder.global_position), str(sp_occ), occluder.layers])
	for i in 15:
		await process_frame

	# Also force real furniture under occluder roots onto layer 8.
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var cursor: Node = mesh
		while cursor != null:
			if cursor.has_meta(&"occlusion_cutout_occluder") and bool(cursor.get_meta(&"occlusion_cutout_occluder")):
				mesh.layers = 8
				break
			cursor = cursor.get_parent()

	RenderingServer.global_shader_parameter_set("occlusion_viewport_size", vp_size)
	var root_size := Vector2(1280, 720)
	var scale := minf(root_size.x / vp_size.x, root_size.y / vp_size.y)
	var offset := (root_size - vp_size * scale) * 0.5
	var px := int(offset.x + sp_player.x * scale)
	var py := int(offset.y + sp_player.y * scale)

	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)

	log_line("capturing_off")
	var img_off: Image = await capture_root()
	RenderingServer.global_shader_parameter_set(
		"occlusion_cutout_0",
		Vector4(sp_player.x / vp_size.x, sp_player.y / vp_size.y, 70.0, 1.0)
	)
	log_line("capturing_on")
	var img_on: Image = await capture_root()

	var img_behind: Image = null
	if behind_vp != null:
		await process_frame
		await RenderingServer.frame_post_draw
		img_behind = behind_vp.get_texture().get_image()
		var bc := avg(img_behind, img_behind.get_width()/2, img_behind.get_height()/2, 30)
		var bp := avg(img_behind, int(sp_player.x), int(sp_player.y), 8)
		log_line("behind_center=%s behind_player=%s" % [str(bc), str(bp)])

	occluder.visible = false
	for i in range(0, 8):
		RenderingServer.global_shader_parameter_set("occlusion_cutout_%d" % i, Vector4.ZERO)
	log_line("capturing_open")
	var img_open: Image = await capture_root()

	var runtime := ProjectSettings.globalize_path("res://.runtime/cutout_sample")
	DirAccess.make_dir_recursive_absolute(runtime)
	img_off.save_png(runtime.path_join("penetrate_off.png"))
	img_on.save_png(runtime.path_join("penetrate_on.png"))
	img_open.save_png(runtime.path_join("penetrate_open.png"))
	if img_behind != null:
		img_behind.save_png(runtime.path_join("penetrate_behind_only.png"))
	crop_around(img_off, px, py, 72).save_png(runtime.path_join("penetrate_crop_off.png"))
	crop_around(img_on, px, py, 72).save_png(runtime.path_join("penetrate_crop_on.png"))
	crop_around(img_open, px, py, 72).save_png(runtime.path_join("penetrate_crop_open.png"))
	if img_behind != null:
		crop_around(img_behind, int(sp_player.x), int(sp_player.y), 48).save_png(runtime.path_join("penetrate_crop_behind.png"))

	var off_c := avg(img_off, px, py, 8)
	var on_c := avg(img_on, px, py, 8)
	var open_c := avg(img_open, px, py, 8)
	var behind_c := avg(img_behind, int(sp_player.x), int(sp_player.y), 6) if img_behind != null else Color.BLACK
	log_line("off=%s" % str(off_c))
	log_line("on=%s" % str(on_c))
	log_line("open=%s" % str(open_c))
	log_line("behind_only=%s" % str(behind_c))

	var on_l := luma(on_c)
	var off_l := luma(off_c)
	var open_l := luma(open_c)
	# 3D soft-ALPHA path: hole must match "occluder hidden" (real behind), not clear-black,
	# and must differ from solid occluder. Darkening vs off is OK when occluder was brighter.
	var near_open := absf(on_c.r - open_c.r) + absf(on_c.g - open_c.g) + absf(on_c.b - open_c.b) < 0.12
	var changed := absf(on_c.r - off_c.r) + absf(on_c.g - off_c.g) + absf(on_c.b - off_c.b) > 0.06
	var not_clear_black := on_l > 0.25
	var ok := near_open and changed and not_clear_black
	log_line(
		"PASS=%s near_open=%s changed=%s not_clear_black=%s on_l=%.3f open_l=%.3f off_l=%.3f"
		% [str(ok), str(near_open), str(changed), str(not_clear_black), on_l, open_l, off_l]
	)
	log_line("PENETRATE_DONE")
	quit(0 if ok else 2)