extends Node3D
## Region-owned civilians and speaker-anchored dialogue for the final escape.
signal spoke(speaker: int, text: String)

const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const ACTOR := preload("res://scripts/testing/h06_chapter/hangar_crew_actor.gd")
const ACTOR_SCENE := preload("res://scenes/entities/employee_enemy.tscn")
const BUBBLE := preload("res://scripts/ui/dialogue/growing_dialogue_bubble.gd")
const ENGINEER := preload("res://art/Dream/enemy/Engineer.png")
const SCIENTIST_A := preload("res://art/Dream/enemy/Scientist.png")
const SCIENTIST_B := preload("res://art/Dream/enemy/Scientist2.png")
const PORTRAITS := [ENGINEER,SCIENTIST_A,SCIENTIST_B,ENGINEER,SCIENTIST_A,SCIENTIST_B,ENGINEER]
const UNIFORM_COLOURS := [Color.WHITE,Color.WHITE,Color.WHITE,Color(.72,.89,1.),
	Color(.72,.90,.86),Color(.82,.89,1.),Color(.94,.74,.65)]
const STAFF_ROUTES := [
	# Receiving: take the east aisle around the reactor.
	[Vector2(44.4,31.1),Vector2(44.6,26.7),Vector2(44.55,24.5),Vector2(40.8,22.4),Vector2(39.2,19.7)],
	# Clinic: leave along the west side of the mezzanine posts.
	[Vector2(28.35,34.35),Vector2(27.34,32.25),Vector2(27.34,26.72),Vector2(36.7,26.72),Vector2(36.7,20.7)],
	# Dispatch console and north armory each have their own way out.
	[Vector2(33.75,26.86),Vector2(37.12,26.86),Vector2(37.16,19.5)],
	[Vector2(41.32,19.62),Vector2(41.22,16.8),Vector2(39.35,15.45)],
	[Vector2(30.34,31.25),Vector2(35.98,31.05),Vector2(36.62,26.2),Vector2(36.79,21.2)],
	[Vector2(37.16,36.78),Vector2(37.02,32.75),Vector2(37.65,29.66),Vector2(37.74,21.7)],
	[Vector2(33.12,18.35),Vector2(35.4,17.95),Vector2(36.87,15.35)],
]
const RUN_DELAYS := [0.,.86,1.72,2.58,.24,.47,1.16]
const EXIT_APPROACH := [Vector2(38.10,15.3),Vector2(38.,11.7)]
const DECK_OFFSETS := [Vector2(-1.85,1.51),Vector2(1.85,1.53),Vector2(0,2.32),Vector2(-1.07,.16),
	Vector2(1.10,.13),Vector2(-1.48,-1.58),Vector2(1.33,-1.72)]
const FALL_ANGLES := [-1.33,1.12,-1.91,1.86,-.91,2.06,-1.14]
const STAFF_LINES := ["快去设施出口","快跑","走这里","别带东西了"]
const LIFT_LINES := ["快启动","来不及了","我们安全了...暂时"]
const LINE_GAP := .86
const RUN_SPEED := 5.75
const RUN_PACE := [1.0,.94,1.04,.97,1.02,.91,1.08]
const STRIDE_RATE := [3.42,3.98,3.62,3.31,3.76,3.53,4.05]
const GLANCE_INTERVAL := [2.49,2.73,2.27,2.36,2.54,2.18,2.84]
const LIFT_GESTURES := [
	# Signal the controls, watch the doorway, catch a breath, hold the helmet,
	# plant both feet, clasp hands and wave the others aboard.
	{"lean":-.09,"dip":.25,"left":Vector2(1,-2),"right":Vector2(3,-11),"look":-.64,"rhythm":6.2},
	{"lean":.09,"dip":.10,"left":Vector2(2,-2),"right":Vector2(1,1),"look":.62,"rhythm":2.0},
	{"lean":.16,"dip":2.10,"left":Vector2(2,2),"right":Vector2(-2,3),"look":.18,"rhythm":3.0},
	{"lean":-.10,"dip":.65,"left":Vector2(1,-15),"right":Vector2(-1,1),"look":-.36,"rhythm":2.6},
	{"lean":.03,"dip":1.17,"left":Vector2(-1,2),"right":Vector2(1,2),"look":.48,"rhythm":1.7},
	{"lean":-.06,"dip":.52,"left":Vector2(6,-1),"right":Vector2(-5,-1),"look":-.25,"rhythm":4.0},
	{"lean":-.11,"dip":.30,"left":Vector2(-3,-8),"right":Vector2(1,-1),"look":.51,"rhythm":5.7}
]

var world: Node3D
var on_lift := false
var sources: Node2D
var actors: Array[ACTOR] = []
var bridges: Array[Node3D] = []
var paths: Array[Curve2D] = []
var escaped := 0
var crushed := false
var elapsed := 0.
var speech_age := 0.
var fall_age := 0.
var blood_index := 0
var next_line := 0
var speaker := -1
var bubble: BUBBLE

func prepare(art, lift: bool) -> void:
	name = "LiftEvacuees" if lift else "EscapingStaff"
	world = art.world
	on_lift = lift
	sources = Node2D.new()
	sources.name = "EvacuationPoseSources"
	sources.process_mode = Node.PROCESS_MODE_DISABLED
	art.physics_root.add_child(sources)
	var layer := CanvasLayer.new()
	layer.name = "EvacuationSpeech"
	layer.layer = 70
	layer.custom_viewport = get_tree().root
	add_child(layer)
	bubble = BUBBLE.new()
	layer.add_child(bubble)
	set_process(false)

func prepare_actor(index: int) -> void:
	var instance := ACTOR_SCENE.instantiate()
	instance.set_script(ACTOR)
	var actor := instance as ACTOR
	actor.name = "Evacuee%d"%(index+1)
	actor.portrait_atlas = PORTRAITS[index]
	actor.engineer = actor.portrait_atlas==ENGINEER
	actor._cached_dream_world = world
	var feet: Vector2 = PLAN.BOSS_MARK+DECK_OFFSETS[index] if on_lift else STAFF_ROUTES[index][0]
	actor.position = feet*world.CELL_PIXELS
	sources.add_child(actor)
	actor.face(Vector2.DOWN if on_lift else feet.direction_to(STAFF_ROUTES[index][1]))
	actor.random.seed = 17713+index*7919
	actor.enemy_blink_time_left = .30+index*.17 if on_lift else RUN_DELAYS[index]+.15+index*.023
	actor.body.modulate = UNIFORM_COLOURS[index]
	actor._sync_enemy_hands_visibility()
	actors.append(actor)
	var bridge: Node3D = world._spawn_depth_bridge(actor,[^"CharacterVisual"])
	bridge.reparent(self,true)
	bridge.ground_surface_height = .022
	bridges.append(bridge)
	if not on_lift:
		var path := Curve2D.new()
		var lane := Vector2((index-(PORTRAITS.size()-1)*.5)*.27,0)
		for point: Vector2 in STAFF_ROUTES[index]:
			path.add_point(point)
		for point: Vector2 in EXIT_APPROACH:
			path.add_point(point+lane)
		path.add_point(PLAN.PASSAGES[PLAN.Visit.STAFF].at+lane+Vector2.UP*.35)
		path.get_baked_length()
		paths.append(path)

func activate() -> void:
	set_process(true)

func deactivate() -> void:
	hide_speech()
	set_process(false)

func _process(delta: float) -> void:
	if crushed:
		_present_aftermath(delta)
		return
	elapsed += delta
	if not on_lift:
		_run_to_exit(delta)
	else:
		for i in actors.size():
			_pose_lift(actors[i],i,delta)
	if not on_lift or speech_age>0. or world._feet().y<=PLAN.LIFT_ENTRY.y+5.5:
		speech_age += delta
	_update_speech()
	if not on_lift and escaped==actors.size():
		deactivate()

func _run_to_exit(delta: float) -> void:
	for i in actors.size():
		var actor := actors[i]
		if not actor.visible: continue
		var path := paths[i]
		var running_age := maxf(elapsed-RUN_DELAYS[i],0.)
		var distance: float = running_age*RUN_SPEED*RUN_PACE[i]
		if distance>=path.get_baked_length():
			actor.position = path.sample_baked(path.get_baked_length())*world.CELL_PIXELS
			actor.hide()
			bridges[i].hide()
			bridges[i].set_room_presentation_active(false)
			escaped += 1
			continue
		var feet := path.sample_baked(distance)
		var toward := feet.direction_to(path.sample_baked(distance+.24))
		actor.position = feet*world.CELL_PIXELS
		var shoulder := signf(toward.x) if absf(toward.x)>.18 else float(1-2*(i%2))
		var glance := fposmod(running_age,GLANCE_INTERVAL[i])<.47
		var facing := Vector2(shoulder*.63,.81) if glance else toward
		var phase: float = distance*STRIDE_RATE[i]+i*1.73
		actor.pose_escape_run(facing,phase,distance>0.)
		var pumping := sin(phase) if distance>0. else 0.
		actor.left_leg.position.y += pumping*(float(i%3)*.46)
		actor.right_leg.position.y -= pumping*(float(i%3)*.46)
		actor.body_pivot.position.y = actor.body_pivot_base_position.y+float(i%3)*.35
		actor.body_pivot.rotation = -.075+float(i%4)*.030+pumping*.023
		actor.left_hand.rotation = pumping*.20
		actor.right_hand.rotation = -pumping*.22
		match i%4:
			0:
				actor.right_hand.position += Vector2(2.0,-3.1+pumping*.8)
			1:
				actor.left_hand.position += Vector2(3.1,-3.6)
			2:
				actor.right_hand.position += Vector2(-1.4,1.2-pumping)
			3:
				actor.left_hand.position += Vector2(1.7,-8.9+pumping*.8)
		if not actor.facing_back or actor.enemy_blink_phase!=0:
			actor._update_enemy_blink(delta)

func _pose_lift(actor: ACTOR, index: int, delta: float) -> void:
	var gesture: Dictionary = LIFT_GESTURES[index]
	var rhythm := sin(elapsed*float(gesture.rhythm)+index*1.37)
	var breath := sin(elapsed*(1.73+index*.19)+index*1.13)
	var looking := float(gesture.look)+sin(elapsed*(1.71+index*.09)+index*1.4)*.57
	actor.face(Vector2(looking,.74))
	actor.body_pivot.position = actor.body_pivot_base_position+Vector2(0,float(gesture.dip)+breath*.46)
	actor.body_pivot.rotation = float(gesture.lean)+breath*.028
	var left: Vector2 = gesture.left
	var right: Vector2 = gesture.right
	# The palm that is already raised carries the motion of the gesture.
	var left_motion := .5+maxf(-left.y-3.0,0.0)*.14
	var right_motion := .5+maxf(-right.y-3.0,0.0)*.14
	actor.left_hand.position = actor.left_hand_base_position+left+Vector2(rhythm*.65,rhythm*left_motion)
	actor.right_hand.position = actor.right_hand_base_position+right+Vector2(-rhythm*.65,-rhythm*right_motion)
	actor.left_hand.rotation = rhythm*.12
	actor.right_hand.rotation = -rhythm*.16
	actor.left_leg.position = actor.left_leg_base_position+Vector2(-float(index%3)*.65,0.)
	actor.right_leg.position = actor.right_leg_base_position+Vector2(float(index%3)*.65,0.)
	actor._update_enemy_blink(delta)

func _update_speech() -> void:
	var lines := LIFT_LINES if on_lift else STAFF_LINES
	var first_line := .15 if on_lift else .075
	if next_line<lines.size() and speech_age>=first_line+next_line*LINE_GAP:
		speaker = next_line
		next_line += 1
		spoke.emit(speaker,lines[speaker])
	if speaker<0: return
	if speech_age>=first_line+speaker*LINE_GAP+(.83 if on_lift else .80):
		hide_speech()
		return
	var camera: Camera3D = world.camera_3d
	var head_at: Vector3 = bridges[speaker].get_status_mark_world_position()
	var point := camera.unproject_position(head_at)
	if not actors[speaker].visible or camera.is_position_behind(head_at) or not camera.get_viewport().get_visible_rect().has_point(point):
		bubble.hide()
		return
	var mapper: Variant = world.get_meta(&"presentation_world_to_hud",null)
	var hud_point: Vector2 = mapper.call(point) if mapper is Callable and mapper.is_valid() else (
		point*get_tree().root.get_visible_rect().size/camera.get_viewport().get_visible_rect().size)
	bubble.present_hint(hud_point,lines[speaker])

func hide_speech() -> void:
	speaker = -1
	bubble.dismiss(0.)

func hit_by_crawler() -> void:
	if not on_lift or crushed: return
	crushed = true
	hide_speech()
	for i in actors.size():
		actors[i].pose_corpse(FALL_ANGLES[i],i)
	set_process(true)

func _present_aftermath(delta: float) -> void:
	fall_age += delta
	var slide := smoothstep(0.,.22,fall_age)
	for i in actors.size():
		var spread: Vector2 = DECK_OFFSETS[i].normalized()*lerpf(.63,.95,float(i)/(actors.size()-1))
		actors[i].position = (PLAN.BOSS_MARK+DECK_OFFSETS[i]+spread*slide)*world.CELL_PIXELS
	if fall_age<.17+blood_index*.062: return
	if blood_index<actors.size():
		var actor := actors[blood_index]
		world.spawn_death_blood_pool(actor.global_position,0,.84,false,DECK_OFFSETS[blood_index].normalized())
		blood_index += 1
	else:
		for bridge in bridges:
			bridge.freeze_static_visual()
		set_process(false)
