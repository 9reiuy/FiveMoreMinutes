extends SceneTree
const CONFIG=preload("res://resources/demo_config.tres")
var checks := 0
var failures := 0
var arena: Node2D
var player: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func victim(source: StringName, direction:=Vector2.RIGHT, inherited:=Vector2.ZERO) -> EmployeeEnemy:
	player.position=-direction*30
	var enemy: EmployeeEnemy=load("res://scenes/entities/employee_enemy.tscn").instantiate()
	arena.add_child(enemy)
	enemy.configure(player,10,0,Rect2(-1000,-1000,2000,2000),0,0,CONFIG)
	enemy.set_room_bounds(Rect2(-1000,-1000,2000,2000))
	enemy.knockback_velocity=inherited
	enemy.take_damage(100,enemy.global_position-direction*30,1,source)
	enemy.set_process(false); enemy.set_physics_process(false)
	return enemy
func step(enemy: EmployeeEnemy, count: int) -> void:
	for index in count:
		enemy._update_death_motion(1.0/60)
		enemy._update_death_presentation(1.0/60,false)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	arena=Node2D.new(); root.add_child(arena); player=Node2D.new(); arena.add_child(player); player.position=Vector2(-800,-800)
	var gun_distance := 0.0
	for source in [&"player_projectile_basic",&"player_projectile_assault_rifle",&"player_projectile_shotgun",&"kick",&"lucille",&"books",&"furniture_impact"]:
		var enemy := victim(source)
		var start := enemy.global_position
		var speed := enemy.death_ground_velocity.length()
		var expected := minf(enemy.death_burst_force*CONFIG.corpse_impulse_transfer,CONFIG.corpse_max_launch_speed)
		check(enemy.dead and enemy.ragdoll_active and is_equal_approx(speed,expected),String(source)+" transfers existing attack force to complete corpse")
		check(is_equal_approx(enemy.death_presentation_left,CONFIG.corpse_linger_duration),"Existing corpse lifetime preserved")
		enemy._update_death_presentation(.016,false)
		check(enemy.global_position==start,"Render presentation cannot move corpse a second time")
		step(enemy,120)
		var distance := enemy.global_position.distance_to(start)
		print("CORPSE_IMPULSE_SAMPLE ",JSON.stringify({"source":source,"force":enemy.death_burst_force,"initial_speed":speed,"distance":distance}))
		check(distance>30 and enemy.death_landed and enemy.death_ground_velocity.length()<.01,"Physical launch, landing and friction produce bounded displacement")
		check(enemy.death_origin_gameplay_position==start,"Cached death origin remains separate from moving corpse")
		if source==&"player_projectile_basic": gun_distance=distance
		if source==&"kick": check(distance>gun_distance*1.5,"Existing stronger kick yields greater corpse travel")
		enemy.free()
	var moving := victim(&"player_projectile_basic",Vector2.RIGHT,Vector2(100,0))
	check(is_equal_approx(moving.death_ground_velocity.x,CONFIG.gun_knockback_force*CONFIG.corpse_impulse_transfer+35),"Death retains bounded preexisting knockback momentum")
	moving.free()
	var left := victim(&"player_projectile_basic",Vector2.LEFT)
	step(left,120); check(left.global_position.x < -80,"Opposite lethal direction reverses corpse trajectory"); left.free()
	var wall := StaticBody2D.new(); wall.collision_layer=4; wall.position=Vector2(85,0)
	var shape := CollisionShape2D.new(); var rectangle := RectangleShape2D.new(); rectangle.size=Vector2(4,200); shape.shape=rectangle; wall.add_child(shape); arena.add_child(wall)
	await physics_frame; await physics_frame
	var blocked := victim(&"kick")
	step(blocked,120)
	check(blocked.global_position.x<77 and blocked.global_position.x>0,"Actual sweep prevents launch through a closed wall")
	check(blocked.death_ground_velocity.length()<.01 and blocked.death_landed,"Collision response settles without residual motion")
	blocked.free(); wall.free(); arena.free()
	print("CORPSE_DEATH_IMPULSE_CHECKS=",checks," FAILURES=",failures)
	quit(1 if failures else 0)
