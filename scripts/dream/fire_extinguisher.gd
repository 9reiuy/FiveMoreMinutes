extends CharacterBody2D
## Gameplay owner. Hanging and spent cylinders remain shootable cover; only
## the five-second gas-powered flight can damage enemies.
const MAX_HP:=20.0
const SPEED:=560.0
const MAX_BOUNCES:=7
const PERF=preload("res://scripts/app/performance_markers.gd")
var world: Node3D
var controller: Node3D
var hp:=MAX_HP
var broken:=false
var flying:=false
var flight_age:=0.0
var bounces:=0
var inward:=Vector2.DOWN
var visual: Node3D
var contacts: Dictionary={}
var gas_emit_left:=0.0
var paint_material: ShaderMaterial
var palette_check_left:=0.0
var gas_source_id:=0
var emission_stopped:=false
var smoke_silhouette:=false

func _ready() -> void:
	add_to_group(&"fire_extinguishers")
	add_to_group(&"damageable_props")
	collision_layer=8
	collision_mask=1|4
	var collider:=CollisionShape2D.new()
	collider.name="CollisionShape2D"
	var circle:=CircleShape2D.new()
	circle.radius=6
	collider.shape=circle
	add_child(collider)
	visual=preload("res://scripts/dream/fire_extinguisher_model.gd").build()
	controller.add_child(visual)
	var mesh: MeshInstance3D=visual.get_child(0)
	var paint: ShaderMaterial=mesh.mesh.surface_get_material(1).duplicate()
	paint_material=paint
	paint.set_shader_parameter("preserve_red",world.get_viewport().get_node_or_null("WorldPaletteLayer")!=null)
	mesh.set_surface_override_material(1,paint)
	_sync_visual()

func is_damage_runtime_active() -> bool:return not broken
func get_projectile_blocking_height() -> float:return 2.0 if not broken else .6
func get_projectile_blocking_rect(_height: float) -> Rect2:return Rect2(-8,-8,16,16)
func take_damage(amount: float,direction:=Vector2.ZERO,_force:=1.0) -> void:
	if broken or amount<=0:return
	hp=maxf(0,hp-amount)
	if hp>0:return
	broken=true
	flying=true
	emission_stopped=false
	velocity=(direction.normalized() if direction.length_squared()>.001 else inward)*SPEED
	gas_source_id=controller.discharge(global_position)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or world.floor_transition_in_progress:return
	palette_check_left-=delta
	if palette_check_left<=0:
		palette_check_left=.25
		_sync_paint()
	if not flying:return
	if flying:
		var diagnostic_started:=PERF.begin(self)
		advance_flight(delta)
		PERF.end(self,"extinguisher_flight",diagnostic_started)
	_sync_visual()

func advance_flight(delta: float) -> void:
	if not flying:return
	flight_age+=delta
	if flight_age>=5.0:stop_flight();return
	gas_emit_left-=delta
	if not emission_stopped and gas_emit_left<=0.0:
		gas_emit_left=.035
		controller.emit_jet(global_position,-velocity.normalized())
	var remaining:=velocity*delta
	for step in 4:
		var from:=global_position
		var collision:=move_and_collide(remaining)
		if not emission_stopped:controller.emit_trail(from,global_position,gas_source_id)
		_hit_enemies(from,global_position)
		if collision==null:break
		bounce(collision.get_normal())
		if not flying:break
		remaining=collision.get_remainder().bounce(collision.get_normal())
		if remaining.length_squared()<.001:break
	# Never allow a cylinder to become an infinite exterior projectile.
	if not world.floor_cells.has(world._cell_for_gameplay_position(global_position)):stop_flight()

func bounce(normal: Vector2) -> void:
	if not flying:return
	bounces+=1
	if not emission_stopped:
		emission_stopped=true
		PERF.event(self,"extinguisher_emission_stopped",{"source":gas_source_id,"bounces":bounces})
	PERF.event(self,"extinguisher_bounce",{"bounces":bounces,"x":global_position.x,"y":global_position.y})
	if bounces>=MAX_BOUNCES:stop_flight();return
	velocity=velocity.bounce(normal).normalized()*SPEED

func stop_flight() -> void:
	PERF.event(self,"extinguisher_stopped",{"age":flight_age,"bounces":bounces})
	flying=false
	emission_stopped=true
	velocity=Vector2.ZERO
	contacts.clear()

func _hit_enemies(from: Vector2,to: Vector2) -> void:
	var shape:=CapsuleShape2D.new()
	shape.radius=9
	shape.height=from.distance_to(to)+18
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D((to-from).angle()-PI*.5,(from+to)*.5)
	query.collision_mask=16
	query.collide_with_areas=true
	query.collide_with_bodies=true
	var touching: Dictionary={}
	for hit in get_world_2d().direct_space_state.intersect_shape(query,32):
		var target: Node=hit.collider
		if target.has_method("get_damage_owner"):target=target.call("get_damage_owner")
		if not is_instance_valid(target) or not target.is_in_group(&"dream_enemies") or target.get("dead")==true:continue
		if target.get("drone")!=null:continue # The ground cylinder cannot hit an airborne drone.
		var id:=target.get_instance_id()
		touching[id]=true
		if contacts.has(id):continue
		if target.has_method("take_damage"):target.call("take_damage",10.0,from,.35,&"extinguisher")
	contacts=touching

func _sync_visual() -> void:
	if not is_instance_valid(visual):return
	_sync_paint()
	var height:=1.25 if not broken else (.40+.5*maxf(0,1.0-flight_age/.5) if flying else .24)
	visual.global_position=world.get_gameplay_world_position(global_position,height)
	visual.rotation=Vector3(0,atan2(inward.x,inward.y),0) if not broken else Vector3(flight_age*12.0,flight_age*5.0,PI*.5)

func _sync_paint() -> void:
	if paint_material==null:return
	var enabled:=world.get_viewport().get_node_or_null("WorldPaletteLayer")!=null
	if paint_material.get_shader_parameter("preserve_red")!=enabled:paint_material.set_shader_parameter("preserve_red",enabled)

func set_smoke_silhouette(enabled: bool) -> void:
	if smoke_silhouette==enabled or not is_instance_valid(visual):return
	smoke_silhouette=enabled
	var mesh:=visual.get_child(0) as MeshInstance3D
	if enabled:
		var black:=StandardMaterial3D.new()
		black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;black.albedo_color=Color.BLACK
		black.render_priority=8
		black.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_overlay=black
	else:mesh.material_overlay=null

func _notification(what: int) -> void:
	# Floor rollback reparents the gameplay owner without deleting it. Only
	# actual deletion may retire its separately floor-owned visual.
	if what==NOTIFICATION_PREDELETE and is_instance_valid(visual):visual.queue_free()
