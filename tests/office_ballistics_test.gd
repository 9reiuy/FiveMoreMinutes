extends SceneTree
const SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const BULLET = preload("res://scenes/entities/basic_projectile.tscn")
const GLASS = preload("res://scripts/dream/continuous_office_glass.gd")
const DOOR = preload("res://scenes/dream/3d/PhysicalDoor3D.tscn")
var checks := 0
var failures := 0
var world: Node3D

class Barrier extends StaticBody2D:
	var hits := 0
	func take_damage(_amount: float,_direction: Vector2,_force: float) -> void: hits += 1
	func is_damage_runtime_active() -> bool: return true
	func get_size_category() -> int: return 3

class Victim extends StaticBody2D:
	var hits := 0
	func receive_damage(_amount: float,_kind: StringName,_point: Vector2,_direction: Vector2) -> void: hits += 1

func _init() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",label)

func birth_has_only_head(shot: Node2D) -> bool:
	var sprite := shot.get_node("BulletSprite") as Sprite2D
	var image := sprite.texture.get_image()
	var head := -sprite.position / sprite.scale
	for x in image.get_width():
		for y in image.get_height():
			if Vector2(x, y).distance_squared_to(head) > shot.TRACER_HEAD_RADIUS_SQUARED and image.get_pixel(x, y).a > 0.0:
				return false
	return image.get_pixelv(Vector2i(head)).a > .99

func head_is_at_gameplay_origin(shot: Node2D) -> bool:
	var sprite := shot.get_node("BulletSprite") as Sprite2D
	var head := -sprite.position / sprite.scale
	var image := sprite.texture.get_image()
	return Rect2i(Vector2i.ZERO, image.get_size()).has_point(Vector2i(head)) and image.get_pixelv(Vector2i(head)).a > .99

func shape(body: StaticBody2D) -> void:
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2,24)
	collision.shape = rect
	body.add_child(collision)
	body.collision_layer = 1
	body.collision_mask = 0
	world.collision_root.add_child(body)

func barrier(at: Vector2,kind: String) -> Barrier:
	var body := Barrier.new()
	body.position = at
	if kind == "door": body.set_meta(&"physical_door",true)
	if kind == "glass": body.add_to_group(&"glass_windows")
	if kind == "furniture": body.add_to_group(&"damageable_props")
	shape(body)
	return body

func bullet(at: Vector2,direction: Vector2,range_pixels: float=1536.0,office: bool=true,shot_speed: float=2500.0) -> Node2D:
	var shot: Node2D = BULLET.instantiate()
	world.gameplay_world.add_child(shot)
	shot.set_physics_process(false)
	shot.position=at
	shot.setup(direction,10.0,range_pixels,shot_speed,&"enemy")
	if office: shot.enable_office_ballistics()
	return shot

func run() -> void:
	world=SCENE.instantiate()
	world.generate_on_ready=false
	world.spawn_content=false
	world.persist_profile=false
	world.enable_game_start_cab_exit=false
	root.add_child(world)
	await process_frame
	check(world.regenerate(60321),"normal 3D floor")
	world.set_process(false)
	world.player.set_physics_process(false)
	var origin := Vector2(100000,100000)
	for index in 8:
		var start := origin+Vector2(0,index*120)
		var direction := Vector2.RIGHT.rotated(index*PI/4.0)
		var door := barrier(start+direction*8.0,"door")
		var glass := barrier(start+direction*17.0,"glass")
		var target := Victim.new()
		target.add_to_group(&"dream_player")
		target.position=start+direction*34.0
		shape(target)
		await physics_frame
		var shot := bullet(start,direction)
		shot._physics_process(1.0/60.0)
		check(door.hits==1,"direction %d door damaged once"%index)
		check(glass.hits==1,"direction %d glass damaged once"%index)
		check(target.hits==1,"direction %d same tick reaches victim"%index)
		check(shot.consumed,"direction %d stops at victim"%index)
		door.queue_free(); glass.queue_free(); target.queue_free()
		await process_frame
	# Keep the faster 2500 stress cases above; verify production 1500 across ticks.
	for index in 8:
		var start := origin+Vector2(1500,index*120)
		var direction := Vector2.RIGHT.rotated(index*PI/4.0)
		var door := barrier(start+direction*8.0,"door")
		var glass := barrier(start+direction*17.0,"glass")
		var target := Victim.new()
		target.add_to_group(&"dream_player")
		target.position = start+direction*41.0
		shape(target)
		await physics_frame
		var shot := bullet(start,direction,1536.0,true,1500.0)
		shot._physics_process(1.0/60.0)
		check(door.hits==1 and glass.hits==1,"1500 penetrates door and glass once")
		check(absf(shot.traveled-25.0)<.01,"1500 advances 25 px per tick")
		check(target.hits==0,"1500 does not prematurely hit farther victim")
		shot._physics_process(1.0/60.0)
		check(target.hits==1 and shot.consumed,"1500 next tick hits victim")
		door.queue_free(); glass.queue_free(); target.queue_free()
		await process_frame
	for kind in ["wall","furniture"]:
		var start := origin+Vector2(300,0)
		var door := barrier(start+Vector2(8,0),"door")
		var solid := barrier(start+Vector2(25,0),kind)
		var behind := barrier(start+Vector2(34,0),"glass")
		await physics_frame
		var shot := bullet(start,Vector2.RIGHT)
		shot._physics_process(1.0/60.0)
		check(door.hits==1,"penetrates door before "+kind)
		check(shot.consumed and shot.global_position.x<start.x+26,"solid stops fast bullet: "+kind)
		check(behind.hits==0,"no hit behind "+kind)
		door.queue_free(); solid.queue_free(); behind.queue_free()
		await process_frame
	for distance in [640.0,1024.0,1536.0]:
		var shot := bullet(origin+Vector2(600,0),Vector2.RIGHT,distance)
		var initial := shot.global_position
		check(birth_has_only_head(shot),"birth tail does not precede muzzle")
		for frame in 60:
			shot._physics_process(1.0/60.0)
			if frame==0:
				check(absf(shot.traveled-2500.0/60.0)<0.01,"true 2500 px/s movement (far-coordinate float tolerance)")
				check(head_is_at_gameplay_origin(shot),"dynamic texture head stays at gameplay origin")
			if shot.consumed: break
		check(is_equal_approx(shot.traveled,distance),"exact authored range %.0f"%distance)
		check(is_equal_approx(shot.global_position.distance_to(initial),distance),"range not lifetime truncated")
		await process_frame
	var legacy_door := barrier(origin+Vector2(900,8),"door")
	await physics_frame
	var legacy := bullet(origin+Vector2(900,0),Vector2.DOWN,1536,false)
	legacy._physics_process(1.0/60.0)
	check(legacy.consumed and legacy_door.hits==1,"old 2D door still terminal")
	legacy_door.queue_free()
	# Actual continuous pane, including height filtering and deferred collision removal.
	var pane := GLASS.new()
	world.wall_root.add_child(pane)
	pane.configure_window({"axis":"V","x":20000,"y":20000,"preview_run_width":3},"test",2.6,1.0,world.collision_root)
	var pane_start: Vector2 = pane.collision_body_2d.global_position-Vector2(40,0)
	var pane_target := Victim.new()
	pane_target.add_to_group(&"dream_player")
	pane_target.position=pane_start+Vector2(90,0)
	shape(pane_target)
	await physics_frame
	var pane_shot := bullet(pane_start,Vector2.RIGHT)
	pane_shot.set_meta(&"shot_height_pixels",25.0)
	pane_shot._physics_process(0.05)
	check(pane.is_shattered,"real continuous glass shatters")
	check(pane_target.hits==1,"real glass allows same-frame hit behind it")
	pane.queue_free(); pane_target.queue_free()
	await process_frame
	var hinge: Node3D = DOOR.instantiate()
	hinge.configure(2.0,3.0,0.1,"left",99999,&"single")
	hinge.position=Vector3(25000,0,25000)
	world.door_root.add_child(hinge)
	hinge.configure_gameplay_collision(world.collision_root,32,4)
	await physics_frame
	var leaf: StaticBody2D = hinge._collision_bodies[0]
	var leaf_start := leaf.global_position-Vector2(0,20)
	var leaf_health: float = hinge.current_health
	var door_shot := bullet(leaf_start,Vector2.DOWN)
	door_shot._physics_process(1.0/60.0)
	check(hinge.current_health<leaf_health,"real door takes damage")
	check(not door_shot.consumed and door_shot.global_position.y>leaf.global_position.y+10,"real door does not consume shot")
	check(leaf.collision_layer!=0,"intact door still blocks people")
	door_shot.queue_free(); hinge.queue_free()
	# Weapon muzzle can be beyond thin geometry at point blank. The mandatory
	# shooter-to-muzzle sweep must still stop at solid walls, but pass doors.
	for kind in ["wall","door"]:
		var source := Node2D.new()
		world.gameplay_world.add_child(source)
		source.position=origin+Vector2(1300,0)
		var blocker := barrier(source.position+Vector2(10,0),kind)
		await physics_frame
		var shot := bullet(source.position+Vector2(30,0),Vector2.RIGHT)
		shot.setup(Vector2.RIGHT,10,1024,2500,&"enemy",source)
		shot._physics_process(1.0/60.0)
		check(shot.consumed if kind=="wall" else not shot.consumed,"point-blank spawn guard respects "+kind)
		if kind=="door":
			check(blocker.hits==1,"point-blank door damaged only once")
			check(absf(shot.traveled-2500.0/60.0)<0.01,"point-blank penetration retains tick travel budget")
		if not shot.consumed: shot.queue_free()
		blocker.queue_free(); source.queue_free()
		await process_frame
	var real := BULLET.instantiate() as Node2D
	real.setup(Vector2.RIGHT,10,1024,2500,&"player",world.player)
	real.position=world.player.global_position
	world.add_projectile(real,world.player)
	check(real.office_ballistics,"normal world projectile path opts in")
	check(real.has_meta(&"shot_visual_origin"),"normal path retains formal muzzle snapshot")
	real.queue_free()
	world.queue_free()
	await create_timer(1.0).timeout
	print("OFFICE BALLISTICS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
