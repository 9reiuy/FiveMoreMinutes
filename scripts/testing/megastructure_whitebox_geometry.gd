extends RefCounted
const LAYOUT = preload("res://scripts/testing/megastructure_whitebox_layout.gd")
const MAINTENANCE = preload("res://scripts/testing/maintenance_environment.gd")
const END_FADE := Vector4(-.5, 2.2, 34.9, 37.5)

static func build_boundaries(world: Node3D, right_opening := Vector2.ZERO, fade := END_FADE) -> void:
	var contours := LAYOUT.solid_boundaries()
	for index in contours.size():
		_add_boundary(world,contours[index],2.6 if index==0 else .65,"NorthContour" if index==0 else "SouthContour",fade)
	# The openings fade on the floor and side walls. Keep the end bodies invisible.
	# The west fade remains visible, but its old invisible end wall is removed.
	# The optional branch owns its outer collision limits.
	if right_opening == Vector2.ZERO:
		_add_boundary(world,PackedVector2Array([Vector2(37.5,-1),Vector2(38,-1),Vector2(38,12),Vector2(37.5,12)]),0.0,"RightBoundary")
	else:
		for span: Vector2 in [Vector2(-.5, right_opening.x), Vector2(right_opening.y, 11.5)]:
			var wall := PackedVector2Array([Vector2(37.5,span.x),Vector2(37.68,span.x),
				Vector2(37.68,span.y),Vector2(37.5,span.y)])
			_add_boundary(world, wall, 2.6, "LinkReturnWall", fade)

static func _add_boundary(world: Node3D, polygon: PackedVector2Array, height: float, title: String, fade := END_FADE) -> void:
	var body := StaticBody2D.new();body.name=title;body.collision_layer=4;body.collision_mask=0
	body.set_meta(&"whitebox_contour",polygon)
	var pixels := PackedVector2Array()
	for point in polygon:pixels.append(point*32.0)
	var collision := CollisionPolygon2D.new();collision.polygon=pixels
	body.add_child(collision);world.collision_root.add_child(body)
	if height <= 0.0:
		return
	var mesh := MeshInstance3D.new();mesh.name=title
	mesh.mesh=_prism(polygon,height,fade)
	world.wall_root.add_child(mesh)
	world.authored_cutout.register_mesh(mesh, false, true)
	# The front cutaway is presentation only; its high wall still casts shadows.
	if height<2.6:
		var shadow := MeshInstance3D.new();shadow.mesh=_prism(polygon,2.6)
		shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		world.wall_root.add_child(shadow)

static func _prism(polygon: PackedVector2Array, height: float, fade := Vector4.ZERO) -> ArrayMesh:
	# A separate surface on the existing wall mesh: continuous black cap,
	# concrete sides, with no overlapping cap geometry or extra occluder.
	var cap := SurfaceTool.new();cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	cap.set_material(MAINTENANCE.wall_top_black())
	var triangles := Geometry2D.triangulate_polygon(polygon)
	for index in range(0,triangles.size(),3):
		var a := Vector3(polygon[triangles[index]].x,height,polygon[triangles[index]].y)
		var b := Vector3(polygon[triangles[index+1]].x,height,polygon[triangles[index+1]].y)
		var c := Vector3(polygon[triangles[index+2]].x,height,polygon[triangles[index+2]].y)
		_triangle(cap,a,b,c,Vector3.UP)
	var mesh := cap.commit()
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var concrete := MAINTENANCE.concrete(false)
	concrete.set_shader_parameter("passage_end_fade", fade)
	surface.set_material(concrete)
	var signed_area := 0.0
	for index in polygon.size():signed_area+=polygon[index].cross(polygon[(index+1)%polygon.size()])
	for index in polygon.size():
		var a := Vector3(polygon[index].x,0,polygon[index].y)
		var b := Vector3(polygon[(index+1)%polygon.size()].x,0,polygon[(index+1)%polygon.size()].y)
		var c := b+Vector3.UP*height
		var edge := polygon[(index+1)%polygon.size()]-polygon[index]
		var outward := Vector3(edge.y,0,-edge.x).normalized()*signf(signed_area)
		_triangle(surface,a,b,c,outward);_triangle(surface,a,c,a+Vector3.UP*height,outward)
	surface.commit(mesh)
	return mesh

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot's front faces wind clockwise. Match that winding to the outward
	# lighting normal; two-sided rendering otherwise flips the visible wall's
	# normal inward and rejects light arriving from the playable corridor.
	if (b-a).cross(c-a).dot(normal)>0.0:
		var swap := b;b=c;c=swap
	surface.set_normal(normal);surface.add_vertex(a)
	surface.set_normal(normal);surface.add_vertex(b)
	surface.set_normal(normal);surface.add_vertex(c)

static func build_exit(world: Node3D) -> void:
	var label := Label3D.new();label.text="EXIT →";label.font_size=18;label.pixel_size=.015
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3(35.65,2.65,5.5)
	world.wake_exit_root.add_child(label)
