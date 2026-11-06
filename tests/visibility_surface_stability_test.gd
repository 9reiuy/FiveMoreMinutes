extends "res://tests/woo_volume_shadow_test.gd"
## Real material lookup vs independent source triangles, plus native collision
## contact and actual Camera evidence. No temporal filtering or actor overlays.
const RECEIVERS = preload("res://scripts/preview/woo_shadow_materials.gd")
const ROOT_OUT := "res://.runtime/hellkind_purple_sample_20261103/visibility_surface_revision"
var baseline := false
var destination := ""

func strict_visible(origin: Vector3, target: Vector3, triangles: PackedVector3Array) -> bool:
	var ray := target - origin
	var distance := ray.length()
	for i in range(0, triangles.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, ray/distance, triangles[i], triangles[i+1], triangles[i+2])
		if hit is Vector3 and origin.distance_to(hit) < distance - .001: return false
	return true

func write_picture(label: String) -> void:
	var picture: Image = lab.world.get_viewport().get_texture().get_image()
	picture.save_png(destination.path_join(label + ".png"))

func material_probe() -> void:
	var field := FIELD.new()
	root.add_child(field)
	field._create_shadow_rig()
	var box := BoxMesh.new()
	box.size = Vector3(12,3,.25)
	var triangles := source_triangles(box, Transform3D(Basis(),Vector3(0,1.5,0)))
	field._install_static_vertices(triangles)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var categories: Array[String] = []
	for face in ["front", "back", "top"]:
		for strip in 4:
			for x in 45:
				var p := Vector3(-5.5 + float(x)*.25, .10 + float(strip)*.94, -.125)
				var normal := Vector3.FORWARD
				if face == "back": p.z=.125; normal=Vector3.BACK
				if face == "top": p.y=3.0; p.z=-.105+float(strip)*.065; normal=Vector3.UP
				positions.append(p); normals.append(normal); categories.append(face)
	var point_image := Image.create(45,12,false,Image.FORMAT_RGBAF)
	var normal_image := Image.create(45,12,false,Image.FORMAT_RGBAF)
	for i in positions.size():
		var p := positions[i]; var n := normals[i]
		point_image.set_pixel(i%45,i/45,Color(p.x,p.y,p.z,1))
		normal_image.set_pixel(i%45,i/45,Color(n.x,n.y,n.z,1))
	var header: String = RECEIVERS.SHADOW_HEADER
	for declaration in ["varying vec3 woo_position;", "varying vec3 woo_world_normal;", "varying float woo_occluded;"]:
		header = header.replace(declaration, "")
	header = header.replace("float woo_polygon_occlusion(vec3 point)", "float woo_polygon_occlusion(vec3 point, vec3 woo_world_normal)")
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded, blend_disabled;\n" + header + """
uniform sampler2D probe_positions : filter_nearest;
uniform sampler2D probe_normals : filter_nearest;
void fragment() {
	float hidden = woo_polygon_occlusion(texture(probe_positions, UV).xyz, texture(probe_normals, UV).xyz);
	COLOR = vec4(vec3(1.0-hidden), 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("woo_polygon_mask",field.texture)
	material.set_shader_parameter("probe_positions",ImageTexture.create_from_image(point_image))
	material.set_shader_parameter("probe_normals",ImageTexture.create_from_image(normal_image))
	var view := SubViewport.new()
	view.disable_3d = true
	view.world_2d = World2D.new()
	view.size = Vector2i(45,12)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var rect := ColorRect.new()
	rect.size = Vector2(45,12)
	rect.material = material
	view.add_child(rect)
	var false_hidden := 0
	var false_visible := 0
	var flips := 0
	var samples := 0
	var by_face := {"front":0,"back":0,"top":0}
	var errors: Array[Dictionary] = []
	var previous: Array[bool] = []
	var expected_previous: Array[bool] = []
	for step in 48:
		# A nearly grazing wall view, where fixed radial-depth bias is unstable.
		var origin := Vector3(-5.8+float(step)*.075,.95,-.40)
		set_probe_origin(field,origin)
		for camera: Camera3D in field._cameras: camera.force_update_transform()
		await frames(3)
		var pixels: Image = view.get_texture().get_image()
		var actual_now: Array[bool] = []
		var expected_now: Array[bool] = []
		for i in positions.size():
			var actual := pixels.get_pixel(i%45,i/45).r > .5
			var expected := strict_visible(origin,positions[i],triangles)
			actual_now.append(actual); expected_now.append(expected)
			samples += 1
			if expected != actual:
				by_face[categories[i]] += 1
				if expected: false_hidden += 1
				else: false_visible += 1
				if errors.size() < 40:
					var atlas: Image = field.texture.get_image()
					var ray := positions[i]-origin
					var face := 0
					for f in 6:
						if ray.dot(FIELD.DIRECTIONS[f]) > ray.dot(FIELD.DIRECTIONS[face]): face=f
					var projected: Vector2 = field._cameras[face].unproject_position(positions[i])
					var pixel := Vector2i(clampi(floori(projected.x),0,511),clampi(floori(projected.y),0,511))+Vector2i(face%3,face/3)*512
					errors.append({"step":step,"point":positions[i],"origin":origin,"expected":expected,"actual":actual,"atlas":atlas.get_pixelv(pixel),"face":face,"projected":projected,"independent_lookup":gpu_visible(field,positions[i],atlas)})
			if step > 0 and expected == expected_previous[i] and actual != previous[i]: flips += 1
		previous = actual_now; expected_previous = expected_now
		if step%8 == 0: pixels.save_png(destination.path_join("receiver_%02d.png" % step))
	evidence["receiver_material"] = {"samples":samples,"false_hidden":false_hidden,"false_visible":false_visible,"temporal_flips":flips,"mismatches_by_face":by_face,"errors":errors}
	check(false_hidden == 0, "Grazing front wall stays visible during movement")
	check(false_visible == 0, "Back face and top do not acquire bright sawtooth leaks")
	check(flips == 0, "Unchanged optical visibility has no black-white flips")
	view.queue_free(); field.queue_free()
	await frames(4)
	if is_instance_valid(lab):
		lab.visibility_field._last_origin = Vector3(INF,INF,INF)
		lab.update_visibility()
		await frames(4)

func contact_probe() -> void:
	var contacts: Array[Dictionary] = []
	for direction: Vector2 in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
		lab.teleport(0)
		await frames(4)
		var player: CharacterBody2D = lab.world.player
		# Disabling a CollisionObject's process mode removes it from the
		# physics space. Keep the original collider active for real contact.
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.set_physics_process(false)
		var body_shape: CollisionShape2D = player.body_collision
		var offset := body_shape.global_position-player.global_position
		var radius: float = body_shape.shape.radius
		var found := false
		for body: Node in lab.world.collision_root.get_children():
			if not body is StaticBody2D or not body.has_meta(&"generated_wall_edge"): continue
			var shape: CollisionShape2D = body.get_child(0)
			if not shape.shape is RectangleShape2D: continue
			var size: Vector2 = shape.shape.size
			if (direction.y != 0 and size.x < size.y) or (direction.x != 0 and size.y < size.x): continue
			var start: Vector2 = body.global_position-direction*48.0
			if not lab.world._is_blood_ground_allowed(start): continue
			player.global_position = start-offset
			await physics_frame
			var contact: KinematicCollision2D = player.move_and_collide(direction*70.0)
			if contact == null or contact.get_collider() != body: continue
			var center := body_shape.global_position
			var extent := absf(direction.x)*size.x*.5+absf(direction.y)*size.y*.5
			if absf(center.distance_to(body.global_position)-extent-radius) > 1.0: continue
			await frames(6)
			lab.world._update_camera_and_actor_projection(0.0)
			lab.update_visibility()
			await frames(5)
			collect_native_geometry()
			var eye: Vector3 = lab.world.to_global(Vector3(center.x/32.0,.95,center.y/32.0))
			var target_2d := center-direction*24.0
			var target: Vector3 = lab.world.to_global(Vector3(target_2d.x/32.0,.95,target_2d.y/32.0))
			if not strict_visible(eye,target,native_triangles): continue
			var actual: bool = lab.visibility_field.is_point_visible(target_2d)
			var row := {"direction":direction,"feet":player.global_position,"body_center":center,"light":lab.visibility_field.light_position,"body_eye":eye,"wall":body.name,"own_room_visible":actual}
			contacts.append(row)
			check(actual,"Native wall contact %s still sees its own room" % str(direction))
			write_picture("contact_%d_on" % contacts.size())
			lab.set_vision_enabled(false)
			await frames(4)
			write_picture("contact_%d_off" % contacts.size())
			lab.set_vision_enabled(true)
			if direction == Vector2.DOWN:
				var walk_mismatches := 0
				var walk_start := player.global_position
				player.set_physics_process(true)
				Input.action_press("move_right")
				for step in 12:
					for tick in 3: await physics_frame
					await frames(1)
					var current_center := body_shape.global_position
					var room_point := current_center-direction*24.0
					var current_eye: Vector3 = lab.world.to_global(Vector3(current_center.x/32.0,.95,current_center.y/32.0))
					var room_target: Vector3 = lab.world.to_global(Vector3(room_point.x/32.0,.95,room_point.y/32.0))
					if strict_visible(current_eye,room_target,native_triangles) and not lab.visibility_field.is_point_visible(room_point): walk_mismatches += 1
					write_picture("wall_walk_%02d" % step)
				Input.action_release("move_right"); Input.action_release("move_down")
				player.set_physics_process(false)
				evidence["wall_walk"] = {"false_hidden_frames":walk_mismatches,"movement":player.global_position.distance_to(walk_start)}
				check(player.global_position.distance_to(walk_start)>4.0,"Input actually moves the character along the wall")
				check(walk_mismatches == 0,"Actual input sliding along the wall retains its own room")
			found=true
			break
		check(found,"Native collision contact fixture exists for %s" % str(direction))
	evidence["wall_contacts"] = contacts

func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	destination = ROOT_OUT.path_join("baseline" if baseline else "fixed")
	if "--receiver-only" in OS.get_cmdline_user_args(): destination = ROOT_OUT.path_join("receiver_diagnostic")
	DirAccess.make_dir_recursive_absolute(destination)
	create_timer(240.0).timeout.connect(func(): print("SURFACE_TIMEOUT"); quit(2))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-20000,-20000))
	if "--receiver-only" in OS.get_cmdline_user_args():
		RenderingServer.global_shader_parameter_add(&"hk_woo_polygon_enabled",RenderingServer.GLOBAL_VAR_TYPE_BOOL,true)
		for key in [&"hk_woo_polygon_rect",&"hk_woo_polygon_map_x",&"hk_woo_polygon_map_z"]:
			RenderingServer.global_shader_parameter_add(key,RenderingServer.GLOBAL_VAR_TYPE_VEC4,Vector4())
		await material_probe()
		finish_surface()
		return
	await synthetic_test()
	lab = load("res://scenes/preview/hellkind_purple_sample.tscn").instantiate()
	lab.automation = true
	root.add_child(lab)
	while not lab.sample_ready or lab.busy or lab._loading_layer.visible: await process_frame
	lab.sample_ui.hide()
	lab.world.player.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(6)
	await material_probe()
	await contact_probe()
	var audio: Node = root.get_node("SFXManager")
	if audio.music_tween != null and audio.music_tween.is_valid(): audio.music_tween.kill()
	audio.music_player.stop()
	audio.music_player.stream = null
	await lab.retire_drawing()
	lab.queue_free()
	await frames(6)
	finish_surface()

func finish_surface() -> void:
	var file := FileAccess.open(destination.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"baseline":baseline},"\t"))
	file.close()
	print("SURFACE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if baseline or failures.is_empty() else 1)
