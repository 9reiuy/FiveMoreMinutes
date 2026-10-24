extends SceneTree
const CONFIG := preload("res://resources/demo_config.tres")
var checks := 0
var failures: Array[String] = []
class Enemy extends Node2D:
	var dead := false
	var hits := 0
	var hp := 1000.0
	var total := 0.0
	func take_damage(amount: float) -> void:
		hits += 1
		total += amount
		hp -= amount
		dead = hp<=0
class World extends Node3D:
	var floor_root := Node3D.new()
	var floor_cells := {}
	var pit_cells := {}
	var _layout_generation := 1
	var aim := Vector2(300,0)
	var player: CharacterBody2D
	var enemies: Array = []
	var sources: Array = []
	func _ready() -> void:
		add_child(floor_root)
		add_to_group(&"dream_world")
		for x in range(-20,21):
			for y in range(-20,21): floor_cells[Vector2i(x,y)] = true
	func _cell_for_gameplay_position(point: Vector2) -> Vector2i: return Vector2i(roundi(point.x/32),roundi(point.y/32))
	func get_gameplay_aim_position() -> Vector2: return aim
	func get_dream_enemies_snapshot() -> Array: return enemies
	func resolve_player_hit(enemy: Node,damage: float,_origin: Vector2,source: StringName) -> Dictionary:
		sources.append(source)
		enemy.take_damage(damage)
		return {"damage":damage}
	func resolve_phase_dash_attack(start: Vector2,end: Vector2,radius: float,damage: float,source: StringName,handled: Variant = null,_feedback: bool = true) -> Dictionary:
		return preload("res://scripts/dream/phase_dash_combat.gd").resolve(self,player,start,end,radius,damage,source,handled)
var world: World
var player: Node
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func reset() -> void:
	player.cancel_dash()
	for enemy in world.enemies:
		if is_instance_valid(enemy): enemy.free()
	world.enemies.clear()
	world.sources.clear()
	world.pit_cells.clear()
	player.max_dash_charges = 1
	player.global_position = Vector2.ZERO
	player.dead = false
	player.movement_enabled = true
	player.set_attacking_enabled(true)
	player.dash_charges = 1
	player.dash_cooldown_left = 0.0
	player.invulnerability_left = 0.0
	world.aim = Vector2(300,0)
	player.equip_weapon("lucille",CONFIG,{})
func enemy_at(point: Vector2,health := 1000.0,duplicate_area := false) -> Enemy:
	var enemy := Enemy.new()
	enemy.hp = health
	enemy.add_to_group(&"dream_enemies")
	for i in (2 if duplicate_area else 1):
		var area := Area2D.new()
		area.collision_layer = 16
		area.collision_mask = 0
		area.monitoring = false
		var shape := CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 1.0
		area.add_child(shape)
		enemy.add_child(area)
	world.add_child(enemy)
	enemy.global_position = point
	world.enemies.append(enemy)
	return enemy
func blocker(point: Vector2,size: Vector2,layer := 4) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	body.add_child(shape)
	world.add_child(body)
	body.position = point
	return body
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	world = World.new()
	root.add_child(world)
	player = load("res://scenes/entities/dream_player.tscn").instantiate()
	world.add_child(player)
	world.player = player
	player.configure_weapon("lucille",CONFIG,{})
	player.set_physics_process(false)
	await physics_frame
	check(player.dash_distance==168 and is_equal_approx(player.dash_duration,.14) and is_equal_approx(player.dash_cooldown,.8),"Approved 168 / 140ms / 800ms configuration")
	check(CONFIG.phase_dash_attack_radius==16 and not CONFIG.tactical_dash_enabled,"32px capsule replaces hold planning")
	for i in 8:
		reset()
		var heading := Vector2.RIGHT.rotated(i*PI/4)
		world.aim = heading*300
		check(player.try_start_phase_dash(),"Eight-way phase starts %d" % i)
		check(player.collision_mask==0 and player.collision_layer==0,"Body can phase without pushing %d" % i)
		player._update_dash(.07)
		check(player.global_position.is_equal_approx(heading*84),"Constant-speed half distance %d" % i)
		check(player.body_pivot.scale!=player.phase_dash.body_scale,"Presentation squash without changing movement %d" % i)
		world.aim = -heading*300
		player._update_dash(.07)
		check(player.global_position.is_equal_approx(heading*168),"Locked heading and exact endpoint %d" % i)
		check(player.collision_mask!=0 and player.collision_layer!=0 and not player.dashing and player.dash_invulnerability_left==0,"Collision/immunity restored %d" % i)
		check(player.body_pivot.scale==player.phase_dash.body_scale and player.body_pivot.rotation==player.body_base_rotation,"Body presentation restored %d" % i)
	check(player.phase_dash.effect.ghosts.size()==6,"Six bounded passive afterimages")
	check(player.phase_dash.effect.find_children("*","SubViewport",true,false).is_empty(),"No new character capture viewport")
	player.phase_dash.effect.fade(0.0)
	check(not player.phase_dash.effect.visible and player.phase_dash.effect.ghost_materials[0].get_shader_parameter("capture_texture")==null,"Fade releases captured texture references")
	reset()
	var wall := blocker(Vector2(64,0),Vector2(8,120))
	await physics_frame
	var front := enemy_at(Vector2(20,0),1000,true)
	var behind := enemy_at(Vector2(120,0))
	var edge := enemy_at(Vector2(90,15))
	var outside := enemy_at(Vector2(90,19))
	await physics_frame
	check(player.try_start_phase_dash(),"Interior wall is traversable")
	player._update_dash(.07)
	check(front.hits==1 and behind.hits==0,"Capsule damages traversed segment immediately, not future path")
	var health: float = player.current_health
	player.receive_damage(10)
	check(player.current_health==health,"Actual damage authority rejects phase damage")
	player._update_dash(.07)
	check(player.global_position.x==168 and front.hits==1 and behind.hits==1 and edge.hits==1 and outside.hits==0,"One capsule crosses wall, deduplicates areas, respects width")
	check(is_equal_approx(front.total,player.lucille_weapon.damage),"Existing held melee damage, no damage multiplier")
	check(player.dash_charges==0 and player.dash_cooldown_left>0 and not player.try_start_phase_dash(),"Nonlethal dash does not refresh")
	wall.free()
	await physics_frame
	reset()
	var at_origin := enemy_at(Vector2(-15,0))
	var travelling := enemy_at(Vector2(50,0))
	await physics_frame
	player.try_start_phase_dash()
	check(at_origin.hits==1 and travelling.hits==0,"Full starting circle applies immediately, including rear cap")
	player._update_dash(.05)
	check(travelling.hits==1,"Enemy takes damage when reached before dash ends")
	travelling.global_position = Vector2(50,90)
	player._update_dash(.09)
	check(travelling.hits==1 and at_origin.hits==1,"Leaving route before arrival cannot erase a hit or cause repeat damage")
	reset()
	player.equip_weapon("books",CONFIG,{})
	player.equip_weapon("basic",CONFIG,{})
	var book := enemy_at(Vector2(80,0))
	await physics_frame
	check(player.try_start_phase_dash(),"Gun in hand can use carried melee slot")
	player._update_dash(.14)
	check(book.total==player.books_weapon.damage and world.sources==[&"books"] and player.selected_weapon_id=="basic","Uses carried book damage without changing selected gun")
	reset()
	player.melee_weapon_id = ""
	var fist := enemy_at(Vector2(80,0))
	await physics_frame
	check(player.try_start_phase_dash(),"No melee item still permits dash")
	player._update_dash(.14)
	check(fist.total==CONFIG.player_punch_damage and world.sources==[&"player_punch"],"Empty melee slot uses original fist damage")
	reset()
	for x in [32,64,96]: enemy_at(Vector2(x,0),1)
	await physics_frame
	player.try_start_phase_dash()
	player._update_dash(.14)
	check(player.phase_dash.last_result.kills==3 and player.dash_charges==1 and player.dash_cooldown_left==0,"Multi-kill refreshes once without stacking")
	world.aim = player.global_position+Vector2(300,0)
	check(player.try_start_phase_dash(),"Kill permits immediate next press")
	player.cancel_dash()
	reset()
	player.max_dash_charges = 2
	enemy_at(Vector2(60,0),1)
	await physics_frame
	player.try_start_phase_dash()
	player._update_dash(.14)
	player._update_dash_recharge(.01)
	check(player.dash_charges==1,"Kill restores only consumed charge, not an extra upgrade charge next tick")
	check(player.try_start_phase_dash(),"Restored charge usable while spare upgrade slot recharges")
	player.cancel_dash()
	reset()
	var end_block := blocker(Vector2(168,0),Vector2(24,40))
	await physics_frame
	check(player.try_start_phase_dash() and player.dash_end.x<150,"Wall endpoint backs off to full-body safe floor")
	player.cancel_dash()
	check(player.collision_layer!=0 and player.collision_mask!=0 and not player.dashing,"Cancel restores collision")
	end_block.free()
	await physics_frame
	reset()
	world.pit_cells[Vector2i(5,0)] = true
	check(player.try_start_phase_dash() and player.dash_end.x<140,"Hole cannot be a landing")
	player.cancel_dash()
	reset()
	var no_space := blocker(Vector2(84,0),Vector2(350,120))
	await physics_frame
	check(not player.try_start_phase_dash() and player.dash_charges==1 and player.dash_cooldown_left==0,"No legal endpoint consumes nothing")
	no_space.free()
	await physics_frame
	reset()
	check(player.try_start_phase_dash(),"Start before a moving blocker covers route")
	player._update_dash(.06)
	var moving := blocker(Vector2(84,0),Vector2(350,80))
	await physics_frame
	player._update_dash(.08)
	check(not player.dashing and player.collision_mask!=0 and player.phase_dash._standable(player.global_position,player.collision_mask),"Blocked route recovers to nearby legal floor, not a wall")
	check(player.phase_dash.last_result.hits==0,"Emergency recovery never damages remote targets")
	moving.free()
	await physics_frame
	reset()
	var cancel_wall := blocker(Vector2(64,0),Vector2(12,100))
	await physics_frame
	player.try_start_phase_dash()
	player._update_dash(.055)
	player.cancel_dash()
	check(player.phase_dash._standable(player.global_position,player.collision_mask) and not player.dashing,"Cancellation while inside a wall backs off safely")
	cancel_wall.free()
	await physics_frame
	reset()
	var full_floor: Dictionary = world.floor_cells.duplicate()
	for cell in world.floor_cells.keys():
		if cell.x>=1 and cell.x<=3: world.floor_cells.erase(cell)
	check(player.try_start_phase_dash() and player.dash_end.x>=128,"Reachable platform across an exterior gap is a legal dash target")
	player._update_dash(.07)
	check(player.is_phase_dash_active() and not player._dash_floor_position_valid(player.global_position),"Mid-dash can travel above void")
	player._update_dash(.07)
	check(not player.dashing and player.phase_dash._standable(player.global_position,player.collision_mask),"Cross-gap dash restores collisions on safe platform")
	reset()
	for cell in world.floor_cells.keys():
		if cell.x>=1: world.floor_cells.erase(cell)
	check(player.try_start_phase_dash() and player.dash_end.x<16,"No far platform stops dash inside current edge")
	player._update_dash(.14)
	check(player.phase_dash._standable(player.global_position,player.collision_mask),"No far platform never leaves player over void")
	world.floor_cells = full_floor
	reset()
	var stale := enemy_at(Vector2(60,0))
	await physics_frame
	player.try_start_phase_dash()
	world._layout_generation += 1
	player._update_dash(.14)
	check(stale.hits==0 and not player.dashing and player.collision_mask!=0,"New floor invalidates deferred capsule and restores body")
	world.free()
	preload("res://scripts/audio/sfx_manager.gd").stop_event(&"dash")
	await create_timer(.15,true,false,true).timeout
	for i in 4: await process_frame
	print("PHASE_DASH checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
