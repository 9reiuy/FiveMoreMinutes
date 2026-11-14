extends SceneTree
## The real 0-1 Camera and lighting, plus labelled close Camera inspection.
const EGG := preload("res://scripts/testing/level01_easter_layout.gd")
var display: Control
var world: Node3D
var output := ""
var checks := 0
var failures: Array[String] = []


func _initialize() -> void: call_deferred("run")


func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures.append(title)
	print("PASS " if ok else "FAIL ",title)


func ticks(count: int) -> void:
	for frame in count: await physics_frame


func capture(label: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = display.world_viewport.get_texture().get_image()
	check(picture != null and picture.save_png(output.path_join(label+".png")) == OK,"Actual Camera "+label)
	return picture


func wheel_clearance(mesh: ArrayMesh) -> bool:
	# Inspect the first visible material along side-on rays through the tyre.
	# This catches a solid side panel or full-length rub strip covering a wheel.
	var covered := 0
	for axle: Vector2 in [Vector2(-1.36,.332),Vector2(1.05,.302)]:
		for side: float in [-1.0,1.0]:
			for angle: float in [.15,.50,.95,1.57,2.19,2.64,2.99]:
				var xy := Vector2(axle.x,axle.y)+Vector2(cos(angle),sin(angle))*axle.y*.92
				var from := Vector3(xy.x,xy.y,side*1.30)
				var to := Vector3(xy.x,xy.y,side*.65)
				var nearest := INF
				var finish := -1
				for surface in mesh.get_surface_count():
					var material: ShaderMaterial = mesh.surface_get_material(surface)
					var arrays := mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for j in range(0,indices.size(),3):
						var at: Variant = Geometry3D.segment_intersects_triangle(from,to,vertices[indices[j]],vertices[indices[j+1]],vertices[indices[j+2]])
						if at == null: continue
						var distance: float = from.distance_to(at)
						if distance < nearest:
							nearest = distance
							finish = int(material.get_shader_parameter("finish_kind"))
				if finish != 2: covered += 1
	print("Wheel sidewall rays obstructed/missing: ",covered," / 28")
	return covered == 0


func wear_region_changes(before: Image, after: Image, camera: Camera3D, car: Node3D) -> Dictionary:
	var regions := {
		"door": [Vector3(-.74,.38,.947),Vector3(.49,.38,.947),Vector3(.49,.70,.947),Vector3(-.74,.70,.947)],
		"hood": [Vector3(1.03,.75,-.55),Vector3(1.75,.71,-.55),Vector3(1.75,.71,.55),Vector3(1.03,.75,.55)],
		"roof": [Vector3(-.48,1.19,-.47),Vector3(.10,1.19,-.47),Vector3(.10,1.19,.47),Vector3(-.48,1.19,.47)]}
	var result := {}
	for title: String in regions:
		var polygon := PackedVector2Array()
		for point: Vector3 in regions[title]: polygon.append(camera.unproject_position(car.to_global(point)))
		var rectangle := Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon: rectangle = rectangle.expand(point)
		var pixels := 0
		var difference := 0.0
		for y in range(maxi(0,floori(rectangle.position.y)),mini(before.get_height(),ceili(rectangle.end.y))):
			for x in range(maxi(0,floori(rectangle.position.x)),mini(before.get_width(),ceili(rectangle.end.x))):
				if not Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),polygon): continue
				var a := before.get_pixel(x,y)
				var b := after.get_pixel(x,y)
				difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
				pixels += 1
		result[title] = {"pixels":pixels,"mean_rgb_difference":difference/maxi(pixels,1)/3.0}
		check(pixels > 100 and difference/maxi(pixels,1)/3.0 > .001,"Wear is visible on "+title+" under the actual scene light")
	return result


func run() -> void:
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output = argument.trim_prefix("--artifact-dir=")
	display = load("res://scenes/testing/LinkedMaintenanceGarageDisplay.tscn").instantiate()
	root.add_child(display)
	current_scene = display
	world = display.world
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	process_frame.connect(func(): RenderingServer.force_draw(false))
	world.player.dash_invulnerability_left = 600.0
	for enemy: EmployeeEnemy in world.enemy_root.get_children():
		if int(enemy.get_meta(&"dream_room_id",-1)) < world.GARAGE_ROOM_ID and not enemy.dead:
			enemy.take_damage(enemy.maximum_health+100.0,world.player.global_position,0.0,&"model_review")
	await ticks(20)
	world.player.global_position = (EGG.CAR_AT+Vector2(3.8,2.2))*32.0
	await ticks(65)
	var egg: Node3D = world.floor_root.get_node("WestEasterEgg")
	var mesh: ArrayMesh = egg.car.get_node("StainlessWedgeCoupe").mesh
	var triangles := 0
	for s in mesh.get_surface_count(): triangles += mesh.surface_get_array_index_len(s)/3
	check(wheel_clearance(mesh),"All four tyre sidewalls clear the body and trim")
	check(egg.spotlight.shadow_enabled and RenderingServer.get_current_rendering_method() == "forward_plus","Production Forward+ and original shadowed spotlight")
	await capture("01_game_camera")
	# Freeze this authored scene only; no replacement studio lamps or environment.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = world.camera_3d
	var target: Vector3 = egg.car.global_position+Vector3(0,.55,0)
	camera.global_position = target+Vector3(5.3,3.25,4.6)
	camera.look_at(target,Vector3.UP)
	await ticks(6)
	await capture("02_front_detail")
	camera.global_position = target+Vector3(-5.1,3.1,4.8)
	camera.look_at(target,Vector3.UP)
	await ticks(6)
	await capture("03_rear_detail")
	camera.global_position = target+Vector3(.25,1.55,7.8)
	camera.look_at(target,Vector3.UP)
	await ticks(6)
	var aged: Image = await capture("04_side_aged")
	for surface in mesh.get_surface_count():
		var material: ShaderMaterial = mesh.surface_get_material(surface)
		material.set_shader_parameter("age",0.0)
	await ticks(6)
	var clean: Image = await capture("05_side_clean_comparison")
	var wear_regions := wear_region_changes(aged,clean,camera,egg.car)
	for surface in mesh.get_surface_count():
		var material: ShaderMaterial = mesh.surface_get_material(surface)
		material.set_shader_parameter("age",.78)
	await ticks(6)
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"triangles":triangles,"surfaces":mesh.get_surface_count(),"wear_region_comparison":wear_regions,"viewport":display.world_viewport.size,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"audio":AudioServer.get_driver_name(),"scope":"Original game Camera plus explicitly closer Camera views; original 0-1 light, probe and environment unchanged; no export"},"\t"))
	print("DMC12 REVIEW checks=",checks," failures=",failures," triangles=",triangles)
	quit(0 if failures.is_empty() else 1)
