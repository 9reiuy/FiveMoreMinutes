extends Node3D
## Two crane drops on the moving lift. The real landing footprints become shot and movement cover.
signal event(kind: StringName, data: Dictionary)

const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const FREIGHT := preload("res://scripts/testing/h06_chapter/freight_art.gd")
const MOTION := preload("res://scripts/testing/h06_chapter/crawler_motion.gd")
const BURN := preload("res://scripts/dream/burning_effects.gd")
const FOOTPRINTS := [Vector2(3.8,2.4),Vector2(2.4,3.8)]
const TINTS := ["slate","ochre"]
const FIREARMS := ["basic","assault_rifle","mp5","shotgun"]
const HEIGHT := 2.62
const START_HEIGHT := 9.8
const WARNING_TIME := .40
const STAGGER := 1.40
const BOUNCE_TIME := .22
enum Phase { WAITING, AIRBORNE, LANDED, BROKEN }

class Drop:
	var rect := Rect2()
	var tint := ""
	var phase := Phase.WAITING
	var age := 0.0
	var model: Node3D
	var warning: Node3D
	var crane: Node3D
	var body: StaticBody2D
	var footprint: RectangleShape2D

var world: Node3D
var drops: Array[Drop] = []
var debris: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var released := false

func prepare_slot(art, index: int) -> void:
	world = art.world
	name = "H06CargoDrop"
	set_process(false)
	if index==0: random.randomize()
	var drop := Drop.new()
	var size: Vector2 = FOOTPRINTS[index]
	drop.rect = Rect2(-size*.5,size)
	drop.tint = TINTS[index]
	drop.model = FREIGHT.spawn_functional_cargo_module(self,art.fittings,"arena_container",
		Vector3.ZERO,Vector3(size.x,HEIGHT,size.y),0.,drop.tint,drop.tint,null,false,true)
	drop.model.name = "CraneContainer%d"%(index+1)
	drop.crane = drop.model.get_node(^"CraneSpreaderRig")
	drop.model.hide()
	art.cutout.register_tree(drop.model,true)
	drop.warning = FREIGHT.build_holographic_warning_zone(self,drop.rect,true)
	drop.body = art._dynamic_freight_body("H06Cargo%d"%(index+1),drop.rect,false)
	drop.body.set_meta(&"shot_height_pixels",HEIGHT*MOTION.PIXELS)
	drop.footprint = (drop.body.get_child(0) as CollisionShape2D).shape
	drops.append(drop)

func release(mech_at: Vector2) -> void:
	if released: return
	released = true
	var allowed := PLAN.ARENA_DECK.grow(-2.65)
	var first := (mech_at+Vector2.from_angle(random.randf_range(0.,TAU))
		*random.randf_range(1.3,4.7)).clamp(allowed.position,allowed.end)
	# The second drop lands across the deck with an open route between the two footprints.
	var left_side := first.x>=allowed.get_center().x
	var x := random.randf_range(allowed.position.x,allowed.get_center().x-6.0) if left_side else (
		random.randf_range(allowed.get_center().x+6.0,allowed.end.x))
	var second := Vector2(x,random.randf_range(allowed.position.y,allowed.end.y))
	for index in drops.size():
		var drop := drops[index]
		var center := first if index==0 else second
		drop.rect.position = center-drop.rect.size*.5
		drop.body.position = center*MOTION.PIXELS
		drop.model.position = Vector3(center.x,START_HEIGHT,center.y)
		drop.warning.position = Vector3(center.x,.036,center.y)
		drop.age = -.03-float(index)*STAGGER

func advance(delta: float, motion: MOTION) -> bool:
	if not released: return false
	var hit_mech := false
	for drop in drops:
		if drop.phase==Phase.BROKEN: continue
		drop.age += delta
		if drop.phase==Phase.WAITING:
			if drop.age<0.: continue
			drop.phase = Phase.AIRBORNE
			drop.warning.show()
			drop.model.show()
			var at := drop.rect.get_center()
			world.SFX.play_world_sfx_3d(&"enemy_fire_cue",to_global(Vector3(at.x,1.,at.y)),.8,34.)
			event.emit(&"cargo_warning",{"at":at,"body":drop.body.name})
		if drop.phase==Phase.AIRBORNE:
			hit_mech = _fall(drop,motion) or hit_mech
		elif drop.age<BOUNCE_TIME+delta:
			var t := clampf(drop.age/BOUNCE_TIME,0.,1.)
			drop.model.position.y = HEIGHT*.5+sin(t*PI)*.16*(1.-t*.3)
			drop.model.rotation.z = sin(t*TAU)*.045*(1.-t)
	return hit_mech

func _fall(drop: Drop, motion: MOTION) -> bool:
	var fall_time := drop.age-WARNING_TIME
	if fall_time<0.:
		drop.model.position.y = START_HEIGHT-drop.age*.9
		return false
	drop.crane.hide()
	drop.model.position.y = maxf(HEIGHT*.5,START_HEIGHT-.36-6.8*fall_time-13.*fall_time*fall_time)
	drop.model.rotation.z = sin(drop.model.position.y*.5)*.035
	var bottom := drop.model.position.y-HEIGHT*.5
	var at := drop.rect.get_center()
	if _strikes_mech(drop,motion,bottom):
		_impact(at)
		_break(drop,Vector2(motion.model.position.x,motion.model.position.z),&"cargo_fall")
		return true
	if bottom>0.: return false
	_impact(at)
	drop.warning.hide()
	drop.phase = Phase.LANDED
	drop.age = 0.0
	var truck = world.blockout.forklift
	if (is_instance_valid(truck) and truck.is_damage_runtime_active()
			and drop.rect.grow(.88).has_point(truck.global_position/MOTION.PIXELS)):
		_break(drop,at,&"cargo_floor")
		return false
	_clear_player(drop.rect)
	world.blockout.set_freight_body_enabled(drop.body,true)
	event.emit(&"cargo_landed",{"at":at,"body":drop.body.name})
	return false

func _strikes_mech(drop: Drop, motion: MOTION, bottom: float) -> bool:
	var mech_height: float = motion.model.position.y
	if bottom>mech_height+2.5 or bottom+HEIGHT<mech_height: return false
	var transform_2d := drop.body.global_transform
	if drop.footprint.collide(transform_2d,motion.hull.shape,motion.hull.global_transform):
		return true
	if bottom>mech_height+1.1: return false
	for limb in motion.leg_shapes:
		for segment: CollisionShape2D in limb:
			if drop.footprint.collide(transform_2d,segment.shape,segment.global_transform): return true
	return false

func _clear_player(footprint: Rect2) -> void:
	var feet: Vector2 = world._feet()
	var margin := footprint.grow(.48)
	if not margin.has_point(feet): return
	var adjacent := [Vector2(margin.position.x-.10,feet.y),Vector2(margin.end.x+.10,feet.y),
		Vector2(feet.x,margin.position.y-.10),Vector2(feet.x,margin.end.y+.10)]
	var nearest := INF
	var safe := feet
	for candidate: Vector2 in adjacent:
		var distance := feet.distance_squared_to(candidate)
		if PLAN.ARENA_DECK.grow(-.32).has_point(candidate) and distance<nearest:
			nearest = distance
			safe = candidate
	world._place_feet(safe)

func _impact(at: Vector2) -> void:
	var effects: Node3D = BURN.install(world).effects
	var contact := to_global(Vector3(at.x,.28,at.y))
	effects.emit_smoke(effects.to_local(contact),14,1.25)
	world.SFX.play_world_sfx_3d(&"container_impact",contact,0.0,34.)
	world.blockout.inclined_lift.shake_on_landing()
	world.request_camera_impulse(&"medium",Vector2.DOWN)

func break_body(body: Object, origin: Vector2, source: StringName) -> bool:
	for drop in drops:
		if drop.phase==Phase.LANDED and drop.body==body:
			_break(drop,origin,source)
			return true
	return false

func break_in_radius(at: Vector2, radius: float, source: StringName) -> void:
	for drop in drops:
		if drop.phase!=Phase.LANDED: continue
		var nearest := at.clamp(drop.rect.position,drop.rect.end)
		if at.distance_squared_to(nearest)<=radius*radius: _break(drop,at,source)

func break_in_area(area: Rect2, origin: Vector2, source: StringName) -> void:
	for drop in drops:
		if drop.phase==Phase.LANDED and area.intersects(drop.rect): _break(drop,origin,source)

func _break(drop: Drop, origin: Vector2, source: StringName) -> void:
	drop.phase = Phase.BROKEN
	drop.model.hide()
	drop.warning.hide()
	world.blockout.set_freight_body_enabled(drop.body,false)
	var at := drop.rect.get_center()
	var direction := origin.direction_to(at)
	if direction==Vector2.ZERO: direction = Vector2.DOWN
	var contact := Vector3(at.x,drop.model.position.y,at.y)
	var effects: Node3D = BURN.install(world).effects
	effects.emit_smoke(effects.to_local(to_global(contact)),13,1.36)
	FREIGHT.spawn_container_debris(self,contact-Vector3.UP*(HEIGHT*.5),direction,
		Vector3(drop.rect.size.x,HEIGHT,drop.rect.size.y),drop.tint,debris,true)
	set_process(true)
	# A falling load striking the crawler has no separate floor-impact callback.
	# A floor hit already played _impact before a vehicle underneath broke it.
	if source!=&"cargo_floor":
		world.SFX.play_world_sfx_3d(&"container_impact" if source==&"cargo_fall" else &"wall_break",to_global(contact),0.0 if source==&"cargo_fall" else 1.25,36.)
	var weapon: String = FIREARMS[random.randi_range(0,FIREARMS.size()-1)]
	var safe := PLAN.ARENA_DECK.grow(-.75)
	var position := (at+direction*.52).clamp(safe.position,safe.end)
	var request := {"weapon_id":weapon,"position":position*MOTION.PIXELS,
		"impulse":Vector2.ZERO,"skin_index":0,"room_id":0,"from_pit":false,
		"floor_token":world.get_current_floor_token(),"root":weakref(world.world_weapon_root)}
	world._commit_employee_weapon_drop.call_deferred(request)
	event.emit(&"cargo_broken",{"at":at,"body":drop.body.name,"source":source,"weapon":weapon})

func _process(delta: float) -> void:
	FREIGHT.tick_container_debris(delta,debris,PLAN.ARENA_DECK)
	if debris.is_empty(): set_process(false)

func finish() -> void:
	for drop in drops:
		if drop.phase in [Phase.WAITING,Phase.AIRBORNE]:
			drop.phase = Phase.BROKEN
			drop.model.hide()
			drop.warning.hide()
