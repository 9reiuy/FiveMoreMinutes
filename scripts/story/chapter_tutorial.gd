extends Node
## Live training exercises; 2D gameplay remains authoritative.
const TARGET_POSITION := Vector2(4.0, 2.6) * 32.
const WEAPON_POSITION := Vector2(7.0, 7.3) * 32.
const DASH_LINE := 12.7 * 32.
var world: Node3D
var panel: CanvasLayer
var hint: Control
var stage := 0
var presented_stage := -1
var distance := 0.
var dashed := false
var talked := false
var fired := 0
var reload_started := false
var reload_done := false
var manual_reload_requested := false
var training_target: Node2D
var pickup: Node2D
var picked := false
var previous := Vector2.ZERO
var target_defeated := false
var celebration_started := false
var target_layers: Array = []
var dash_origin := Vector2.ZERO
var dash_crossed := false
var sample_was_dashing := false
var dash_lesson_armed := false
var last_health:=200.
var hit_count:=0
var target_readout: Control
var recoil: Tween
var armour_meter: Control
var ammo_meter: Control
func _ready() -> void:
	world = get_parent(); await world.ready
	panel = preload("res://scripts/story/chapter_panel.gd").new(); add_child(panel)
	hint = preload("res://scripts/story/context_hint.gd").new(); panel.add_child(hint)
	previous = world.player.global_position
	world.player.configure_weapon("", world.CONFIG, {})
	world.player.set_attacking_enabled(true) # Shared phase-dash needs this gate.
	world.player.set_meta(&"tutorial_manual_reload", true)
	world.player.set_meta(&"tutorial_loan_weapon", true)
	world.guide.interaction_requested.connect(func():
		if stage == 1: talked = true)
	world.player.confirmed_projectile_fired.connect(func():
		if picked: fired += 1)
	world.player.ammo_changed.connect(func(_current, _capacity, reloading):
		if picked and manual_reload_requested:
			if reloading: reload_started = true
			elif reload_started: reload_done = true)
	world.player.died.connect(_restart)
	target_readout=preload("res://scripts/story/context_hint.gd").new(); panel.add_child(target_readout)
	armour_meter=preload("res://scripts/story/training_telemetry.gd").new(); panel.add_child(armour_meter)
	ammo_meter=preload("res://scripts/story/training_telemetry.gd").new(); ammo_meter.armour=false; panel.add_child(ammo_meter)
	_prepare_range()
	_sync_progression()
func can_exit() -> bool: return stage >= 6 and not celebration_started
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(world) or get_tree().paused or world.player.dead: return
	var position: Vector2 = world.player.global_position
	distance += position.distance_to(previous); previous = position
	if stage == 0 and position.y <= 21.0 * 32. and absf(position.x - 128.) < 64.: stage = 1
	var active: bool = world.player.is_phase_dash_active()
	if active and not sample_was_dashing:
		dash_origin = position; dash_crossed = false; dash_lesson_armed = stage == 2
	if stage == 2 and dash_lesson_armed and active and dash_origin.y > DASH_LINE and position.y < DASH_LINE and position.x > 2.8 * 32. and position.x < 5.2 * 32.:
		dash_crossed = true
	if stage == 2 and not active and sample_was_dashing and dash_crossed:
		dashed = true; stage = 3; _setup_training()
	sample_was_dashing = active
func _process(_delta: float) -> void:
	if not is_instance_valid(hint): return
	hint.hide(); target_readout.hide(); armour_meter.hide(); ammo_meter.hide()
	if world.exit_sequence_started or get_tree().paused or world.player.dead or world.dialogue_controller.is_active(): return
	if stage == 1 and talked:
		stage = 2; world.guide.set_interaction_enabled(false)
	world.player.set_attacking_enabled(not celebration_started)
	if stage == 3 and picked and fired > 0: stage = 4
	if stage == 4 and reload_done:
		stage = 5; world.player.remove_meta(&"tutorial_manual_reload")
	if stage == 5 and target_defeated:
		stage = 6; _celebrate()
	_sync_progression()
	if celebration_started: return
	if stage==1 and world.interaction_prompt.visible: return
	var ammo: Dictionary=world.player.get_ammo_status()
	var prompts: Array[String] = ["WASD 移动 · 前往登记台", "靠近登记员，E 交谈", "进入机动室 · 冲过发光地槽",
		"右侧武器台：E 领取手枪" if not picked else "瞄准靶道 · 左键射击  %d/12"%int(ammo.current),
		"弹匣 %d/12 · R 手动装填"%int(ammo.current) if not reload_started else "装填中……",
		"弹匣 %d/12 · 击倒测试体"%int(ammo.current), "校准完成 · 沿连廊向右，前往出口"]
	if stage==2 and world.player.global_position.y < DASH_LINE: prompts[2]="回到地槽起点，再朝房间右侧冲刺"
	_update_target_feedback()
	var at: Vector2 = world.player.global_position
	var projected: Vector2 = world.player.get_presentation_hud_position(world.camera_3d.unproject_position(Vector3(at.x / 32., 0, at.y / 32.)))
	hint.present(prompts[stage], projected + Vector2(0, 42))
	if picked and stage<6:
		ammo_meter.rounds=int(ammo.current); ammo_meter.position=Vector2(clampf(projected.x-50.,8.,532.),minf(hint.position.y+hint.size.y+2.,346.)).round(); ammo_meter.show(); ammo_meter.queue_redraw()
	if is_instance_valid(training_target) and not training_target.dead: training_target.set_physics_process(false)
func _prepare_range() -> void:
	world.get_node("TutorialGeometry/ChapterLayout/Range/TrainingTarget/EditorPreview").hide()
	training_target = preload("res://scenes/entities/employee_enemy.tscn").instantiate()
	world.gameplay_world.add_child(training_target); training_target.global_position = TARGET_POSITION
	training_target.configure(world.player, 200., 0., Rect2(TARGET_POSITION - Vector2(100, 100), Vector2(200, 200)), 0., 0., world.CONFIG)
	training_target.set_physics_process(false)
	training_target.defeated.connect(func(_where, _count): target_defeated = true; _target_power_down())
	for object in [training_target] + training_target.find_children("*", "CollisionObject2D", true, false):
		if object is CollisionObject2D:
			target_layers.append([object, object.collision_layer]); object.set_deferred("collision_layer", 0)
	_bridge(training_target, [NodePath("CharacterVisual")])
	pickup = preload("res://scenes/dream/world_weapon_pickup.tscn").instantiate(); world.gameplay_world.add_child(pickup)
	pickup.global_position = WEAPON_POSITION; pickup.configure("basic"); pickup.freeze = true
	_bridge(pickup, [NodePath("Shadow"), NodePath("WeaponSprite")])
	set_range_visible(bool(world.training_zone_states.get(2,false)))
	var mounts := Node3D.new(); world.add_child(mounts)
	var camera: Node3D = preload("res://scripts/story/surveillance_camera.gd").new()
	camera.position = Vector3(1.0, 2.2, .65); camera.target = world.player; mounts.add_child(camera)
func _setup_training() -> void:
	for key in ["StartGroove","DashStrip","FinishSensor"]:
		world.get_node("TutorialGeometry/ChapterLayout/Movement/"+key).material_override=OfficePixelMaterials.make(Color("518b82"),"metal",false,true)
	for entry in target_layers:
		if is_instance_valid(entry[0]): entry[0].set_deferred("collision_layer", entry[1])

func set_range_visible(enabled: bool) -> void:
	# Presentation follows room power; target/collision/progression remain authoritative.
	for source in [training_target,pickup]:
		if not is_instance_valid(source): continue
		source.visible=enabled
		var reference: WeakRef=source.get_meta(&"depth_visual_bridge",null)
		var bridge: Node3D=reference.get_ref() if reference!=null else null
		if is_instance_valid(bridge):
			bridge.visible=enabled
			bridge.set_room_presentation_active(enabled)
	if not enabled:
		for overlay in [target_readout,armour_meter,ammo_meter]:
			if is_instance_valid(overlay): overlay.hide()
func _bridge(source: Node2D, paths: Array) -> void:
	var bridge: Node3D = preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn").instantiate(); world.actor_depth_bridges_root.add_child(bridge)
	bridge.configure(source, bridge.get_node("ActorDepthViewport"), bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"), null, paths)
	bridge.set_world_camera(world.camera_3d)
	source.set_meta(&"depth_visual_bridge",weakref(bridge))
func _input(event: InputEvent) -> void:
	if get_tree().paused or world.exit_sequence_started or world.dialogue_controller.is_active() or world.player.dead: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_R and picked and fired > 0:
		var ammo: Dictionary = world.player.get_ammo_status()
		if not ammo.reloading and int(ammo.current) < int(ammo.capacity): manual_reload_requested = true
	if event.physical_keycode != KEY_E or stage != 3 or picked or not is_instance_valid(pickup): return
	if world.player.global_position.distance_to(pickup.global_position) >= 42.: return
	if pickup.request_player_pickup(world.player):
		world.player.equip_weapon("basic", world.CONFIG); picked = true
		world.player.ammo_states["basic"] = {"current":2,"reload_left":0.}
		world.player._emit_ammo_state()
		pickup.queue_free(); world.interaction_consumed_until_release = true; get_viewport().set_input_as_handled()
func _celebrate() -> void:
	celebration_started = true; world.player.set_attacking_enabled(false)
	await get_tree().create_timer(.2, false).timeout
	if not is_inside_tree(): return
	preload("res://scripts/audio/sfx_manager.gd").trigger_multi_kill_reaction(&"audience_applause")
	panel.command("校准通过")
	if not is_inside_tree(): return
	celebration_started = false; world.player.movement_enabled = true
	_sync_progression(true)
func _restart() -> void:
	await get_tree().create_timer(1.).timeout
	if not is_inside_tree(): return
	world.player.revive_for_floor_restart("basic" if picked else "", world.CONFIG, {})
	world.player.global_position = Vector2(128,22*32.) if stage<=1 else Vector2(128,15.5*32.) if stage==2 else Vector2(128,8*32.)
	world.player.movement_enabled = true
	_sync_progression(true)
	if stage == 2: sample_was_dashing = false; dash_crossed = false
	if picked and not reload_done:
		manual_reload_requested = false; reload_started = false
		world.player.ammo_states["basic"] = {"current":2,"reload_left":0.}
func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.player):
		world.player.remove_meta(&"tutorial_manual_reload"); world.player.remove_meta(&"tutorial_loan_weapon")

func _sync_progression(force: bool=false) -> void:
	if presented_stage==stage and not force: return
	presented_stage=stage
	world.player.set_dash_enabled(stage<3)
	world.set_training_zone_enabled(0,true)
	world.set_training_zone_enabled(1,stage>=2)
	world.set_training_zone_enabled(2,stage>=3)
	_gate("EntryToDash").set_open(stage>=2)
	_gate("DashToRange").set_open(stage>=3)
	_gate("Exit").set_open(stage>=6 and not celebration_started)

func _gate(key: String) -> Node:
	return world.get_node("TutorialGeometry/ChapterLayout/Architecture/"+key)
func _update_target_feedback() -> void:
	target_readout.hide()
	if not picked or not is_instance_valid(training_target): return
	if training_target.current_health<last_health and not training_target.dead:
		hit_count+=1; last_health=training_target.current_health
		if is_instance_valid(recoil): recoil.kill()
		var visual: Node2D=training_target.get_node("CharacterVisual")
		visual.rotation=-.09
		recoil=create_tween(); recoil.tween_property(visual,"rotation",0.,.16)
	var at: Vector2=world.player.get_presentation_hud_position(world.camera_3d.unproject_position(Vector3(TARGET_POSITION.x/32.,1.7,TARGET_POSITION.y/32.)))
	target_readout.present("命中 %d  装甲 %d%%"%[hit_count,maxi(0,roundi(training_target.current_health/2.))],at+Vector2(0,-20))
	armour_meter.position=Vector2(target_readout.position.x+(target_readout.size.x-100.)*.5,target_readout.position.y+target_readout.size.y+1.).round()
	armour_meter.ratio=training_target.current_health/200.; armour_meter.show(); armour_meter.queue_redraw()

func _target_power_down() -> void:
	if is_instance_valid(recoil): recoil.kill()
	var visual: Node2D=training_target.get_node("CharacterVisual")
	recoil=create_tween(); recoil.set_parallel(true)
	recoil.tween_property(visual,"rotation",1.25,.25); recoil.tween_property(visual,"modulate",Color(.38,.43,.48),.25)
