extends Node3D
## Reusable, visual-only fire/explosion/smoke. Coordinates and wind are LOCAL
## to this floor-owned node. No damage, physics bodies, audio or global RNG.
const PARTICLE_SHADER = preload("res://shaders/dream3d/elemental_particle.gdshader")
const OUTLINE_SHADER = preload("res://shaders/dream3d/elemental_particle_outline.gdshader")
const LIMIT := 384
const MAX_FIRES := 8
const MAX_LIGHTS := 4
var wind := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var fires: Dictionary = {}
var banks: Array[MultiMesh] = []
var outline_banks: Array[MultiMesh] = []
var outline_materials: Array[ShaderMaterial] = []
var lights: Array[OmniLight3D] = []
var next_id := 1
var dropped := 0
var clock := 0.0
var preserve_flame_colors := false
var fire_limit := MAX_FIRES
var emission_cursor := 0
var shockwaves: Array[Dictionary] = []
const WAVE_SHADER=preload("res://shaders/dream3d/elemental_shockwave.gdshader")

func _ready() -> void:
	rng.randomize()
	_build()

func _build() -> void:
	if not banks.is_empty(): return
	for kind in 3:
		var material := ShaderMaterial.new()
		material.shader = PARTICLE_SHADER
		material.render_priority=-1
		material.set_shader_parameter("particle_kind",kind)
		var mesh := QuadMesh.new()
		mesh.size=Vector2.ONE
		mesh.material=material
		var bank:=MultiMesh.new()
		bank.transform_format=MultiMesh.TRANSFORM_3D
		bank.use_colors=true
		bank.mesh=mesh
		bank.instance_count=LIMIT
		bank.visible_instance_count=0
		var carrier:=MultiMeshInstance3D.new()
		carrier.name=["FireMass","SmokeMass","Embers"][kind]
		carrier.multimesh=bank
		carrier.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(carrier)
		banks.append(bank)
		var outline_material:=ShaderMaterial.new()
		outline_material.shader=OUTLINE_SHADER
		outline_material.render_priority=-2
		outline_material.set_shader_parameter("particle_kind",kind)
		outline_material.set_shader_parameter("outline_pass",true)
		var outline_mesh:=QuadMesh.new()
		outline_mesh.size=Vector2.ONE
		outline_mesh.material=outline_material
		var outline_bank:=MultiMesh.new()
		outline_bank.transform_format=MultiMesh.TRANSFORM_3D
		outline_bank.use_colors=true
		outline_bank.mesh=outline_mesh
		outline_bank.instance_count=LIMIT
		outline_bank.visible_instance_count=0
		var contour:=MultiMeshInstance3D.new()
		contour.name=String(carrier.name)+"UnionContour"
		contour.multimesh=outline_bank
		contour.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(contour)
		outline_banks.append(outline_bank)
		outline_materials.append(outline_material)
	for index in MAX_LIGHTS:
		var light:=OmniLight3D.new()
		light.light_color=Color("ff9b38")
		light.shadow_enabled=false
		light.omni_range=3.0
		light.visible=false
		add_child(light)
		lights.append(light)

func set_wind(value: Vector3) -> void:
	wind=value.limit_length(6.0) if value.is_finite() else Vector3.ZERO

func emit_fire(at: Vector3, radius: float=0.20, duration: float=-1.0) -> int:
	if not at.is_finite() or fires.size()>=fire_limit: return -1
	var id:=next_id
	next_id+=1
	fires[id]={"at":at,"radius":clampf(radius,.08,1.5),"duration":duration,"heat":0.0,"smoke":0.0,"ember":0.0}
	return id

func stop_fire(id: int) -> void:
	fires.erase(id) # Existing particles finish naturally; no sudden cutoff.


func emit_muzzle(at: Vector3, direction: Vector3) -> void:
	if not at.is_finite() or not direction.is_finite() or direction.length_squared()<.001: return
	var forward:=direction.normalized()
	# A connected bright throat, tapered fire jet, and ballistic hot sparks.
	for index in 12:
		var travel:=float(index)/11.0
		_spawn(0,at+forward*(.05+travel*.60),forward*rng.randf_range(3.5,6.0),lerpf(.38,.13,travel),rng.randf_range(.10,.18),true)
	for index in 8:
		var spread:=Vector3(rng.randf_range(-.45,.45),rng.randf_range(-.15,.40),rng.randf_range(-.45,.45))
		_spawn(2,at+forward*.18,(forward+spread).normalized()*rng.randf_range(5,9),rng.randf_range(.045,.085),rng.randf_range(.14,.28),true)

func emit_smoke(at: Vector3, count: int=12, strength: float=1.0) -> void:
	if not at.is_finite() or not is_finite(strength): return
	strength=clampf(strength,.25,3.0)
	for index in clampi(count,0,64):
		_spawn(1,at+_disk(.18*strength),Vector3(rng.randf_range(-.25,.25),rng.randf_range(.5,1.1),rng.randf_range(-.25,.25)),rng.randf_range(.25,.45)*strength,rng.randf_range(1.6,2.4),false)

func explode(at: Vector3, strength: float=1.0) -> void:
	if not at.is_finite(): return
	strength=clampf(strength,.25,3.0)
	_emit_shockwave(at,strength)
	for index in 44:
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(.05,1),rng.randf_range(-1,1)).normalized()
		_spawn(0,at+_disk(.12),direction*rng.randf_range(1.0,3.5)*strength,rng.randf_range(.30,.60)*strength,rng.randf_range(.30,.65),true)
	for index in 18:
		_spawn(1,at+_disk(.18*strength),Vector3(rng.randf_range(-.5,.5),rng.randf_range(.6,1.2),rng.randf_range(-.5,.5)),rng.randf_range(.3,.5)*strength,rng.randf_range(1.6,2.4),true)
	for index in 26:
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(.3,1.3),rng.randf_range(-1,1)).normalized()
		_spawn(2,at,direction*rng.randf_range(2.0,5.0)*strength,rng.randf_range(.035,.075),rng.randf_range(.6,1.3),true)

func clear() -> void:
	for wave in shockwaves:
		wave.mesh.hide()
		wave.mesh.queue_free()
	shockwaves.clear()
	fires.clear()
	particles.clear()
	for bank in banks: bank.visible_instance_count=0
	for bank in outline_banks: bank.visible_instance_count=0
	for light in lights: light.visible=false

func _disk(radius: float) -> Vector3:
	var angle:=rng.randf()*TAU
	var distance:=sqrt(rng.randf())*radius
	return Vector3(cos(angle)*distance,0,sin(angle)*distance)

func _spawn(kind: int, at: Vector3, velocity: Vector3, size: float, life: float, burst: bool) -> void:
	# Leave room for an explosion even when continuous fire reaches its budget.
	if particles.size()>=(LIMIT if burst else LIMIT-96):
		dropped+=1
		return
	particles.append({"kind":kind,"at":at,"velocity":velocity,"size":size,"life":life,"age":0.0,"burst":burst,"seed":rng.randf()*TAU})

func _process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if delta<=0.0 or not is_finite(delta): return
	# Bounded substeps prevent a long frame from producing an emission storm.
	var remaining:=minf(delta,.2)
	while remaining>0.00001:
		var dt:=minf(remaining,1.0/60.0)
		_advance(dt)
		remaining-=dt
	_upload()

func _advance(dt: float) -> void:
	clock+=dt
	for index in range(shockwaves.size()-1,-1,-1):
		var wave: Dictionary=shockwaves[index]
		wave.age+=dt
		var progress:=float(wave.age)/.42
		if progress>=1.0:
			wave.mesh.queue_free()
			shockwaves.remove_at(index)
			continue
		var radius:=lerpf(.20,3.0*float(wave.strength),1.0-pow(1.0-progress,2))
		wave.mesh.scale=Vector3(radius,1,radius)
		wave.material.set_shader_parameter("progress",progress)
		wave.material.set_shader_parameter("flame_color",Color(1,0,.24) if preserve_flame_colors else Color("ffd151"))
	var fire_ids:=fires.keys()
	for offset in fire_ids.size():
		var id: int=fire_ids[(emission_cursor+offset)%fire_ids.size()]
		var fire: Dictionary=fires[id]
		if float(fire.duration)>=0.0:
			fire.duration-=dt
			if float(fire.duration)<=0.0: fires.erase(id); continue
		fire.heat+=dt*105.0
		fire.smoke+=dt*7.0
		fire.ember+=dt*8.0
		while float(fire.heat)>=1.0:
			fire.heat-=1.0
			var scale_factor:=clampf(sqrt(float(fire.radius)/.30),.8,2.1)
			var size:=rng.randf_range(.42,.68)*scale_factor
			var spread: Vector3=_disk(float(fire.radius))
			if fire.has("extent"):
				var extent: Vector2=fire.extent
				spread=Vector3(rng.randf_range(-extent.x,extent.x),0,rng.randf_range(-extent.y,extent.y)).rotated(Vector3.UP,float(fire.get("yaw",0.0)))
			_spawn(0,Vector3(fire.at)+spread,Vector3(rng.randf_range(-.12,.12),rng.randf_range(1.8,2.6)*sqrt(scale_factor),rng.randf_range(-.12,.12)),size,rng.randf_range(.50,.75),false)
		if float(fire.smoke)>=1.0:
			fire.smoke-=1.0
			_spawn(1,Vector3(fire.at)+Vector3.UP*1.15+_disk(.15),Vector3(0,rng.randf_range(.6,1.0),0),rng.randf_range(.28,.45),rng.randf_range(1.4,2.2),false)
		if float(fire.ember)>=1.0:
			fire.ember-=1.0
			_spawn(2,Vector3(fire.at)+_disk(float(fire.radius)),Vector3(rng.randf_range(-.3,.3),rng.randf_range(1.5,2.6),rng.randf_range(-.3,.3)),rng.randf_range(.025,.055),rng.randf_range(.5,1.1),false)
	emission_cursor+=1
	for index in range(particles.size()-1,-1,-1):
		var particle: Dictionary=particles[index]
		particle.age+=dt
		if float(particle.age)>=float(particle.life):
			particles.remove_at(index)
			continue
		var kind:=int(particle.kind)
		var velocity: Vector3=particle.velocity
		var response:=2.4 if kind==1 else 1.5
		velocity.x=lerpf(velocity.x,wind.x,1.0-exp(-response*dt))
		velocity.z=lerpf(velocity.z,wind.z,1.0-exp(-response*dt))
		velocity.y+=wind.y*dt
		if kind==2 and bool(particle.burst): velocity.y-=3.5*dt
		if bool(particle.burst) and kind!=2: velocity*=exp(-2.0*dt)
		var curl:=Vector3(sin(clock*7.0+float(particle.seed)),0,cos(clock*5.0+float(particle.seed)))*(.13 if kind==1 else .20)
		particle.at=Vector3(particle.at)+(velocity+curl)*dt
		particle.velocity=velocity

func _upload() -> void:
	if banks.is_empty(): return
	for wave in shockwaves:
		wave.material.set_shader_parameter("flame_color",Color(1,0,.24) if preserve_flame_colors else Color("ffd151"))
	var counts: Array[int]=[0,0,0]
	for particle in particles:
		var kind:=int(particle.kind)
		var age:=float(particle.age)/float(particle.life)
		var size:=float(particle.size)
		var tint:=Color.WHITE
		if kind==0:
			size*=lerpf(1.0,.16,age)
			tint=Color("fff5b2") if age<.30 else (Color("ffd151") if age<.52 else (Color("ff8429") if age<.76 else Color("c53e27")))
			if preserve_flame_colors:
				var phase:=0 if age<.30 else (1 if age<.52 else (2 if age<.76 else 3))
				tint=Color(1,0,.20+.04*phase)
		elif kind==1:
			size*=lerpf(.65,2.4,age)
			tint=Color("555063") if age<.45 else Color("353342")
			tint.a=clampf((1.0-age)*2.8,0,1)
		else:
			size*=lerpf(1.0,.25,age)
			tint=Color("ffd97c") if age<.5 else Color("e26229")
			if preserve_flame_colors:tint=Color(1,0,.36 if age<.5 else .40)
			tint.a=clampf((1.0-age)*4.0,0,1)
		var height_scale:=1.4 if kind==0 and not bool(particle.burst) else 1.0
		banks[kind].set_instance_transform(counts[kind],Transform3D(Basis.IDENTITY.scaled(Vector3(size,size*height_scale,1)),Vector3(particle.at)))
		banks[kind].set_instance_color(counts[kind],tint)
		outline_banks[kind].set_instance_transform(counts[kind],banks[kind].get_instance_transform(counts[kind]))
		outline_banks[kind].set_instance_color(counts[kind],tint)
		counts[kind]+=1
	var camera:=get_viewport().get_camera_3d() if is_inside_tree() else null
	var contour_width:=1.0/32.0
	if camera!=null and camera.projection==Camera3D.PROJECTION_ORTHOGONAL:
		contour_width=camera.size/maxf(1.0,get_viewport().get_visible_rect().size.y)
	for kind in 3:
		banks[kind].visible_instance_count=counts[kind]
		outline_banks[kind].visible_instance_count=counts[kind]
		outline_materials[kind].set_shader_parameter("contour_world_width",contour_width)
	var index:=0
	for id in fires:
		if index>=lights.size(): break
		lights[index].position=Vector3(fires[id].at)+Vector3.UP*.35
		lights[index].light_energy=.55+.12*sin(clock*17.0+float(id))+.07*sin(clock*29.0)
		lights[index].visible=true
		index+=1
	for slot in range(index,lights.size()): lights[slot].visible=false

func _emit_shockwave(at: Vector3,strength: float) -> void:
	if shockwaves.size()>=8:return
	var mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(2,2)
	mesh.mesh=plane
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new()
	material.shader=WAVE_SHADER
	material.set_shader_parameter("flame_color",Color(1,0,.24) if preserve_flame_colors else Color("ffd151"))
	mesh.material_override=material
	add_child(mesh)
	mesh.position=at
	mesh.scale=Vector3(.2,1,.2)
	shockwaves.append({"mesh":mesh,"material":material,"age":0.0,"strength":strength})
