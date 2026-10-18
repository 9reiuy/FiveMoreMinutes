extends SceneTree
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const PICKUP = preload("res://scenes/dream/world_weapon_pickup.tscn")
const ENEMY = preload("res://scenes/entities/employee_enemy.tscn")
const CONFIG = preload("res://resources/demo_config.tres")
var checks := 0
var failures: Array[String] = []
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func verify(world: Node, label: String) -> void:
	check(world.player.runtime_config == world.config,label+" retains run config")
	for weapon in [world.player.auto_weapon,world.player.assault_rifle_weapon,world.player.shotgun_weapon]:
		check(is_equal_approx(weapon.projectile_speed,1500.0),label+" all guns have 1500 speed")
	for entry in [[world.player.auto_weapon,4.2],[world.player.assault_rifle_weapon,9.0],[world.player.shotgun_weapon,2.4]]:
		check(is_equal_approx(entry[0].attack_interval,1.0 / float(entry[1])),label+" firing cadence survives swapping and floors")
	check(is_equal_approx(world.player.movement_speed,290.0),label+" player speed 290")
	var before: int = get_nodes_in_group("dream_projectiles").size()
	world.player.auto_weapon._fire(Vector2.RIGHT,false)
	world.player.assault_rifle_weapon._fire(Vector2.RIGHT,false)
	world.player.shotgun_weapon._fire_full_volley(Vector2.RIGHT,false)
	check(get_nodes_in_group("dream_projectiles").size() > before,label+" live projectiles emitted")
	for shot in get_nodes_in_group("dream_projectiles"):
		check(is_equal_approx(shot.speed,1500.0),label+" actual shot speed 1500")
		shot.queue_free()
func pickup(world: Node, id: String) -> Node2D:
	var item := PICKUP.instantiate()
	item.weapon_id = id
	world.pickup_root.add_child(item)
	item.global_position = world.player.global_position
	return item
func run() -> void:
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	var available: Array[String] = ["basic","assault_rifle","shotgun","books"]
	world.configure_campaign_run("basic",available,CONFIG,{},1,false,false,0)
	root.add_child(world)
	await process_frame
	verify(world,"initial")
	for id in ["assault_rifle","shotgun","basic"]:
		var item := pickup(world,id)
		world._swap_world_weapon(item)
		check(world.player.selected_weapon_id == id,"normal pickup equipped "+id)
		verify(world,"swap "+id)
		item.queue_free()
		await process_frame
	# Taking the active gun uses the same drop data as a throw; re-pick through world.
	var dropped: Dictionary = world.player.take_active_weapon_for_throw()
	check(not dropped.is_empty(),"gun can be removed for re-pick")
	var gun := pickup(world,"assault_rifle")
	world._store_world_weapon(gun)
	check(world.player.ranged_weapon_id == "assault_rifle","inventory pickup stores gun")
	verify(world,"inventory pickup")
	await process_frame
	var book := pickup(world,"books")
	world._store_world_weapon(book)
	world.player.switch_weapon_slot()
	world.player.switch_weapon_slot()
	verify(world,"category cycling")
	await process_frame
	var enemy := ENEMY.instantiate()
	world.enemy_root.add_child(enemy)
	enemy.configure(world.player,100.0,0.0,Rect2(-128,-128,256,256),0.0,0.0,world.config)
	check(is_equal_approx(enemy.movement_speed,150.0),"enemy speed 150")
	check(is_equal_approx(enemy._cfg("basic_projectile_speed",0.0),1500.0),"enemy bullet uses same run speed")
	enemy.queue_free()
	world._apply_3d_firearm_profile(world.config)
	verify(world,"idempotent run profile")
	check(world.regenerate(60321),"next floor builds")
	verify(world,"after floor rebuild")
	check(is_equal_approx(CONFIG.basic_projectile_speed,550.0),"shared source unchanged")
	world.queue_free()
	await process_frame
	print("SWAP SPEED checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
