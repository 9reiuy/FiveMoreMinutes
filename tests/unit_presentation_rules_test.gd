extends SceneTree
var checks:=0
var failures:=0
var world: Node
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	create_timer(90,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.spawn_content=false; world.enable_game_start_cab_exit=false
	root.add_child(world); check(world.regenerate(42001),"Real floor generates")
	world.player.set_physics_process(false)
	var origin:=Vector2(12000,12000)
	for y in range(368,390):
		for x in range(368,390): world.floor_cells[Vector2i(x,y)]=true
	world.player.global_position=origin+Vector2(110,0)
	var unit: Node=load("res://scripts/entities/hotel_robot_unit.gd").new()
	world.enemy_root.add_child(unit); unit.global_position=origin; unit.configure(world,world.player,Rect2(origin-Vector2(100,100),Vector2(300,300)))
	unit.set_physics_process(false); unit.deploy=1.0; unit.alert=true; unit._fire_timer=0
	var cues: Array=[]
	root.get_node("SFXManager").sfx_played.connect(func(event: StringName) -> void:
		if event==&"enemy_fire_cue": cues.append(event))
	unit._engage(.1,110)
	check(unit.get_ranged_telegraph_state().progress>0.0,"Robot publishes pale initial red-line state")
	check(not world.floor_root.get_node("EnemyAimTelegraph").aim_segment(unit).is_empty(),"Robot is accepted by shared red-line presenter")
	unit._engage(.4,110)
	check(cues.size()==1 and unit._magazine_primed,"First robot shot announces completed windup once")
	unit._fire(Vector2.RIGHT); check(cues.size()==1,"Robot automatic followup has no extra ding")
	unit._magazine_left=1; unit._fire(Vector2.RIGHT)
	check(cues.size()==1 and not unit._magazine_primed,"Last round does not accidentally announce reload reset")
	unit._reload_left=0; unit.deploy=1; unit._fire_timer=0; unit._engage(.5,110)
	check(cues.size()==2,"New robot magazine earns one new cue")
	# Flower pot changes traversal only, never its ballistic height.
	var plant: Node=load("res://scenes/dream/props/desk.tscn").instantiate()
	var catalog:=load("res://scripts/dream/office_furniture_catalog.gd")
	catalog.configure(plant,"plant"); plant.freeze=true; world.furniture_root.add_child(plant)
	check(plant.vaultable and catalog.allows_auto_vault(plant),"Potted plant explicitly supports automatic vault")
	check(not catalog.allows_projectile_pass_through(plant) and is_equal_approx(catalog.size_of("plant").y,1.3),"Plant retains original model and ballistic height")
	world.player.global_position=origin-Vector2(160,0)
	var shape: CollisionShape2D=plant.get_node("CollisionShape2D")
	plant.global_position=world.player.body_collision.global_position+Vector2(world.player.body_collision.shape.radius+shape.shape.get_rect().size.x*.5+2,0)
	await physics_frame; await physics_frame
	root.get_node("SettingsManager").set_setting(&"auto_vault_enabled",false)
	check(not world.player.try_auto_vault(Vector2.RIGHT),"Disabled assistance does not vault plant")
	root.get_node("SettingsManager").set_setting(&"auto_vault_enabled",true)
	check(world.player.try_auto_vault(Vector2.RIGHT),"Close directional movement vaults plant")
	world.player._cancel_vault()
	# Actual model is handed to the floor-owned death animation, no replacement mesh.
	var visuals: Node=world._hotel_robot_visual_container()
	world._spawn_hotel_robot(world.current_room_id,origin,visuals)
	var visual: Node=visuals.get_child(0)
	var victim: Node=visual.unit
	victim.set_physics_process(false)
	var original_model: Node=visual._model
	check(is_equal_approx(original_model.scale.x,1.6),"Robot model is exactly two thirds of previous scale")
	check(is_equal_approx(victim.get_node("HitShape").shape.radius,10.0) and is_equal_approx(victim.get_hurt_radius(),20.0),"Robot movement and melee hit radii shrink with model")
	check(visual.find_children("*HealthBar*","",true,false).is_empty() and victim.health_bar_3d==null,"Robot has no health bar node")
	victim.take_damage(1,origin)
	check(visual.hit_flash.left>0 and original_model.get_node("Body").material_override==visual.hit_flash.white,"Robot damage flashes actual mesh white")
	visual.hit_flash._process(.2)
	check(original_model.get_node("Body").material_override!=visual.hit_flash.white,"Robot hit flash restores original texture")
	check(visual.outline.records.size()>0,"Whole-model silhouette capture exists")
	var saved_outline: Node=visual.outline
	visual.reparent(world)
	visual.reparent(visuals)
	check(RenderingServer.frame_pre_draw.is_connected(saved_outline.sync),"Outline resubscribes after stash-style reparenting")
	visual.outline.set_target_highlight_state(1); check(visual.outline.aimed,"Aim highlight selects white silhouette")
	visual.outline.set_target_highlight_state(0); visual.outline.set_combat_range_highlight(true)
	check(visual.outline.melee,"Melee range selects white silhouette independently")
	visual.flash_muzzle(-1.0); visual._sync_pose()
	check(visual.recoil[-1.0]>.05 and visual.recoil[1.0]==0.0,"Only firing robot barrel recoils")
	victim.defeat_by_parry(origin)
	var effect: Node
	for child in visuals.get_children():
		if child.get_meta(&"unit_death_effect",false): effect=child
	check(is_instance_valid(effect) and effect.model==original_model,"Robot death animates original 3D model")
	await frames(2)
	check(victim.collision_layer==0 and victim.hurtbox.collision_layer==0,"Death immediately releases gameplay collision")
	var health: float=world.player.current_health
	effect.set_process(false); effect._process(.43)
	check(effect.burst_started and is_instance_valid(effect.elemental),"Landing starts shared outlined particle explosion")
	check(effect.elemental.effects.outline_banks.size()==3,"Death uses merged particle contours")
	check(effect.find_children("*","CollisionObject3D",true,false).is_empty() and effect.find_children("*","CollisionObject2D",true,false).is_empty(),"Explosion creates no damage or collision bodies")
	effect._process(.8)
	effect.elemental.effects.step(.2)
	check(effect.elemental.effects.particles.any(func(p: Dictionary)->bool:return int(p.kind)==1 and Vector3(p.at).y>0.2),"Shared explosion contains rising smoke")
	check(world.player.current_health==health,"Visual explosion does not damage nearby player")
	effect._process(1.9); await frames(2)
	check(not is_instance_valid(effect),"Death effect retires itself after smoke")
	# Real flying unit: proxy forwarding, one warning per magazine and manual-fire recovery.
	world._spawn_exterior_drones()
	check(world._exterior_drone_root.get_child_count()>0,"Real window patrol is available for presentation regression")
	if world._exterior_drone_root.get_child_count()>0:
		var drone: Node=world._exterior_drone_root.get_child(0)
		drone.set_physics_process(false)
		check(is_equal_approx(drone._body.scale.x,1.3*2.0/3.0) and is_equal_approx(drone._proxy.get_hurt_radius(),12.0),"Drone model and hurtbox both shrink to two thirds")
		check(drone.health_bar()==null and drone.find_children("*HealthBar*","",true,false).is_empty(),"Drone has no health bar node")
		drone.take_damage(1,origin)
		check(drone.hit_flash.left>0 and drone._body.get_node("Body").material_override==drone.hit_flash.white,"Drone damage flashes actual mesh white")
		drone.hit_flash._process(.2)
		check(drone._body.get_node("Body").material_override!=drone.hit_flash.white,"Drone hit flash restores original texture")
		var drone_local: Vector3=world.to_local(drone.global_position)
		world.player.global_position=Vector2(drone_local.x,drone_local.z)*32+drone.inward_normal*90+drone.inward_normal.orthogonal()*70
		drone._spot_elapsed=.1; drone._aim_target=world.player.global_position
		drone._apply_facing()
		var toward: Vector3=world.get_gameplay_world_position(world.player.global_position,0)-drone.global_position; toward.y=0
		check((-drone.global_basis.z).dot(toward.normalized())>.999,"Locked drone head faces target instead of facade normal")
		check(drone._spot_light is SpotLight3D and is_equal_approx(drone._spot_light.spot_angle,20),"Drone uses a narrow directional spotlight")
		var beam: Vector3=world.get_gameplay_world_position(world.player.global_position,.35)-drone._spot_light.global_position
		check((-drone._spot_light.global_basis.z).normalized().dot(beam.normalized())>.999,"Spotlight actually points toward target height")
		drone._spot_elapsed=.42; world.player.global_position+=Vector2(80,80)
		drone._apply_facing()
		check((-drone.global_basis.z).dot(toward.normalized())>.999,"Final short aim lock does not track new target position")
		check(drone._rig._make_puff_texture()==preload("res://scripts/dream/nyangeon_vfx_shapes.gd").smoke_texture(),"Drone muzzle shares running and death smoke texture")
		world.player.global_position=drone._proxy.global_position+Vector2(4,0)
		drone._spot_elapsed=.25; drone._aim_target=world.player.global_position
		check(is_equal_approx(drone._proxy.get_ranged_telegraph_state().progress,.5),"Drone forwards half-windup through its gameplay proxy")
		check(not world.floor_root.get_node("EnemyAimTelegraph").aim_segment(drone._proxy).is_empty(),"Shared red-line presenter accepts drone proxy")
		var count_before:=cues.size()
		drone._magazine_primed=false; drone._magazine_left=3; drone._reload_left=0
		drone._fire(); drone._spot_elapsed=-1; drone._fire(); drone._fire()
		check(cues.size()==count_before+1,"Drone magazine has one warning cue, not one per followup")
		check(drone._rig.flash_time<.01 and drone.body_recoil>0,"Drone actual fire begins muzzle flash and body kick")
		drone._rig.set_process(false); drone._rig._process(.3); drone._process(.3)
		check(drone._rig.flash_time>=.3 and drone.body_recoil==0,"Manual drone fire animation expires and body recovers")
		var drone_model: Node=drone._body
		var drone_parent: Node=drone.get_parent()
		drone.defeat_by_parry(origin)
		var aerial: Node
		for child in drone_parent.get_children():
			if child.get_meta(&"unit_death_effect",false): aerial=child
		check(is_instance_valid(aerial) and aerial.model==drone_model and aerial.flying,"Drone original model transfers to airborne death effect")
		aerial.set_process(false)
		var start_height: float=aerial.model.position.y
		aerial._process(.3)
		check(aerial.model.position.y<start_height and not aerial.burst_started,"Drone visibly falls and rotates before exploding")
		aerial._process(.36)
		check(aerial.burst_started and is_instance_valid(aerial.elemental),"Drone landing produces shared particle explosion and smoke")
		await frames(2)
		check(not is_instance_valid(drone._proxy),"Dead drone immediately retires its gameplay hitbox")
		var old_floor: int=world.floor_index
		world.floor_transition_in_progress=true
		world._stash_current_floor_for_rollback()
		await frames(2)
		check(is_instance_valid(aerial) and not aerial.can_process(),"Pending death effect suspends with stashed floor")
		world._reset_layout_data()
		world._rollback_failed_transition(world.transition_generation_token,old_floor)
		await frames(2)
		check(is_instance_valid(aerial) and aerial.can_process(),"Failed transition restores the same death effect without duplication")
		world.floor_transition_in_progress=false
		check(world.regenerate(42002),"Next floor generates with pending old death effect")
		await frames(2)
		check(not is_instance_valid(aerial),"Successful floor replacement removes old smoke and explosion")
	world.free(); await frames(2)
	print("UNIT_PRESENTATION checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
