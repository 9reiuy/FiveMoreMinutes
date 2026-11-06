extends Node3D
## Cab-relative architectural geometry. A fixed shaft passes downward as the cab rises.

const STEP := 3.15
const TRAVEL_SPEED := 3.05
const SEGMENTS := 5
const SHAFT_LIGHT_ENERGY := 4.6
const SHAFT_FIXTURE_OFFSET := .64
const SHAFT_START_PHASE := .58
const CAB_SIGNAL_RECEIVERS := 1 << 16
const OFFICE_ARROW_SHADER := preload("res://shaders/dream3d/elevator_office_arrows.gdshader")
const RENDER_LAYERS := preload("res://scripts/dream/render_layer_mask.gd")
const ATLAS := "res://art/preview/elevator_reference/"
const DISPLAY := preload("res://scripts/ui/elevator_floor_indicator.gd")
static var materials: Dictionary = {}
static var boxes: Dictionary = {}
static var quads: Dictionary = {}
var cab: Node3D
var shaft: Node3D
var segments: Array[Node3D] = []
var portal_leaves: Array[MeshInstance3D] = []
var walls_near: Array[Node3D] = []
var underlays: Dictionary = {}
var metal_underlay: StandardMaterial3D
var hud: CanvasLayer
var floor_display: Control
var sweep_light: SpotLight3D
var shaft_fixture: Node3D
var dock_light_mask := 0
var passenger_receivers: Array[VisualInstance3D] = []
var distance := 0.0
var speed := 0.0
var target := 0
var active := false
var travelling := false
var retry := false

func configure(owner: Node3D) -> void:
	cab = owner
	var shell: Node3D = cab.cab_visual_root
	var deck := atlas_material(&"floor")
	var door := atlas_material(&"door")
	var steel := cabin_steel(Color("434b51"))
	metal_underlay = steel
	var lip := cabin_steel(Color("657078"))
	var trim := cabin_steel(Color("48545d"))
	var indicator := metal(Color("86b2cb"), .34)
	for surface: MeshInstance3D in [cab.east_wall, cab.cab_floor_mesh, cab.south_return_left, cab.south_return_right, cab.inner_left_door, cab.inner_right_door]:
		underlays[surface] = surface.material_override
	_quad(cab.cab_floor_mesh, Vector2(3.60, 2.60), Vector3(0, .022, 0), Vector3(-PI / 2, 0, 0), deck)
	for source in [cab.west_wall, cab.north_wall, shell.get_node("CenterPilaster"), cab.indicator_root, cab.cab_reader_root]:
		walls_near.append(source)
	for rail in cab.handrail_root.get_children():
		if rail.position.z < -1.04 or rail.position.x < -1.52:
			walls_near.append(rail)
	var scene := Node3D.new()
	scene.name = "RidePortal"
	add_child(scene)
	for side in [-1.0, 1.0]:
		_box(scene, Vector3(.78, 2.53, .16), Vector3(side * 1.40, 1.265, 1.30), steel, true)
		_box(scene, Vector3(.075, 2.28, .055), Vector3(side * 1.005, 1.13, 1.203), lip)
		_box(scene, Vector3(.105, .08, .21), Vector3(side * 1.73, 2.50, 1.30), trim)
	_box(scene, Vector3(2.13, .30, .18), Vector3(0, 2.39, 1.30), steel, true)
	_box(scene, Vector3(1.98, .042, .16), Vector3(0, .063, 1.32), trim)
	_box(scene, Vector3(.058, .09, 2.46), Vector3(1.694, .17, 0), lip)
	_box(scene, Vector3(.036, .047, 2.51), Vector3(1.682, 2.48, 0), lip)
	_box(scene, Vector3(.24, .57, .065), Vector3(-1.41, 1.32, 1.185), lip)
	for row in 5:
		for column in 2:
			_box(scene, Vector3(.044, .043, .025), Vector3(-1.45 + column * .086, 1.50 - row * .079, 1.135), indicator if row == 2 and column == 0 else steel)
	for side in [-1.0, 1.0]:
		var leaf := _box(scene, Vector3(.92, 2.08, .045), Vector3(side * .46, 1.09, 1.29), steel)
		_quad(leaf, Vector2(.92, 2.08), Vector3(0, 0, -.024), Vector3(0, PI, 0), door)
		portal_leaves.append(leaf)
	# Low near rims remain as true cutaway sections around the collision footprint.
	_box(scene, Vector3(3.64, .20, .14), Vector3(0, .095, -1.31), lip, true)
	_box(scene, Vector3(.14, .20, 2.61), Vector3(-1.80, .095, 0), lip, true)
	_box(scene, Vector3(3.73, .18, .10), Vector3(0, -.08, -1.36), steel)
	_box(scene, Vector3(.10, .18, 2.71), Vector3(-1.85, -.08, 0), steel)
	for root in [scene, shell]:
		for surface in root.find_children("*", "MeshInstance3D", true, false):
			surface.layers |= CAB_SIGNAL_RECEIVERS
	shaft = Node3D.new()
	shaft.name = "Shaft"
	add_child(shaft)
	var far := atlas_material(&"shaft")
	var dark := metal(Color("242e36"))
	var track := metal(Color("546269"))
	var aperture := Node3D.new()
	aperture.name = "CutawayLightAperture"
	add_child(aperture)
	# The camera sees the cutaway. The beam still sees the solid steel around its opening.
	_shadow_solid(aperture, Vector3(3.6, .57, .14), Vector3(0, .285, -1.31), steel)
	_shadow_solid(aperture, Vector3(3.6, .55, .14), Vector3(0, 2.325, -1.31), steel)
	for side in [-1.0, 1.0]:
		_shadow_solid(aperture, Vector3(.46, 1.48, .14), Vector3(side * 1.57, 1.31, -1.31), steel)
	for i in SEGMENTS:
		var segment := Node3D.new()
		shaft.add_child(segment)
		segments.append(segment)
		for x in [-3.68, 3.38]:
			_box(segment, Vector3(.13, STEP, .18), Vector3(x, 0, -1.73), dark, true)
			_box(segment, Vector3(.055, STEP, .025), Vector3(x + .10, 0, -1.82), track)
			_box(segment, Vector3(.24, .22, .27), Vector3(x, .68, -1.74), steel)
		_box(segment, Vector3(7.10, .15, .16), Vector3(-.15, .70, -1.79), dark, true)
		_box(segment, Vector3(7.10, .031, .031), Vector3(-.15, .756, -1.88), track)
		_box(segment, Vector3(6.98, .080, .13), Vector3(-.15, .44, -1.76), dark, true)
		for x in [-2.1, 2.07]:
			_quad(segment, Vector2(.92, STEP), Vector3(x, 0, 2.28), Vector3(0, PI, 0), far)
		_quad(segment, Vector2(1.05, STEP), Vector3(2.72, 0, -.70), Vector3(0, -PI / 2, 0), far)
		_box(segment, Vector3(.46, .16, .13), Vector3(2.21, .10, 2.19), dark)
	shaft_fixture = Node3D.new()
	shaft_fixture.name = "ExteriorShaftFixture"
	shaft.add_child(shaft_fixture)
	_box(shaft_fixture, Vector3(.53, .23, .23), Vector3(0, 0, -.14), steel)
	_box(shaft_fixture, Vector3(.43, .085, .065), Vector3(0, 0, -.015), metal(Color("a2cbf8"), .40))
	sweep_light = SpotLight3D.new()
	sweep_light.name = "ExteriorColdSpot"
	sweep_light.light_color = Color("a2cbf8")
	sweep_light.light_energy = SHAFT_LIGHT_ENERGY
	sweep_light.spot_range = 6.0
	sweep_light.spot_angle = 40.0
	sweep_light.spot_attenuation = 1.45
	sweep_light.spot_angle_attenuation = 1.8
	sweep_light.light_specular = .38
	sweep_light.light_size = .22
	sweep_light.shadow_enabled = true
	sweep_light.shadow_bias = .032
	sweep_light.shadow_normal_bias = .62
	sweep_light.light_cull_mask = 7 | 8
	sweep_light.position.z = .035
	sweep_light.basis = Basis.looking_at(Vector3(.58, -.36, 1.0), Vector3.UP)
	shaft_fixture.add_child(sweep_light)
	dock_light_mask = cab.cab_light.light_cull_mask
	hud = CanvasLayer.new()
	hud.name = "ElevatorFloorHUD"
	hud.layer = 30
	add_child(hud)
	floor_display = DISPLAY.new()
	floor_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(floor_display)
	floor_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_active(false)

func set_active(value: bool) -> void:
	active = value
	visible = value
	hud.visible = value
	for wall in walls_near:
		wall.visible = not value
	for surface: MeshInstance3D in underlays:
		surface.material_override = metal_underlay if value else underlays[surface]
	cab.cab_light.light_cull_mask = CAB_SIGNAL_RECEIVERS if value else dock_light_mask
	cab.cab_light.shadow_enabled = cab.managed_shadows and not value
	_set_passenger_receivers(value and is_visible_in_tree())
	if not value:
		set_process(false)
	else:
		set_process(true)
		_update_pose()

func begin(target_floor: int, same_floor: bool) -> void:
	target = target_floor
	retry = same_floor
	distance = 0.0
	speed = 0.0
	travelling = true
	set_active(true)
	_update_indicator()

func arrive(floor_index: int) -> void:
	target = floor_index
	travelling = false
	_update_indicator()

func refresh_visibility() -> void:
	hud.visible = active and is_visible_in_tree()
	_set_passenger_receivers(hud.visible)

func _set_passenger_receivers(enabled: bool) -> void:
	if not enabled:
		release_passenger_light()
		return
	var world := cab.get_parent_node_3d()
	var bridge: Node3D = world.get("player_depth_bridge") if is_instance_valid(world) else null
	if not is_instance_valid(bridge):
		release_passenger_light()
		return
	var receivers: Array[VisualInstance3D] = []
	for surface: VisualInstance3D in [bridge.actor_sprite, bridge.weapon_sprite]:
		if is_instance_valid(surface):
			receivers.append(surface)
	if receivers == passenger_receivers:
		return
	release_passenger_light()
	for surface in receivers:
		RENDER_LAYERS.apply(surface, surface.layers | CAB_SIGNAL_RECEIVERS)
	passenger_receivers = receivers

func release_passenger_light() -> void:
	for surface in passenger_receivers:
		if is_instance_valid(surface):
			RENDER_LAYERS.apply(surface, surface.layers & ~CAB_SIGNAL_RECEIVERS)
	passenger_receivers.clear()

func _exit_tree() -> void:
	release_passenger_light()

func _update_indicator() -> void:
	floor_display.present(cab.current_floor_index, target, cab.total_indicator_floors, travelling, retry)

func _process(delta: float) -> void:
	if is_visible_in_tree():
		advance_motion(delta)

func advance_motion(delta: float) -> void:
	var direction := -1.0 if target < cab.current_floor_index else 1.0
	var desired := TRAVEL_SPEED * direction if travelling and not retry else 0.0
	speed = move_toward(speed, desired, 9.0 * delta)
	distance += speed * delta
	_update_pose()

func restore_motion(previous_distance: float, previous_speed: float) -> void:
	distance = previous_distance
	speed = previous_speed
	_update_pose()

func _update_pose() -> void:
	var phase := fposmod(distance + SHAFT_START_PHASE, STEP)
	for i in segments.size():
		segments[i].position.y = float(i - 2) * STEP - phase + 2.2
	portal_leaves[0].position.x = cab.inner_left_door.position.x
	portal_leaves[1].position.x = cab.inner_right_door.position.x
	var fixture_y := segments[2].position.y + SHAFT_FIXTURE_OFFSET
	shaft_fixture.position = Vector3(-1.08, fixture_y, -1.60)
	# The light enters through the cutaway aperture. The shaft repeats only
	# once the lamp is behind steel and no longer lighting the cab.
	var aperture_exposure := smoothstep(.62, 1.10, fixture_y) * (1.0 - smoothstep(1.37, 1.96, fixture_y))
	var sweep_energy := SHAFT_LIGHT_ENERGY * aperture_exposure
	if not is_equal_approx(sweep_light.light_energy, sweep_energy):
		sweep_light.light_energy = sweep_energy
	sweep_light.visible = sweep_energy > 0.0

static func build_office_panel(wall: MeshInstance3D) -> MeshInstance3D:
	var face := _quad(wall, Vector2(2.60, 2.60), Vector3(-.072, 0, 0),
		Vector3(0, -PI / 2, 0), atlas_material(&"wall"))
	var texel := 2.60 / 84.0
	var signal_material := ShaderMaterial.new()
	signal_material.shader = OFFICE_ARROW_SHADER
	# The signal occupies wall texels (34, 29) through (50, 43).
	var arrows := _quad(face, Vector2(17, 15) * texel, Vector3(.5 * texel, 5.5 * texel, .003),
		Vector3.ZERO, signal_material)
	arrows.name = "OfficeArrows"
	return arrows

static func atlas_material(key: StringName) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var material := cabin_steel(Color.WHITE) if key == &"wall" or key == &"door" else metal(Color.WHITE)
	material.albedo_texture = load(ATLAS + String(key) + ".png") as Texture2D
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if key == &"floor":
		material.roughness = .45
		material.metallic = .24
		material.metallic_specular = .94
	if key != &"shaft":
		material.normal_enabled = true
		material.normal_texture = load(ATLAS + String(key) + "_normal.png") as Texture2D
		material.normal_scale = .92
	materials[key] = material
	return material

static func cabin_steel(color: Color) -> StandardMaterial3D:
	var material := metal(color)
	material.roughness = .78
	material.metallic = .17
	material.metallic_specular = .38
	return material

static func metal(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .90
	material.metallic = .04
	material.set("metallic_specular", .11)
	material.set_flag(BaseMaterial3D.FLAG_DISABLE_AMBIENT_LIGHT, true)
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _box(parent: Node3D, size: Vector3, center: Vector3, material: Material, casts_shadow: bool = false) -> MeshInstance3D:
	if not boxes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		boxes[size] = mesh
	var visual := _mesh(parent, boxes[size], center, Vector3.ZERO, material)
	if casts_shadow:
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return visual

func _shadow_solid(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var solid := _box(parent, size, center, material)
	solid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

static func _quad(parent: Node3D, size: Vector2, center: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	if not quads.has(size):
		var mesh := QuadMesh.new()
		mesh.size = size
		quads[size] = mesh
	return _mesh(parent, quads[size], center, rotation, material)

static func _mesh(parent: Node3D, mesh: Mesh, center: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = center
	visual.rotation = rotation
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual
