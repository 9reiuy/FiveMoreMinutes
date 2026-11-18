extends "res://tests/h06_hangar_crew_entry_test.gd"
const PATTERNS := preload("res://scripts/testing/h06_chapter/crawler_attacks.gd")
const EVACUATION := preload("res://scripts/testing/h06_chapter/evacuation_scene.gd")
const CARGO := preload("res://scripts/testing/h06_chapter/crawler_cargo.gd")
var attack_events: Array[Dictionary] = []
var ride_frames: Array[int] = []
var ride_images: Array[Image] = []
var staff_lines: Array[String] = []
var lift_lines: Array[String] = []
var lift_shots: Array[int] = []
var lift_pose_images: Array[Image] = []
var lift_pose_ticks: Array[int] = []

func record_ride_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	ride_images.append(display.world_viewport.get_texture().get_image())
	ride_frames.append(Engine.get_physics_frames())

func walk_through_passage(destination: int, record_entrance := false) -> float:
	var door: Dictionary = PLAN.PASSAGES[destination-1]
	world._place_feet(door.at-door.forward*1.35)
	world.previous_feet=world._feet()
	if record_entrance: await photograph("00-staff-entrance")
	var longest_step := 0.
	world.player.set_scripted_locomotion(door.forward,3.3*32)
	for i in 150:
		if world.blockout.visit==destination: break
		var before: Vector2 = world._feet()
		await physics_frame
		longest_step = maxf(longest_step,before.distance_to(world._feet()))
	world.player.clear_scripted_locomotion()
	return longest_step

func capture_lift_caption(crew: EVACUATION) -> void:
	if not crew.bubble.visible or crew.bubble.modulate.a<=.74 or crew.speaker in lift_shots: return
	var speaker_index := crew.speaker
	lift_shots.append(speaker_index)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join("lift-bark-%d.png"%speaker_index))

func rehearse_staff_evacuation(staff: EVACUATION, record: bool) -> void:
	var running_lines: Array[bool] = []
	staff.spoke.connect(func(index: int, line: String):
		staff_lines.append(line)
		running_lines.append((staff.actors[index].position/32.).distance_to(EVACUATION.STAFF_ROUTES[index][0])>.15))
	var photographed: Array[int] = []
	var observed_speaker := -1
	var near_entrance := 0
	for path in staff.paths:
		if path.get_point_position(0).distance_to(PLAN.PASSAGES[PLAN.Visit.FREIGHT].at)<6.0:
			near_entrance += 1
	check(near_entrance==1 and PLAN.LOWER.clinic.has_point(staff.paths[1].get_point_position(0))
		and PLAN.LOWER.canteen.has_point(staff.paths[2].get_point_position(0))
		and PLAN.LOWER.duty.has_point(staff.paths[6].get_point_position(0)),
		"the seven evacuees start in different work areas instead of concentrating at the player entrance")
	var paths_clear := true
	var blinking_runners := {}
	for path in staff.paths:
		for i in ceili(path.get_baked_length()/.18):
			var feet := path.sample_baked(i*.18)
			for obstacle: Rect2 in world.blockout.fixture_barriers:
				paths_clear = paths_clear and not obstacle.grow(.14).has_point(feet)
	for i in 550:
		if staff.escaped==staff.actors.size(): break
		await physics_frame
		for index in staff.actors.size():
			var actor := staff.actors[index]
			if actor.visible and not actor.facing_back and actor.enemy_head_frame_index==2:
				var start: Vector2 = EVACUATION.STAFF_ROUTES[index][0]
				if actor.position.distance_to(start*32.)>1.:
					blinking_runners[index] = true
		if record and staff.speaker>=0 and staff.speaker!=observed_speaker:
			observed_speaker = staff.speaker
			# View each local bark with the regular game camera from its work area.
			if observed_speaker>0:
				world._place_feet(staff.actors[observed_speaker].position/32.+Vector2(1.6,2.3))
		if record and staff.bubble.visible and staff.bubble.modulate.a>.74 and staff.speaker not in photographed:
			photographed.append(staff.speaker)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(evidence.path_join("staff-bark-%d.png"%photographed[-1]))
	check(staff_lines==EVACUATION.STAFF_LINES and running_lines.size()==4
		and running_lines.all(func(moving: bool):return moving),"all four requested lines are spoken by different running staff")
	check(paths_clear and staff.escaped==7,"all seven staff safely run around the fixtures to the real north exit")
	check(blinking_runners.size()==7,"all seven runners show an authored closed-eye frame during a glance back")

func rehearse_lift_motion(crew: EVACUATION, record: bool) -> void:
	var closed_heads := {}
	var reopened_heads := {}
	var pose_after_speech: Array[Transform2D] = []
	var movement_after_speech := false
	var blink_after_speech := false
	for tick in 300:
		await physics_frame
		var finished_speaking := crew.next_line==EVACUATION.LIFT_LINES.size() and crew.speaker<0
		var poses: Array[Vector2] = []
		for index in crew.actors.size():
			var actor := crew.actors[index]
			var copies: Array[Node2D] = crew.bridges[index].clone_roots
			var head := copies[0].get_node(^"BodyPivot/Head") as Sprite2D
			if head.texture==actor.enemy_head_frames[2]:
				closed_heads[index] = true
				blink_after_speech = blink_after_speech or finished_speaking
			elif closed_heads.has(index) and head.texture==actor.enemy_head_frames[0]:
				reopened_heads[index] = true
			poses.append(actor.right_hand.position-actor.right_hand_base_position)
		if finished_speaking:
			var current: Array[Transform2D] = []
			for actor in crew.actors: current.append(actor.body_pivot.transform)
			if pose_after_speech.is_empty(): pose_after_speech = current
			else: movement_after_speech = movement_after_speech or current!=pose_after_speech
		if record:
			await capture_lift_caption(crew)
			if tick<102 and tick%3==0:
				await RenderingServer.frame_post_draw
				lift_pose_images.append(display.world_viewport.get_texture().get_image())
				lift_pose_ticks.append(Engine.get_physics_frames())
		if tick==10:
			var unique := {}
			for pose in poses: unique[pose.round()] = true
			check(unique.size()>=6,"the lift actors show distinct readable gestures")
	check(closed_heads.size()==7 and reopened_heads.size()==7,
		"all seven captured lift characters close and reopen their eyes")
	check(blink_after_speech and movement_after_speech and crew.is_processing(),
		"independent blinks and gestures continue after the last subtitle while the lift waits")

func run() -> void:
	create_timer(120,true,false,true).timeout.connect(func():push_error("H06_PATTERN_ENTRY_TIMEOUT");quit(2))
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	await enter(CHAPTER.Save.CROSS_DOCK)
	check(not world.has_meta(&"h06_boss_patterns"),"ordinary chapter entry uses default attack rules without test metadata")
	var record_ride := OS.get_environment("H06_RECORD_ASCENT")=="1"
	if record_ride:DirAccess.make_dir_recursive_absolute(evidence.path_join("ride"))
	world.player.maximum_health=1000
	world.player.current_health=1000
	await walk_through_passage(PLAN.Visit.STAFF)
	var staff: EVACUATION = world.blockout.evacuation
	check(world.blockout.visit==PLAN.Visit.STAFF and is_instance_valid(staff) and staff.actors.size()==7,
		"crossing into the logistics district activates seven evacuees")
	if not is_instance_valid(staff): quit(1); return
	check(staff.actors.all(func(actor: EmployeeEnemy):
		return (not actor.is_in_group(&"dream_enemies") and not actor.is_damage_runtime_active()
			and actor.get("portrait_atlas") in [EVACUATION.ENGINEER,EVACUATION.SCIENTIST_A,EVACUATION.SCIENTIST_B])),
		"the escape cast consists only of passive lab staff and engineers")
	await rehearse_staff_evacuation(staff,record_ride)
	var staff_reference: WeakRef = weakref(staff)
	world._place_feet(Vector2(38,15.3))
	for i in 8: await physics_frame
	var longest_entry_step := await walk_through_passage(PLAN.Visit.ARENA,record_ride)
	check(world.blockout.visit==PLAN.Visit.ARENA and world.blockout.inclined_lift!=null,"walking the real staff passage enters the inclined cargo shaft")
	if world.blockout.inclined_lift==null:quit(1);return
	var evacuees: EVACUATION = world.blockout.evacuation
	check(is_instance_valid(evacuees) and evacuees.actors.size()==7
		and evacuees.actors.all(func(actor: EmployeeEnemy):
			return not actor.dead and (actor.position/32.).distance_to(PLAN.BOSS_MARK)<2.65),
		"the same seven staff designs gather within H06's landing footprint on the deck")
	if not is_instance_valid(evacuees): quit(1); return
	evacuees.spoke.connect(func(_index: int,line: String):lift_lines.append(line))
	var platform = world.blockout.inclined_lift
	world.player.clear_scripted_locomotion()
	var arena_nodes: Array[Node] = world.blockout.physics_root.get_children()
	check(arena_nodes.all(func(node:Node):return not String(node.name).begins_with("pillar_")) and world.blockout.hoist_bridge==null,"the new chamber has no old pillars or overhead crossing")
	check(not world.blockout.gates.has("lift") and world.blockout.floor_root.find_child("LiftLeaf",true,false)==null,"the rear of the shaft has a deck guardrail and no separate elevator door")
	check(world.blockout.floor_root.find_child("UpperMaintenanceLedge",true,false)==null
		and world.blockout.wall_root.find_child("UpperMaintenanceLedge",true,false)==null,"the shaft has no independent H06 platform")
	check(platform.is_docked and platform.distance==0. and not world.blockout.closed.boarding,"the platform starts flush with the lower boarding floor")
	await frames(18)
	check(platform.is_docked and world.stage==CHAPTER.Stage.APPROACH and world.boss==null
		and not world.blockout.mech.visible and is_zero_approx(platform.deck_vertical_offset),"the platform waits motionless for real boarding")
	var bridge: Node3D = platform.lower_landing
	var grate := bridge.get_node("BoardingGrating") as MeshInstance3D
	var grate_bounds := grate.transform*grate.get_aabb()
	var thresholds := bridge.find_children("BridgeThreshold*","MeshInstance3D",false,false)
	check(PLAN.ARENA_BRIDGE.size.y>=16. and is_equal_approx(PLAN.ARENA_BRIDGE.end.y,PLAN.LOWER.arena_link.position.y)
		and is_equal_approx(PLAN.ARENA_BRIDGE.position.y,PLAN.ARENA_DECK.end.y)
		and grate_bounds.size.z>16. and is_zero_approx(grate_bounds.end.y) and thresholds.size()==2
		and bridge.has_node("BoardingTrusses") and not platform.has_node("BoardingForegroundTopBlack"),
		"the grated bridge reaches the staff exit and the deck at the same walking height")
	var gap := PLAN.GATES.boarding as Rect2
	check(is_equal_approx(gap.size.x,PLAN.ARENA_BRIDGE.size.x) and platform.has_node("OpenDeckFrame")
		and platform.has_node("PlatformGuardrails") and not platform.get_node("DockSafetyRail").visible,
		"the docked lift leaves an entrance as wide as the bridge between its permanent rails")
	await photograph("01-boarding-bridge")
	world.player.set_scripted_locomotion(Vector2.UP,3.3*32)
	for i in 415:
		if world._feet().y<PLAN.LIFT_ENTRY.y+4.8: break
		var before: Vector2 = world._feet()
		await physics_frame
		longest_entry_step = maxf(longest_entry_step,before.distance_to(world._feet()))
		if record_ride and i%8==0: await record_ride_frame()
	world.player.clear_scripted_locomotion()
	check(platform.is_docked and PLAN.ARENA_BRIDGE.has_point(world._feet()) and world._feet().y<PLAN.LIFT_ENTRY.y+4.8,
		"the ordinary passage can be walked end to end without starting the lift early")
	await photograph("01a-platform-docked")
	await rehearse_lift_motion(evacuees,record_ride)
	world.player.maximum_health=1000
	world.player.current_health=1000
	world.player.set_scripted_locomotion(Vector2.UP,3.3*32)
	var crossed_dock_edge := false
	for i in 160:
		if not platform.is_docked:break
		var before: Vector2 = world._feet()
		await physics_frame
		longest_entry_step = maxf(longest_entry_step,before.distance_to(world._feet()))
		if not crossed_dock_edge and PLAN.ARENA_DECK.has_point(world._feet()):
			crossed_dock_edge = true
			if record_ride: await photograph("01b-stepping-onto-deck")
		if record_ride:
			await capture_lift_caption(evacuees)
			if i%4==0: await record_ride_frame()
	world.player.clear_scripted_locomotion()
	check(crossed_dock_edge and longest_entry_step<.15,"walking across the region boundary and deck seam never skips the player's feet forward")
	check(platform.travel==platform.Travel.ASCENDING and world.stage==CHAPTER.Stage.APPROACH and world.blockout.closed.boarding
		and PLAN.ARENA_DECK.has_point(world._feet()),"boarding immediately starts ascent and closes the real edge behind the player")
	var foot_on_boarding: Vector2 = world._feet()
	var wall_bay: Node3D = platform.shaft_bays[6]
	var outer_wall := wall_bay.get_node("OuterShaftWallWest") as MeshInstance3D
	var wall_joint := wall_bay.get_node("OuterWallJointCoverWest") as MeshInstance3D
	var west_guide := wall_bay.get_node("CentralInclinedGuideway/WestRail") as Node3D
	var east_guide := wall_bay.get_node("CentralInclinedGuideway/EastRail") as Node3D
	var services := wall_bay.get_node("CentralInclinedGuideway/GuidewayServices") as Node3D
	var wall_finish := outer_wall.get_active_material(1) as ShaderMaterial
	var before := wall_bay.global_position
	var outer_before := outer_wall.global_position
	var joint_before := wall_joint.global_position
	var guide_before := west_guide.global_position
	var services_before := services.global_position
	var bridge_before := bridge.global_position
	var travel_before: float = platform.distance
	var shudder_peaks: Array[Vector2] = [Vector2.ZERO,Vector2.ZERO]
	var shook_before_landing := [false]
	var sample_shudder := func() -> void:
		var heave: float = platform.deck_vertical_offset
		var index := 0
		if world.stage==CHAPTER.Stage.DROP:
			if int(world.get_meta(&"h06_landing_smoke_count",0))==0:
				shook_before_landing[0] = shook_before_landing[0] or not is_zero_approx(heave)
				return
			index = 1
		shudder_peaks[index] = shudder_peaks[index].max(Vector2(-heave,heave))
	physics_frame.connect(sample_shudder)
	for i in 59:
		await physics_frame
		if record_ride: await capture_lift_caption(evacuees)
		if record_ride and i%(2 if i<25 else 7)==0:
			await record_ride_frame()
	check(shudder_peaks[0].x>.09 and shudder_peaks[0].y>.025 and is_zero_approx(platform.deck_vertical_offset),
		"boarding produces a brief elevator shudder and the deck settles back into its ride")
	check(wall_bay.global_position.y<before.y-.40 and wall_bay.global_position.z>before.z+.55
		and world._feet().distance_to(foot_on_boarding)<.03 and world.player.movement_enabled,
		"real wall modules descend along the track while the player remains on the controllable deck")
	var travel_delta: float = platform.distance-travel_before
	var shaft_drift := Vector3(0,-travel_delta*platform.GUIDE_GRADE,travel_delta)
	check((outer_wall.global_position-outer_before).is_equal_approx(shaft_drift)
		and (wall_joint.global_position-joint_before).is_equal_approx(shaft_drift)
		and (west_guide.global_position-guide_before).is_equal_approx(shaft_drift)
		and wall_finish.get_shader_parameter("attached_finish")==true,
		"outer walls, their surfaces, joints and actual guide beams descend together")
	check((bridge.global_position-bridge_before).is_equal_approx(shaft_drift) and platform.get_node("DockSafetyRail").visible,
		"the bridge pulls away along the shaft and the safety rail closes only the opening")
	var conduits := services.get_children().filter(func(node: Node):
		return node is MeshInstance3D and node.mesh is CylinderMesh and node.mesh.height>platform.BAY_LENGTH)
	check((services.global_position-services_before).is_equal_approx(shaft_drift)
		and conduits.size()==9 and services.has_node("CableTray") and services.has_node("CableJunction"),
		"the four service pipes and five electrical strands travel along with the central guideway")
	var walls: Node3D = world.blockout.wall_root
	check(walls.find_children("OuterShaftWall*","MeshInstance3D",true,false).size()==2*platform.shaft_bays.size()
		and walls.get_node_or_null("ContinuousShaftWall")==null and walls.get_node_or_null("RearShaftBulkhead")==null,
		"both outer sides are moving bay walls with no stationary shell or end wall")
	var next_bay: Node3D = platform.shaft_bays[7]
	var next_wall := next_bay.get_node("OuterShaftWallWest") as MeshInstance3D
	var end_z: float = platform.BAY_LENGTH*.5
	var wall_corner := Vector3(0,outer_wall.get_aabb().end.y,end_z)
	var rail_end := Vector3(0,platform.RAIL_HEAD_TOP,Vector2(end_z,end_z*platform.GUIDE_GRADE).length())
	var next_guide := next_bay.get_node("CentralInclinedGuideway/WestRail") as Node3D
	check(outer_wall.to_global(wall_corner).is_equal_approx(next_wall.to_global(wall_corner*Vector3(1,1,-1)))
		and west_guide.to_global(rail_end).is_equal_approx(next_guide.to_global(rail_end*Vector3(1,1,-1))),
		"continuous concrete walls and rail heads join at the same height across bay seams")
	var carriages: Array[Node] = platform.find_children("DeckGuideCarriage*","Node3D",false,false)
	var under_deck := west_guide.global_position.x>PLAN.ARENA_DECK.position.x and east_guide.global_position.x<PLAN.ARENA_DECK.end.x
	check(under_deck and carriages.size()==4 and carriages.all(func(carriage: Node3D):
		var line := west_guide if carriage.global_position.x<PLAN.ARENA_DECK.get_center().x else east_guide
		var track_local := line.to_local(carriage.global_position)
		return Vector2(track_local.x,track_local.y).length()<.01),
		"the two central rails stay inside the four carriages beneath the platform")
	var front_z := PLAN.ARENA_DECK.position.y
	var rail_height: float = platform.RAIL_HEAD_TOP*Vector2(1.,platform.GUIDE_GRADE).length()
	var track_probe_z := front_z-1.6
	var track_probe := Vector3(west_guide.position.x+PLAN.ARENA_DECK.get_center().x,
		platform.guide_axis_height(track_probe_z)+rail_height,track_probe_z)
	var entry_camera: Camera3D = world.camera_3d
	var viewport := entry_camera.get_viewport().get_visible_rect()
	var rim_clear := true
	for bay: Node3D in platform.shaft_bays:
		for side: float in [-1.,1.]:
			var wall := bay.get_node("OuterShaftWallWest" if side<0. else "OuterShaftWallEast") as MeshInstance3D
			var bounds := wall.get_aabb()
			for z: float in [bounds.position.z,bounds.end.z]:
				var top := wall.to_global(Vector3(-side*bounds.size.x*.5,bounds.end.y,z))
				rim_clear = rim_clear and (entry_camera.is_position_behind(top) or entry_camera.unproject_position(top).y<viewport.position.y)
	check(rim_clear and walls.find_children("ShaftCrownJoint*","MeshInstance3D",true,false).is_empty(),
		"both raised concrete faces hide the shaft crown from the gameplay camera")
	var track_screen := entry_camera.unproject_position(world.to_global(track_probe))
	var deck_lip_screen := entry_camera.unproject_position(world.to_global(Vector3(track_probe.x,0.,front_z)))
	check(platform.guide_axis_height(front_z)+rail_height<-.50 and track_screen.y<deck_lip_screen.y-15.
		and entry_camera.get_viewport().get_visible_rect().has_point(track_screen),
		"rails clear the platform underside and appear forward of the deck in the actual camera")
	await photograph("02-platform-on-the-move")
	for i in 240:
		if world.stage==CHAPTER.Stage.DROP:break
		await physics_frame
		if record_ride: await capture_lift_caption(evacuees)
		if record_ride and i%7==0:
			await record_ride_frame()
	var camera: Camera3D = world.camera_3d
	var from := world.to_global(world.drop_origin)
	var view := camera.get_viewport().get_visible_rect()
	check(world.stage==CHAPTER.Stage.DROP and platform.distance>3.
		and world.crawler_motion.jump==world.CRAWLER_MOTION.Jump.FLIGHT
		and (camera.is_position_behind(from) or not view.has_point(camera.unproject_position(from))),
		"H06 enters already airborne from offscreen after actual travel")
	check(not evacuees.crushed and evacuees.actors.all(func(actor: EmployeeEnemy):return not actor.dead),
		"all seven passengers stay alive while H06 is airborne")
	var saw_dust := false
	for i in 330:
		if world.stage==CHAPTER.Stage.BOSS:break
		await physics_frame
		saw_dust = int(world.get_meta(&"h06_landing_smoke_count",0))>0
		if record_ride and i%(2 if saw_dust else 6)==0:
			await record_ride_frame()
		if i==56: await photograph("03-h06-falling")
	physics_frame.disconnect(sample_shudder)
	check(world.stage==CHAPTER.Stage.BOSS and is_instance_valid(world.boss),"normal approaching-elevator ambush still lands as an active boss")
	check(saw_dust and int(world.get_meta(&"h06_landing_smoke_count",0))==1,"ordinary first landing emits its ground-and-feet smoke exactly once")
	check(lift_lines==EVACUATION.LIFT_LINES and evacuees.crushed
		and evacuees.actors.all(func(actor: EmployeeEnemy):return actor.dead)
		and not evacuees.bubble.visible and staff_reference.get_ref()==null,
		"all three lift lines play and one H06 touchdown kills the seven evacuees and dismisses their speech")
	check(not shook_before_landing[0] and shudder_peaks[1].x>shudder_peaks[0].x*1.6 and shudder_peaks[1].y>.07
		and is_zero_approx(platform.deck_vertical_offset) and world._feet().distance_to(foot_on_boarding)<.03,
		"H06 touchdown rocks the deck more strongly than startup and settles before combat, with riders in place")
	check(world.boss.attacks!=null and world.boss.current_health==160,"normal boss starts the live attack director at full health")
	if world.boss.attacks==null:quit(1);return
	check(not world.boss.attacks.fx.shield.is_shield_active(),"ordinary chapter battle has no shield at full health")
	check(platform.speed>1. and world.player.movement_enabled,"the lift still climbs with normal player input after H06 lands")
	await photograph("05-h06-on-platform")
	check(evacuees.bridges.all(func(bridge: Node3D):return bool(bridge.get("static_visual_frozen"))),
		"after the impact animation the seven corpse poses are captured once for the remaining fight")
	world._place_feet(PLAN.LIFT_ENTRY+Vector2(0,-3.))
	await frames(25)
	await photograph("06-fight-presentation")
	world.boss.attacks.event.connect(func(kind:StringName,data:Dictionary):attack_events.append({"kind":kind,"data":data.duplicate(true)}))
	for i in 420:
		if attack_events.filter(func(row:Dictionary):return row.kind==&"missile_launched").size()==6:break
		await frames(1)
	check(attack_events.any(func(row:Dictionary):return row.kind==&"cannon_fired") and attack_events.any(func(row:Dictionary):return row.kind==&"cannon_impact"),"ordinary unpaused boss fires the real recoil cannon and resolves its swept impact")
	var locks := attack_events.filter(func(row:Dictionary):return row.kind==&"lock")
	var launches := attack_events.filter(func(row:Dictionary):return row.kind==&"missile_launched")
	check(locks.size()==6 and launches.size()==6 and launches[0].data.time<locks[1].data.time,"ordinary attack loop ejects the first missile before showing the second lock")
	await photograph("normal-missile-salvo")
	var effects_ref:WeakRef=weakref(world.boss.attacks.fx)
	var cargo: CARGO = world.boss.attacks.cargo
	cargo.random.seed = 59520
	world.boss.take_damage(world.boss.current_health-world.boss.MAX_HEALTH*PATTERNS.SHIELD_HEALTH+.01)
	check(cargo.released and world.boss.attacks.fx.shield.is_shield_active() and not world.boss.attacks.burst_pending,
		"the formal fight schedules its two containers alongside the shield at two-thirds health")
	for i in 450:
		if world.boss.attacks.state!=PATTERNS.State.STUNNED and cargo.drops.all(func(drop:CARGO.Drop):
			return drop.phase in [CARGO.Phase.LANDED,CARGO.Phase.BROKEN]):break
		await physics_frame
	check(attack_events.filter(func(row:Dictionary):return row.kind==&"cargo_warning").size()==2,
		"the ordinary moving platform presents both separate container warnings")
	world.boss.take_damage(world.boss.current_health-(world.boss.MAX_HEALTH*.5-1.))
	for i in 480:
		if world.boss.attacks.burst_used:break
		await physics_frame
	check(world.boss.attacks.burst_used and world.boss.attacks.attack==PATTERNS.Attack.BURST and world.boss.attacks.fx.shield.is_shield_active(),"the separate half-health transition starts the rotating beams with the field already active")
	await photograph("normal-half-health-burst")
	for i in 1000:
		if attack_events.filter(func(row:Dictionary):return row.kind==&"barrage_row_fired").size()>=3:break
		await physics_frame
	var six_sweeps := attack_events.filter(func(row:Dictionary):return row.kind==&"burst_complete")
	check(six_sweeps.size()==1 and is_equal_approx(six_sweeps[0].data.rotation,TAU/6.),"ordinary half-health attack completes the one-time rotating six-beam sweep")
	check(attack_events.filter(func(row:Dictionary):return row.kind==&"barrage_row_fired").size()>=3,"ordinary cycle reaches the three-row barrage and fires all three waves")
	await photograph("normal-barrage")
	var foot_on_deck: Vector2 = world._feet()
	var distance_at_defeat: float = platform.distance
	var completion := [0]
	world.set_meta(&"chapter_one",true)
	world.chapter_completed.connect(func():completion[0]+=1)
	world.boss.take_damage(10000)
	await frames(5)
	check(world.stage==CHAPTER.Stage.EXIT and effects_ref.get_ref()==null and world.boss.attacks.rockets.is_empty()
		and platform.travel==platform.Travel.ARRIVING,"defeating H06 clears the missiles and begins the upper approach")
	await frames(75)
	check(platform.distance>distance_at_defeat+1. and platform.speed>0.
		and world.stage==CHAPTER.Stage.EXIT,"the platform keeps climbing until the automatic upper stop")
	check(world._feet().distance_to(foot_on_deck)<.07 and is_zero_approx(world._floor_height_at(world._feet())),
		"the player's ground alignment is preserved throughout travel")
	await photograph("07-platform-ascending")
	for i in 350:
		if completion[0]>0:break
		await physics_frame
	check(world.stage==CHAPTER.Stage.DONE and platform.travel==platform.Travel.UPPER and is_zero_approx(platform.speed)
		and completion[0]==1,"arriving uphill completes the chapter exactly once without a rear doorway")
	await photograph("08-platform-upper-arrival")
	var old_body:WeakRef=weakref(world.crawler_motion)
	var old_platform:WeakRef=weakref(platform)
	var old_evacuees:WeakRef=weakref(evacuees)
	await enter(CHAPTER.Save.ENTRANCE)
	check(old_body.get_ref()==null and world.boss==null and world.get_meta(&"h06_landing_smoke_count",0)==0,"new chapter clears old missiles, smoke counters and boss references")
	check(old_platform.get_ref()==null,"restarting releases the old deck, gate and ride state")
	check(old_evacuees.get_ref()==null,"restarting releases the seven bodies and their dialogue")
	check(world.blockout.hangar_crew.actors.size()==3 and world.blockout.wall_root.has_node("GalleryTopBlack"),"new chapter retains the living crew, original gallery and topblack")
	current_scene.queue_free()
	await frames(8)
	for i in ride_images.size():
		ride_images[i].save_png(evidence.path_join("ride/%03d.png"%i))
	if record_ride:
		var folder := evidence.path_join("lift-gestures")
		DirAccess.make_dir_recursive_absolute(folder)
		for i in lift_pose_images.size():
			lift_pose_images[i].save_png(folder.path_join("%03d.png"%i))
		FileAccess.open(folder.path_join("ticks.json"),FileAccess.WRITE).store_string(JSON.stringify(lift_pose_ticks))
	var failures:=checks.filter(func(row:Dictionary):return not row.pass)
	var ride := {"frame_ticks":ride_frames,"startup_drop":shudder_peaks[0].x,"startup_rebound":shudder_peaks[0].y,
		"landing_drop":shudder_peaks[1].x,"landing_rebound":shudder_peaks[1].y}
	FileAccess.open(evidence.path_join("entry-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"events":attack_events,"ride":ride,"staff_lines":staff_lines,"lift_lines":lift_lines,"muted":AudioServer.is_bus_mute(0),"renderer":RenderingServer.get_current_rendering_method(),"audio":AudioServer.get_driver_name()},"\t"))
	print("H06_PATTERN_ENTRY checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
