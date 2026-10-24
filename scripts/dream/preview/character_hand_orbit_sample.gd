extends Node3D
## Standalone A/B lab; never loaded by Main or the random-floor generator.
const RIG = preload("res://scripts/dream/preview/elliptical_hand_rig.gd")
const PLAYER = preload("res://scenes/entities/dream_player.tscn")
var actors: Array[Node2D] = []
var rigs: Array = []
var carriers: Array[Sprite3D] = []
var camera: Camera3D
var label: Label
var mode := 1
var aim := Vector2.RIGHT
var ground := Vector2.ZERO
var attack := -1.0
var dash := 0.0
var dash_direction := Vector2.RIGHT
var clock := 0.0
var automatic := false
var manual_step := false
var last_motion := Vector2.ZERO

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141b2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5d2ee")
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	add_child(camera)
	camera.position = Vector3(0, 8, 9)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	for index in 2:
		_make_stage(index)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(18, 12)
	label.add_theme_font_size_override("font_size", 18)
	ui.add_child(label)
	set_mode(1)
	step(0.0, Vector2.ZERO, Vector2.RIGHT)

func _make_stage(index: int) -> void:
	var x := -2.5 if index == 0 else 2.5
	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.4, 0.15, 3.8)
	floor_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("34445b") if index == 0 else Color("3c5168")
	material.roughness = 1.0
	floor_mesh.material_override = material
	floor_mesh.position = Vector3(x, -0.1, 0)
	add_child(floor_mesh)
	var caption := Label3D.new()
	caption.text = "固定双手（结构对照）" if index == 0 else "椭圆双手 / 高度 / 遮挡"
	caption.font_size = 36
	caption.pixel_size = 0.006
	caption.position = Vector3(x, 0.1, 1.85)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(caption)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var actor: Node2D = PLAYER.instantiate()
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(actor)
	actor.position = Vector2(64, 92)
	actor.movement_enabled = false
	actor.attacking_enabled = false
	actor.set_meta(&"aim_direction_override", aim)
	# Keep gameplay entirely disabled, including all firearm/attack children.
	var rig = RIG.new()
	rig.bind(actor)
	actors.append(actor)
	rigs.append(rig)
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = 1.0 / 32.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.05
	sprite.no_depth_test = false
	# Pixel at (64,92) is the ground contact, 28px below texture centre.
	sprite.offset = Vector2(0, 28)
	sprite.position = Vector3(x, 0.05, 0)
	add_child(sprite)
	carriers.append(sprite)

func set_mode(value: int) -> void:
	mode = clampi(value, 0, 3)
	attack = -1.0
	for rig in rigs:
		rig.set_mode(mode)
	_update_label()

func _update_label() -> void:
	if label == null: return
	label.text = "独立角色样板 · 不影响正式玩家\n鼠标转向 · WASD移动 · 左键动作 · 空格冲刺\n1拳头  2手枪  3步枪  4球棍 · T自动转向\n当前：%s · 现有素材方向，未新增八方向身体图" % ["拳头", "手枪", "步枪", "球棍"][mode]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			set_mode(event.keycode - KEY_1)
		elif event.keycode == KEY_T:
			automatic = not automatic
		elif event.keycode == KEY_SPACE and dash <= 0.0:
			dash = 0.18
			dash_direction = aim
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attack = 0.0

func _process(delta: float) -> void:
	if manual_step: return
	var motion := Input.get_vector("move_left", "move_right", "move_up", "move_down") * 290.0
	var chest := camera.unproject_position(carriers[1].position + Vector3(0, 0.65, 0))
	var mouse := get_viewport().get_mouse_position() - chest
	var direction := Vector2(mouse.x, mouse.y * 2.0).normalized()
	if automatic: direction = Vector2.from_angle(clock * 0.9)
	step(minf(delta, 0.05), motion, direction)

func step(delta: float, motion: Vector2, direction: Vector2) -> void:
	clock += delta
	if direction.length_squared() > 0.0001: aim = direction.normalized()
	if attack >= 0.0:
		attack += delta / (0.42 if mode == 3 or mode == 0 else 0.22)
		if attack > 1.0: attack = -1.0
	if dash > 0.0:
		dash = maxf(dash - delta, 0.0)
		motion = dash_direction * 600.0
	ground += motion * delta / 32.0
	ground = ground.clamp(Vector2(-1.4, -1.2), Vector2(1.4, 1.1))
	last_motion = motion
	for index in 2:
		var actor = actors[index]
		actor.velocity = motion
		actor.last_aim_direction = aim
		actor.set_meta(&"aim_direction_override", aim)
		# Reuse the existing front/back art and gait. No combat update runs.
		actor._update_direction_animation(motion, delta)
		actor.visual.rotation = -aim.x * 0.12 if dash > 0.0 else 0.0
		rigs[index].step(delta, aim, motion, attack, dash / 0.18, index == 0)
		var hair: Node = actor.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
		hair.step(delta, motion, aim.angle(), actor.character_facing_right, actor.character_facing_back, false, false)
		carriers[index].position = Vector3((-2.5 if index == 0 else 2.5) + ground.x, 0.05, ground.y)
