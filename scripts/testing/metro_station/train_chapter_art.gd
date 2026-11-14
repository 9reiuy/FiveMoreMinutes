extends RefCounted
## Geometry and collision for the playable train and the final station.

const M := preload("res://scripts/testing/maintenance_environment.gd")
const SURFACE := preload("res://shaders/dream3d/transit_surfaces.gdshader")
const CONSIST := preload("res://scripts/testing/metro_station/train_chapter_consist.gd")
const CUTOUT := preload("res://scripts/dream/authored_occlusion_cutout.gd")
const OFFSET := Vector2i(136, 0)
const CAR_COUNT := CONSIST.CAR_COUNT
const CABIN_EDGE := CONSIST.CABIN_EDGE
const EXIT_X := 37.0
const PLATFORM := Rect2i(29, -10, 19, 8)
const STAIRS := Rect2i(42, -14, 3, 4)
const STAIR_X := 43.0
const STAIR_TOP := -14.10
const STAIR_BASE := -10.50
const TRACK_FIRST := -18.0
const TRACK_SECTION := 10.0
const TRACK_SECTIONS := 15
const SLEEPERS_PER_TRACK := 168
const SLEEPER_STEP := .89
const RAIL_GAUGE_HALF := .87
const STEP_COUNT := 9
const STEP_RUN := .40
const STEP_RISE := .225
const ACTOR_EDGE := CONSIST.ACTOR_EDGE

var world: Node3D
var root: Node3D
var station: Node3D
var tunnels: Array[Node3D] = []
var player_train: CONSIST
var rival_train: CONSIST
var _station_collision: Node2D
var cutout := CUTOUT.new()
var _whitebox: bool
var _steel: StandardMaterial3D
var _trim: StandardMaterial3D
var _rubber: StandardMaterial3D
var _stripe: StandardMaterial3D
var _tube: StandardMaterial3D
var _station_tile: Material
var _ties: Array[MultiMeshInstance3D] = []
var _rival_track: Node3D
var _turnout: Node3D
var _sleeper: BoxMesh


func _init(owner: Node3D, whitebox: bool) -> void:
	world = owner
	_whitebox = whitebox
	_steel = M.metal(Color("687773"), .43)
	_steel.metallic = .48
	_trim = M.metal(Color("343f3e"), .52)
	_rubber = M.metal(Color("182326"), .86)
	_stripe = M.metal(Color("657466"), .63)
	_tube = M.metal(Color("b7e8da"), .43)
	_tube.emission_enabled = true
	_tube.emission = Color("9de7d9")
	_tube.emission_energy_multiplier = 2.3
	_station_tile = _tile(Color("6e8380"), Color("3b5351"), Vector2(.54, .54), .42, .29)
	if _whitebox:
		var neutral := M.metal(Color("b0b2b1"), .9)
		_steel = neutral
		_trim = neutral
		_stripe = neutral
		_station_tile = neutral


func build() -> void:
	root = Node3D.new()
	root.name = "Level06_Train"
	root.position = Vector3(OFFSET.x, 0.0, OFFSET.y)
	root.set_meta(&"train_reference_art_enabled", not _whitebox and not world.get_meta(&"test_train_reference_art_disabled", false))
	if root.get_meta(&"train_reference_art_enabled"):
		var environment: Environment = world.get_node(^"Lighting/WorldEnvironment").environment
		environment.ambient_light_color = Color("b5bdcb")
	world.floor_root.add_child(root)
	_build_tracks()
	player_train = CONSIST.new(root, cutout, false)
	player_train.install_collision(world.collision_root, Vector2(OFFSET) * world.CELL_PIXELS, world.CELL_PIXELS, false)
	rival_train = CONSIST.new(root, cutout, true)
	var fill := DirectionalLight3D.new()
	fill.name = "ConsistFill"
	fill.rotation_degrees = Vector3(-54.0, 36.0, 0.0)
	fill.light_energy = .34
	fill.light_color = Color("c6d7dc")
	fill.light_cull_mask = 2 | 8
	root.add_child(fill)
	set_travel(0.0, true, true)


func _build_tracks() -> void:
	var length := TRACK_SECTION * TRACK_SECTIONS
	var center := TRACK_FIRST + length * .5
	_box(root, "TrackBed", Vector3(length, .30, 11.8), Vector3(center, -.67, 1.55), _rubber)
	_rival_track = Node3D.new()
	_rival_track.name = "RightTrack"
	_rival_track.position.z = CONSIST.TRACK_GAP
	root.add_child(_rival_track)
	_sleeper = BoxMesh.new()
	_sleeper.size = Vector3(.22, .065, 2.39)
	_sleeper.material = _trim
	for bank in [root, _rival_track]:
		for rail: float in [-RAIL_GAUGE_HALF, RAIL_GAUGE_HALF]:
			_box(bank, "RunningRail", Vector3(length, .11, .12), Vector3(center, -.46, rail), _steel)
		var sleepers := _track_instances(bank, "TrackSleepers", _sleeper, SLEEPERS_PER_TRACK)
		for index in SLEEPERS_PER_TRACK:
			sleepers.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY,
				Vector3(TRACK_FIRST + index * SLEEPER_STEP, -.50, 0.0)))
		_ties.append(sleepers)
	for index in TRACK_SECTIONS:
		var section := Node3D.new()
		section.name = "TunnelSection_%d" % index
		root.add_child(section)
		tunnels.append(section)
		for side: float in [-1.0, 1.0]:
			var bank := Node3D.new()
			bank.name = "NorthTunnel" if side < 0.0 else "SouthTunnel"
			section.add_child(bank)
			var z := -4.05 if side < 0.0 else 6.80
			_box(bank, "TunnelWall", Vector3(TRACK_SECTION, 2.55, .20), Vector3(0.0, .69, z), _trim)
			_box(bank, "Pier", Vector3(.51, 2.66, .35), Vector3(3.6, .75, z - side * .08), _rubber)
			_box(bank, "TunnelCable", Vector3(TRACK_SECTION, .049, .055), Vector3(0.0, 1.19, z - side * .15), _steel)
			_box(bank, "PassingLamp", Vector3(.68, .10, .07), Vector3(-2.6, 1.64, z - side * .16), _tube)


func set_travel(distance: float, moving: bool, passing: bool) -> void:
	for sleepers in _ties:
		sleepers.position.x = -fposmod(distance, SLEEPER_STEP)
	var station_edge := station.position.x + PLATFORM.position.x - .5 if station != null else INF
	for index in tunnels.size():
		var section := tunnels[index]
		section.position.x = fposmod(float(index) * TRACK_SECTION - distance,
			TRACK_SECTION * TRACK_SECTIONS) + TRACK_FIRST
		section.visible = moving
		(section.get_node(^"NorthTunnel") as Node3D).visible = section.position.x + 4.9 < station_edge
		(section.get_node(^"SouthTunnel") as Node3D).visible = _turnout == null or section.position.x + 5.0 < _turnout.position.x
	if passing:
		rival_train.root.position.x = 99.0 - distance * 1.85
		rival_train.root.visible = rival_train.root.position.x > -135.0


func build_turnout(at: float) -> void:
	_rival_track.hide()
	_turnout = Node3D.new()
	_turnout.name = "RightTurnout"
	_turnout.position = Vector3(at, 0.0, CONSIST.TRACK_GAP)
	root.add_child(_turnout)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(1.0, .11, .12)
	rail_mesh.material = _steel
	var rail_points := PackedFloat32Array([-140.0, 0.0])
	for index in 16:
		rail_points.append(CONSIST.TURN_ARC * (index + 1.0) / 16.0)
	rail_points.append(82.0)
	var rails := _track_instances(_turnout, "TurnoutRails", rail_mesh, (rail_points.size() - 1) * 2)
	var slot := 0
	for gauge: float in [-RAIL_GAUGE_HALF, RAIL_GAUGE_HALF]:
		for index in rail_points.size() - 1:
			var start := _rail_point(rail_points[index], gauge)
			var finish := _rail_point(rail_points[index + 1], gauge)
			var middle := (start + finish) * .5
			var basis := Basis(Vector3.UP, -(finish - start).angle())
			basis = basis.scaled_local(Vector3(start.distance_to(finish) + .026, 1.0, 1.0))
			rails.multimesh.set_instance_transform(slot, Transform3D(basis, Vector3(middle.x, -.46, middle.y)))
			slot += 1
	var sleepers := _track_instances(_turnout, "TurnoutSleepers", _sleeper, ceili(222.0 / SLEEPER_STEP))
	for index in sleepers.multimesh.instance_count:
		var distance := -140.0 + index * SLEEPER_STEP
		var at_tie := CONSIST.turnout_point(distance)
		var basis := Basis(Vector3.UP, -clampf(distance / CONSIST.TURN_RADIUS, 0.0, CONSIST.TURN_ANGLE))
		sleepers.multimesh.set_instance_transform(index, Transform3D(basis, Vector3(at_tie.x, -.50, at_tie.y)))


func scroll_turnout(x: float) -> void:
	if _turnout != null:
		_turnout.position.x = x


static func _rail_point(distance: float, gauge: float) -> Vector2:
	var tangent := clampf(distance / CONSIST.TURN_RADIUS, 0.0, CONSIST.TURN_ANGLE)
	return CONSIST.turnout_point(distance) + Vector2.from_angle(tangent + PI * .5) * gauge


static func _track_instances(parent: Node3D, title: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var model := MultiMesh.new()
	model.transform_format = MultiMesh.TRANSFORM_3D
	model.mesh = mesh
	model.instance_count = count
	var visual := MultiMeshInstance3D.new()
	visual.name = title
	visual.multimesh = model
	parent.add_child(visual)
	return visual


func build_station(shift: float) -> void:
	station = Node3D.new()
	station.name = "TerminalPlatform"
	station.position.x = shift
	_station_collision = Node2D.new()
	_station_collision.name = "TerminalCollision"
	_station_collision.position = (Vector2(OFFSET) + Vector2(shift, 0.0)) * world.CELL_PIXELS
	world.collision_root.add_child(_station_collision)
	root.add_child(station)
	var center := Vector2(PLATFORM.position) + Vector2(PLATFORM.size) * .5 - Vector2.ONE * .5
	_box(station, "PlatformTile", Vector3(PLATFORM.size.x, .27, PLATFORM.size.y),
		Vector3(center.x, -.135, center.y), _station_tile)
	_box(station, "PlatformEdgeStone", Vector3(19.0, .21, .22), Vector3(center.x, -.112, -2.54), _trim)
	var tactile := _tile(Color("738477"), Color("324740"), Vector2(.18, .18), .64, .18)
	_box(station, "TactileStrip", Vector3(18.93, .015, .39), Vector3(center.x, .007, -2.78), tactile)
	_box(station, "BoardingBridge", Vector3(CONSIST.DOOR_WIDTH, .11, 1.20),
		Vector3(EXIT_X, -.055, -2.00), _trim)
	for side: float in [-.71, .71]:
		_box(station, "BridgeEdge", Vector3(.040, .024, 1.15), Vector3(EXIT_X + side, .012, -2.02), _stripe)
	var pale := _tile(Color("a4b9ad"), Color("495c52"), Vector2(.34, .34), .53, .31, true)
	var green := _tile(Color("405750"), Color("243931"), Vector2(.34, .34), .49, .36, true)
	for span: Vector2 in [Vector2(28.50, 41.50), Vector2(44.50, 47.50)]:
		_station_wall(Vector2((span.x + span.y) * .5, -10.57), Vector2(span.y - span.x, .18), pale, green)
	for side: float in [28.44, 47.56]:
		_station_wall(Vector2(side, -6.51), Vector2(.18, 8.09), pale, green)
	for post: Vector2 in [Vector2(30.78, -6.99), Vector2(39.37, -7.66), Vector2(46.2, -6.70)]:
		_box(station, "TiledColumn", Vector3(.69, 2.78, .65), Vector3(post.x, 1.39, post.y), green, true)
		_box(station, "ColumnCap", Vector3(.75, .053, .71), Vector3(post.x, 2.806, post.y), cutout.top_black, true)
		_box(station, "ColumnPlinth", Vector3(.77, .15, .73), Vector3(post.x, .075, post.y), _trim)
		_solid("PlatformColumn", post, Vector2(.77, .73))
		_sign("EXIT  ↑", Vector3(post.x, 1.67, post.y + .331), .66, .25)
	_solid("PlatformLipWest", Vector2(32.40, -2.45), Vector2(7.80, .18), ACTOR_EDGE)
	_solid("PlatformLipEast", Vector2(42.60, -2.45), Vector2(9.80, .18), ACTOR_EDGE)
	_solid("BridgeWestRail", Vector2(EXIT_X - .71, -2.08), Vector2(.09, 1.12), ACTOR_EDGE)
	_solid("BridgeEastRail", Vector2(EXIT_X + .71, -2.08), Vector2(.09, 1.12), ACTOR_EDGE)
	_build_stairs(green)
	for lamp_x: float in [31.5, 36.4, 41.2, 46.2]:
		_lamp(station, Vector3(lamp_x, 2.68, -6.07), Color("8ddbd0"), 2.42, 6.5, lamp_x == 41.2, 3.06)
	_lamp(station, Vector3(43.0, 2.56, -9.98), Color("a7e5d5"), 2.30, 5.2, true, 2.61)
	_sign("UPTOWN  /  EXIT  ↑", Vector3(STAIR_X, 2.45, -10.46), 2.74, .37)


func _station_wall(at: Vector2, size: Vector2, pale: Material, green: Material) -> void:
	_box(station, "GlazedWall", Vector3(size.x, 2.77, size.y), Vector3(at.x, 1.385, at.y), pale, true)
	_box(station, "WallTileBand", Vector3(size.x + .012, .43, size.y + .012), Vector3(at.x, .84, at.y), green, true)
	_box(station, "WallCrown", Vector3(size.x + .04, .062, size.y + .038), Vector3(at.x, 2.80, at.y), cutout.top_black, true)
	_solid("PlatformWall", at, size)


func _build_stairs(tile: Material) -> void:
	for index in STEP_COUNT:
		var height := STEP_RISE * (index + 1)
		var z := STAIR_BASE - (float(index) + .5) * STEP_RUN
		_box(station, "StairTread", Vector3(2.94, height, STEP_RUN + .012),
			Vector3(STAIR_X, height * .5, z), tile)
		_box(station, "StairNosing", Vector3(2.90, .024, .064),
			Vector3(STAIR_X, height + .009, z + STEP_RUN * .44), _stripe)
	for side: float in [-1.0, 1.0]:
		var x := STAIR_X + side * 1.52
		_box(station, "StairStringer", Vector3(.13, 1.60, 3.68), Vector3(x, .79, -12.30), _trim, true)
		_solid("StairSide", Vector2(x, -12.30), Vector2(.15, 3.68))
		M.pipe(station, Vector3(x - side * .16, .91, STAIR_BASE + .24),
			Vector3(x - side * .16, 2.94, STAIR_TOP), .032, _steel)
		for index in 3:
			var z := STAIR_BASE - (float(index) + .23) * 1.18
			var y := stair_height(z)
			M.pipe(station, Vector3(x - side * .16, y, z), Vector3(x - side * .16, y + .82, z), .024, _steel)
	_box(station, "UpperLanding", Vector3(2.95, .20, .84), Vector3(STAIR_X, STEP_COUNT * STEP_RISE - .10, STAIR_TOP - .42), tile)
	_solid("UpperLandingStop", Vector2(STAIR_X, STAIR_TOP - .68), Vector2(2.95, .18))


static func stair_height(z: float) -> float:
	if z > STAIR_BASE:
		return 0.0
	return float(clampi(floori((STAIR_BASE - z) / STEP_RUN) + 1, 1, STEP_COUNT)) * STEP_RISE


func _sign(words: String, at: Vector3, width: float, height: float) -> void:
	_box(station, "EnamelSign", Vector3(width, height, .052), at, _rubber)
	if _whitebox:
		return
	var label := Label3D.new()
	label.name = "Wayfinding"
	label.text = words
	label.font = preload("res://scripts/ui/crisp_interaction_font.gd").get_font()
	label.font_size = 24
	label.pixel_size = .009 if width > 1.0 else .0062
	label.modulate = Color("c5e0cc")
	label.position = at + Vector3(0.0, 0.0, .028)
	station.add_child(label)


func _lamp(parent: Node3D, at: Vector3, color: Color, energy: float, radius: float, shadows: bool, length: float) -> void:
	_box(parent, "LampCase", Vector3(length + .12, .10, .23), at, _trim)
	var diffuser := _box(parent, "FluorescentTube", Vector3(length, .047, .13), at - Vector3(0, .065, 0), _tube)
	var light := OmniLight3D.new()
	light.name = "FluorescentPool"
	light.position = at - Vector3(0, .36, 0)
	light.omni_range = radius
	light.omni_attenuation = 1.32
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = shadows and not _whitebox
	light.light_cull_mask = 15
	light.shadow_caster_mask = 15
	parent.add_child(light)
	preload("res://scripts/dream/office_light_optics.gd").mark_fixture(parent, light, [diffuser])


func _solid(title: String, at: Vector2, size: Vector2, layer := 4) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = at * world.CELL_PIXELS
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = size * world.CELL_PIXELS
	var node := CollisionShape2D.new()
	node.shape = shape
	body.add_child(node)
	_station_collision.add_child(body)
	return node


func _box(parent: Node3D, title: String, size: Vector3, at: Vector3, material: Material, occluder := false, moving := false) -> MeshInstance3D:
	var mesh := M.box(parent, title, size, at, material)
	if occluder:
		cutout.register_mesh(mesh, moving or parent == station)
	return mesh


func _tile(color: Color, joints: Color, spacing: Vector2, roughness: float, wear: float, wall := false) -> Material:
	if _whitebox:
		return M.metal(Color("a0a1a1"), .90)
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("face_colour", color)
	material.set_shader_parameter("joint_colour", joints)
	material.set_shader_parameter("tile_span", spacing)
	material.set_shader_parameter("finish_roughness", roughness)
	material.set_shader_parameter("wear", wear)
	material.set_shader_parameter("wall_surface", wall)
	return material
