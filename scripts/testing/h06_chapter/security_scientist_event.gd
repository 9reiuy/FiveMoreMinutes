extends Node3D
## Room-owned actor and chair; run-owned consequences. Dialogue never takes player input.
const PLAN:=preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const ACTOR:=preload("res://scripts/testing/h06_chapter/security_scientist_actor.gd")
const TEMPLATE:=preload("res://scenes/entities/employee_enemy.tscn")
const BUBBLE:=preload("res://scripts/ui/dialogue/growing_dialogue_bubble.gd")
const LINES:=["卷帘门我已经打开了","不要开枪!"]
const TURN_SECONDS:=.95
var world:Node3D
var chair:Node3D
var actor:ACTOR
var bridge:Node3D
var source_root:Node2D
var bubble:Control
var bubble_layer:CanvasLayer
var active:=false
var started:=false
var elapsed:=0.0
var current_line:=-1
var chair_start:=0.0
var seat_height:=0.0

func build(art,room:Node3D)->void:
	name="MonitoringScientist"
	world=art.world
	var model:Node3D=room.get_node("CameraChair")
	# Fittings.fit offsets the imported model's origin to align its bounds.
	# Rotate a new pivot at the seat centre instead of orbiting that old origin.
	var seat:Vector2=PLAN.WATCH_FIXTURES.CameraChair.get_center()
	chair=Node3D.new()
	chair.name="ScientistChairPivot"
	room.add_child(chair)
	chair.position=Vector3(seat.x,0,seat.y)
	seat_height=room.to_global(Vector3(seat.x,.47,seat.y)).y
	model.reparent(chair,true)
	art.cutout.register_tree(model,true)
	chair_start=chair.rotation.y
	if world.staff_story.scientist_killed:return
	source_root=Node2D.new()
	source_root.name="MonitoringScientistSource"
	art.physics_root.add_child(source_root)
	var instance:=TEMPLATE.instantiate()
	instance.set_script(ACTOR)
	actor=instance as ACTOR
	actor.name="SeatedScientist"
	actor._cached_dream_world=world
	actor.position=PLAN.WATCH_FIXTURES.CameraChair.get_center()*32.0
	actor.set_meta(&"dream_room_id",0)
	source_root.add_child(actor)
	var bounds:Rect2=PLAN.UPPER.observation
	actor.set_room_bounds(Rect2(bounds.position*32.0,bounds.size*32.0).grow(-4.0))
	actor.story_killed.connect(_on_killed)
	bridge=world._spawn_depth_bridge(actor,[NodePath("CharacterVisual")])
	bridge.name="MonitoringScientistDepth"
	bridge.ground_surface_height=PLAN.upper_height(PLAN.UPPER.observation.get_center())+.18
	bridge.reparent(self,true)
	actor.floor_height=PLAN.upper_height(PLAN.UPPER.observation.get_center())
	actor.story_bridge=bridge
	if world.staff_story.introduction_seen:
		started=true
		elapsed=7.0
		chair.rotation.y=chair_start+PI
		actor.set_seated_facing(true)

func set_active(value:bool)->void:
	active=value
	if is_instance_valid(actor):
		actor.set_story_active(value)
	if not value:_dismiss()

func _process(delta:float)->void:
	if not active or not is_instance_valid(actor) or actor.dead:return
	_align_seat()
	if not started:
		if world.on_lower_floor or not PLAN.UPPER.observation.has_point(world._feet()):return
		started=true
		world.staff_story.monitoring_shutter_open=true
	if elapsed>=7.0:return
	elapsed+=delta
	var turn:=smoothstep(0,TURN_SECONDS,elapsed)
	chair.rotation.y=chair_start+PI*turn
	actor.set_seated_facing(turn>=.5)
	var line:=0 if elapsed<TURN_SECONDS+3.0 else 1
	if elapsed<TURN_SECONDS:return
	if line!=current_line:_say(line)
	if is_instance_valid(bubble):
		var age:=elapsed-TURN_SECONDS-(3.0 if line==1 else 0.0)
		bubble.set_speaker_hud_position(_anchor())
		bubble.set_typing_progress(1.0,mini(LINES[line].length(),int(age*22)))
	if elapsed>=6.5:
		world.staff_story.introduction_seen=true
		elapsed=7.0
		_dismiss()

func _align_seat()->void:
	# Billboards tilt with the real Camera. Keep the two hip joints on the
	# actual 3D seat instead of fixing an offset which only fits one angle.
	var hips:Vector3=(bridge.get_attached_part_world_position(actor.left_leg)+bridge.get_attached_part_world_position(actor.right_leg))*.5
	bridge.ground_surface_height+=seat_height-hips.y

func _anchor()->Vector2:
	var point:Vector2=world.camera_3d.unproject_position(bridge.get_status_mark_world_position())
	var mapper:Variant=world.get_meta(&"presentation_world_to_hud",null)
	if mapper is Callable and (mapper as Callable).is_valid():return mapper.call(point)
	return point*Vector2(640,360)/Vector2(world.camera_3d.get_viewport().size)

func _say(index:int)->void:
	current_line=index
	if not is_instance_valid(bubble_layer):
		bubble_layer=CanvasLayer.new()
		bubble_layer.name="ScientistSpeech"
		bubble_layer.layer=70
		get_tree().root.add_child(bubble_layer)
		bubble=BUBBLE.new()
		bubble.name="ScientistSpeechBubble"
		bubble_layer.add_child(bubble)
	bubble.show_dialogue(LINES[index],_anchor(),[])
	bubble.progress_bar_container.hide()

func _on_killed()->void:
	world.staff_story.scientist_killed=true
	world.staff_story.crew_escaped=false
	_dismiss()

func _dismiss()->void:
	if is_instance_valid(bubble):bubble.dismiss(0)

func _exit_tree()->void:
	if is_instance_valid(bubble_layer):bubble_layer.queue_free()
