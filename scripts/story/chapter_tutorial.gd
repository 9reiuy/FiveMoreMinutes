extends Node
## Three TV-led lessons. Gameplay actors, weapons and jumping stay authoritative.
enum Stage { INTRO, JUMP_CALL, JUMP_TEST, JUMP_DONE, RANGE_CALL, RANGE_TEST, COMPLETING, RETURN_WEAPON, DONE }
const CONTROL_HINTS := {
	&"move": "使用键盘 WASD 控制移动\n使用鼠标移动镜头",
	&"roll": "使用空格键进行翻滚",
	&"pickup": "接近物品后按 E 拿取",
	&"return_weapon": "按右键丢掉武器",
}
const WEAPON_SCENE := preload("res://scenes/dream/world_weapon_pickup.tscn")
const FACILITY := preload("res://scripts/story/tutorial_training_facility_art.gd")
const TARGET_POSITION:=Vector2(4.5,2.9)*32.0
const WEAPON_POSITION := FACILITY.CABINET_PICKUP_POSITION
const WEAPON_APPROACH := FACILITY.CABINET_APPROACH_POSITION
const START_LINE:=14.2*32.0
const FINISH_LINE:=11.4*32.0
var world: Node3D
var stage:=Stage.INTRO
var talked:=false
var dashed:=false
var picked:=false
var fired:=0
var target_defeated:=false
var weapon_returned := false
var training_target: Node2D
var pickup: Node2D
var target_layers: Array=[]
var visited: Array[bool]=[false,false,false]
var vacated: Array[bool]=[false,false,false]
var sealed: Array[bool]=[false,false,false]
var lights_retired: Array[bool]=[false,false,false]
var dialogue_busy:=false
var call_elapsed:=0.0
var sample_was_dashing:=false
var dash_origin:=Vector2.ZERO
var last_health:=50.0
var recoil: Tween
var _signature: Array=[]
var _shown_control_hints: Dictionary = {}
var _active_control_hint: StringName = &""

func _ready() -> void:
	world=get_parent();await world.ready
	world.player.configure_weapon("",world.config,{})
	world.player.set_meta(&"tutorial_loan_weapon",true)
	world.player.confirmed_projectile_fired.connect(func():if picked:fired+=1)
	world.player.died.connect(_restart)
	world.player.weapon_drop_requested.connect(_on_weapon_drop_requested)
	_prepare_range();_sync_progression(true)

func can_exit() -> bool:return stage==Stage.DONE and not dialogue_busy
func is_completion_dialogue() -> bool:return stage==Stage.COMPLETING and dialogue_busy
func can_enter_room(room: int) -> bool:
	return not sealed[room] and (room==0 or (room==1 and stage>=Stage.JUMP_CALL) or (room==2 and stage>=Stage.RANGE_CALL))

func request_tv_interaction(room: int) -> void:
	if dialogue_busy or world.player.dead:return
	if room==0 and stage==Stage.INTRO:_run_dialogue(0,&"tutorial_tv_intro",Stage.JUMP_CALL)
	elif room==1 and stage==Stage.JUMP_CALL:_run_dialogue(1,&"tutorial_jump_brief",Stage.JUMP_TEST)
	elif room==2 and stage==Stage.RANGE_CALL:_run_dialogue(2,&"tutorial_range_brief",Stage.RANGE_TEST)

func _run_dialogue(room: int,id: StringName,next_stage: int) -> void:
	dialogue_busy=true;_sync_progression(true)
	var completed: bool=await world.show_tv_dialogue(room,id)
	if not is_inside_tree():return
	dialogue_busy=false;call_elapsed=0.0
	if completed:
		if stage==Stage.INTRO:talked=true
		stage=next_stage
		if stage==Stage.RANGE_TEST:_enable_target_collision()
	_sync_progression(true)

func get_call_state() -> Dictionary:
	if dialogue_busy:return {}
	var room: int=1 if stage==Stage.JUMP_CALL else 2 if stage==Stage.RANGE_CALL else -1
	if room<0 or not world.training_zone_states.get(room,false):return {}
	return {"room":room,"text":"请到这边来" if room==1 else "到这边来","visible":fmod(call_elapsed,2.1)<1.55}

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(world) or world.player.dead or get_tree().paused:return
	var jumping: bool=world.player.is_phase_dash_active()
	# The player may already have travelled before this sibling's physics tick.
	# Read the movement controller's authoritative start, not a sampled mid-jump pose.
	if jumping and not sample_was_dashing:dash_origin=world.player.phase_dash.origin
	if stage==Stage.JUMP_TEST and not jumping and sample_was_dashing:
		var at: Vector2=world.player.global_position
		if dash_origin.y>=START_LINE-10.0 and at.y<=FINISH_LINE+10.0 and at.x>2.8*32.0 and at.x<5.2*32.0:
			dashed=true;stage=Stage.JUMP_DONE;world.set_dash_strip_complete(true)
			_run_dialogue(1,&"tutorial_jump_good",Stage.RANGE_CALL)
	sample_was_dashing=jumping

func _process(delta: float) -> void:
	if not is_instance_valid(world) or world.exit_sequence_started or get_tree().paused:return
	call_elapsed+=world._get_presentation_delta(delta)
	_update_rooms();_sync_progression()
	_update_control_hint()
	if world.player.dead or dialogue_busy:return
	_update_target_feedback()
	if stage==Stage.RANGE_TEST and picked and fired>0 and target_defeated:
		stage=Stage.COMPLETING
		_run_dialogue(2,&"tutorial_range_good",Stage.RETURN_WEAPON)

func _update_control_hint() -> void:
	if world.player.dead or dialogue_busy:
		world.control_hint.dismiss()
		return
	var cell: Vector2 = world.player.global_position / 32.0
	var room := -1
	for index in 3:
		var rect: Rect2i = world.FLOOR_SECTIONS[index]
		if Rect2(Vector2(rect.position) - Vector2.ONE * 0.5, Vector2(rect.size)).has_point(cell):
			room = index
			break
	var cue: StringName = &""
	if room == 0 and stage == Stage.INTRO:
		cue = &"move"
	elif room == 1 and stage == Stage.JUMP_TEST:
		cue = &"roll"
	elif room == 2 and stage == Stage.RANGE_TEST and not picked:
		cue = &"pickup"
	elif stage == Stage.RETURN_WEAPON and not weapon_returned:
		cue = &"return_weapon"
	if cue != _active_control_hint:
		world.control_hint.dismiss()
		_active_control_hint = cue
	if cue != &"" and not _shown_control_hints.has(cue):
		_shown_control_hints[cue] = true
		world.control_hint.present(CONTROL_HINTS[cue])

func _update_rooms() -> void:
	var cell: Vector2=world.player.global_position/32.0
	# Door access still follows leaving/completion. Illumination has its own
	# one-way handoff, committed only inside an unlocked subsequent room.
	for destination in [1,2]:
		var next_rect: Rect2i = world.FLOOR_SECTIONS[destination]
		var inside_next := Rect2(Vector2(next_rect.position)-Vector2.ONE*.5,Vector2(next_rect.size))
		if can_enter_room(destination) and inside_next.has_point(cell):
			for previous in destination: lights_retired[previous]=true
	for room in [0,1]:
		var rect: Rect2i=world.FLOOR_SECTIONS[room]
		var bounds:=Rect2(Vector2(rect.position)-Vector2.ONE*.5,Vector2(rect.size))
		if bounds.has_point(cell) and can_enter_room(room):visited[room]=true;vacated[room]=false
		elif visited[room] and not bounds.grow(.36).has_point(cell):
			var completed: bool=talked if room==0 else dashed
			if completed:sealed[room]=true
			else:
				vacated[room]=true
				var gate: Node3D=_gate("PreparationDoor" if room==0 else "EntryToDash")
				# An unfinished lesson can be re-entered by walking back toward it.
				if world.player.velocity.x<-.1 and cell.x<10.2 and absf(cell.y-gate.position.z)<1.4:vacated[room]=false

func _sync_progression(force: bool=false) -> void:
	var stamp: Array=[stage,picked,dialogue_busy,sealed[0],sealed[1],vacated[0],vacated[1],lights_retired[0],lights_retired[1]]
	if not force and stamp==_signature:return
	_signature=stamp
	var can_act: bool=not dialogue_busy and not world.player.dead
	world.player.set_meta(&"tutorial_loan_weapon", stage != Stage.RETURN_WEAPON or dialogue_busy)
	world.player.set_dash_enabled(can_act and stage==Stage.JUMP_TEST)
	world.player.set_attacking_enabled(can_act and (stage==Stage.JUMP_TEST or (stage==Stage.RANGE_TEST and picked)))
	var station_names:=["Preparation","Movement","Range"]
	for room in 3:
		var unlocked: bool=room==0 or (room==1 and stage>=Stage.JUMP_CALL) or (room==2 and stage>=Stage.RANGE_CALL)
		var powered: bool=unlocked and not lights_retired[room]
		var access_allowed: bool=can_enter_room(room) and not vacated[room]
		world.set_training_zone_enabled(room,powered)
		var station: Node3D=world.get_node("TutorialGeometry/ChapterLayout/"+station_names[room]+"/TelevisionDesk")
		station.set_power_available(powered)
		var source: Node2D=world.get_tutorial_terminal(room)
		source.set_interaction_enabled(not dialogue_busy and access_allowed and ((room==0 and stage==Stage.INTRO) or (room==1 and stage==Stage.JUMP_CALL) or (room==2 and stage==Stage.RANGE_CALL)))
		var gate: Node3D=_gate(["PreparationDoor","EntryToDash","DashToRange"][room])
		gate.set_indicator_power_enabled(powered)
		gate.set_open(access_allowed and (stage>=Stage.JUMP_CALL if room==0 else can_enter_room(room)))
	_gate("Exit").set_open(can_exit())

func _prepare_range() -> void:
	world.get_node("TutorialGeometry/ChapterLayout/Range/TrainingTarget/EditorPreview").hide()
	training_target=preload("res://scenes/story/TrainingMannequin.tscn").instantiate()
	world.gameplay_world.add_child(training_target);training_target.global_position=TARGET_POSITION
	training_target.configure(world.player,50.0,0.0,Rect2(TARGET_POSITION-Vector2(100,100),Vector2(200,200)),0.0,0.0,world.config)
	training_target.prepare_model()
	training_target.defeated.connect(func(_where,_count):target_defeated=true;_target_power_down())
	for object in [training_target]+training_target.find_children("*","CollisionObject2D",true,false):
		if object is CollisionObject2D:
			target_layers.append([object,object.collision_layer]);object.set_deferred("collision_layer",0)
	_bridge(training_target,[NodePath("CharacterVisual")])
	pickup=preload("res://scenes/dream/world_weapon_pickup.tscn").instantiate();world.gameplay_world.add_child(pickup)
	pickup.global_position=WEAPON_POSITION;pickup.configure("basic");pickup.freeze=true
	_bridge(pickup,[NodePath("WeaponSprite")],FACILITY.CABINET_WEAPON_HEIGHT)
	set_range_visible(false)

func _enable_target_collision() -> void:
	for entry in target_layers:
		if is_instance_valid(entry[0]):entry[0].set_deferred("collision_layer",entry[1])

func set_range_visible(enabled: bool) -> void:
	for source in [training_target,pickup]:
		if not is_instance_valid(source):continue
		source.visible=enabled
		var reference: WeakRef=source.get_meta(&"depth_visual_bridge",null)
		var bridge: Node3D=reference.get_ref() if reference!=null else null
		if is_instance_valid(bridge):bridge.visible=enabled;bridge.set_room_presentation_active(enabled)

func _bridge(source: Node2D,paths: Array,shelf_height := -1.0) -> void:
	var bridge: Node3D=preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn").instantiate();world.actor_depth_bridges_root.add_child(bridge)
	bridge.office_linear_lighting=world.uses_office_night_lighting()
	if shelf_height >= 0.0:
		bridge.configure(source,bridge.get_node("ActorDepthViewport"),bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),null,paths,shelf_height,0.0,Vector2(64,64))
		bridge.shadow_proxy_enabled=false
	else:
		bridge.configure(source,bridge.get_node("ActorDepthViewport"),bridge.get_node("ActorDepthViewport/ActorDepthRenderRoot"),null,paths)
	bridge.set_world_camera(world.camera_3d)
	if source.is_in_group(&"dream_enemies"):world.configure_character_readability(bridge)
	source.set_meta(&"depth_visual_bridge",weakref(bridge))
	if source.is_in_group(&"dream_enemies"):
		world.authored_cutout.watch_actor(source, bridge)

func _input(event: InputEvent) -> void:
	if dialogue_busy or world.exit_sequence_started or world.player.dead or get_tree().paused:return
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_E:return
	if stage!=Stage.RANGE_TEST or picked or not is_instance_valid(pickup):return
	if world.player.global_position.distance_to(pickup.global_position)>=42.0:return
	if pickup.request_player_pickup(world.player):
		world.player.equip_weapon("basic",world.config);picked=true
		pickup.queue_free();world.interaction_consumed_until_release=true;get_viewport().set_input_as_handled()
		_sync_progression(true)

func _restart() -> void:
	if world.player.is_death_shot_playing():
		while world.player.is_death_shot_playing():
			await get_tree().process_frame
			if not is_inside_tree():return
	else:
		await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():return
	world.player.revive_for_floor_restart("basic" if picked and not weapon_returned else "",world.config,{})
	var room: int=0 if stage==Stage.INTRO else 1 if stage<Stage.RANGE_CALL else 2
	world.player.global_position=Vector2(4,22 if room==0 else 14.8 if room==1 else 6.8)*32.0
	vacated[room]=false;sample_was_dashing=false;_sync_progression(true)
	if stage == Stage.COMPLETING:
		var dialogue_id: StringName = &"tutorial_weapon_returned" if weapon_returned else &"tutorial_range_good"
		var next_stage: int = Stage.DONE if weapon_returned else Stage.RETURN_WEAPON
		_run_dialogue(2, dialogue_id, next_stage)

func _on_weapon_drop_requested(drop_data: Dictionary) -> void:
	if stage != Stage.RETURN_WEAPON or dialogue_busy or bool(drop_data.get("forced_drop", false)):
		return
	weapon_returned = true
	stage = Stage.COMPLETING
	world.control_hint.dismiss()
	_sync_progression(true)
	_commit_weapon_return.call_deferred(drop_data)

func _commit_weapon_return(drop_data: Dictionary) -> void:
	if not is_inside_tree():
		return
	var returned := WEAPON_SCENE.instantiate() as WorldWeaponPickup
	returned.weapon_id = String(drop_data["weapon_id"])
	returned.skin_index = int(drop_data.get("skin_index", 0))
	returned.visual_scale_override = float(drop_data.get("visual_scale", -1.0))
	returned.rotation = float(drop_data.get("visual_rotation", 0.0))
	world.gameplay_world.add_child(returned)
	var visual_position: Vector2 = drop_data.get("visual_position", world.player.global_position)
	returned.global_position = visual_position - returned.weapon_sprite.position.rotated(returned.rotation)
	returned.add_collision_exception_with(world.player)
	returned.set_thrown(
		Vector2(drop_data["direction"]) * float(drop_data["speed"]),
		float(drop_data["damage"]),
		float(drop_data["force"]),
		world.player.get_instance_id(),
		world.config.world_weapon_throw_pickup_lockout
	)
	_bridge(returned, [NodePath("Shadow"), NodePath("WeaponSprite")])
	preload("res://scripts/audio/sfx_manager.gd").play_weapon_throw()
	_run_dialogue(2, &"tutorial_weapon_returned", Stage.DONE)

func _gate(key: String) -> Node3D:return world.get_node("TutorialGeometry/ChapterLayout/Architecture/"+key)
func _update_target_feedback() -> void:
	if not picked or not is_instance_valid(training_target) or training_target.dead:return
	if training_target.current_health<last_health:
		last_health=training_target.current_health
		if is_instance_valid(recoil):recoil.kill()
		var visual: Node2D=training_target.get_node("CharacterVisual");visual.rotation=-.09
		recoil=create_tween();recoil.tween_property(visual,"rotation",0.0,.16)
func _target_power_down() -> void:
	if is_instance_valid(recoil):recoil.kill()
	var visual: Node2D=training_target.get_node("CharacterVisual")
	recoil=create_tween();recoil.set_parallel(true)
	recoil.tween_property(visual,"rotation",1.25,.25);recoil.tween_property(visual,"modulate",Color(.38,.43,.48),.25)
func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.player):world.player.remove_meta(&"tutorial_loan_weapon")
