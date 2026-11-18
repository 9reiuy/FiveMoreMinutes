extends Node3D
## Approved Le Lu reference study: smooth heat, curved plumes and flying sparks.
## Visual-only. The shared pool owns time, surface context and Camera glow.
const BODY_V2 := preload("res://shaders/dream3d/explosion_cloud.gdshader")
const SHELL_V2 := preload("res://shaders/dream3d/explosion_shock.gdshader")
const SPARK_V2 := preload("res://shaders/dream3d/explosion_streak.gdshader")
const GROUND_V2 := preload("res://shaders/dream3d/explosion_cracks.gdshader")
const HIT_V2 := preload("res://shaders/dream3d/explosion_flash.gdshader")
const PRIMARY := 7
const PLUMES := 5
const PUFFS := 9
const FLYING_SPARKS := 64
const SOURCE_TEXTURES := {
	"T_cloudy_noise_211c.png": preload("res://art/Dream/VFX/LeLuExplosion/textures/T_cloudy_noise_211c.res"),
	"T_VFX_Noise_44xainv.png": preload("res://art/Dream/VFX/LeLuExplosion/textures/T_VFX_Noise_44xainv.res"),
	"T_MarbleNoise_tiled.png": preload("res://art/Dream/VFX/LeLuExplosion/textures/T_MarbleNoise_tiled.res"),
	"T_4_streaks.png": preload("res://art/Dream/VFX/LeLuExplosion/textures/T_4_streaks.res"),
	"T_vfx_hit122.jpg": preload("res://art/Dream/VFX/LeLuExplosion/textures/T_vfx_hit122.res"),
	"T_cracks33_E3.jpg": preload("res://art/Dream/VFX/LeLuExplosion/textures/T_cracks33_E3.res"),
}
var cloud: MultiMeshInstance3D
var streak: MultiMeshInstance3D
var shock: MeshInstance3D
var flash: MeshInstance3D
var cracks: MeshInstance3D
var cloud_material: ShaderMaterial
var streak_material: ShaderMaterial
var shock_material: ShaderMaterial
var flash_material: ShaderMaterial
var crack_material: ShaderMaterial
var points: Array[Dictionary] = []
var age := 0.0
var seed_id := 0
var surface_y := 0.0
var ground_marks := true
var surface_anchor := Vector3.ZERO
var shock_anchor := Vector3.ZERO

static func source_texture(filename: String) -> Texture2D:
	return SOURCE_TEXTURES[filename]

func set_surface_context(height: float, marks: bool) -> void:
	surface_y = height
	ground_marks = marks

func paint(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_meta(&"runtime_uniform_owner", true)
	return material

func bank(mesh: Mesh, material: ShaderMaterial, count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count
	var carrier := MultiMeshInstance3D.new()
	carrier.multimesh = multi
	carrier.material_override = material
	carrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carrier.custom_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 18, 24))
	add_child(carrier)
	return carrier

func surface(mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var carrier := MeshInstance3D.new()
	carrier.mesh = mesh
	carrier.material_override = material
	carrier.set_meta(&"surface_blood_excluded", true)
	carrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(carrier)
	return carrier

func retire() -> void:
	hide()
	age = 2.8

var trail_flights: Array[Dictionary] = []
var spark_flights: Array[Dictionary] = []
var debris_flights: Array[Dictionary] = []
var tips: MultiMeshInstance3D
var debris: MultiMeshInstance3D

func open_hemisphere() -> ArrayMesh:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var triangles := PackedInt32Array()
	var slices := 40
	var rows := 18
	for row in range(rows + 1):
		var v := float(row) / float(rows)
		var theta := v * PI * .5
		for column in range(slices + 1):
			var u := float(column) / float(slices)
			var point := Vector3(cos(u * TAU) * sin(theta), cos(theta), sin(u * TAU) * sin(theta))
			positions.append(point)
			normals.append(point)
			uv.append(Vector2(u, v))
	for row in rows:
		for column in slices:
			var a := row * (slices + 1) + column
			var b := a + 1
			var c := a + slices + 1
			var d := c + 1
			triangles.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ready() -> void:
	cloud_material = paint(BODY_V2)
	cloud_material.set_shader_parameter("cloud_noise", source_texture("T_cloudy_noise_211c.png"))
	cloud_material.set_shader_parameter("heat_noise", source_texture("T_VFX_Noise_44xainv.png"))
	cloud_material.set_shader_parameter("dissolve_noise", source_texture("T_VFX_Noise_44xainv.png"))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 14
	cloud = bank(sphere, cloud_material, PRIMARY + PLUMES * PUFFS)
	cloud.name = "SmoothHeatClouds"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = .09
	cone.height = .48
	cone.radial_segments = 6
	tips = bank(cone, cloud_material, PLUMES)
	tips.name = "HotPlumeTips"
	streak_material = paint(SPARK_V2)
	streak_material.set_shader_parameter("streaks", source_texture("T_4_streaks.png"))
	var ribbon := QuadMesh.new()
	ribbon.size = Vector2.ONE
	streak = bank(ribbon, streak_material, FLYING_SPARKS)
	streak.name = "FlyingSparks"
	shock_material = paint(SHELL_V2)
	shock_material.set_shader_parameter("cloud_noise", source_texture("T_cloudy_noise_211c.png"))
	shock_material.set_shader_parameter("heat_noise", source_texture("T_MarbleNoise_tiled.png"))
	shock = surface(open_hemisphere(), shock_material)
	shock.name = "BroadRaggedShock"
	flash_material = paint(HIT_V2)
	flash_material.set_shader_parameter("flash_mask", source_texture("T_vfx_hit122.jpg"))
	var hit := QuadMesh.new()
	hit.size = Vector2.ONE
	flash = surface(hit, flash_material)
	flash.name = "ShortIgnition"
	crack_material = paint(GROUND_V2)
	crack_material.set_shader_parameter("cracks", source_texture("T_cracks33_E3.jpg"))
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(3.6, 3.6)
	cracks = surface(floor_mesh, crack_material)
	cracks.name = "HotGroundFracture"
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE
	var chunk_material := ShaderMaterial.new()
	chunk_material.shader = preload("res://shaders/dream3d/explosion_debris.gdshader")
	debris = bank(chunk, chunk_material, 14)
	debris.name = "VisualDebris"
	hide()

func activate(at: Vector3, strength: float, seed_value: int) -> void:
	seed_id = seed_value
	position = at
	# Match the source effect's proportions against a 1.8m height reference.
	var visual_scale := strength * .75
	scale = Vector3.ONE * visual_scale
	surface_anchor = Vector3(at.x, surface_y + .025, at.z)
	shock_anchor = surface_anchor if ground_marks else at + Vector3(0, -.20, 0)
	cracks.position = transform.affine_inverse() * surface_anchor
	shock.position = transform.affine_inverse() * shock_anchor
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	rotation.y = random.randf_range(-PI, PI)
	points.clear()
	trail_flights.clear()
	spark_flights.clear()
	debris_flights.clear()
	var centers: Array[Vector3] = [Vector3(0, .78, 0), Vector3(.46, .53, .12), Vector3(-.46, .56, -.08), Vector3(.10, .50, .46), Vector3(-.12, .55, -.44), Vector3(.22, 1.12, .02), Vector3(-.22, 1.12, -.06)]
	for i in PRIMARY:
		points.append({"at": centers[i], "radius": (.72 if i == 0 else .56 if i < 5 else .46) * random.randf_range(.94, 1.06), "seed": random.randf(), "delay": random.randf_range(0.0, .018), "trail": false})
	for i in PLUMES:
		var theta := float(i) * TAU / float(PLUMES) + random.randf_range(-.55, .55)
		var velocity := Vector3(cos(theta) * random.randf_range(3.2, 4.7), random.randf_range(1.8, 2.8) if i == 0 else random.randf_range(4.5, 7.0), sin(theta) * random.randf_range(3.2, 4.7))
		if i == PLUMES - 1:
			velocity.x *= .22
			velocity.z *= .22
		trail_flights.append({"velocity": velocity, "bend": random.randf_range(-.6, .6), "gravity": random.randf_range(2.5, 4.3)})
		tips.multimesh.set_instance_custom_data(i, Color(random.randf(), 1, .03, 2))
		for j in PUFFS:
			var progress := float(j) / float(PUFFS - 1)
			points.append({"radius": lerpf(.15, .095, progress) * random.randf_range(.78, 1.26), "seed": random.randf(), "delay": .025 + progress * .32, "trail": true, "flight": i, "progress": progress})
	for i in points.size():
		var data: Dictionary = points[i]
		cloud.multimesh.set_instance_custom_data(i, Color(data.seed, float(data.progress) if data.trail else 1.0, data.delay, 1.0 if data.trail else 0.0))
	for i in FLYING_SPARKS:
		var theta := random.randf_range(-PI, PI)
		var direction := Vector3(cos(theta), random.randf_range(.02, .18) if i < 25 else random.randf_range(.25, 1.1), sin(theta)).normalized()
		var birth := random.randf_range(.0, .055)
		var life := random.randf_range(.40, .90)
		var velocity := direction * random.randf_range(5.0, 12.0)
		spark_flights.append({"velocity": velocity, "birth": birth, "life": life, "width": random.randf_range(.12, .28), "size": random.randf_range(.8, 1.3) if i < 14 else random.randf_range(.20, .55)})
		streak.multimesh.set_instance_custom_data(i, Color(random.randf(), birth, life, 1))
	for i in 14:
		var theta := random.randf_range(-PI, PI)
		debris_flights.append({"velocity": Vector3(cos(theta) * random.randf_range(1.2, 3.5), random.randf_range(2, 4.4), sin(theta) * random.randf_range(1.2, 3.5)), "size": random.randf_range(.065, .15), "angle": random.randf_range(-PI, PI)})
	show()
	set_age(0.0)

func trajectory(flight: int, time: float) -> Vector3:
	var data: Dictionary = trail_flights[flight]
	var velocity: Vector3 = data.velocity
	var center := velocity * time + Vector3(0, .20 - float(data.gravity) * time * time, 0)
	center.x += sin(time * 2.0) * float(data.bend) * time
	if ground_marks: center.y = maxf(.07, center.y)
	return center

func flight_basis(direction: Vector3) -> Basis:
	var y_axis := direction.normalized()
	var x_axis := y_axis.cross(Vector3.FORWARD).normalized()
	if x_axis.length_squared() < .01: x_axis = Vector3.RIGHT
	return Basis(x_axis, y_axis, x_axis.cross(y_axis).normalized())

func set_age(time: float) -> void:
	age = maxf(time, 0.0)
	cloud_material.set_shader_parameter("age", age)
	streak_material.set_shader_parameter("age", age)
	flash_material.set_shader_parameter("age", age)
	crack_material.set_shader_parameter("age", age)
	cloud.visible = age < 1.78
	tips.visible = age > .025 and age < 1.50
	cracks.visible = ground_marks and age > .035 and age < 2.50
	flash.visible = age > .001 and age < .105
	shock.visible = age > .008 and age < .31
	streak.visible = age > .01 and age < 1.0
	debris.visible = age > .035 and age < 2.65
	var radius := .12 + 3.6 * pow(clampf(age / .28, 0.0, 1.0), .65)
	shock.scale = Vector3.ONE * radius
	shock_material.set_shader_parameter("phase", clampf(age / .31, 0.0, 1.0))
	for i in points.size():
		var data: Dictionary = points[i]
		var t := maxf(age - float(data.delay), 0.0)
		var center: Vector3
		var pose: Basis
		if data.trail:
			var progress: float = data.progress
			var sample_time := maxf(age - .02, 0.0) * lerpf(.29, 1.0, progress)
			center = trajectory(int(data.flight), sample_time)
			center += Vector3(sin(progress * 12.0 + float(data.seed) * 2.0), cos(progress * 8.0), cos(progress * 11.0)) * .065 * smoothstep(0.0, .45, age)
			var forward := trajectory(int(data.flight), sample_time + .005) - center
			var size := maxf(.001, float(data.radius) * smoothstep(0.0, .14, t) * (1.0 + t * .72))
			var axis := flight_basis(forward)
			pose = Basis(axis.x * size, axis.y * size * 1.85, axis.z * size)
		else:
			var growth := smoothstep(0.0, .45, t)
			var size := maxf(.001, float(data.radius) * (.025 + growth) * (1.0 + t * .12) * 1.28)
			center = Vector3(data.at) * lerpf(.15, 1.0, growth)
			center *= 1.28
			center.y += t * .16
			pose = Basis(Vector3.UP, float(data.seed) * TAU).scaled(Vector3.ONE * size)
		cloud.multimesh.set_instance_transform(i, Transform3D(pose, center))
	var head_time := maxf(age - .02, 0.0)
	for i in PLUMES:
		var center := trajectory(i, head_time)
		var forward := trajectory(i, head_time + .005) - center
		var size := smoothstep(.02, .13, age) * (1.0 - smoothstep(1.12, 1.50, age))
		tips.multimesh.set_instance_transform(i, Transform3D(flight_basis(forward).scaled(Vector3.ONE * maxf(size, .001)), center))
	for i in debris_flights.size():
		var data: Dictionary = debris_flights[i]
		var t := maxf(age - .035, 0.0)
		var velocity: Vector3 = data.velocity
		var center := velocity * t + Vector3(0, .15 - 4.9 * t * t, 0)
		if ground_marks: center.y = maxf((surface_y + .015 - position.y) / scale.y + float(data.size) * .5, center.y)
		var pose := Basis.from_euler(Vector3(t * 2.8, float(data.angle) + t * 2.3, t * 3.5)).scaled(Vector3.ONE * float(data.size))
		debris.multimesh.set_instance_transform(i, Transform3D(pose, center))
	sync_transform()

func sync_transform() -> void:
	cracks.position = transform.affine_inverse() * surface_anchor
	shock.position = transform.affine_inverse() * shock_anchor
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var camera_basis := global_basis.inverse() * camera.global_basis
	var flash_size := .6 + 1.8 * smoothstep(0.0, .09, age)
	flash.transform = Transform3D(camera_basis.scaled(Vector3.ONE * flash_size), Vector3(0, .4, 0))
	for i in spark_flights.size():
		var data: Dictionary = spark_flights[i]
		var t := maxf(age - float(data.birth), 0.0)
		var velocity: Vector3 = data.velocity
		var center := Vector3(0, .25, 0) + velocity * t + Vector3(0, -2.8 * t * t, 0)
		if ground_marks: center.y = maxf(.03, center.y)
		var direction := (velocity + Vector3(0, -5.6 * t, 0)).normalized()
		var face := (to_local(camera.global_position) - center).normalized()
		var x_axis := direction.cross(face).normalized()
		if x_axis.length_squared() < .01: x_axis = Vector3.RIGHT
		var z_axis := x_axis.cross(direction).normalized()
		var length := lerpf(1.35, .13, smoothstep(.06, .53, t)) * float(data.size)
		var width := float(data.width)
		if age < float(data.birth) or t > float(data.life): width = .00001
		streak.multimesh.set_instance_transform(i, Transform3D(Basis(x_axis * width, direction * length, z_axis), center))
