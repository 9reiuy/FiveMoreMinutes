extends "res://tests/h06_hangar_crew_test.gd"
const OUT:="res://.runtime/h06_scientist_choice_20261117"
const ESCAPE:=preload("res://scripts/testing/h06_chapter/hangar_crew_escape.gd")
var timings:Array[Dictionary]=[]
var blocked_paths:Array[Dictionary]=[]
var greatest_step:=0.0
var previous_positions:Dictionary={}
var fast_steps:Array[Dictionary]=[]

func _initialize()->void:call_deferred("run")

func step(count:int,label:="")->void:
	var stamp:=Time.get_ticks_usec()
	for frame in count:
		await physics_frame
		await process_frame
		var now:=Time.get_ticks_usec()
		if not label.is_empty():timings.append({"stage":label,"frame":frame,"wall_ms":(now-stamp)/1000.0})
		stamp=now

func until(condition:Callable,label:="",limit:=300)->bool:
	for frame in limit:
		if condition.call():return true
		await step(1,label)
	return bool(condition.call())

func shot(label:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func inspect_room()->void:
	world.set_process(false)
	var focus:Vector3=world.to_global(Vector3(-1.6,3.65,-20.6))
	world.camera_3d.global_position=focus+Vector3(4.2,5.8,8.0)
	world.camera_3d.look_at(focus,Vector3.UP)
	var pointer:=InputEventMouseMotion.new()
	pointer.position=Vector2(80,285)
	root.push_input(pointer,true)

func inspect_hangar()->void:
	world.set_process(false)
	var focus:Vector3=world.to_global(Vector3(2.2,.5,3.3))
	world.camera_3d.global_position=focus+Vector3(16,23,19)
	world.camera_3d.look_at(focus,Vector3.UP)

func dispose()->void:
	world.set_physics_process(false)
	display.queue_free()
	await frames(6)

func fire_at(target:EmployeeEnemy)->bool:
	var before:float=target.current_health
	var shooter=world.player
	var pointer:=InputEventMouseMotion.new()
	pointer.position=display.content_rect.get_center()
	root.push_input(pointer,true)
	if not InputMap.has_action("attack"):InputMap.add_action("attack")
	shooter.set_meta(&"aim_direction_override",shooter.get_projectile_origin().direction_to(target.global_position))
	await step(3)
	Input.action_press("attack")
	for frame in 90:
		shooter.set_meta(&"aim_direction_override",shooter.get_projectile_origin().direction_to(target.global_position))
		await physics_frame
		if target.dead or target.current_health<before:break
	Input.action_release("attack")
	shooter.remove_meta(&"aim_direction_override")
	return target.dead or target.current_health<before

func observe_escape(crew:Node3D,count:int)->void:
	var circle:=CircleShape2D.new()
	circle.radius=5.5
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=circle
	query.collision_mask=world.blockout.ACTOR_EDGE
	query.collide_with_areas=false
	var space:PhysicsDirectSpaceState2D=world.player.get_world_2d().direct_space_state
	var stamp:=Time.get_ticks_usec()
	var previous_age:float=crew.escape.age
	var roof_stayed_closed := true
	var actors_hidden_on_entry := true
	for frame in count:
		await physics_frame
		await process_frame
		var now:=Time.get_ticks_usec()
		timings.append({"stage":"three_survivors_escape","frame":frame,"wall_ms":(now-stamp)/1000.0})
		stamp=now
		var speed:float=world.config.employee_movement_speed*world.config.employee_run_speed_multiplier
		var movement_budget:float=speed*maxf(0,crew.escape.age-previous_age)+.2
		previous_age=crew.escape.age
		roof_stayed_closed = roof_stayed_closed and world.blockout.secret_roof.visible and not world.blockout.secret_visible
		for index in crew.actors.size():
			var actor:EmployeeEnemy=crew.actors[index]
			var at:=actor.global_position
			if previous_positions.has(actor.get_instance_id()):
				var distance:float=at.distance_to(previous_positions[actor.get_instance_id()])
				greatest_step=maxf(greatest_step,distance)
				if distance>movement_budget:fast_steps.append({"frame":frame,"distance":distance,"budget":movement_budget})
			previous_positions[actor.get_instance_id()]=at
			query.transform=Transform2D(0,at)
			var hits:Array=space.intersect_shape(query,4)
			var floor_ok:bool=world.floor_cells.has(Vector2i((at/32.0).round()))
			var behind_roof := PLAN.behind_service_roof(at/world.CELL_PIXELS)
			actors_hidden_on_entry = actors_hidden_on_entry and (crew.bridges[index].visible != behind_roof)
			if (not floor_ok or not hits.is_empty()) and blocked_paths.size()<60:
				blocked_paths.append({"actor":index,"at":str(at/32.0),"floor":floor_ok,"colliders":hits.map(func(hit:Dictionary):return str(hit.collider.name))})
		if frame in [45,140]:
			await shot("survivors-running-%03d"%frame)
			# GPU image readback/file writing is evidence collection, not a game frame sample.
			stamp=Time.get_ticks_usec()
	check(roof_stayed_closed,"the roof stays covered during the full three-person escape")
	check(actors_hidden_on_entry,"each runner becomes concealed as they reach the covered passage")

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):quit(2);return
	create_timer(180,true,false,true).timeout.connect(func():quit(3))
	var stamp:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf((now-stamp[0])/1000000.0,0.0,.05))
		stamp[0]=now)
	root.size=Vector2i(1280,720)
	evidence=OS.get_environment("H06_BOUNDARY_EVIDENCE")
	if evidence.is_empty():evidence=ProjectSettings.globalize_path(OUT)
	test_staff_story={}
	await enter(CHAPTER.Save.ENTRANCE,true)
	var event=world.blockout.monitoring_scientist
	check(is_instance_valid(event.actor) and not event.started and event.actor.facing_back,"the living scientist initially sits facing the monitors before room entry")
	check(event.actor.held_weapon_id.is_empty() and not event.actor.hostile and not world.members.has(event.actor),"the scientist has no weapon or hostile AI and is outside warehouse wave membership")
	var future=world._plan_region(PLAN.Visit.EMPTY_HANGAR)
	while not future.build_steps.is_empty():future.prepare_step()
	world.chapter_staged_regions[PLAN.Visit.EMPTY_HANGAR]=future
	var future_ids:Array=future.hangar_crew.actors.map(func(actor:EmployeeEnemy):return actor.get_instance_id())
	check(not future.hangar_crew.aftermath,"the future return room can be prepared before the scientist's fate is known")
	inspect_room()
	await shot("00-scientist-at-monitors")
	world._place_feet(Vector2(-5.8,-12.0))
	await until(func():return event.elapsed>=.30,"chair_turn")
	check(event.started and event.chair.rotation.y>event.chair_start and event.chair.rotation.y<event.chair_start+PI,"entering the monitoring room starts a visible chair turn")
	await shot("01-chair-turn")
	await until(func():return event.current_line==0,"first_speech")
	await until(func():return event.elapsed>=1.55,"first_speech")
	check(event.current_line==0 and event.bubble.visible and event.bubble._current_text=="卷帘门我已经打开了","the first speech bubble uses the requested line")
	check(world.staff_story.monitoring_shutter_open and world.blockout.threshold_open>.99,"the monitoring-room roller shutter is physically open when the scientist says it is open")
	check(event.actor.turned and is_equal_approx(event.chair.rotation.y,event.chair_start+PI),"the seated scientist and chair finish turning toward the room")
	var hips:Vector3=(event.bridge.get_attached_part_world_position(event.actor.left_leg)+event.bridge.get_attached_part_world_position(event.actor.right_leg))*.5
	check(absf(hips.y-event.seat_height)<.01,"the seated hip joints rest at the actual chair-seat height")
	check(world.player.movement_enabled and world.player.attacking_enabled and not paused,"the speech preserves movement and shooting controls")
	await shot("02-first-speech")
	await until(func():return event.current_line==1,"second_speech")
	await until(func():return event.elapsed>=4.30,"second_speech")
	check(event.current_line==1 and event.bubble.visible and event.bubble._current_text=="不要开枪!","the second speech bubble warns not to shoot")
	await shot("03-dont-shoot")
	var before:float=event.actor.current_health
	world.resolve_player_hit(event.actor,1.0,world.player.global_position)
	await step(2)
	check(event.actor.current_health<before and not event.actor.dead and not world.staff_story.scientist_killed and not event.actor.hostile,"a nonlethal hit hurts the scientist without selecting the death branch or enabling hostile AI")
	world._place_feet(Vector2(-1.44,-17.5))
	event.actor.current_health=1.0
	check(await fire_at(event.actor),"a real player gunshot can hit the seated scientist through the ordinary projectile path")
	await step(8)
	check(event.actor.dead and world.staff_story.scientist_killed and not event.bubble.visible,"killing the scientist records the choice and immediately removes her speech bubble")
	future.hangar_crew.activate()
	check(future.hangar_crew.aftermath and future.hangar_crew.actors.all(func(actor:EmployeeEnemy):return actor.dead) and future.hangar_crew.actors.map(func(actor:EmployeeEnemy):return actor.get_instance_id())==future_ids,"a room prepared before the killing selects the dead branch on activation while reusing its three actors")
	await shot("04-scientist-killed")
	world.set_meta(&"story_retry_handler",func()->void:pass)
	world.player.dead=true
	check(world.restart_current_floor_after_death(),"the ordinary death retry accepts the current story state")
	var retry:Dictionary=get_meta(CHAPTER.RETRY_KEY,{})
	check(retry.get("staff_story",{}).get("scientist_killed",false),"the real retry payload preserves the scientist's death")
	remove_meta(CHAPTER.RETRY_KEY)
	test_staff_story=retry.staff_story
	var speech:WeakRef=weakref(event.bubble_layer)
	await dispose()
	check(speech.get_ref()==null,"leaving the room frees its root speech layer")
	await enter(CHAPTER.Save.OBSERVATION,true)
	check(world.staff_story.scientist_killed and not is_instance_valid(world.blockout.monitoring_scientist.actor),"retry does not resurrect the killed monitoring scientist")
	await dispose()
	await enter(CHAPTER.Save.RETURN_BAY,true)
	var crew:Node3D=world.blockout.hangar_crew
	check(crew.aftermath and crew.escape==null and crew.actors.all(func(actor:EmployeeEnemy):return actor.dead),"the killed-scientist branch preserves all three original dead workers")
	check(crew.blood_created and crew.blood_segments>0 and is_instance_valid(crew.blood_scenery),"the killed branch retains the existing corpse and orange-blood aftermath")
	inspect_hangar()
	await shot("05-killed-branch-three-corpses")
	world.staff_story.scientist_killed=false
	crew.activate()
	check(not crew.aftermath and crew.escape!=null and crew.actors.all(func(actor:EmployeeEnemy):return not actor.dead and not actor.corpse_upper_parts_active),"a previously prepared dead pose can restore a complete living rig without duplicating actors")
	await dispose()
	test_staff_story={"scientist_killed":false,"introduction_seen":true,"monitoring_shutter_open":true}
	await enter(CHAPTER.Save.RETURN_BAY,true)
	crew=world.blockout.hangar_crew
	check(not crew.aftermath and crew.escape!=null and crew.actors.all(func(actor:EmployeeEnemy):return not actor.dead),"sparing the scientist returns three living workers instead of corpses")
	check(not crew.blood_created and (not is_instance_valid(crew.blood_scenery) or not crew.blood_scenery.visible),"the living branch shows no corpse-blood scenery")
	check(world.discovered and world.blockout._hatch_open and not world.blockout.secret_visible and world.blockout.secret_roof.visible,
		"the entrance opens for the survivors while the room stays covered from the hangar")
	inspect_hangar()
	await observe_escape(crew,390)
	check(crew.escape.finished and world.staff_story.crew_escaped,"all three survivors physically finish the run into the hidden room")
	check(not world.blockout.under_cover,"the upstairs cutaway returns to normal once everyone clears the hatch")
	check(not world.blockout.secret_visible and world.blockout.secret_roof.is_visible_in_tree(),"the roof stays closed from the hangar as the three survivors finish")
	check(crew.bridges.all(func(bridge:Node3D)->bool:return not bridge.is_visible_in_tree()),"concealed survivors do not cut holes through the roof")
	check(blocked_paths.is_empty(),"the escape routes stay on authored floor and clear real active wall/furniture colliders")
	check(fast_steps.is_empty(),"survivors move within the configured run-speed budget without teleporting along the route")
	for index in 3:
		check(crew.actors[index].position.distance_to(ESCAPE.DESTINATIONS[index]*32.0)<.2 and not crew.actors[index].dead,"survivor %d remains alive at a separate position inside the hidden room"%index)
	world.set_process(true)
	world._place_feet(Vector2(16.7,2.2))
	await step(24)
	check(world.blockout.secret_visible and not world.blockout.secret_roof.visible and crew.bridges.all(func(bridge:Node3D)->bool:return bridge.is_visible_in_tree()),"walking into the hidden room exposes its interior and the three survivors")
	await shot("06-survivors-in-hidden-room")
	world._place_feet(Vector2(6.0,1.5))
	await step(5)
	check(world.blockout.under_cover and world.blockout.secret_roof.visible and not world.blockout.secret_visible,"returning beneath the stairs conceals the room again")
	var saved:Dictionary=world.staff_story.snapshot()
	var departed:WeakRef=weakref(crew.actors[0])
	await dispose()
	check(departed.get_ref()==null,"leaving the returned hangar releases its survivor actors")
	test_staff_story=saved
	await enter(CHAPTER.Save.RETURN_BAY,true)
	crew=world.blockout.hangar_crew
	check(crew.escape.finished and crew.actors.all(func(actor:EmployeeEnemy):return not actor.dead),"retry after escape keeps the three survivors alive inside the hidden room")
	check(world.blockout.secret_roof.visible and not world.blockout.secret_visible and crew.bridges.all(func(bridge:Node3D)->bool:return not bridge.is_visible_in_tree()),"retry starts with the escaped crew behind the restored roof")
	await dispose()
	var failures:Array=checks.filter(func(row:Dictionary):return not row.pass)
	FileAccess.open(evidence.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pid":OS.get_process_id(),"timings":timings,"blocked_paths":blocked_paths,"fast_steps":fast_steps,"maximum_survivor_step_pixels":greatest_step,"scope":"actual authored rooms and Camera, real player gunshot, both story branches, physical route sampling, dialogue controls, retry and cleanup; capture file IO excluded from frame timings; limited native sample, not whole-game performance certification"},"\t"))
	print("SCIENTIST_CHOICE checks=",checks.size()," failures=",failures.size()," pid=",OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
