extends Node3D
## The optional westward branch stays in 0-1 and retires with its entry region.
const LAYOUT := preload("res://scripts/testing/level01_easter_layout.gd")
const MIN_X := LAYOUT.MIN_X
const HEIGHT := LAYOUT.HEIGHT
const CAR_AT := LAYOUT.CAR_AT
const M := preload("res://scripts/testing/maintenance_environment.gd")
const CAR := preload("res://scripts/testing/dmc12_easter_prop.gd")
const FIRE := preload("res://scripts/dream/elemental_particles_3d.gd")
const BURN := preload("res://shaders/dream3d/burning_tyre_marks.gdshader")
static var _stage_ground_shader: Shader
var world: Node3D
var display: Node3D
var car: Node3D
var fire: Node3D
var spotlight: SpotLight3D
var _awake := false


func _init(owner_world: Node3D) -> void:
	world = owner_world
	name = "WestEasterEgg"
	set_meta(&"dream_room_id", 0)


func build() -> void:
	var black := M.wall_top_black()
	M.box(self,"UnlitWestPath",Vector3(140.0,.12,HEIGHT),Vector3(-70.5,-.06,5.5),black)
	display = Node3D.new()
	display.name = "SpotlitReveal"
	add_child(display)
	var ground := M.concrete(true)
	if _stage_ground_shader == null:
		_stage_ground_shader = Shader.new()
		_stage_ground_shader.code = ground.shader.code.replace(
			"apply_passage_end_fade(surface_world.x, ALBEDO, ROUGHNESS, SPECULAR);",
			"""apply_passage_end_fade(surface_world.x, ALBEDO, ROUGHNESS, SPECULAR);
			float stage_edge = smoothstep(-.5, 1.2, surface_world.z) * (1.0 - smoothstep(9.8, 11.5, surface_world.z));
			ALBEDO *= stage_edge;
			SPECULAR *= stage_edge;
			ROUGHNESS = mix(1.0, ROUGHNESS, stage_edge);""")
	ground.shader = _stage_ground_shader
	ground.set_shader_parameter("wear_amount", .38)
	ground.set_shader_parameter("wetness", .55)
	ground.set_shader_parameter("passage_end_fade", Vector4(-168.5,-165.0,-143.0,-140.5))
	M.box(display,"RevealFloor",Vector3(28.0,.12,12.0),Vector3(-154.5,-.06,5.5),ground)
	car = CAR.build()
	car.position = Vector3(CAR_AT.x,0.0,CAR_AT.y)
	# A slight angle exposes the front, gull-wing door and slatted rear deck.
	car.rotation.y = -.32
	display.add_child(car)
	spotlight = SpotLight3D.new()
	spotlight.name = "CarExhibitionSpotlight"
	spotlight.position = Vector3(CAR_AT.x+1.25,6.4,CAR_AT.y+1.75)
	spotlight.light_color = Color("e2ecf1")
	spotlight.light_energy = 11.0
	spotlight.spot_range = 12.0
	spotlight.spot_angle = 30.0
	spotlight.spot_attenuation = .85
	spotlight.spot_angle_attenuation = 1.8
	spotlight.shadow_enabled = true
	spotlight.light_cull_mask = 15
	spotlight.shadow_caster_mask = 15
	display.add_child(spotlight)
	spotlight.look_at(Vector3(CAR_AT.x,.25,CAR_AT.y),Vector3.UP)
	var fixture := M.metal(Color("141a1e"),.65)
	M.cylinder(display,"OverheadSpotHousing",.22,.34,spotlight.position,fixture)
	var probe := ReflectionProbe.new()
	probe.name = "StainlessReflection"
	probe.position = Vector3(CAR_AT.x,1.45,CAR_AT.y)
	probe.size = Vector3(11,7,11)
	probe.box_projection = true
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.cull_mask = 1
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	display.add_child(probe)
	_build_tracks()
	var collision := Node2D.new()
	collision.name = "SecretCollision"
	add_child(collision)
	_solid(collision,"NorthUnlitEdge",Vector2(MIN_X*.5,-.55),Vector2(-MIN_X+1,.1))
	_solid(collision,"SouthUnlitEdge",Vector2(MIN_X*.5,11.55),Vector2(-MIN_X+1,.1))
	_solid(collision,"FarWestLimit",Vector2(MIN_X-.5,5.5),Vector2(.1,12.1))
	var hull := _solid(collision,"DMC12Collision",CAR_AT,Vector2(4.4,1.92))
	hull.rotation = -car.rotation.y
	display.hide()
	display.process_mode = Node.PROCESS_MODE_DISABLED


func _build_tracks() -> void:
	var trails := Node3D.new()
	trails.name = "BurningTyreTrails"
	trails.transform = car.transform
	display.add_child(trails)
	var glow := ShaderMaterial.new()
	glow.shader = BURN
	var soot := M.metal(Color("080b0c"),.97)
	for z: float in [-.86,.86]:
		M.box(trails,"CharredRubberMark",Vector3(10.4,.009,.31),Vector3(-7.45,.009,z),soot)
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(10.3,.28)
		var node := MeshInstance3D.new()
		node.name = "SmoulderingTyrePrint"
		node.mesh = mesh
		node.position = Vector3(-7.45,.022,z)
		node.material_override = glow
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trails.add_child(node)
	fire = FIRE.new()
	fire.name = "TyreFlames"
	fire.fire_limit = 6
	trails.add_child(fire)
	fire.rng.seed = 0xd0c12
	for z: float in [-.86,.86]:
		for x: float in [-3.85,-7.15,-10.45]:
			var id: int = fire.emit_fire(Vector3(x,.035,z),.12)
			fire.fires[id].extent = Vector2(1.60,.065)
			fire.fires[id].yaw = 0.0


func _process(_delta: float) -> void:
	var x: float = world.player.global_position.x / world.CELL_PIXELS
	var active := x < CAR_AT.x + 22.0
	if active == _awake: return
	_awake = active
	display.visible = active
	display.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if not active: fire.clear()
	elif fire.fires.is_empty():
		for z: float in [-.86,.86]:
			for at: float in [-3.85,-7.15,-10.45]:
				var id: int = fire.emit_fire(Vector3(at,.035,z),.12)
				fire.fires[id].extent = Vector2(1.60,.065)


func _solid(parent: Node2D, title: String, at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = at * world.CELL_PIXELS
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size * world.CELL_PIXELS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body
