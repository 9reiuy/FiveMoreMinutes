extends SceneTree

const CATALOG := preload("res://scripts/dream/office_furniture_catalog.gd")
const PROP := preload("res://scenes/dream/props/desk.tscn")
const BULLET := preload("res://scenes/entities/basic_projectile.tscn")
var world: Node
var checks := 0
var failures := 0

class Victim extends StaticBody2D:
	var dead := false
	var hits := 0
	var total_damage := 0.0
	func take_damage(amount: float,_origin: Vector2,_force: float,_source: StringName) -> void:
		hits += 1
		total_damage += amount
	func receive_damage(amount: float,_source: StringName,_origin: Vector2,_direction: Vector2) -> void:
		hits += 1
		total_damage += amount

func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
func prop(kind: String,at: Vector2,angle: float = 0.0) -> RigidBody2D:
	var item: RigidBody2D = PROP.instantiate()
	CATALOG.configure(item,kind)
	world.furniture_root.add_child(item)
	item.global_position = at
	item.rotation = angle
	item.freeze = true
	item.set_process(false)
	return item
func victim(at: Vector2,faction: StringName) -> Victim:
	var target := Victim.new()
	target.collision_layer = 16
	target.collision_mask = 0
	target.add_to_group(&"dream_enemies" if faction==&"player" else &"dream_player")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10,30)
	shape.shape = box
	target.add_child(shape)
	world.gameplay_world.add_child(target)
	target.global_position = at
	return target
func bullet(at: Vector2,faction: StringName,height: float = 32.0) -> Node2D:
	var shot: Node2D = BULLET.instantiate()
	world.gameplay_world.add_child(shot)
	shot.set_physics_process(false)
	shot.global_position = at
	shot.setup(Vector2.RIGHT,10.0,1536.0,1500.0,faction)
	shot.enable_office_ballistics()
	shot.set_meta(&"shot_height_pixels",height)
	shot.penetration_chance = 0.0
	return shot
func cleanup(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node): node.queue_free()
	await frames(2)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.approved_sample_art_enabled = false
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var origin := Vector2(10000,10000)
	for faction in [&"player",&"enemy"]:
		for kind in ["desk","workstation","chair","table","coffee_table","sofa","sorting_table","counter","sink","washbasin","toilet","bin","box"]:
			var item := prop(kind,origin+Vector2(100,0),.3)
			var target := victim(origin+Vector2(250,0),faction)
			await frames(2)
			var hp: float = item.hp
			var impacts: int = get_nodes_in_group(&"firearm_impact_visuals").size()
			var shot := bullet(origin,faction)
			shot._physics_process(.2)
			var label := "%s/%s" % [faction,kind]
			check(is_equal_approx(hp-item.hp,10.0),label+": one normal furniture damage event")
			check(target.hits==1,label+": reaches actor behind low furniture")
			check(is_equal_approx(shot.speed,1500.0) and is_equal_approx(shot.damage,10.0),label+": speed/damage unchanged")
			check(shot.penetration_count==0,label+": does not spend actor penetration")
			check(get_nodes_in_group(&"firearm_impact_visuals").size()>impacts,label+": creates normal impact pixels")
			if kind=="coffee_table":
				var contact: Node3D = get_nodes_in_group(&"firearm_impact_visuals").back()
				check(world.to_local(contact.global_position).y<=CATALOG.size_of(kind).y+.001,"Coffee-table impact stays on surface, not muzzle height")
			await cleanup([shot,item,target])
		for kind in ["cabinet","cabinet_open","shelf","fridge","server","partition","water_dispenser"]:
			var item := prop(kind,origin+Vector2(100,0))
			var target := victim(origin+Vector2(250,0),faction)
			await frames(2)
			var hp: float = item.hp
			var shot := bullet(origin,faction)
			shot._physics_process(.2)
			check(shot.consumed and target.hits==0,"%s/%s: high furniture blocks" % [faction,kind])
			check(is_equal_approx(hp-item.hp,10.0),"High furniture still takes ordinary damage")
			await cleanup([shot,item,target])
		# Ordered multi-contact sweep: pass only the first, damage/stop on second.
		var first := prop("coffee_table",origin+Vector2(60,0))
		var second := prop("chair",origin+Vector2(110,0),.5)
		var behind := prop("sofa",origin+Vector2(220,0))
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var wall_shape := CollisionShape2D.new()
		var wall_box := RectangleShape2D.new()
		wall_box.size = Vector2(4,100)
		wall_shape.shape = wall_box
		wall.add_child(wall_shape)
		world.collision_root.add_child(wall)
		wall.global_position = origin+Vector2(160,0)
		await frames(2)
		var first_hp: float = first.hp
		var second_hp: float = second.hp
		var behind_hp: float = behind.hp
		var chain := bullet(origin,faction)
		chain._physics_process(.2)
		check(is_equal_approx(first_hp-first.hp,10.0) and is_equal_approx(second_hp-second.hp,10.0),"Both low contacts damaged once in one tick")
		check(chain.consumed and chain.global_position.x<origin.x+130,"Second low furniture stops same-tick chain")
		check(chain.low_furniture_passes==1,"Furniture penetration budget capped at one")
		check(is_equal_approx(behind_hp,behind.hp),"Third furniture receives no damage")
		second.queue_free()
		await frames(2)
		var wall_shot := bullet(origin,faction)
		wall_shot._physics_process(.2)
		check(wall_shot.consumed and absf(wall_shot.global_position.x-origin.x-158)<.1,"One low furniture followed by wall still stops at wall")
		check(is_equal_approx(behind_hp,behind.hp),"No damage behind wall after permitted furniture pass")
		await cleanup([chain,wall_shot,first,behind,wall])
		# One wide object spanning several physics ticks must not repeatedly hit.
		var wide := prop("table",origin+Vector2(100,0))
		await frames(2)
		var wide_hp: float = wide.hp
		var slow := bullet(origin,faction)
		for i in 10: slow._physics_process(1.0/60.0)
		check(is_equal_approx(wide_hp-wide.hp,10.0),"Wide table damaged only once across ticks")
		check(not slow.consumed and is_equal_approx(slow.traveled,250.0),"Low furniture never reduces movement budget")
		check(slow.low_furniture_passes==1,"Repeated shape/tick contacts spend one slot only")
		var pellet := bullet(origin,faction,10.0)
		pellet._physics_process(.2)
		check(is_equal_approx(wide_hp-wide.hp,20.0),"Independent pellet deals its own one contact, including lower muzzle height")
		await cleanup([slow,pellet,wide])
		var near := prop("desk",origin+Vector2(70,0))
		var far := prop("chair",origin+Vector2(150,0))
		var actor_behind := victim(origin+Vector2(250,0),faction)
		await frames(2)
		var across_ticks := bullet(origin,faction)
		for i in 15:
			across_ticks._physics_process(1.0/60.0)
			if across_ticks.consumed: break
		check(across_ticks.consumed and actor_behind.hits==0,"Second furniture stops actor damage across physics ticks")
		check(across_ticks.low_furniture_passes==1,"One-furniture cap persists across ticks")
		await cleanup([across_ticks,near,far,actor_behind])
	# Real enemy gun-clearance authority must agree with projectile policy.
	for kind in ["workstation","cabinet"]:
		var item := prop(kind,origin+Vector2(100,0))
		await frames(2)
		check(world.is_furniture_shot_path_clear(origin,origin+Vector2(250,0),world.player)==(kind=="workstation"),"AI shot clearance agrees: "+kind)
		await cleanup([item])
	var cover_a := prop("coffee_table",origin+Vector2(60,0))
	var cover_b := prop("chair",origin+Vector2(140,0))
	await frames(2)
	check(not world.is_furniture_shot_path_clear(origin,origin+Vector2(250,0),world.player),"AI clearance rejects path through two low furniture items")
	await cleanup([cover_a,cover_b])
	world.free()
	await frames(3)
	print("OFFICE_LOW_COVER checks=",checks," failures=",failures)
	quit(1 if failures else 0)
