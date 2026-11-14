extends Control
## Production Camera/actors/art, isolated visual-only blood candidate.
const LAB := preload("res://scenes/testing/BloodSurfaceWorld.tscn")
const SYSTEM := preload("res://scripts/testing/surface_blood_system.gd")
const FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
var world: Node3D
var display: Control
var blood: Node3D
var enemy: EmployeeEnemy
var enemy_bridge: Node
var label: Label
var ready_world := false
var busy := false
var dark := false
var whitebox := false
var mode := 0
var generation := 0
var light_records: Array[Dictionary] = []
var environment: Environment
var ambient_energy := 0.0
var props: Array[Node3D] = []
var moved_prop: Node3D
var prop_home := Transform3D.IDENTITY
var moving := false
var motion_time := 0.0
var hide_hud := false
var pixel_drag := true
const PRESETS := [
	["墙面",Vector2(5.5,1.8),Vector2.UP,1.15],
	["桌面",Vector2(3,5.2),Vector2.UP,.85],
	["柜侧",Vector2(10,5.7),Vector2.UP,.9],
	["地面",Vector2(7,7),Vector2(.894427,.447214),.85]]

func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(_enforce_dark)
	var hud := CanvasLayer.new(); hud.layer = 245; add_child(hud)
	label = Label.new(); label.position = Vector2(10,8)
	label.add_theme_font_override("font",FONT.get_font()); label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",1)
	hud.add_child(label)
	call_deferred("rebuild")

func rebuild() -> void:
	if busy: return
	busy = true; ready_world = false; light_records.clear(); props.clear()
	if is_instance_valid(display): display.free(); world = null; await get_tree().process_frame
	world = LAB.instantiate()
	world.pixel_drag_enabled = pixel_drag
	world.surface_blood_enabled = false
	world.generate_on_ready = false; world.spawn_content = false; world.persist_profile = false
	world.lab_enemy_count = 0; world.lab_furniture = false; world.lab_whitebox = whitebox
	world.approved_sample_art_enabled = not whitebox
	var pause_bridge := world.get_node_or_null("Dream3DPauseBridge")
	if pause_bridge != null: pause_bridge.free()
	display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world; display.preview_mode = false
	add_child(display); move_child(display,0)
	await get_tree().process_frame
	if not world.regenerate(71432):
		label.text = "生成失败，F5 重试"; busy = false; return
	world._spawn_room_furniture(); world.populate_lab()
	_add_sample_prop("workstation",Vector2(3,4))
	_add_sample_prop("cabinet",Vector2(10,4))
	_add_sample_wall()
	for art in world.office_art_root.get_children():
		if art.get_script() == preload("res://scripts/dream/office_approved_art.gd"):
			art.furniture.refresh_assets(); art.walls.refresh_assets()
	if whitebox:
		var material := StandardMaterial3D.new(); material.albedo_color = Color("8ca0b1"); material.roughness = 1.0
		for bridge in world.actor_depth_bridges_root.get_children():
			if bridge is Furniture3DVisual: world._paint_static(bridge,material)
	var probe := world.get_node_or_null("LabPlayerShadowReceiver")
	if probe != null: probe.free()
	world.run_interface.auto_open_upgrades = false; world.run_interface.hud.hide()
	world.player_has_left_elevator_cab = true
	world.player.global_position = Vector2(6,6)*32
	world.player.equip_weapon("basic",world.config,{})
	world.current_room_id = 1; world.reveal_room(1)
	world.target_highlight.set_physics_process(false)
	world._update_camera_and_actor_projection(0.0)
	# The sparse manager may otherwise extinguish a fixture while testing N.
	# All scene fixtures retain their original visibility/energy/masks.
	world.sparse_lighting.set_enabled(false)
	blood = SYSTEM.new(); blood.name = "SurfaceBloodCandidate"; world.add_child(blood)
	blood.record_diagnostics = true
	blood.camera = world.camera_3d; world.surface_blood = blood
	for i in 10: await get_tree().process_frame
	blood.register_receiver(world.floor_root,"地面")
	blood.register_receiver(world.wall_root,"墙壁")
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get_script() != preload("res://scripts/dream/furniture_3d_visual.gd"): continue
		var source: Node2D = bridge.source_actor
		if not is_instance_valid(source): continue
		if source is RigidBody2D: source.freeze = true
		var kind: String = source.get_meta(&"office_furniture_kind","")
		var receiver_id: int = blood.register_receiver(bridge,"家具:"+kind)
		if receiver_id >= 0: props.append(bridge)
		if source.global_position.distance_to(Vector2(3,4)*32) < 70 and kind in ["desk","workstation"]:
			moved_prop = bridge; prop_home = bridge.global_transform
	for light in world.find_children("*","Light3D",true,false):
		light_records.append({"ref":weakref(light),"mask":light.light_cull_mask,"visible":light.visible})
	environment = world.get_node("Lighting/WorldEnvironment").environment.duplicate()
	world.get_node("Lighting/WorldEnvironment").environment = environment
	ambient_energy = environment.ambient_light_energy
	_spawn_target()
	set_dark(dark)
	var timing := get_tree().root.get_node_or_null("DreamTimeController")
	if timing != null:
		# This independent preview shows normal speed even while standing still;
		# keep the ordinary hit-stop compositor alive so it can release impacts.
		timing.end_tactical_planning(); timing.clear_reaction_time(); timing.set_slow_time_enabled(false)
	generation += 1; ready_world = true; busy = false; _update_label()
	print("BLOOD_SAMPLE_READY ",JSON.stringify({"generation":generation,"receivers":blood.receivers.size(),"props":props.size(),"renderer":RenderingServer.get_current_rendering_method()}))

func _add_sample_prop(kind: String, cell: Vector2) -> void:
	var source: RigidBody2D = load("res://scenes/dream/props/desk.tscn").instantiate()
	source.position = cell*32
	source.set_meta(&"dream_room_id",1); source.set_meta(&"content_kind",&"furniture")
	source.set_meta(&"office_visual_style","approved_office")
	source.set_meta(&"office_art_review",true); source.set_meta(&"office_pixel_sample",true)
	world.furniture_root.add_child(source)
	preload("res://scripts/dream/office_furniture_catalog.gd").configure(source,kind)
	source.freeze = true
	world._spawn_furniture_presentation(source)

func _add_sample_wall() -> void:
	# Three original production wall modules, with the same real 2D blocker.
	# This intact partition exposes the impact height above the cut-away walls.
	for x in [4.5,5.5,6.5]:
		var wall := Node3D.new(); wall.name = "IntactBloodSampleWall"
		wall.set_script(load("res://scripts/dream/wall_segment_3d.gd"))
		var mesh := MeshInstance3D.new(); mesh.name = "WallMesh"; wall.add_child(mesh)
		wall.position = Vector3(x,0,1.0)
		wall.set_meta(&"dream_room_id",1)
		wall.set_meta(&"edge",{"axis":"H","x":roundi(x),"y":1})
		world.wall_root.add_child(wall); wall.configure_wall(2.6,.15)
	var body := StaticBody2D.new(); body.collision_layer = 4; body.collision_mask = 0
	body.position = Vector2(5.5,1.0)*32
	var shape := RectangleShape2D.new(); shape.size = Vector2(3*32,.15*32)
	var collision := CollisionShape2D.new(); collision.shape = shape; body.add_child(collision)
	world.collision_root.add_child(body)

func _spawn_target() -> void:
	if is_instance_valid(enemy):
		for bridge in world.actor_depth_bridges_root.get_children():
			if bridge.get("source_actor") == enemy: bridge.queue_free()
		enemy.queue_free()
	enemy = world._spawn_regular_employee(1,Vector2(7,7)*32,&"employee",false,"basic")
	enemy.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	enemy.set_room_runtime_active(true); enemy.set_player_vision_visible(true)
	enemy.current_health = 100000.0
	enemy.sky_drop_height = 0.0; enemy.sky_drop_delay_left = 0.0
	enemy._update_sky_drop(.001)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	# Disable AI while keeping the authoritative hitbox active for real shots.
	enemy.velocity = Vector2.ZERO
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge.get("source_actor") == enemy: enemy_bridge = bridge
	set_preset(mode)

func set_preset(value: int) -> void:
	mode = clampi(value,0,3)
	if not is_instance_valid(enemy): return
	enemy.global_position = PRESETS[mode][1]*32
	PhysicsServer2D.body_set_state(enemy.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0,enemy.global_position))
	enemy._apply_live_facing(Vector2.DOWN); enemy._update_weapon_aim()
	world.blood_wound_height = PRESETS[mode][3]
	_update_label()

func hit_target(lethal := false) -> void:
	if not ready_world: return
	if enemy.dead: _spawn_target()
	var direction: Vector2 = PRESETS[mode][2]
	if lethal: enemy.current_health = .5
	# A real accepted friendly-fire hit keeps the supplied impact heading.
	# Player gun hits still use the production Player->Enemy heading unchanged.
	enemy.take_damage(1.0,enemy.global_position-direction*16,0.0,&"enemy_projectile")
	_update_label()

func play_drag_demo() -> void:
	if not ready_world: return
	world.clear_preview_blood()
	if enemy.dead: _spawn_target()
	set_preset(3)
	enemy.random.seed = 71432
	enemy.current_health = .5
	var direction := Vector2(.894427,.447214)
	enemy.take_damage(1.0,enemy.global_position-direction*16,180.0,&"enemy_projectile")
	_update_label()

func set_dark(value: bool) -> void:
	dark = value
	if not is_instance_valid(world): return
	for record in light_records:
		var light: Light3D = record.ref.get_ref()
		if is_instance_valid(light):
			light.light_cull_mask = record.mask
			light.visible = false if value else record.visible
	environment.ambient_light_energy = 0.0 if value else ambient_energy
	_enforce_dark()
	_update_label()

func _enforce_dark() -> void:
	if not dark or not is_instance_valid(world): return
	# Some fixture scripts restore visibility and reflection code restores masks.
	# Suppress actual sources after those updates; include late-created fixtures.
	for light in world.find_children("*","Light3D",true,false):
		var known := false
		for record in light_records:
			if record.ref.get_ref()==light: known = true; break
		if not known: light_records.append({"ref":weakref(light),"mask":light.light_cull_mask,"visible":light.visible})
		light.hide()
	if environment != null: environment.ambient_light_energy = 0.0

func _process(delta: float) -> void:
	if not ready_world: return
	if dark:
		for record in light_records:
			var light: Light3D = record.ref.get_ref()
			if is_instance_valid(light): light.hide()
	if is_instance_valid(enemy):
		# Keep the actual hit flash, face, hand and death presentation ticking;
		# only living enemy AI locomotion is held still in this target fixture.
		if not enemy.dead: enemy.velocity = Vector2.ZERO
		enemy._process(delta)
		if enemy.dead: enemy.set_physics_process(true)
	if moving and is_instance_valid(moved_prop):
		motion_time += delta
		var source: Node2D = moved_prop.source_actor
		source.global_position = Vector2(3,4)*32+Vector2(sin(motion_time)*.75,0)*32
		source.rotation = sin(motion_time*.7)*.25
		moved_prop._sync_transform()

func toggle_prop_motion() -> void:
	moving = not moving
	if not moving and is_instance_valid(moved_prop):
		moved_prop.source_actor.global_position = Vector2(3,4)*32
		moved_prop.source_actor.rotation = 0.0; moved_prop._sync_transform()
	_update_label()

func set_drag_style(value: bool) -> void:
	pixel_drag = value
	if is_instance_valid(world): world.pixel_drag_enabled = value
	_update_label()

func _update_label() -> void:
	if label == null: return
	label.visible = not hide_hud
	label.text = "血液实景小样 · %s · %s · %s拖痕\n1 墙面　2 桌面　3 柜侧　4 地面　F 中弹　K 致死\nP 切换后续拖痕　G 拖痕演示　N 关灯　R 清理\nM 家具移动　F1 白盒　F5 重建　H 隐藏\nWASD 移动／鼠标开枪" % [PRESETS[mode][0],"全暗" if dark else "场景原灯","像素" if pixel_drag else "原版"]

func _input(event: InputEvent) -> void:
	if not ready_world or not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1: set_preset(0)
		KEY_2: set_preset(1)
		KEY_3: set_preset(2)
		KEY_4: set_preset(3)
		KEY_F: hit_target()
		KEY_K: hit_target(true)
		KEY_N: set_dark(not dark)
		KEY_M: toggle_prop_motion()
		KEY_P: set_drag_style(not pixel_drag)
		KEY_G: play_drag_demo()
		KEY_R: world.clear_preview_blood()
		KEY_H: hide_hud = not hide_hud; _update_label()
		KEY_F1: whitebox = not whitebox; rebuild()
		KEY_F5: rebuild()
		_: return
	get_viewport().set_input_as_handled()
