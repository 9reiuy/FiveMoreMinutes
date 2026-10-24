extends Node
## Approved GPU motes shared by the independent review and floor-owned gameplay.
const DUST_SHADER=preload("res://shaders/dream3d/preview/indoor_pixel_dust.gdshader")
const LIMIT:=192
const ROOM_LIMIT:=28
var world: Node3D
var pool: Node3D
var source_floor: WeakRef
var material: ShaderMaterial
var records: Array[Dictionary]=[]
var elapsed:=0.0
var enabled:=true
var built_seed:=-1
var last_update_usec:=0
var update_samples:=0
var update_total_usec:=0
var rng:=RandomNumberGenerator.new()
var production_mode:=false
var build_usec:=0

static func install(owner_world: Node3D) -> Node:
	# Only formal random office worlds opt in. Reception/tutorial/bedroom do not.
	if owner_world.get("use_native_office_skeletons")==null or owner_world.get("use_authored_office_sample")==true: return null
	var floor: Node=owner_world.get("floor_root")
	if not is_instance_valid(floor): return null
	var existing:=floor.get_node_or_null("IndoorDust")
	if is_instance_valid(existing): return existing
	var component: Node=load("res://scripts/dream/preview/sample_indoor_dust.gd").new()
	component.name="IndoorDust"; component.world=owner_world; component.production_mode=true
	floor.add_child(component)
	return component

func _ready() -> void:
	if world==null: world=get_parent()
	# Explicit opt-in scene placement, with a second authored-map guard.
	if not production_mode and not world.get("use_authored_office_sample"): set_process(false); return
	if production_mode: rebuild(true) # Prewarm while loading, not after control returns.

func set_enabled(value: bool) -> void:
	enabled=value
	if is_instance_valid(pool): pool.visible=enabled and _active()

func _active() -> bool:
	return is_instance_valid(world) and is_instance_valid(world.get("floor_root")) and world.floor_root.is_inside_tree() and (not production_mode or get_parent()==world.floor_root) and world.get("floor_transition_in_progress")!=true and world.get("elevator_transition_in_progress")!=true and (not production_mode or world.get("transition_phase")==&"IDLE")

func _process(delta: float) -> void:
	var start:=Time.get_ticks_usec()
	if not _active():
		if is_instance_valid(pool): pool.hide()
		return
	if source_floor==null or source_floor.get_ref()!=world.floor_root or not is_instance_valid(pool) or built_seed!=world.active_seed: rebuild()
	if not is_instance_valid(pool): return
	pool.visible=enabled
	if enabled:
		elapsed+=delta
		material.set_shader_parameter("dust_clock",elapsed)
	last_update_usec=Time.get_ticks_usec()-start
	update_samples+=1; update_total_usec+=last_update_usec

func rebuild(prewarm: bool=false) -> void:
	if prewarm:
		if not is_instance_valid(world) or not is_instance_valid(world.get("floor_root")) or get_parent()!=world.floor_root: return
	elif not _active(): return
	var started:=Time.get_ticks_usec()
	if is_instance_valid(pool): pool.queue_free()
	records.clear(); elapsed=0; built_seed=world.active_seed
	rng.seed=int(built_seed)^0x174A6D
	source_floor=weakref(world.floor_root)
	pool=Node3D.new(); pool.name="IndoorDustPool" if production_mode else "SampleIndoorDustPool"; world.floor_root.add_child(pool)
	material=ShaderMaterial.new(); material.shader=DUST_SHADER
	material.set_shader_parameter("dust_clock",elapsed)
	var quad:=QuadMesh.new(); quad.size=Vector2.ONE
	var count:=0
	var remaining_rooms: int = world.rooms.size()
	for room in world.rooms:
		remaining_rooms-=1
		if room.get("room_type","")=="elevator" or room.get("archetype","")=="elevator_lobby": continue
		var cells: Array=[]
		for cell in room.get("usable_cells",[]):
			if world.floor_cells.has(cell) and int(world.room_cells.get(cell,-1))==int(room.id): cells.append(cell)
		if cells.is_empty(): continue
		# Local shuffle, never Array.shuffle() / global gameplay RNG.
		for i in range(cells.size()-1,0,-1):
			var other:=rng.randi_range(0,i); var value: Variant=cells[i]; cells[i]=cells[other]; cells[other]=value
		var amount:=mini(LIMIT-count,mini(ROOM_LIMIT,maxi(4,roundi(cells.size()*.12))))
		# Reserve a small share for later rooms/corridors on large random maps.
		if production_mode: amount=mini(amount,maxi(1,LIMIT-count-remaining_rooms*4))
		amount=mini(amount,cells.size())
		if amount<=0: break
		var batch:=MultiMeshInstance3D.new(); batch.name="IndoorDustRoom_%d"%int(room.id)
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.add_child(batch)
		batch.global_position=world.get_gameplay_world_position(Vector2(room.center_cell)*32.0,0)
		var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.use_custom_data=true; mm.mesh=quad; mm.instance_count=amount
		batch.multimesh=mm; batch.material_override=material
		var bounds:=AABB()
		for i in amount:
			var cell: Vector2i=cells[i]
			var start:=Vector2(cell)+Vector2(rng.randf_range(-.07,.07),rng.randf_range(-.07,.07))
			var route:=_choose_route(int(room.id),start)
			var finish: Vector2=route.finish
			var bend: float=route.bend
			var height:=rng.randf_range(.35,1.7)
			var from: Vector3=world.get_gameplay_world_position(start*32.0,height)
			var to: Vector3=world.get_gameplay_world_position(finish*32.0,height)
			var point:=from.lerp(to,.5)
			var local:=batch.to_local(point)
			var trail:=batch.to_local(to)-batch.to_local(from)
			# Billboard shader ignores basis scale and consumes X as the whole path.
			mm.set_instance_transform(i,Transform3D(Basis(trail,Vector3.UP,trail.normalized().cross(Vector3.UP)*bend),local))
			var custom:=Color(rng.randf(),rng.randf(),rng.randf(),rng.randf())
			mm.set_instance_custom_data(i,custom)
			records.append({"cell":cell,"room":int(room.id),"point":point,"start":start,"finish":finish,"bend":bend,"trail":to-from,"side":(to-from).normalized().cross(Vector3.UP)*bend,"custom":custom})
			bounds=bounds.expand(local) if i>0 else AABB(local,Vector3.ZERO)
			bounds=bounds.expand(batch.to_local(from)).expand(batch.to_local(to))
		mm.custom_aabb=bounds.grow(.65)
		count+=amount
	pool.visible=enabled and _active()
	build_usec=Time.get_ticks_usec()-started

func path_inside_room(room_id: int,start: Vector2,finish: Vector2,bend: float=0.0) -> bool:
	var steps:=maxi(1,ceili(start.distance_to(finish)/.10))
	var direction: Vector2=(finish-start).normalized()
	var side:=Vector2(-direction.y,direction.x)*absf(bend)
	for i in range(steps+1):
		var point:=start.lerp(finish,float(i)/steps)
		# Validate the entire bend envelope, including both possible cycle turns.
		for curve in [Vector2.ZERO,side,-side]:
			for offset in [Vector2.ZERO,Vector2(.13,.13),Vector2(-.13,.13),Vector2(.13,-.13),Vector2(-.13,-.13)]:
				var cell:=Vector2i((point+curve+offset).round())
				if not world.floor_cells.has(cell) or int(world.room_cells.get(cell,-1))!=room_id: return false
	return true

func _choose_route(room_id: int,start: Vector2) -> Dictionary:
	var length:=rng.randf_range(1.3,2.4)
	# Full-circle independent headings, never a shared wind-sector preference.
	var angle:=rng.randf_range(0,TAU)
	var bend:=rng.randf_range(.12,.38)*(-1.0 if rng.randf()<.5 else 1.0)
	for direction in [Vector2.from_angle(angle),Vector2.from_angle(angle+PI*.5),Vector2.from_angle(angle-PI*.5),Vector2.from_angle(angle+PI)]:
		for factor in [1.0,.7,.45]:
			var finish: Vector2=start+direction*length*factor
			if path_inside_room(room_id,start,finish,bend): return {"finish":finish,"bend":bend}
	# Safe short fallback for unusually narrow or isolated usable cells.
	var finish:=start+Vector2(.20,0) if path_inside_room(room_id,start,start+Vector2(.20,0),.02) else start-Vector2(.20,0)
	return {"finish":finish,"bend":.02}

## Same analytic state as the shader, for projected-pixel verification.
static func mote_state(record: Dictionary,time: float) -> Dictionary:
	var custom: Color=record.custom
	var speed:=lerpf(.18,.28,custom.g)
	var life:=maxf(2.0,Vector3(record.trail).length()/speed)
	var raw:=time/life+custom.r
	var phase:=fposmod(raw,1.0)
	var cycle:=floorf(raw)
	var direction:=1.0 if sin(cycle*2.399+custom.a*TAU)>=0 else -1.0
	var fade:=smoothstep(0.0,.08,phase)*(1.0-smoothstep(.86,1.0,phase))
	var period:=lerpf(3.2,7.5,custom.a)
	var flash_time:=fposmod(time+custom.a*11.31,period)
	var glint:=pow(maxf(0,1.0-absf(flash_time-period*.55)/.10),1.2)*fade
	var turn:=sin(phase*PI)*(.65+.35*sin(phase*lerpf(PI*1.2,PI*2.8,custom.a)+custom.a*TAU))
	var point: Vector3=record.point+record.trail*(phase-.5)*direction+record.side*turn*direction+Vector3.UP*(phase-.5)*.18
	return {"position":point,"phase":phase,"glint":glint,"life":life,"speed":speed}

func _unhandled_key_input(event: InputEvent) -> void:
	if production_mode: return # F8 remains an independent-review control only.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		set_enabled(not enabled); get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Stash/rollback reparents the floor: exiting is not destruction.
	if is_instance_valid(pool):
		if production_mode: pool.hide()
		else: pool.queue_free()

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and is_instance_valid(pool): pool.queue_free()
