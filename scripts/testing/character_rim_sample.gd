extends Control
## GameTestLab presentation: production actors/Camera and a controlled real lamp.
const LAB := preload("res://scenes/testing/LabWorld.tscn")
const EFFECT := preload("res://scripts/testing/character_rim_effect.gd")
const FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
var world: Node3D
var display: Control
var enemy: EmployeeEnemy
var effect = EFFECT.new()
var rig: Node3D
var lamp: OmniLight3D
var blocker: MeshInstance3D
var label: Label
var ready_world := false
var busy := false
var whitebox := false
var enabled := true
var light_mode := 1
var blocker_enabled := false
var frozen := false
var generation := 0
var scene_lighting := true
var _disabled_lights: Array[Dictionary] = []
var center := Vector3.ZERO
var camera_right := Vector3.RIGHT
var camera_back := Vector3.BACK
var role_bridges: Array[Node] = []

func _ready() -> void:
	var hud := CanvasLayer.new(); hud.layer = 245; add_child(hud)
	label = Label.new(); label.position = Vector2(10,9)
	label.add_theme_font_override("font",FONT.get_font()); label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",1)
	hud.add_child(label)
	call_deferred("rebuild")

func rebuild() -> void:
	if busy: return
	var restore_scene_lighting := scene_lighting
	busy = true; ready_world = false
	effect.clear(); role_bridges.clear(); _disabled_lights.clear()
	if is_instance_valid(display): display.free(); world = null; await get_tree().process_frame
	world = LAB.instantiate()
	world.generate_on_ready = false; world.spawn_content = false; world.persist_profile = false
	world.lab_enemy_count = 0; world.lab_furniture = true; world.lab_whitebox = whitebox
	world.approved_sample_art_enabled = not whitebox
	var pause_bridge := world.get_node_or_null("Dream3DPauseBridge")
	if pause_bridge != null: pause_bridge.free()
	display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world; display.preview_mode = false
	add_child(display); move_child(display,0)
	await get_tree().process_frame
	if not world.regenerate(71432):
		label.text = "场景生成失败，F5 重试"; busy = false; return
	world._spawn_room_furniture()
	world.populate_lab()
	# A controlled fixture is deliberately not subject to the production
	# sparse-light whitelist. Restore that policy only when leaving this sample.
	world.sparse_lighting.set_enabled(false)
	# That separate lab experiment rewrites the player's shader every draw.
	# Use the unmodified production carrier for this independent comparison.
	var face_probe := world.get_node_or_null("LabPlayerShadowReceiver")
	if face_probe != null: face_probe.free()
	world.run_interface.auto_open_upgrades = false; world.run_interface.hud.hide()
	world.target_highlight.set_physics_process(false)
	world.player_has_left_elevator_cab = true
	world.player.global_position = Vector2(6,7)*32
	world.player.equip_weapon("basic",world.config,{})
	world.current_room_id = 1; world.reveal_room(1)
	world._update_camera_and_actor_projection(0.0)
	enemy = world._spawn_regular_employee(1,Vector2(9,7)*32,&"employee",false,"assault_rifle")
	enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.set_room_runtime_active(true); enemy.set_player_vision_visible(true)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy._apply_live_facing(Vector2.DOWN)
	enemy._update_weapon_aim()
	role_bridges.append(world.player_depth_bridge)
	for bridge in world.actor_depth_bridges_root.get_children():
		var actor: Variant = bridge.get("source_actor")
		if actor == world.player or actor == enemy: role_bridges.append(bridge)
	var environment_node: WorldEnvironment = world.get_node("Lighting/WorldEnvironment")
	var environment := environment_node.environment.duplicate() as Environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("72869d"); environment.ambient_light_energy = 0.16
	environment_node.environment = environment
	# One lamp is the controlled fixture, common to original/candidate states.
	for node in world.find_children("*","Light3D",true,false):
		_disabled_lights.append({"ref":weakref(node),"mask":node.light_cull_mask})
		node.light_cull_mask = 0
	rig = Node3D.new(); rig.name = "RimSampleFixtures"; world.add_child(rig)
	# Let deferred spawning/canvas projection settle before positioning a real
	# fixture. Receive light at the same reference plane used by the carriers.
	for i in 8: await get_tree().process_frame
	for bridge in role_bridges: bridge._process(0.0)
	center = (world.player_depth_bridge.body_reference_origin + role_bridges.back().body_reference_origin)*0.5+Vector3.UP*0.75
	camera_right = world.camera_3d.global_basis.x.normalized()
	camera_back = world.camera_3d.global_basis.z.normalized()
	lamp = OmniLight3D.new(); lamp.name = "ControlledRealLight"
	lamp.omni_range = 8; lamp.omni_attenuation = 0.6; lamp.light_energy = 3.5; lamp.shadow_enabled = true
	lamp.shadow_bias = 0.02; lamp.shadow_normal_bias = 0.05
	lamp.light_cull_mask = 15; lamp.shadow_caster_mask = 1|2|8
	lamp.light_color = Color("c8e3ff"); lamp.light_size = 0.05; rig.add_child(lamp)
	blocker = MeshInstance3D.new(); blocker.name = "SolidShadowBlocker"
	var mesh := BoxMesh.new(); mesh.size = Vector3(0.20,4.0,8.0); blocker.mesh = mesh
	var wall_material := StandardMaterial3D.new(); wall_material.albedo_color = Color("667684"); wall_material.roughness = 0.9
	blocker.material_override = wall_material; rig.add_child(blocker)
	effect.strength = 1.8; effect.width = 1.0
	for bridge in role_bridges: effect.bind_bridge(bridge)
	effect.set_enabled(enabled)
	set_light(light_mode); set_blocker(blocker_enabled)
	if restore_scene_lighting: set_scene_lighting(true)
	set_frozen(frozen)
	generation += 1; ready_world = true; busy = false
	_update_label()

func _process(_delta: float) -> void:
	if not ready_world: return
	# Existing light managers can update visibility/energy; keep their receiver
	# masks disabled only in this independently constructed test world.
	if not scene_lighting:
		for record in _disabled_lights:
			var light: Light3D = record.ref.get_ref()
			if is_instance_valid(light) and light.light_cull_mask != 0: light.light_cull_mask = 0
	for bridge in role_bridges:
		if is_instance_valid(bridge): effect.bind_bridge(bridge)

func set_enabled(value: bool) -> void:
	enabled = value; effect.set_enabled(value); _update_label()

func set_light(mode: int) -> void:
	light_mode = mode
	if not is_instance_valid(lamp): return
	if scene_lighting: set_scene_lighting(false)
	lamp.visible = mode != 0
	match mode:
		1: lamp.global_position = center-camera_right*3.0+camera_back*1.5+Vector3.UP*0.4
		2: lamp.global_position = center+camera_right*3.0+camera_back*1.5+Vector3.UP*0.4
		3: lamp.global_position = center-Vector3(camera_back.x,0,camera_back.z).normalized()*2.5+Vector3.UP*1.3
	_update_blocker(); _update_label()

func set_scene_lighting(value: bool) -> void:
	scene_lighting=value
	if not is_instance_valid(world): return
	world.sparse_lighting.set_enabled(value)
	for record in _disabled_lights:
		var light: Light3D = record.ref.get_ref()
		if is_instance_valid(light): light.light_cull_mask=record.mask if value else 0
	if is_instance_valid(lamp): lamp.visible=not value and light_mode!=0
	_update_label()

func set_blocker(value: bool, shadow_only: bool = false) -> void:
	blocker_enabled = value
	if is_instance_valid(blocker):
		blocker.visible = value
		blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if shadow_only else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_update_blocker()
	_update_label()

func _update_blocker() -> void:
	if not is_instance_valid(blocker): return
	var sign_x := 1.0 if light_mode == 2 else -1.0
	blocker.global_position = center+camera_right*2.2*sign_x
	blocker.global_position.y = 2.0
	blocker.global_basis = Basis(Vector3.UP,-atan2(camera_right.z,camera_right.x))

func set_frozen(value: bool) -> void:
	frozen = value
	if not is_instance_valid(world): return
	world.player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	world.player.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if value:
		world.set_physics_process(false)
	else:
		world.set_physics_process(true)

func _update_label() -> void:
	if label == null: return
	label.text = "角色轮廓受光 · %s · %s\nT 对照　L 场景原灯　1 左光  2 右光  3 逆光  0 关灯\nB 挡光墙　WASD 移动 / 鼠标瞄准 / 空格翻滚\nF1 白盒/正式美术　F5 重建" % ["新版" if enabled else "原版","场景原灯" if scene_lighting else ["灯关闭","左侧冷光","右侧冷光","背后冷光"][light_mode]]

func _input(event: InputEvent) -> void:
	if not ready_world or not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_T: set_enabled(not enabled)
		KEY_L: set_scene_lighting(true)
		KEY_0: set_light(0)
		KEY_1: set_light(1)
		KEY_2: set_light(2)
		KEY_3: set_light(3)
		KEY_B: set_blocker(not blocker_enabled)
		KEY_F1: whitebox = not whitebox; rebuild()
		KEY_F5: rebuild()
		_: return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	effect.clear()
