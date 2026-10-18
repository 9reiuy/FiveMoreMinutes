extends SceneTree
class TestPlayer extends CharacterBody2D:
	var dead := false
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func ticks(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var arena := Node2D.new()
	root.add_child(arena)
	var player := TestPlayer.new()
	player.collision_layer = 1
	var player_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7
	player_shape.shape = circle
	player.add_child(player_shape)
	arena.add_child(player)
	var enemy = load("res://scenes/entities/employee_enemy.tscn").instantiate()
	arena.add_child(enemy)
	enemy.configure(player,100.0,0.0,Rect2(-500,-500,1000,1000),10.0,20.0,null)
	enemy.death_burst_direction = Vector2.RIGHT
	enemy.death_burst_force = 100
	enemy._die()
	enemy.set_process(false)
	check(enemy.dead and enemy.collision_layer==0,"Corpse is dead and does not block or receive bullets")
	check(enemy.corpse_contact.collision_layer==0,"Sensor cannot be hit by projectiles")
	for i in 180: enemy._update_death_presentation(1.0/60)
	check(enemy.death_landed and enemy.knockdown_height==0,"Corpse lands on ground")
	check(absf(enemy.ragdoll_left_hand_rot)+absf(enemy.ragdoll_right_hand_rot)>0.1,"Landed limbs retain a non-standing relaxed pose")
	for i in 180: enemy._update_death_presentation(1.0/60)
	check(not enemy.ragdoll_active,"All joints sleep when settled")
	var timer: float = enemy.death_presentation_left
	var sensor = enemy.corpse_contact
	sensor._physics_process(1.0/60)
	player.global_position = sensor.global_position-Vector2(10,0)
	player.velocity = Vector2(290,0)
	await ticks(4)
	check(enemy.death_ground_velocity.x>0,"Real overlap with walking player wakes and pushes corpse")
	check(enemy.ragdoll_active,"Walking contact wakes limbs")
	sensor.set_physics_process(false)
	enemy.death_ground_velocity = Vector2.ZERO
	player.velocity = Vector2.ZERO
	check(not sensor.try_push(player,1.0/60),"Stationary player does not push")
	player.velocity = Vector2(-290,0)
	check(not sensor.try_push(player,1.0/60),"Receding player does not pull corpse")
	var prop := RigidBody2D.new()
	prop.add_to_group(&"damageable_props")
	prop.add_to_group(&"pushable_prop")
	prop.gravity_scale = 0
	arena.add_child(prop)
	prop.global_position = sensor.global_position-Vector2(15,0)
	prop.linear_velocity = Vector2(160,0)
	check(sensor.try_push(prop,1.0/60),"Moving furniture can push")
	check(enemy.death_ground_velocity.x>0,"Furniture transfers motion")
	prop.linear_velocity = Vector2.ZERO
	check(not sensor.try_push(prop,1.0/60),"Stationary furniture does not push")
	prop.global_position = sensor.global_position-Vector2(0,15)
	prop.angular_velocity = -3
	check(sensor.try_push(prop,1.0/60),"Rotating furniture surface can push")
	var pickup := RigidBody2D.new()
	pickup.add_to_group(&"pushable_prop")
	arena.add_child(pickup)
	pickup.linear_velocity = Vector2(300,0)
	check(not sensor.try_push(pickup,1.0/60),"Dropped weapons are not furniture")
	var bullet := Node2D.new()
	arena.add_child(bullet)
	check(not sensor.try_push(bullet,1.0/60),"Projectiles cannot push through contact API")
	var previous_velocity: Vector2 = enemy.death_ground_velocity
	enemy.take_damage(999,Vector2.LEFT,500,&"rifle")
	check(enemy.death_ground_velocity==previous_velocity,"Shooting a dead enemy does not add impulse")
	check(enemy.death_presentation_left==timer,"Contact never resets corpse lifetime")
	var before := enemy.global_position as Vector2
	enemy._update_death_presentation(1.0/60)
	check(enemy.global_position!=before,"Contact causes actual corpse displacement")
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var wall_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4,100)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.position = enemy.global_position+Vector2(25,0)
	arena.add_child(wall)
	await ticks(2)
	enemy.death_ground_velocity = Vector2(240,0)
	for i in 30: enemy._update_death_presentation(1.0/60)
	check(enemy.global_position.x<=wall.position.x-8.5,"Swept corpse footprint stops before solid wall")
	check(enemy.knockdown_height==0,"Pushing does not relaunch corpse below/above floor")
	for i in 240: enemy._update_death_presentation(1.0/60)
	check(not enemy.ragdoll_active,"Pushed corpse settles and sleeps again")
	var sensor_ref: WeakRef = weakref(sensor)
	arena.free()
	await ticks(2)
	check(sensor_ref.get_ref()==null,"Corpse sensor is released with its floor-owned enemy")
	print("CORPSE_RAGDOLL_CONTACT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
