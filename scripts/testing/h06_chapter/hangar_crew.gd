extends Node3D
## Region-owned living crew on first visit, staged aftermath on the return visit.
const ACTOR := preload("res://scripts/testing/h06_chapter/hangar_crew_actor.gd")
const TEMPLATE := preload("res://scenes/entities/employee_enemy.tscn")
const BLOOD_SCENERY := preload("res://scripts/testing/h06_chapter/hangar_crew_blood.gd")
const ESCAPE := preload("res://scripts/testing/h06_chapter/hangar_crew_escape.gd")
const PORTRAITS := [preload("res://art/Dream/enemy/Scientist.png"),preload("res://art/Dream/enemy/Scientist2.png"),preload("res://art/Dream/enemy/Engineer.png")]
const STANDING := [Vector2(-6.20,4.60),Vector2(0.65,-1.35),Vector2(0.85,4.40)]
const FALLEN := [Vector2(-6.35,5.40),Vector2(0.75,-0.15),Vector2(0.85,5.80)]
const BLOOD_HEIGHT := 0.045 # Above the bay grate (0.032 m), outside the central pad.
const TRAILS := [
	[Vector2(-6.20,4.20),Vector2(-6.30,4.65),Vector2(-6.35,5.40)],
	[Vector2(0.65,-1.35),Vector2(0.90,-0.85),Vector2(0.75,-0.15)],
	[Vector2(0.85,3.85),Vector2(0.65,4.80),Vector2(0.85,5.80)]]
const SCATTERED := [Vector2(-9.15,6.45),Vector2(-2.45,-3.30),Vector2(0.40,11.35)]
const LONG_TRAILS := [
	[Vector2(-6.80,2.40),Vector2(-6.90,3.60),Vector2(-6.55,4.50),Vector2(-7.50,5.20),Vector2(-8.25,5.85),Vector2(-9.15,6.45)],
	[Vector2(0.65,-1.10),Vector2(1.20,-0.80),Vector2(1.15,-2.35),Vector2(-0.60,-3.10),Vector2(-2.45,-3.30)],
	[Vector2(0.85,4.40),Vector2(1.10,5.40),Vector2(0.45,6.50),Vector2(-0.35,8.35),Vector2(0.10,9.85),Vector2(0.40,11.35)]]
var world: Node3D
var sources := Node2D.new()
var actors: Array[EmployeeEnemy] = []
var bridges: Array[Node3D] = []
var aftermath := false
var blood_created := false
var blood_segments := 0
var enhanced := false
var active := false
var elapsed := 0.0
var blood_preparation_ms := 0.0
var blood_scenery: Node3D
var escape:ESCAPE
var returning:=false
var owner_art

func _process(delta: float) -> void:
	advance_activity(delta)

func advance_activity(delta: float) -> void:
	if active and escape!=null:
		escape.advance(delta)
		return
	if not active or aftermath or not enhanced: return
	elapsed += delta
	for actor in actors:
		actor.work_activity.advance(delta)

func build(art, returned: bool) -> void:
	world = art.world
	owner_art=art
	returning=returned
	aftermath = returned and world.staff_story.scientist_killed
	name="HangarCrewAftermath" if aftermath else ("HangarCrewSurvivors" if returned else "HangarCrew")
	enhanced = world.hangar_crew_activity_enabled
	set_process(false)
	sources.name = "HangarCrewPoseSources"
	sources.process_mode = Node.PROCESS_MODE_DISABLED
	art.physics_root.add_child(sources)
	for i in 3:
		var instance := TEMPLATE.instantiate()
		instance.set_script(ACTOR)
		var actor := instance as ACTOR
		actor.name = ["ScientistA","ScientistB","Engineer"][i]
		actor.portrait_atlas = PORTRAITS[i]
		actor.engineer = i == 2
		actor._cached_dream_world = world
		actor.position = ((SCATTERED[i] if enhanced else FALLEN[i]) if aftermath else STANDING[i])*32
		sources.add_child(actor)
		if aftermath: actor.pose_corpse([-1.24,1.60,-1.81][i],i)
		else:
			actor.face(Vector2(-3,1.6)-STANDING[i])
			if enhanced or returned: actor.start_work(i)
		actors.append(actor)
		var bridge: Node3D = world._spawn_depth_bridge(actor,[NodePath("CharacterVisual")])
		bridge.name = "CrewDepth_"+str(actor.name)
		bridge.ground_surface_height = 0.040
		bridge.reparent(self,true)
		bridges.append(bridge)
	if returned and not aftermath:
		escape=ESCAPE.new()
		escape.bind(self,art)
	# The choice can change after this room's loading-only preparation.
	# Prepare its baked blood resource now; visibility is selected on entry.
	if enhanced and returned:
		blood_scenery = BLOOD_SCENERY.new()
		add_child(blood_scenery)
		blood_scenery.hide()

func sync_visibility()->void:
	if is_instance_valid(blood_scenery):blood_scenery.visible=aftermath and blood_created

func _sync_return_branch()->void:
	if not returning:return
	var killed:bool=world.staff_story.scientist_killed
	if killed!=aftermath:
		aftermath=killed
		blood_created=false
		blood_segments=0
		escape=null
		for index in actors.size():
			var actor:EmployeeEnemy=actors[index]
			if actor.work_activity!=null:actor.work_activity.reset_pose()
			actor.character_visual.scale=actor.base_visual_scale
			if killed:
				actor.position=(SCATTERED[index] if enhanced else FALLEN[index])*32.0
				actor.pose_corpse([-1.24,1.60,-1.81][index],index)
			else:
				actor.pose_living()
				actor.position=STANDING[index]*32.0
				if actor.work_activity==null:actor.start_work(index)
		if not killed:
			escape=ESCAPE.new()
			escape.bind(self,owner_art)
		else:
			for bridge: Node3D in bridges: bridge.show()
			owner_art.service_view(world.on_lower_floor,world._feet())
	name="HangarCrewAftermath" if aftermath else "HangarCrewSurvivors"
	sync_visibility()

func activate() -> void:
	_sync_return_branch()
	active = true
	set_process((enhanced and not aftermath) or escape!=null)
	if escape!=null:escape.start()
	if not aftermath or blood_created: return
	var started := Time.get_ticks_usec()
	blood_created = true
	if enhanced and not world.get_meta(&"test_dynamic_hangar_crew_blood",false):
		blood_scenery.show()
		blood_segments = BLOOD_SCENERY.DATA.SEGMENTS
		blood_preparation_ms = (Time.get_ticks_usec()-started)*0.001
		return
	var existing: Array[Node] = world.world_effects_root.get_children()
	var paths: Array = LONG_TRAILS if enhanced else TRAILS
	for i in paths.size():
		var points: Array = paths[i]
		for j in points.size()-1:
			paint_segment(points[j],points[j+1],13.0 if i != 2 else 15.0)
		var pooled: Vector2 = (SCATTERED[i] if enhanced else FALLEN[i])+Vector2(0,-0.18)
		paint_segment(pooled+Vector2(-0.18,0),pooled+Vector2(0.18,0.05),20.0)
		if enhanced:
			paint_segment(pooled+Vector2(-0.30,-0.15),pooled+Vector2(0.32,0.18),24.0)
			paint_segment(pooled+Vector2(-0.18,0.28),pooled+Vector2(0.21,-0.28),23.0)
	var marks: Array[BlackBloodEffect] = []
	for effect: Node in world.world_effects_root.get_children():
		if effect in existing or not effect is BlackBloodEffect: continue
		effect.set_meta(&"hangar_crew_scenery",true)
		# Story stains sit on the grate instead of merging into the lower slab's
		# shared blood plane. Keep the original painter, colours and pooled carrier.
		effect.set_meta(&"blood_merge_registered",true)
		marks.append(effect)
		var reference: Variant = effect.get_meta(&"depth_visual_bridge",null)
		var bridge: Node = reference.get_ref() if reference is WeakRef else null
		if is_instance_valid(bridge):
			bridge.actor_center_height = BLOOD_HEIGHT
			bridge.request_capture_refresh()
			# Mask compaction freezes the carrier immediately. Commit its raised
			# transform first, otherwise its actual quad stays at the old 0.02 m.
			bridge._process(0.0)
	if enhanced: compact_marks(marks)
	blood_preparation_ms = (Time.get_ticks_usec()-started)*0.001

func compact_marks(marks: Array[BlackBloodEffect]) -> void:
	# Consolidate only this scenery with the existing exact-mask merger. Keep
	# it out of ordinary floor buckets, whose plane is below the bay grate.
	var targets: Array[BlackBloodEffect] = []
	var pool: Node3D = world._get_blood_ground_capture_pool()
	for mark in marks:
		var merged := false
		for target in targets:
			if target.absorb_ground_effect(mark,108.0):
				pool.commit_ground_merge(target,mark,world.camera_3d,BLOOD_HEIGHT,112)
				merged = true
				break
		if not merged: targets.append(mark)
	for target in targets:
		var reference: WeakRef = target.get_meta(&"depth_visual_bridge")
		var bridge: Node3D = reference.get_ref()
		if not is_instance_valid(bridge): continue
		# A compact mask can rebase its source, then freeze before another frame.
		# Publish the complete matching flat-floor transform together with it.
		bridge.actor_sprite.global_position = bridge.get_parent_node_3d().to_global(Vector3(
			target.global_position.x/32,BLOOD_HEIGHT,target.global_position.y/32))

func paint_segment(a: Vector2, b: Vector2, width: float) -> void:
	# The shared smear painter accepts bounded short segments; split long
	# sections while retaining its continuous grooves and original blood art.
	var count := maxi(1,ceili(a.distance_to(b)/1.25))
	for i in count:
		if world.spawn_corpse_drag_trail(a.lerp(b,float(i)/count)*32,a.lerp(b,float(i+1)/count)*32,0,1.0,width):
			blood_segments += 1
