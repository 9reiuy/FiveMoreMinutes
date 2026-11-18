extends StaticBody2D
## The displayed H06 and this gameplay body share one position. Shots use the game's swept projectile path.
signal health_changed(ratio: float)
signal defeated
const SHOT := preload("res://scenes/entities/basic_projectile.tscn")
const RULES := preload("res://scripts/dream/dream_firearm_rules.gd")
const MAX_HEALTH := 160.0
const ATTACKS := preload("res://scripts/testing/h06_chapter/crawler_attacks.gd")
var current_health := MAX_HEALTH
var dead := false
var world: Node3D
var model: Node3D
var warning: MeshInstance3D
var ring_material := StandardMaterial3D.new()
var wait := 1.1
var winding := false
var volley := false
var aim := Vector2.ZERO
var return_y := 0.0
var motion: CharacterBody2D
var attacks: ATTACKS
var red_lamp_material: StandardMaterial3D
var _lamp_energy := 0.0
var _lamp_colour := Color.BLACK
var _lamp_fade: Tween

func configure(host: Node3D,visual: Node3D,at: Vector2) -> void:
	world = host
	model = visual
	_bind_red_lamps()
	position = at*world.CELL_PIXELS
	motion = host.ensure_crawler_motion()
	if is_instance_valid(motion): motion.set_arena(self)
	collision_layer = 0 if is_instance_valid(motion) else 2 | 16
	collision_mask = 0
	add_to_group(&"dream_enemies")
	set_meta(&"dream_room_id",0)
	set_meta(&"content_kind",&"boss")
	if not is_instance_valid(motion):
		var collider := CollisionShape2D.new()
		var hull := CircleShape2D.new()
		hull.radius = 1.5*world.CELL_PIXELS
		collider.shape = hull
		add_child(collider)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 2.3
	mesh.outer_radius = 2.55
	mesh.rings = 36
	mesh.ring_segments = 6
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("ff6645")
	warning = MeshInstance3D.new()
	warning.name = "TargetWarning"
	warning.mesh = mesh
	warning.material_override = ring_material
	warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.floor_root.add_child(warning)
	warning.hide()
	if world.get_meta(&"h06_boss_patterns",true) and is_instance_valid(motion):
		attacks=ATTACKS.new()
		attacks.configure(self)

func _bind_red_lamps() -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original==null or original.resource_name!="M_Emissive_Red": continue
			if red_lamp_material==null:
				# All four emissive surfaces share one material inside this boss only.
				red_lamp_material = original.duplicate() as StandardMaterial3D
				_lamp_energy = original.emission_energy_multiplier
				_lamp_colour = original.albedo_color
			mesh.set_surface_override_material(surface,red_lamp_material)

func set_stun_lamps(stunned: bool) -> void:
	if not dead: _fade_red_lamps(.18 if stunned else 1.0,.14 if stunned else .19)

func _fade_red_lamps(level: float, seconds: float) -> void:
	if red_lamp_material==null: return
	if _lamp_fade!=null and _lamp_fade.is_valid(): _lamp_fade.kill()
	_lamp_fade = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lamp_fade.tween_property(red_lamp_material,"emission_energy_multiplier",_lamp_energy*level,seconds)
	_lamp_fade.tween_property(red_lamp_material,"albedo_color",_lamp_colour.darkened(1.0-level),seconds)

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(world) or world.player.dead: return
	if attacks!=null:
		attacks.advance(delta)
		return
	var target: Vector2 = world.player.body_collision.global_position/world.CELL_PIXELS
	var origin := Vector2(model.position.x,model.position.z)
	var direction := origin.direction_to(target)
	if is_instance_valid(motion):
		# Move between attacks; planted feet also reposition when turning to face the player.
		var destination := origin
		if not winding and origin.distance_to(target)>5.6:
			destination = origin.move_toward(target,delta*2.3)
			var safe := world.PLAN.ARENA_DECK.grow(-world.PLAN.CRAWLER_RADIUS-.15) as Rect2
			destination = destination.clamp(safe.position,safe.end)
		motion.move_toward_point(Vector3(destination.x,0,destination.y),delta,target)
		position = motion.position
		origin = Vector2(model.position.x,model.position.z)
	else:
		model.rotation.y = lerp_angle(model.rotation.y,atan2(direction.x,direction.y),1.0-exp(-delta*4.0))
		return_y = move_toward(return_y,0,delta*1.9)
		model.position.y = return_y
	wait -= delta
	if wait > 0: return
	if not winding:
		aim = target
		winding = true
		wait = .8 if volley else 1.05
		warning.position = Vector3(aim.x,.045,aim.y)
		warning.scale = Vector3(.48,.11,.48) if volley else Vector3(1,.16,1)
		warning.show()
		world.SFX.play_world_sfx_3d(&"enemy_fire_cue",model.global_position)
	else:
		warning.hide()
		if volley:
			var heading := origin.direction_to(aim)
			for angle: float in [-.14,0.0,.14]:
				var bullet: Node2D = SHOT.instantiate()
				var dir := heading.rotated(angle)
				bullet.position = (origin+dir*1.8)*world.CELL_PIXELS
				RULES.setup_projectile(bullet,dir,12,29*world.CELL_PIXELS,340,&"enemy",self,&"assault_rifle")
				world.add_projectile(bullet,self)
		else:
			return_y = .22
			world.request_camera_impulse(&"heavy",direction)
			world.SFX.play_world_sfx_3d(&"wall_break",Vector3(aim.x,.2,aim.y))
			if target.distance_to(aim)<=2.45:
				world.player.receive_damage(25,&"h06_stomp",aim*world.CELL_PIXELS,direction)
		volley = not volley
		winding = false
		wait = 1.5

func blocks_projectile_penetration(at: Vector2, direction: Vector2, height: float) -> bool:
	return not dead and attacks != null and attacks.blocks_projectile_penetration(at, direction, height)

func take_damage(amount: float,hit_at: Vector2=Vector2.ZERO,_force: float=1.0,source: StringName=&"") -> void:
	if dead or amount <= 0: return
	if attacks != null:
		amount *= attacks.damage_factor(hit_at, source)
	var previous_health := current_health
	current_health = maxf(0,current_health-amount)
	var ratio := current_health/MAX_HEALTH
	if attacks != null:
		var player_hit := String(source).begins_with("player_") or source in [&"lucille", &"books"]
		attacks.health_changed(ratio, previous_health-current_health if player_hit else 0.0)
	health_changed.emit(ratio)
	if current_health > 0: return
	dead = true
	_fade_red_lamps(.035,.32)
	if attacks!=null:attacks.stop()
	if is_instance_valid(motion): motion.disable()
	collision_layer = 0
	warning.hide()
	remove_from_group(&"dream_enemies")
	defeated.emit()

func _exit_tree() -> void:
	if attacks!=null:attacks.stop()
