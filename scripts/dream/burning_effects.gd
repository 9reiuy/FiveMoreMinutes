extends Node3D
## One floor-owned gameplay controller; visuals stay in the reusable particle module.
const EFFECTS=preload("res://scripts/dream/elemental_particles_3d.gd")
const DURATION:=5.0
const DAMAGE_FRACTION:=.10
const CONTACT_RADIUS:=26.0
const MAX_BURNING:=32
var world: Node3D
var effects: Node3D
var burning: Dictionary={}
var spread_left:=0.0
var hazards: Array[Dictionary]=[]

static func install(owner_world: Node3D) -> Node3D:
	var host: Node=owner_world.get("floor_root")
	if not is_instance_valid(host): host=owner_world
	var existing:=host.get_node_or_null("BurningEffects")
	if existing!=null:return existing as Node3D
	var controller:=load("res://scripts/dream/burning_effects.gd").new() as Node3D
	controller.name="BurningEffects"
	host.add_child(controller)
	controller.configure(owner_world)
	return controller

func configure(owner_world: Node3D) -> void:
	world=owner_world
	effects=EFFECTS.new()
	effects.fire_limit=MAX_BURNING
	add_child(effects)
	_sync_palette()

func clear() -> void:
	for id in burning.keys():
		remove_burn(id)
	burning.clear()
	hazards.clear()
	if is_instance_valid(effects) and effects.has_method("clear"):
		effects.clear()

func _sync_palette() -> void:
	if is_instance_valid(world):
		effects.preserve_flame_colors=world.get_viewport().get_node_or_null("WorldPaletteLayer")!=null

func canonical(target: Node) -> Node:
	if not is_instance_valid(target):return null
	var drone: Variant=target.get("drone")
	return drone if is_instance_valid(drone) else target

func immune(target: Node) -> bool:
	if target.has_method("is_burning_immune") and target.call("is_burning_immune"):return true
	return target.is_in_group(&"bosses") or target.is_in_group(&"dream_bosses") or bool(target.get_meta(&"is_boss",false)) or target.get("boss_variant")==true or target.get("is_boss")==true or (is_instance_valid(world) and world.get("boss_enemy")==target)

func maximum(target: Node) -> float:
	for key in [&"maximum_health",&"max_health",&"max_hp"]:
		var value: Variant=target.get(key)
		if value is float or value is int:return maxf(float(value),0)
	if target.get("hp")!=null and target.get_script()!=null:
		var constants: Dictionary=target.get_script().get_script_constant_map()
		if constants.has("MAX_HP"):return float(constants.MAX_HP)
	return 0.0

func alive(target: Node) -> bool:
	return is_instance_valid(target) and target.can_process() and not target.is_queued_for_deletion() and target.get("dead")!=true and target.get("_dead")!=true and target.get("destroyed")!=true

func ignite(target: Node) -> bool:
	target=canonical(target)
	if not alive(target) or immune(target) or maximum(target)<=0.0:return false
	if smoke_protected(target):return false
	var id:=target.get_instance_id()
	if burning.has(id):burning[id].left=DURATION;return true
	if burning.size()>=MAX_BURNING:return false
	var profile:=burn_profile(target)
	var fire_id: int=effects.emit_fire(to_local(visual_position(target)),float(profile.radius))
	if fire_id>=0:
		effects.fires[fire_id].extent=profile.extent
		effects.fires[fire_id].yaw=world.global_rotation.y-global_rotation.y
	burning[id]={"ref":weakref(target),"left":DURATION,"tick":0.0,"fire":fire_id}
	if target.has_method("set_burning_panic"):target.call("set_burning_panic",true)
	return true

func remove_burn(id: int) -> void:
	if not burning.has(id):return
	var target: Node=burning[id].ref.get_ref()
	if is_instance_valid(target) and target.has_method("set_burning_panic"):target.call("set_burning_panic",false)
	effects.stop_fire(int(burning[id].fire))
	burning.erase(id)

func flat_position(target: Node) -> Vector2:
	if target is Node2D:return target.global_position
	var point: Vector3=world.to_local(target.global_position)
	return Vector2(point.x,point.z)*32.0

func visual_position(target: Node) -> Vector3:
	if target is Node3D:return target.global_position+Vector3.UP*.15
	var point:=flat_position(target)
	var height:=.45
	var visual: Variant=target.get("visual")
	# A solid delivery robot hides a fire emitted inside its lower hull. Start
	# at its upper body instead; gameplay contact still uses the ground shape.
	if is_instance_valid(visual) and visual is Node3D:height=1.15
	if target.get("max_hp")!=null:height=float(burn_profile(target).height)
	return world.get_gameplay_world_position(point,height)

func burn_profile(target: Node) -> Dictionary:
	var extent:=Vector2(.36,.28)
	var height:=.45
	if target.has_method("get_gameplay_footprint_half_extents"):
		extent=target.call("get_gameplay_footprint_half_extents")/32.0
		var catalog=preload("res://scripts/dream/office_furniture_catalog.gd")
		var size: Vector3=catalog.size_of(catalog.resolved_kind(target))
		height=clampf(size.y*.85,.25,2.2)
		extent*=.85
	elif target is Node3D:extent=Vector2(.62,.45)
	elif target.get("hp")!=null:extent=Vector2(.60,.48)
	extent=extent.clamp(Vector2(.22,.18),Vector2(2.1,1.5))
	return {"extent":extent,"radius":clampf(sqrt(extent.x*extent.y)*sqrt(maxf(height,.5)),.30,1.5),"height":height}

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_instance_valid(world) or world.get("floor_transition_in_progress")==true:return
	_sync_palette()
	for index in range(hazards.size()-1,-1,-1):
		hazards[index].left-=delta
		if float(hazards[index].left)<=0.0:hazards.remove_at(index)
	for id in burning.keys():
		var target: Node=burning[id].ref.get_ref()
		if not alive(target) or immune(target):remove_burn(id);continue
		var record: Dictionary=burning[id]
		var fire_id:=int(record.fire)
		if fire_id>=0 and effects.fires.has(fire_id):effects.fires[fire_id].at=effects.to_local(visual_position(target))
		var elapsed:=minf(delta,float(record.left))
		record.tick+=elapsed
		record.left-=delta
		while float(record.tick)>=1.0 and alive(target):
			record.tick-=1.0
			apply_tick(target)
		if not alive(target) or float(record.left)<=0.0:remove_burn(id)
	spread_left-=delta
	if spread_left<=0.0:
		spread_left=.25
		spread()

func apply_tick(target: Node) -> void:
	if not alive(target) or immune(target):return
	if smoke_protected(target):return
	var damage:=maximum(target)*DAMAGE_FRACTION
	if target.is_in_group(&"dream_player"):
		target.call("receive_damage",damage,&"burning",Vector2.INF,Vector2.ZERO)
	elif target.get("max_hp")!=null:
		target.call("take_damage",damage,Vector2.ZERO,0.0)
	elif target.has_method("take_damage"):
		target.call("take_damage",damage,flat_position(target),0.0,&"burning")

func spread() -> void:
	if burning.is_empty() and hazards.is_empty():return
	var sources: Array=[]
	for record in burning.values():
		var source: Node=record.ref.get_ref()
		if alive(source):sources.append(source)
	var candidates: Array=[]
	for group in [&"dream_player",&"dream_enemies",&"damageable_props"]:
		candidates.append_array(get_tree().get_nodes_in_group(group))
	for candidate in candidates:
		var target:=canonical(candidate)
		if not alive(target) or immune(target) or maximum(target)<=0:continue
		# Only actual furniture (max_hp) joins props, not glass or doors.
		if candidate.is_in_group(&"damageable_props") and target.get("max_hp")==null:continue
		for source in sources:
			if source==target:continue
			if contact_distance(flat_position(source),target)>CONTACT_RADIUS:continue
			if absf(visual_position(source).y-visual_position(target).y)>1.5:continue
			if _contact_clear(source,target):ignite(target);break
		for hazard in hazards:
			var at: Vector3=hazard.at
			var mapped: Vector3=world.to_local(at)
			var flat:=Vector2(mapped.x,mapped.z)*32.0
			if contact_distance(flat,target)>40.0 or absf(at.y-visual_position(target).y)>1.5:continue
			if _point_clear(flat,target):ignite(target);break

func contact_distance(point: Vector2,target: Node) -> float:
	if target.has_method("distance_to_hurtbox"):return float(target.call("distance_to_hurtbox",point))
	if target.has_method("get_gameplay_footprint_half_extents"):
		var half: Vector2=target.call("get_gameplay_footprint_half_extents")
		var center: Vector2=target.call("get_gameplay_footprint_center")
		return point.distance_to(point.clamp(center-half,center+half))
	return point.distance_to(flat_position(target))

func _point_clear(point: Vector2,target: Node) -> bool:
	var query:=PhysicsRayQueryParameters2D.create(point,flat_position(target),1|4)
	if target is CollisionObject2D:query.exclude=[target.get_rid()]
	var gameplay: Node2D=world.get("gameplay_world")
	return gameplay==null or gameplay.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _contact_clear(source: Node,target: Node) -> bool:
	var query:=PhysicsRayQueryParameters2D.create(flat_position(source),flat_position(target),1|4)
	var excludes: Array[RID]=[]
	for actor in [source,target]:
		if actor is CollisionObject2D:excludes.append(actor.get_rid())
	query.exclude=excludes
	var gameplay: Node2D=world.get("gameplay_world")
	return gameplay==null or gameplay.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func muzzle(at: Vector3,direction: Vector3) -> void:
	_sync_palette()
	effects.emit_muzzle(effects.to_local(at),effects.global_basis.inverse()*direction)

func explosion(at: Vector3) -> void:
	_sync_palette()
	effects.explode(effects.to_local(at),1.65)
	if hazards.size()<16:hazards.append({"at":at,"left":.65})

func smoke_protected(target: Node) -> bool:
	if not is_instance_valid(world):return false
	var system: Node=world.floor_root.get_node_or_null("FireExtinguisherSystem")
	return system!=null and system.contains(flat_position(target))
