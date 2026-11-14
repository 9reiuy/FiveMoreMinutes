extends SceneTree
var checks:=0
var failures:=0
var world: Node
var aim_point:=Vector2.ZERO
var origin:=Vector2(12000,12000)
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(count: int) -> void:
	for i in count: await process_frame
func rim(bridge: Node) -> bool:
	return bool(bridge.lit_material.get_shader_parameter("enemy_rim_enabled"))
func run() -> void:
	create_timer(45).timeout.connect(func() -> void: quit(2))
	var diagnostic:=root.get_node_or_null("_DroneGameDiag")
	if diagnostic!=null: diagnostic.free()
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false
	world.spawn_content=false
	world.persist_profile=false
	world.enable_game_start_cab_exit=false
	var display: Node = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.preview_mode = false
	display.world = world
	root.add_child(display)
	check(world.regenerate(42001),"Formal world generates")
	await frames(4)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	for x in range(370,385):
		for y in range(370,385): world.floor_cells[Vector2i(x,y)]=true
	world.player.global_position=origin
	world.player.set_meta(&"presentation_pointer_position",func() -> Vector2: return world.camera_3d.unproject_position(world.get_gameplay_world_position(aim_point,0)))
	world.player.equip_weapon("basic",world.config,{})
	var enemy: Node=world._spawn_regular_employee(world.current_room_id,origin+Vector2(160,0),&"employee",false,"basic")
	enemy.set_room_runtime_active(true)
	if enemy.sky_drop_active: enemy._update_sky_drop(2.0)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	await frames(3)
	var bridge: Node=enemy.get_meta(&"depth_visual_bridge").get_ref()
	var player_bridge: Node=world.player.get_meta(&"depth_visual_bridge").get_ref()
	bridge._process(0)
	player_bridge._process(0)
	aim_point=origin+Vector2(0,300)
	world.target_highlight._physics_process(0)
	check(not rim(bridge),"Unselected enemy has no permanent rim")
	check(not rim(player_bridge),"Player has no permanent rim")
	aim_point=enemy.get_node("Hurtbox/CollisionShape2D").global_position
	await physics_frame
	world.target_highlight._physics_process(0)
	check(world.target_highlight.current_target==enemy,"Actual player aim ray selects enemy")
	check(not rim(bridge),"Firearm aim does not draw an enemy rim")
	check(bridge.actor_sprite.material_overlay==null and bridge.weapon_sprite.material_overlay==null,"Enemy uses one body rim, no stacked outline overlays")
	aim_point=origin+Vector2(0,300)
	world.target_highlight._physics_process(0)
	check(not rim(bridge),"Moving aim away leaves the enemy unoutlined")
	world.player.equip_weapon("lucille",world.config,{})
	aim_point=origin+Vector2(300,0)
	enemy.global_position=origin+Vector2(55,25)
	await physics_frame
	world.target_highlight._physics_process(0)
	check(world.player.is_enemy_in_melee_preview(enemy),"Melee preview shares full swing arc and reach")
	check(rim(bridge) and bridge.lit_material.get_shader_parameter("enemy_rim_color")==Color.WHITE,
		"Primary enemy inside melee arc turns white even off center ray")
	check(world.target_highlight.current_target == null, "Melee cues replace the single ray without leaving an old overlay")
	enemy.global_position=origin+Vector2(-55,0)
	await physics_frame
	world.target_highlight._physics_process(0)
	check(not rim(bridge),"Close enemy behind player is unoutlined")
	enemy.global_position=origin+Vector2(180,0)
	await physics_frame
	world.target_highlight._physics_process(0)
	check(not rim(bridge),"Enemy beyond melee reach is unoutlined")
	enemy.global_position=origin+Vector2(55,0)
	var wall:=StaticBody2D.new()
	wall.collision_layer=4
	var shape:=CollisionShape2D.new()
	var box:=RectangleShape2D.new()
	box.size=Vector2(8,200)
	shape.shape=box
	wall.add_child(shape)
	world.collision_root.add_child(wall)
	wall.global_position=origin+Vector2(25,0)
	await physics_frame
	world.target_highlight._physics_process(0)
	check(not world.player.is_enemy_in_melee_preview(enemy) and not rim(bridge),"Solid wall prevents melee highlight")
	wall.free()
	world.player.equip_weapon("books",world.config,{})
	enemy.global_position=origin+Vector2(35,0)
	await physics_frame
	world.target_highlight._physics_process(0)
	check(rim(bridge) and bridge.lit_material.get_shader_parameter("enemy_rim_color")==Color.WHITE,
		"Book melee uses its actual swing preview")
	world.player.selected_weapon_id=""
	# This fixture is intentionally far outside the real camera-follow area.
	# Supply the same explicit direction used by the actual punch authority.
	world.player.set_meta(&"aim_direction_override",Vector2.RIGHT)
	enemy.global_position=origin+Vector2(20,5)
	await physics_frame
	world.target_highlight._physics_process(0)
	var fist_preview: bool=world.player.is_enemy_in_melee_preview(enemy)
	check(fist_preview and rim(bridge) and bridge.lit_material.get_shader_parameter("enemy_rim_color")==Color.WHITE,
		"Empty hands use the real fist range and arc")
	enemy.take_damage(9999,origin,1,&"player_projectile_basic")
	bridge._process(0)
	check(bridge.lit_material.get_shader_parameter("enemy_rim_enabled")==false,"Dead enemy loses living outline")
	player_bridge._process(0)
	check(not rim(player_bridge),"Player remains unoutlined after enemy state changes")
	display.free()
	await frames(4)
	print("PLAYER_TARGET_OUTLINE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
