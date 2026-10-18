extends Node
## Same gameplay room/state, alternate display only. Production art untouched.
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const ART = preload("res://scripts/dream/preview/face_room_art.gd")
var world: Node3D
var room: Dictionary
var reference_style := true
var furniture_pairs: Array = []
var wall_bindings: Array = []
var light_bindings: Array = []
var main_light: SpotLight3D
var label: Label
var original_mute := false
var initialized := false
var environment: Environment
var original_ambient := 0.0
var light_angle := 0.0

func _ready() -> void:
	process_priority = 10000
	original_mute = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0,true)
	world = WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.use_authored_office_sample = true
	add_child(world)
	await get_tree().process_frame
	world.regenerate(42001)
	for candidate in world.rooms:
		if String(candidate.get("sample_key","")) == "manager":
			room = candidate
			break
	world.player.global_position = Vector2(room.center_cell)*world.CELL_PIXELS
	world.activate_room(int(room.id))
	world.player_has_left_elevator_cab = true
	world.player.invulnerability_left = 100000.0
	world.night_lighting.set_flashlight_enabled(false)
	# This is a peaceful art review, not an encounter or combat rebalance.
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	_setup_furniture()
	_setup_surfaces()
	_setup_lighting()
	var ui := CanvasLayer.new()
	ui.layer = 110
	add_child(ui)
	label = Label.new()
	label.position = Vector2(8,8)
	label.add_theme_font_size_override("font_size",10)
	ui.add_child(label)
	set_reference_style(true)
	initialized = true

func _process(_delta: float) -> void:
	if initialized:
		for enemy in world.enemy_root.find_children("*","CharacterBody2D",true,false):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _setup_furniture() -> void:
	var rect := Rect2(room.grid_rect)
	for node in world.find_children("*","Node3D",true,false):
		if node is Furniture3DVisual and is_instance_valid(node.target_furniture):
			var source: Node2D = node.target_furniture
			if not rect.has_point(source.global_position/world.CELL_PIXELS):
				continue
			var kind := String(source.get_meta(&"office_furniture_kind","desk"))
			var original: Node3D = node.visual_instance
			var replacement := ART.furniture(kind,original)
			node.add_child(replacement)
			furniture_pairs.append([node,original,replacement])

func _setup_surfaces() -> void:
	var surfaces: Array = world.wall_root.find_children("*","MeshInstance3D",true,false)
	surfaces.append_array(world.floor_root.find_children("*","MeshInstance3D",true,false))
	for mesh in surfaces:
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if mesh.material_override != null:
			var original: Material = mesh.material_override
			wall_bindings.append([mesh,original,ART.material(original),-1])
		elif mesh.mesh != null:
			for index in mesh.mesh.get_surface_count():
				var original: Material = mesh.get_active_material(index)
				wall_bindings.append([mesh,original,ART.material(original),index])

func _setup_lighting() -> void:
	for light in world.find_children("*","Light3D",true,false):
		light_bindings.append([light,light.visible])
	main_light = SpotLight3D.new()
	main_light.name = "QuietRoomMainLight"
	main_light.light_color = Color(.90,.94,1.0)
	main_light.light_energy = 1.8
	main_light.spot_range = 30.0
	main_light.spot_angle = 82.0
	main_light.spot_attenuation = .1
	main_light.spot_angle_attenuation = .2
	main_light.shadow_enabled = false
	main_light.shadow_bias = .03
	main_light.shadow_normal_bias = .7
	main_light.shadow_blur = 1.0
	main_light.light_cull_mask = 7
	world.floor_root.add_child(main_light)
	var center: Vector2 = Rect2(room.grid_rect).get_center()
	main_light.position = Vector3(center.x-3.0,2.4,center.y-2.5)
	main_light.look_at(world.floor_root.to_global(Vector3(center.x-3.0,0,center.y-2.5)),Vector3.FORWARD)
	set_light_angle(0.0)
	var environments := world.find_children("*","WorldEnvironment",true,false)
	if not environments.is_empty():
		environment = environments[0].environment.duplicate() as Environment
		environments[0].environment = environment
		original_ambient = environment.ambient_light_energy

func set_reference_style(enabled: bool) -> void:
	reference_style = enabled
	for pair in furniture_pairs:
		pair[0].visual_instance = pair[2] if enabled else pair[1]
		pair[1].visible = not enabled
		pair[2].visible = enabled
	for binding in wall_bindings:
		if is_instance_valid(binding[0]):
			var chosen: Material = binding[2] if enabled else binding[1]
			if binding[3] < 0: binding[0].material_override = chosen
			else: binding[0].set_surface_override_material(binding[3],chosen)
	main_light.visible = enabled
	if environment != null:
		environment.ambient_light_energy = original_ambient
	for binding in light_bindings:
		if is_instance_valid(binding[0]):
			binding[0].visible = false if enabled else binding[1]
	if label != null:
		label.text = "1 Original / 2 Face shading | %s | muted\nL: light direction | Original models + textures" % ("Face shading" if enabled else "Original")

func set_light_angle(angle: float) -> void:
	light_angle = angle
	ART.set_direction(world.floor_root.global_basis * Vector3(-.8,-1.0,-.12).rotated(Vector3.UP,angle))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		set_light_angle(light_angle + PI/2.0)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1,KEY_2]:
		set_reference_style(event.keycode == KEY_2)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	AudioServer.set_bus_mute(0,original_mute)
	ART.materials.clear()
	ART.shader_cache.clear()
