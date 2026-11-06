extends SceneTree
## Real-GPU 3D depth oracle and main-Camera review. The oracle intersects source
## triangles directly; it does not reuse the runtime's shadow or physics result.
const OUT := "res://.runtime/hellkind_purple_sample_20261103/volume_shadow_revision"
const FIELD = preload("res://scripts/preview/woo_visibility_shadow.gd")
const BREACH = preload("res://scripts/dream/shared_wall_breach.gd")
var lab
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var native_triangles := PackedVector3Array()
var last_sampled_depth := 0.0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", message)
	if not condition: failures.append(message)

func frames(count: int) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func write_picture(name: String) -> void:
	var image: Image = lab.world.get_viewport().get_texture().get_image()
	check(image.save_png(OUT.path_join(name + ".png")) == OK, "Camera capture " + name)

func source_triangles(mesh: Mesh, transform: Transform3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and not indices.is_empty():
			for index: int in indices: result.append(transform * vertices[index])
		else:
			for vertex in vertices: result.append(transform * vertex)
	return result

func cpu_visible(origin: Vector3, target: Vector3, triangles: PackedVector3Array) -> bool:
	var ray := target - origin
	var distance := ray.length()
	if distance < 0.01: return true
	for i in range(0, triangles.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, ray / distance, triangles[i], triangles[i+1], triangles[i+2])
		if hit is Vector3 and origin.distance_to(hit) < distance - 0.025: return false
	return true

func gpu_visible(field: Node, target: Vector3, atlas: Image) -> bool:
	var direction: Vector3 = target - field.light_position
	var face := 0
	var best_dot := -INF
	for i in 6:
		var dot := direction.dot(FIELD.DIRECTIONS[i])
		if dot > best_dot: best_dot = dot; face = i
	# Independent engine projection (not the shader's cube-face formula).
	var pixel: Vector2 = field._cameras[face].unproject_position(target)
	var uv := Vector2i(clampi(floori(pixel.x), 0, FIELD.FACE_SIZE-1), clampi(floori(pixel.y), 0, FIELD.FACE_SIZE-1))
	uv += Vector2i(face % 3, face / 3) * FIELD.FACE_SIZE
	var plane := atlas.get_pixelv(uv)
	if plane.r >= .9999: last_sampled_depth = field.range_pixels/32.0; return true
	var oct := Vector2(plane.g,plane.b)*2.0-Vector2.ONE
	var normal := Vector3(oct.x,oct.y,1.0-absf(oct.x)-absf(oct.y))
	if normal.z < 0.0:
		var old_x := normal.x
		normal.x = (1.0-absf(normal.y))*(1.0 if old_x>=0.0 else -1.0)
		normal.y = (1.0-absf(old_x))*(1.0 if normal.y>=0.0 else -1.0)
	normal = normal.normalized()
	var plane_distance: float = plane.r*field.range_pixels/32.0
	last_sampled_depth = plane_distance/maxf(normal.dot(direction.normalized()),.000001)
	return normal.dot(direction) <= plane_distance+.0015+plane_distance*.0005

func set_probe_origin(field: Node, origin: Vector3) -> void:
	field.light_position = origin
	var packed := Vector4(origin.x, origin.y, origin.z, field.range_pixels / 32.0)
	field._depth_material.set_shader_parameter("vision_origin_range", packed)
	RenderingServer.global_shader_parameter_set(FIELD.ORIGIN, packed)
	for camera: Camera3D in field._cameras: camera.position = origin
	field._request_draw()

func synthetic_test() -> void:
	var field := FIELD.new()
	root.add_child(field)
	field._create_shadow_rig()
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 3.0, 0.25)
	var wall := source_triangles(box, Transform3D(Basis(), Vector3(0,1.5,0)))
	box = BoxMesh.new()
	box.size = Vector3(0.25, 3.0, 3.0)
	wall.append_array(source_triangles(box, Transform3D(Basis(), Vector3(3,1.5,1.375))))
	field._install_static_vertices(wall)
	var targets: Array[Vector3] = [Vector3(0,.95,-.15),Vector3(0,.95,.15), Vector3(-3.025,.95,0),Vector3(3.15,.95,2),Vector3(0,3.025,0),Vector3(0,.1,3),Vector3(4,.1,1),Vector3(0,8,3)]
	var mismatch := 0
	var rows: Array[Dictionary] = []
	for origin in [Vector3(0,.95,-4),Vector3(5,.95,0),Vector3(0,.95,5),Vector3(-5,.95,0)]:
		set_probe_origin(field, origin)
		await frames(3)
		var atlas: Image = field.texture.get_image()
		for target in targets:
			var expected := cpu_visible(origin, target, wall)
			var actual := gpu_visible(field, target, atlas)
			if expected != actual: mismatch += 1
			rows.append({"origin": origin, "target": target, "cpu": expected, "gpu": actual})
	check(mismatch == 0, "Merged L wall: front, back, sides, height and all four player directions agree with source triangles")
	evidence["l_wall"] = {"mismatches": mismatch, "samples": rows}
	# A real opening in a complete wall: not a transparent material painted
	# on a rectangular blocker. Sill/header must still occlude their rays.
	wall.clear()
	for part in [[Vector3(.25,3,.25),Vector3(-1,1.5,0)],[Vector3(.25,3,.25),Vector3(1,1.5,0)],[Vector3(2,.7,.25),Vector3(0,.35,0)],[Vector3(2,.5,.25),Vector3(0,2.75,0)]]:
		box = BoxMesh.new(); box.size = part[0]
		wall.append_array(source_triangles(box, Transform3D(Basis(),part[1])))
	field._install_static_vertices(wall)
	set_probe_origin(field, Vector3(0,.95,-1))
	await frames(3)
	var atlas: Image = field.texture.get_image()
	var clear_target := Vector3(0,.95,3)
	var blocked_target := Vector3(0,0,1)
	check(cpu_visible(field.light_position, clear_target, wall) and gpu_visible(field, clear_target, atlas), "Window opening transmits vision at eye height")
	check(not cpu_visible(field.light_position, blocked_target, wall) and not gpu_visible(field, blocked_target, atlas), "Window sill still casts a three-dimensional shadow on low surfaces")
	field._install_static_vertices(PackedVector3Array())
	field._request_draw()
	await frames(3)
	atlas = field.texture.get_image()
	check(gpu_visible(field, blocked_target, atlas), "Removed architecture clears every shadow face")
	field.free()
	await frames(2)

func collect_native_geometry() -> void:
	native_triangles.clear()
	for wall in lab.world.wall_root.get_children():
		var mesh := wall.get_node_or_null(^"ShadowCasterMesh") as MeshInstance3D
		if mesh != null and mesh.mesh != null and not wall.is_queued_for_deletion():
			native_triangles.append_array(source_triangles(mesh.mesh, mesh.global_transform))
	for door in lab.world.door_root.get_children():
		if not door is PhysicalDoor3D or door.is_destroyed: continue
		for mesh: MeshInstance3D in door._visuals:
			if mesh.visible and mesh.mesh != null: native_triangles.append_array(source_triangles(mesh.mesh,mesh.global_transform))

func move_to(point: Vector2) -> void:
	lab.world.player.global_position = point
	lab.world.player.velocity = Vector2.ZERO
	lab.world._update_camera_and_actor_projection(0.0)
	await frames(4)
	lab.update_visibility()
	await frames(3)

func find_wall() -> Dictionary:
	var camera_direction: Vector3 = lab.world.global_basis.inverse() * lab.world.camera_3d.global_basis.z
	var toward_camera := Vector2(camera_direction.x,camera_direction.z).normalized()
	var keys: Array = lab.world.wall_edges.keys()
	var start: Vector2 = lab.world.player.global_position
	keys.sort_custom(func(a,b): return lab.world._edge_gameplay_position(lab.world.wall_edges[a]).distance_squared_to(start)<lab.world._edge_gameplay_position(lab.world.wall_edges[b]).distance_squared_to(start))
	for key in keys:
		if BREACH.wall_for_key(lab.world,str(key)) == null: continue
		var edge: Dictionary = lab.world.wall_edges[key]
		var sides: Array = lab.world._edge_side_cells(edge)
		if sides.size() != 2 or not lab.world.floor_cells.has(sides[0]) or not lab.world.floor_cells.has(sides[1]): continue
		var normal := Vector2.DOWN if str(edge.axis) == "H" else Vector2.RIGHT
		if normal.dot(toward_camera) < 0: normal = -normal
		var body := lab.world.collision_root.get_node_or_null("WallCollision_"+str(key).replace(":","_")) as StaticBody2D
		if body==null: continue
		var center: Vector2 = body.global_position
		var origin := center - normal * 48.0
		var target := center + normal * 48.0
		if lab.world.floor_cells.has(Vector2i((origin/32.0).floor())) and lab.world.floor_cells.has(Vector2i((target/32.0).floor())) and lab.world._is_blood_ground_allowed(origin) and lab.world._is_blood_ground_allowed(target):
			return {"key":key,"origin":origin,"target":target,"normal":normal}
	return {}

func orange_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			if color.r > .45 and color.g > .12 and color.g < color.r*.8 and color.b < .24: count += 1
	return count

func dynamic_test() -> void:
	var wall := find_wall()
	check(not wall.is_empty(), "Real masonry fixture with accessible floor on both sides")
	if wall.is_empty(): return
	evidence["wall_fixture"] = wall
	await move_to(wall.origin)
	var field: Node = lab.visibility_field
	var target: Vector3 = lab.world.to_global(Vector3(wall.target.x/32.0,0.05,wall.target.y/32.0))
	collect_native_geometry()
	check(not cpu_visible(field.light_position,target,native_triangles) and not gpu_visible(field,target,field.texture.get_image()), "Intact complete wall conceals the actual far-side floor")
	var before_count := orange_pixels(lab.world.get_viewport().get_texture().get_image())
	lab.world.spawn_death_blood_pool(wall.origin,-1,4.0,false,Vector2.ZERO)
	for i in 100: await physics_frame
	await frames(3)
	var after_count := orange_pixels(lab.world.get_viewport().get_texture().get_image())
	check(after_count >= before_count+4, "Visible native blood remains orange")
	write_picture("orange_blood_volume")
	lab.set_vision_enabled(false)
	await frames(3)
	var before_hidden: Image = lab.world.get_viewport().get_texture().get_image()
	var blood_count: int = lab.world._owned_black_blood_stains.size()
	lab.world.spawn_death_blood_pool(wall.target,-1,4.0,false,Vector2.ZERO)
	check(lab.world._owned_black_blood_stains.size()>blood_count,"Actual far-side blood pool is spawned")
	for i in 100: await physics_frame
	await frames(3)
	var off: Image = lab.world.get_viewport().get_texture().get_image()
	write_picture("behind_wall_blood_off")
	lab.set_vision_enabled(true)
	await frames(3)
	var on: Image = lab.world.get_viewport().get_texture().get_image()
	write_picture("behind_wall_blood_volume")
	var hidden_pixels := 0
	var leaks := 0
	var camera: Camera3D = lab.world.camera_3d
	var floor_plane := Plane(Vector3.UP,0.01)
	for y in off.get_height():
		for x in off.get_width():
			var c := off.get_pixel(x,y)
			var previous := before_hidden.get_pixel(x,y)
			if not (c.r>.45 and c.g>.12 and c.g<c.r*.8 and c.b<.24): continue
			if previous.r>.45 and previous.g>.12 and previous.g<previous.r*.8 and previous.b<.24: continue
			var pixel := Vector2(x+.5,y+.5)
			var hit: Variant = floor_plane.intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
			if not hit is Vector3 or cpu_visible(field.light_position,hit,native_triangles): continue
			hidden_pixels += 1
			var shown := on.get_pixel(x,y)
			if maxf(shown.r,maxf(shown.g,shown.b)) > .04: leaks += 1
	check(hidden_pixels >= 4 and leaks == 0, "Far-side blood is blacked out by actual 3D occlusion")
	evidence["blood"] = {"orange_before":before_count,"orange_after":after_count,"hidden_pixels":hidden_pixels,"leaks":leaks}
	var builds: int = field.static_builds
	var removed: int = lab.world._commit_dash_wall_breaches([wall.key],lab.world.get_current_floor_token(),wall.normal)
	for i in 4: await physics_frame
	await frames(4)
	collect_native_geometry()
	check(removed==1 and lab.world.edge_states.get(wall.key)==&"OPEN", "Native breach removes the real wall topology")
	check(field.static_builds>builds and cpu_visible(field.light_position,target,native_triangles) and gpu_visible(field,target,field.texture.get_image()), "Breach rebuilds the unified architecture and reveals the new opening")
	evidence["breach_visibility_cpu"] = field.last_topology_profile.duplicate()
	write_picture("after_breach_volume")
	var record := {}
	for door in lab.world.door_root.get_children():
		if not door is PhysicalDoor3D or door.is_destroyed or door.is_locked() or door._collision_bodies.is_empty(): continue
		var body: StaticBody2D = door._collision_bodies[0]
		var normal := Vector2.from_angle(body.global_rotation+PI*.5)
		var center: Vector2 = door.get_leaf_center_2d(0)
		for side in [-1.0,1.0]:
			var origin: Vector2 = center-normal*side*64.0
			var goal: Vector2 = center+normal*side*64.0
			if lab.world._is_blood_ground_allowed(origin) and lab.world._is_blood_ground_allowed(goal): record={"door":door,"origin":origin,"target":goal}; break
		if not record.is_empty(): break
	check(not record.is_empty(), "Real hinged door fixture")
	if not record.is_empty():
		await move_to(record.origin)
		builds = field.static_builds
		var door: PhysicalDoor3D = record.door
		var samples: Array[Dictionary] = []
		var errors := 0
		var first_angle := door.get_open_angle()
		var max_angle := first_angle
		for i in 90:
			door.prepare_enemy_passage(record.origin)
			await physics_frame
			if i%6 != 0: continue
			await frames(1)
			collect_native_geometry()
			var point: Vector3 = lab.world.to_global(Vector3(record.target.x/32.0,FIELD.EYE_HEIGHT,record.target.y/32.0))
			var expected := cpu_visible(field.light_position,point,native_triangles)
			var actual := gpu_visible(field,point,field.texture.get_image())
			var sparse: bool = field.is_point_visible(record.target)
			if expected != actual or sparse != expected: errors += 1
			max_angle = maxf(max_angle,door.get_open_angle())
			samples.append({"angle":door.get_open_angle(),"cpu":expected,"gpu":actual,"object_los":sparse})
		check(max_angle > first_angle+.2, "Original door physically rotates during visibility test")
		check(errors == 0, "Rotating door GPU shadow and object visibility match exact current geometry")
		check(field.static_builds == builds, "Door rotation does not rebuild static walls")
		evidence["door"] = {"errors":errors,"samples":samples}
		write_picture("real_door_open_volume")
	# Capture actual input-driven movement, then release the original actor.
	lab.teleport(3)
	lab.world.player.process_mode = Node.PROCESS_MODE_INHERIT
	var start: Vector2 = lab.world.player.global_position
	builds = field.static_builds
	Input.action_press("move_right")
	for i in 12:
		for tick in 3: await physics_frame
		await frames(1)
		write_picture("walk_%02d" % i)
	Input.action_release("move_right")
	check(lab.world.player.global_position.distance_to(start)>4.0, "Actual player input updates the visibility light while walking")
	check(field.static_builds==builds, "Walking only updates the light, not separate wall geometry")
	check(lab.measure_player_body_pixels() >=30.0 and lab.measure_player_body_pixels() <=34.0, "Complete original player remains approximately 32 pixels")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	create_timer(300.0).timeout.connect(func(): print("VOLUME_TIMEOUT"); quit(2))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-20000,-20000))
	check(DisplayServer.get_name() != "headless", "Actual GPU renderer")
	await synthetic_test()
	lab = load("res://scenes/preview/visibility_light_sample.tscn").instantiate()
	lab.use_volume_visibility = true
	lab.style_index = 3
	root.add_child(lab)
	while not lab.sample_ready or lab.busy: await process_frame
	lab.apply_style(3)
	lab.sample_ui.hide()
	lab.world.player.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(10)
	check(lab.world.get_viewport().size == Vector2i(640,360), "Original 640 by 360 render resolution")
	check(lab.visibility_field._static_mesh.mesh.get_surface_count() == 1, "All static wall surfaces share one merged depth draw")
	check(lab.visibility_field._cameras.size() == 6, "One player-centred shadow map covers all directions")
	evidence["static_triangles"] = lab.visibility_field.static_triangle_count
	evidence["casters"] = lab.visibility_field.caster_count
	evidence["format"] = lab.visibility_field.texture.get_image().get_format()
	evidence["depth_material_code"] = lab.visibility_field._depth_material.shader.code
	evidence["depth_managed_as_receiver"] = lab.visibility_surfaces._records.has(lab.visibility_field._depth_material)
	var count := 0
	var mismatches: Array[Dictionary] = []
	for station in 4:
		lab.teleport(station)
		await frames(6)
		lab.update_visibility()
		await frames(3)
		collect_native_geometry()
		if station == 0:
			evidence["geometry_debug"] = {"caster_transform":lab.visibility_field._casters.global_transform,
				"baked_first":lab.visibility_field._static_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].slice(0,6),
				"native_first":native_triangles.slice(0,6),"world_transform":lab.world.global_transform}
		var atlas: Image = lab.visibility_field.texture.get_image()
		var origin: Vector3 = lab.visibility_field.light_position
		evidence["shadow_state_%d" % station] = {"origin_uniform":lab.visibility_field._depth_material.get_shader_parameter("vision_origin_range"), "camera":lab.visibility_field._cameras[0].global_transform,"atlas_size":atlas.get_size(),"caster_aabb":lab.visibility_field._static_mesh.mesh.get_aabb()}
		for ring in [2.0,4.0,7.0,10.0]:
			for i in 16:
				var direction := Vector2.from_angle(TAU*float(i)/16.0 + .037)
				for height in [0.05,0.95,2.0]:
					var target := origin + Vector3(direction.x*ring,height-origin.y,direction.y*ring)
					var expected := cpu_visible(origin,target,native_triangles)
					var actual := gpu_visible(lab.visibility_field,target,atlas)
					count += 1
					if expected != actual: mismatches.append({"station":station,"origin":origin,"target":target,"cpu":expected,"gpu":actual,"depth":last_sampled_depth})
		atlas.save_exr(OUT.path_join("depth_%d.exr" % station))
		write_picture("room_%d_volume" % station)
		lab.set_vision_enabled(false)
		await frames(3)
		write_picture("room_%d_off" % station)
		lab.set_vision_enabled(true)
		await frames(3)
	check(mismatches.is_empty(), "Four rooms: GPU depth agrees with independent source-triangle visibility")
	evidence["native_geometry_oracle"] = {"samples":count,"mismatches":mismatches}
	check(lab.visibility_surfaces.unsupported_names.is_empty(), "Existing material paths all support the visibility light")
	await dynamic_test()
	# Preserve the newer art treatment as well; only occlusion is replaced.
	lab.apply_style(4)
	await frames(6)
	write_picture("existing_halftone_volume")
	var old_field: WeakRef = weakref(lab.visibility_field)
	await lab.rebuild()
	while not lab.sample_ready or lab.busy: await process_frame
	await frames(4)
	check(old_field.get_ref()==null and lab.visibility_field.field_ready,"Reset releases old shadow world and installs a fresh field")
	await lab.retire_drawing()
	lab.queue_free()
	await frames(6)
	var file := FileAccess.open(OUT.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real GPU depth/camera correctness only; not whole-game 60 FPS certification"},"\t"))
	file.close()
	print("VOLUME_RESULT ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
