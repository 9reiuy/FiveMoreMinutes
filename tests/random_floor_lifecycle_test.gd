extends SceneTree

const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const WEAPON = preload("res://scenes/dream/world_weapon_pickup.tscn")
var world: Node3D
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", label)

func frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func seed_transients() -> Array:
	var pickup: Node2D = WEAPON.instantiate()
	world.world_weapon_root.add_child(pickup)
	pickup.global_position = world.player.global_position
	world._spawn_depth_bridge(pickup, [NodePath("Shadow"),NodePath("WeaponSprite")])
	var debris: Node2D=world.ENVIRONMENT_DEBRIS_SCENE.instantiate()
	world.ground_debris_root.add_child(debris)
	debris.global_position=world.player.global_position+Vector2(40,0)
	debris.monitoring=false
	world._spawn_depth_bridge(debris,[^"Sprite2D"],Vector2(64,64),BaseMaterial3D.BILLBOARD_DISABLED,0.02,0.0,Vector3(-PI/2,0,0),true)
	world.spawn_blood_trail(world.player.global_position, world.spawn_room_id)
	var blood: Node2D=world.world_effects_root.get_children().back()
	blood.set_process(false)
	world.spawn_corpse_blood_emitter(world.player.global_position, world.spawn_room_id, Vector2.RIGHT)
	var bullet: Node2D = preload("res://scenes/entities/basic_projectile.tscn").instantiate()
	bullet.add_to_group(&"dream_projectiles")
	bullet.position = world.player.global_position
	bullet.setup(Vector2.RIGHT, 1.0)
	world.add_projectile(bullet, world.player)
	bullet.set_process(false)
	bullet.set_physics_process(false)
	world.spawn_weapon_muzzle(world.player.get_projectile_origin(),Vector2.RIGHT,&"pistol",world.player)
	var muzzle: Node2D = world.world_effects_root.get_children().back()
	muzzle.set_process(false)
	world.spawn_shell_ejection(world.player.global_position,Vector2.RIGHT,&"assault_rifle")
	var shell: Node2D=world.world_effects_root.get_children().back()
	shell.set_process(false)
	world.spawn_combat_feedback(world.player.global_position,Vector2.RIGHT)
	var feedback: Node2D=world.world_effects_root.get_children().back()
	feedback.set_process(false)
	return [pickup, bullet, muzzle, shell, feedback, blood,debris]

func run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	root.add_child(world)
	await frames(2)
	check(world.regenerate(41001), "initial floor")
	for floor_number in 3:
		var old_nodes := seed_transients()
		var old_atlas: Node=world._get_shell_capture_pool().atlas
		await frames(2)
		var token: int = world.get_current_floor_token()
		world.find_floor_path(world.spawn_cell,world.spawn_cell)
		check(not world._floor_path_goal_searches.is_empty(),"old floor owns a populated goal frontier")
		world.floor_transition_in_progress = true
		world.transition_phase = &"CAB_RIDE"
		check(await world._regenerate_staged(41002 + floor_number, floor_number + 1, world.transition_generation_token), "staged floor %d" % floor_number)
		check(world._floor_path_cache_enabled,"staged floor enables navigation graph before control")
		var objects: Node3D=world._get_floor_object_capture_pool()
		check(objects.idle[&"debris"].size()==64 and objects.idle[&"weapon"].size()==8 and objects.idle[&"shadow"].size()==8,"staged floor prewarms object captures")
		check(world._floor_path_goal_searches.is_empty(),"staged floor cannot retain old goal frontier")
		check(world._current_floor_path_adjacency().keys()==world.floor_cells.keys(),"staged navigation contains only current floor")
		check(world._get_projectile_capture_pool().idle.size()==32, "staged floor prewarms before control resumes")
		check(world._get_muzzle_capture_pool().idle.size()==12, "staged floor prewarms muzzle captures")
		check(world._get_shell_capture_pool().idle.size()==32, "staged floor prewarms shell captures")
		check(world._get_feedback_capture_pool().idle.size()==18, "staged floor prewarms feedback captures")
		check(world._get_blood_ground_capture_pool().small_idle.size()==18,"staged floor prewarms small blood captures")
		check(world._get_blood_ground_capture_pool().large_idle.size()==6,"staged floor prewarms large blood captures")
		await frames(2)
		for node in old_nodes:
			check(not is_instance_valid(node), "old transient freed")
		check(not is_instance_valid(old_atlas), "old atlas freed with floor")
		check(world._get_shell_capture_pool().atlas.pages.size()==1,"new floor has one prewarmed shell atlas page")
		check(world._get_shell_capture_pool().atlas.slots.size()==32,"new atlas has no old cells")
		check(world.world_weapon_root.get_child_count() == 0, "no old weapon")
		check(get_nodes_in_group(&"black_blood_stains").is_empty(), "no old blood")
		check(get_nodes_in_group(&"corpse_blood_emitters").is_empty(), "no old emitters")
		var before: int = world.world_weapon_root.get_child_count()
		world._spawn_room_drop(world.spawn_room_id, {"weapon_id": "pistol", "position": world.player.global_position}, token)
		check(world.world_weapon_root.get_child_count() == before, "old delayed drop rejected")
		world.floor_transition_in_progress = false
		world.transition_phase = &"IDLE"
		world.player.global_position = world.get_player_root_position_for_cell(world.spawn_cell)
	# Force failed generation after real transient creation; restore exact objects.
	var rollback_nodes := seed_transients()
	var old_cells: Dictionary = world.floor_cells.duplicate(true)
	var old_source: Dictionary = world.skeleton_source.duplicate(true)
	var old_panes: Dictionary = world.glass_runs.duplicate(true)
	var old_plans: Dictionary = world.skeleton_plans.duplicate(true)
	var old_door: Node = world.elevator_floor_door
	var old_index: int = world.floor_index
	var old_room: int = world.current_room_id
	world.set_process(false)
	world.set_physics_process(false)
	world.floor_transition_in_progress = true
	world._stash_current_floor_for_rollback()
	check(rollback_nodes[0].process_mode == Node.PROCESS_MODE_DISABLED, "stash stops updates")
	check(rollback_nodes[0].collision_layer == 0, "stash cannot collide with new world")
	world._reset_layout_data()
	world.floor_index += 1
	world._rollback_failed_transition(world.transition_generation_token, old_index)
	check(world._floor_path_goal_searches.is_empty(),"rollback discards staged goal frontiers")
	check(world.current_room_id == old_room, "rollback restores active room before position refresh")
	await frames(2)
	check(world.floor_cells == old_cells, "rollback restores full topology")
	check(world._floor_path_cache_enabled,"rollback reenables navigation")
	check(world._current_floor_path_adjacency().keys()==old_cells.keys(),"rollback rebuilds exact restored graph")
	check(world.skeleton_source == old_source, "rollback restores native skeleton source")
	check(world.glass_runs == old_panes, "rollback restores continuous pane grouping")
	check(world.skeleton_plans == old_plans, "rollback restores functional furniture plans")
	check(world.elevator_floor_door == old_door, "rollback restores elevator pointer")
	for node in rollback_nodes:
		check(is_instance_valid(node), "rollback retains original transient")
	check(rollback_nodes[0].get_parent() == world.world_weapon_root, "rollback weapon restored once")
	check(rollback_nodes[0].process_mode != Node.PROCESS_MODE_DISABLED, "rollback resumes updates")
	var object_pool: Node3D=world._get_floor_object_capture_pool()
	for item in [[rollback_nodes[0],&"depth_visual_bridge",&"weapon"],[rollback_nodes[0],&"floor_object_shadow_bridge",&"shadow"],[rollback_nodes[6],&"depth_visual_bridge",&"debris"]]:
		var ref: WeakRef=item[0].get_meta(item[1])
		var restored: Node3D=ref.get_ref()
		check(is_instance_valid(restored) and restored.configured and restored.source_actor==item[0],"rollback restores live object capture")
		check(not object_pool.idle[item[2]].has(restored),"live object slot never idle after rollback")
	var bridge_ref: WeakRef=rollback_nodes[1].get_meta(&"depth_visual_bridge")
	var restored_bridge: Node3D=bridge_ref.get_ref()
	check(is_instance_valid(restored_bridge) and restored_bridge.configured and restored_bridge.source_actor==rollback_nodes[1], "rollback preserves active pooled projectile binding")
	check(not world._get_projectile_capture_pool().idle.has(restored_bridge), "rollback does not return a live projectile slot twice")
	var muzzle_ref: WeakRef=rollback_nodes[2].get_meta(&"depth_visual_bridge")
	var muzzle_bridge: Node3D=muzzle_ref.get_ref()
	check(is_instance_valid(muzzle_bridge) and muzzle_bridge.configured and muzzle_bridge.source_actor==rollback_nodes[2], "rollback restores live muzzle display")
	check(not world._get_muzzle_capture_pool().idle.has(muzzle_bridge), "rollback muzzle slot not idle")
	var shell_ref: WeakRef=rollback_nodes[3].get_meta(&"depth_visual_bridge")
	var shell_bridge: Node3D=shell_ref.get_ref()
	check(is_instance_valid(shell_bridge) and shell_bridge.configured and shell_bridge.source_actor==rollback_nodes[3], "rollback restores live shell display")
	check(not world._get_shell_capture_pool().idle.has(shell_bridge), "rollback shell slot not idle")
	var feedback_ref: WeakRef=rollback_nodes[4].get_meta(&"depth_visual_bridge")
	var feedback_bridge: Node3D=feedback_ref.get_ref()
	check(is_instance_valid(feedback_bridge) and feedback_bridge.configured and feedback_bridge.source_actor==rollback_nodes[4], "rollback restores live feedback display")
	check(not world._get_feedback_capture_pool().idle.has(feedback_bridge), "rollback feedback slot not idle")
	var blood_pool: Node3D=world._get_blood_ground_capture_pool()
	var blood_ref: WeakRef=rollback_nodes[5].get_meta(&"depth_visual_bridge")
	var blood_bridge: Node3D=blood_ref.get_ref()
	check(is_instance_valid(blood_bridge) and blood_bridge.configured and blood_bridge.source_actor==rollback_nodes[5],"rollback restores original blood carrier source")
	check(not blood_pool.small_idle.has(blood_bridge) and not blood_pool.large_idle.has(blood_bridge),"restored blood capture never remains idle")
	blood_bridge.resize_blood_ground_capture(112.0)
	world.world_effects_root.remove_child(rollback_nodes[5]); await frames(2)
	check(blood_pool.large_idle.has(blood_bridge) and not blood_pool.small_idle.has(blood_bridge),"consolidated capture returns to large bin")
	world.world_effects_root.add_child(rollback_nodes[5])
	blood_pool.restore_binding(rollback_nodes[5],world.camera_3d,world.BLOOD_FLOOR_WORLD_Y)
	check(blood_bridge.configured and blood_bridge.render_viewport.size==Vector2i(224,224),"rollback preserves enlarged blood extent")
	check(not blood_pool.large_idle.has(blood_bridge),"restored enlarged blood is exclusively live")
	var blood_overflow: Array[Node2D]=[]
	for index in 80:
		var effect:=BlackBloodEffect.new(); effect.office_pool_core=index>=60
		world._add_3d_blood_effect(effect,world.current_room_id); effect.set_process(false)
		blood_overflow.append(effect)
	for effect in blood_overflow: world.world_effects_root.remove_child(effect)
	await frames(2)
	check(blood_pool.small_idle.size()==48 and blood_pool.large_idle.size()==16,"blood bins obey retention caps")
	var blood_slots: Dictionary={}
	for effect in blood_overflow:
		world.world_effects_root.add_child(effect); blood_pool.restore_binding(effect,world.camera_3d,world.BLOOD_FLOOR_WORLD_Y)
		var reference: WeakRef=effect.get_meta(&"depth_visual_bridge")
		var bridge: Node3D=reference.get_ref()
		check(bridge.configured and bridge.source_actor==effect,"overflow blood restores exact source")
		check(not blood_pool.small_idle.has(bridge) and not blood_pool.large_idle.has(bridge),"overflow blood live slot not idle")
		blood_slots[bridge.get_instance_id()]=true
	check(blood_slots.size()==80,"blood overflow never steals active slot")
	for effect in blood_overflow: effect.queue_free()
	await frames(2)
	world.world_effects_root.remove_child(rollback_nodes[5]); await frames(2)
	check(not is_instance_valid(blood_bridge),"full large bin discards promoted idle overflow")
	world.world_effects_root.add_child(rollback_nodes[5])
	blood_pool.restore_binding(rollback_nodes[5],world.camera_3d,world.BLOOD_FLOOR_WORLD_Y)
	var rebuilt_blood: Node3D=(rollback_nodes[5].get_meta(&"depth_visual_bridge") as WeakRef).get_ref()
	check(rebuilt_blood.render_viewport.size==Vector2i(224,224) and rebuilt_blood.source_actor==rollback_nodes[5],"destroyed promoted slot rebuild preserves original extent and owner")
	var feedback_overflow: Array[Node2D]=[]
	var feedback_pool: Node3D=world._get_feedback_capture_pool()
	for index in 60:
		world.spawn_combat_feedback(world.player.global_position,Vector2.RIGHT,index%2==0)
		var effect: Node2D=world.world_effects_root.get_children().back()
		effect.set_process(false); feedback_overflow.append(effect)
	for effect in feedback_overflow: world.world_effects_root.remove_child(effect)
	await frames(2)
	check(feedback_pool.idle.size()==48,"feedback idle pool obeys retention cap")
	var feedback_slots: Dictionary={}
	for effect in feedback_overflow:
		world.world_effects_root.add_child(effect)
		feedback_pool.restore_binding(effect,world.camera_3d)
		var reference: WeakRef=effect.get_meta(&"depth_visual_bridge")
		var bridge: Node3D=reference.get_ref()
		check(bridge.configured and bridge.source_actor==effect,"feedback overflow rollback restores exact source")
		check(not feedback_pool.idle.has(bridge),"feedback overflow live slot is not idle")
		feedback_slots[bridge.get_instance_id()]=true
	check(feedback_slots.size()==60,"feedback overflow never steals another live slot")
	for effect in feedback_overflow: effect.queue_free()
	await frames(2)
	# Overflow never drops a casing. Detached sources simulate stash releases
	# beyond the idle retention cap, including slots destroyed before rollback.
	var shell_pool: Node3D=world._get_shell_capture_pool()
	var previously_active: Array[int]=[]
	for id in shell_pool.atlas.slots:
		if shell_pool.atlas.slots[id].active: previously_active.append(id)
	var overflow: Array[Node2D]=[]
	for index in 110:
		world.spawn_shell_ejection(world.player.global_position,Vector2.RIGHT,&"assault_rifle")
		var effect: Node2D=world.world_effects_root.get_children().back()
		effect.set_process(false)
		overflow.append(effect)
	var slots: Dictionary={}
	for effect in overflow:
		var reference: WeakRef=effect.get_meta(&"depth_visual_bridge")
		var bridge: Node3D=reference.get_ref()
		slots[bridge.get_instance_id()]=true
		check(bridge.lit_material!=null,"shell retains original lit material")
	check(slots.size()==110,"overflow has one display per shell")
	check(shell_pool.atlas.pages.size()==4 and shell_pool.atlas.slots.size()==110+previously_active.size(),"atlas grows without losing overflow or existing casings")
	for effect in overflow: world.world_effects_root.remove_child(effect)
	await frames(2)
	check(shell_pool.idle.size()==96,"released shells obey idle retention cap")
	check(shell_pool.atlas.slots.size()==96+previously_active.size(),"deleted carriers release atlas cells, keeping existing active casings")
	for page in shell_pool.atlas.pages:
		var still_active:=false
		for id in previously_active:
			if page.owners.has(id): still_active=true
		check(page.viewport.render_target_update_mode==(SubViewport.UPDATE_ALWAYS if still_active else SubViewport.UPDATE_DISABLED),"released pages stop rendering without disabling another live casing")
	for bridge in shell_pool.idle:
		check(not bridge.configured and not bridge.actor_sprite.visible and bridge.render_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"idle shell display cannot render")
	slots.clear()
	for effect in overflow:
		world.world_effects_root.add_child(effect)
		shell_pool.restore_binding(effect,world.camera_3d)
		var reference: WeakRef=effect.get_meta(&"depth_visual_bridge")
		var bridge: Node3D=reference.get_ref()
		check(bridge.configured and bridge.source_actor==effect,"overflow rollback recovers exact source")
		slots[bridge.get_instance_id()]=true
	check(slots.size()==110,"overflow rollback never steals another live slot")
	world.queue_free()
	await frames(2)
	await create_timer(1.0).timeout
	await create_timer(1.0).timeout
	print("LIFECYCLE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
