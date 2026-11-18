extends Node3D
## Bounded attack presentation. Damage and physics sweeps belong to the director.
const BURN := preload("res://scripts/dream/burning_effects.gd")
const FREIGHT := preload("res://scripts/testing/h06_chapter/freight_art.gd")
const WARNING := preload("res://shaders/dream3d/h06_attack_warning.gdshader")
const LASER_BEAM := preload("res://shaders/dream3d/h06_laser_halo.gdshader")
const LASER_CONTACTS := preload("res://scripts/testing/h06_chapter/laser_contact_effects.gd")
const SHIELD := preload("res://scripts/testing/h06_chapter/crawler_shield.gd")
const WARNING_MARGIN := .28
const LANDING_RADIUS := 4.6
const MISSILE_TUBES := 6
const BARRAGE_ROWS := 3
const EMITTER_RADIUS := .88
const EMITTER_HEIGHT := 1.12
const CHARGE_STREAK_COUNT := 24
const LASER_BEAM_RADIUS := 1.14
var world: Node3D
var _lift: Node3D
var red: StandardMaterial3D
var hot: StandardMaterial3D
var lane: MeshInstance3D
var beam: MeshInstance3D
var extra_beams: Array[MeshInstance3D] = []
var laser_contacts: LASER_CONTACTS
var core: Node3D
var core_light: StandardMaterial3D
var charge_streams: MultiMeshInstance3D
var charge_ports: MultiMeshInstance3D
var charge_light: OmniLight3D
var shield: SHIELD
var marks: Array[MeshInstance3D] = []
var salvo_rows: Array[MeshInstance3D] = []
var shell: MeshInstance3D
var missiles: Array[Node3D] = []
var smoke_bursts := 0
var soft_warnings := false

static func landing_dust(host: Node3D, at: Vector3, feet: Array = [], radius := LANDING_RADIUS) -> void:
	var effects: Node3D=BURN.install(host).effects
	if radius > 3.0:
		effects.emit_smoke(effects.to_local(host.to_global(at+Vector3.UP*.22)), 20, 2.9)
		for i in 10:
			var direction := Vector3(sin(i*TAU/10.),0,cos(i*TAU/10.))
			var from := at+direction*radius*.62+Vector3.UP*.15
			effects.emit_smoke(effects.to_local(host.to_global(from)), 4, 2.45, direction*2.3-Vector3.UP*.32)
		for leg: Dictionary in feet:
			var foot: Vector3=leg.ankle.global_position
			var outward := (foot-host.to_global(at)).slide(Vector3.UP).normalized()
			effects.emit_smoke(effects.to_local(foot-Vector3.UP*.14), 5, 2.6, outward*1.8-Vector3.UP*.32)
		return
	effects.emit_smoke(effects.to_local(host.to_global(at+Vector3.UP*.12)),14,1.65)
	for i in 8:
		var ring:=at+Vector3(sin(i*TAU/8.)*2.25,.12,cos(i*TAU/8.)*2.25)
		effects.emit_smoke(effects.to_local(host.to_global(ring)),3,1.15)
	for leg: Dictionary in feet:
		var foot: Vector3=leg.ankle.global_position
		effects.emit_smoke(effects.to_local(foot+Vector3.UP*.06),2,.85)

func configure(host: Node3D, model: Node3D) -> void:
	world=host
	_lift=world.blockout.inclined_lift
	name="H06AttackEffects"
	soft_warnings=world.get_meta(&"h06_soft_warnings",true)
	red=_material(Color(1,.08,.025,.30),1.1)
	hot=_material(Color(1,.78,.38),4.)
	lane=_warning("AttackLane",false) if soft_warnings else _box("AttackLane",red)
	for i in MISSILE_TUBES+1:
		if soft_warnings:
			marks.append(_warning("LockMark%d"%(i+1),true))
		else:
			marks.append(_legacy_mark(i))
	var rocket_count := MISSILE_TUBES*BARRAGE_ROWS
	var prototype := FREIGHT.build_missile_projectile(self)
	for i in rocket_count:
		var missile := prototype
		if i>0:
			missile=prototype.duplicate(0) as Node3D
			add_child(missile)
		missile.name="H06Missile%d"%(i+1)
		missile.scale=Vector3.ONE*.65
		missile.hide()
		missiles.append(missile)
	for i in BARRAGE_ROWS:
		var label := "BarrageRow%d" % (i+1)
		salvo_rows.append(_warning(label,false) if soft_warnings else _box(label,red))
	shell=MeshInstance3D.new()
	shell.name="CannonShell"
	var sphere:=SphereMesh.new()
	sphere.radius=.15
	sphere.height=.30
	sphere.radial_segments=12
	sphere.rings=6
	shell.mesh=sphere
	shell.material_override=hot
	shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	shell.hide()
	BURN.install(world)
	world._firearm_fx()
	_build_radial_emitter()
	_build_laser_charge()
	shield = SHIELD.new()
	add_child(shield)
	shield.configure(model)

func _build_radial_emitter() -> void:
	var material := ShaderMaterial.new()
	material.shader = LASER_BEAM
	var strip := QuadMesh.new()
	strip.size = Vector2(2.0, 1.0)
	beam = _laser_beam("LaserCore", strip, material)
	for i in range(1, 6):
		extra_beams.append(_laser_beam("LaserCore%d"%i, strip, material))
	laser_contacts = LASER_CONTACTS.new()
	laser_contacts._lift = _lift
	add_child(laser_contacts)
	core = Node3D.new()
	core.name = "LaserEmitter"
	add_child(core)
	core.hide()
	var housing := _material(Color("29333a"),.15)
	housing.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_core_piece("Base", Vector3(0,.86,0), Vector3(1.05,.43,1.05), housing)
	_core_piece("Piston", Vector3(0,1.38,0), Vector3(.45,1.26,.45), housing)
	core_light = _material(Color("ff701f"),1.3)
	var ring := MeshInstance3D.new()
	ring.name = "LaserEmitterRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = EMITTER_RADIUS-.08
	mesh.outer_radius = EMITTER_RADIUS+.07
	mesh.rings = 24
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.material_override = core_light
	ring.position.y = EMITTER_HEIGHT
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.add_child(ring)

func _core_piece(label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.position = at
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 6
	mesh.top_radius = 1.
	mesh.bottom_radius = 1.
	mesh.height = 1.
	node.mesh = mesh
	node.scale = size
	node.material_override = material
	core.add_child(node)

func show_core(at: Vector3, yaw: float, opening: float, firing: bool) -> void:
	core.position = at
	core.rotation.y = yaw
	core.visible = opening > .08
	core_light.emission = Color("ff701f")
	core_light.emission_energy_multiplier = 4.0 if firing else 1.3+opening

func _build_laser_charge() -> void:
	var streak := CylinderMesh.new()
	streak.height = 1.
	streak.top_radius = .30
	streak.bottom_radius = .98
	streak.radial_segments = 6
	charge_streams = _charge_instances("LaserChargeStreams",streak,CHARGE_STREAK_COUNT,
		_material(Color("ff301aff"),3.1))
	var lens := SphereMesh.new()
	lens.radius = .5
	lens.height = 1.
	lens.radial_segments = 12
	lens.rings = 6
	charge_ports = _charge_instances("ChargedLaserPorts",lens,6,_material(Color("ff5428"),4.5))
	charge_light = OmniLight3D.new()
	charge_light.name = "LaserChargeLight"
	charge_light.light_color = Color("ff2a18")
	charge_light.light_specular = .15
	charge_light.omni_range = 5.8
	charge_light.hide()
	add_child(charge_light)

func _charge_instances(label: String, mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var carrier := MultiMeshInstance3D.new()
	carrier.name = label
	carrier.multimesh = MultiMesh.new()
	carrier.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	carrier.multimesh.mesh = mesh
	carrier.multimesh.instance_count = count
	carrier.material_override = material
	carrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carrier.hide()
	add_child(carrier)
	return carrier

func charge_laser(at: Vector3, yaw: float, progress: float, radial: bool) -> void:
	var amount := smoothstep(0.,1.,progress)
	var nozzles := 6 if radial else 1
	charge_streams.show()
	charge_ports.show()
	charge_ports.multimesh.visible_instance_count = nozzles
	var center := at+Vector3.UP*EMITTER_HEIGHT
	for i in nozzles:
		var angle := yaw+i*TAU/6.
		var port := center+Vector3(sin(angle),0,cos(angle))*EMITTER_RADIUS
		charge_ports.multimesh.set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3.ONE*lerpf(.10,.48,amount)),port))
	for i in CHARGE_STREAK_COUNT:
		var port := charge_ports.multimesh.get_instance_transform(i%nozzles).origin
		var theta := i*2.399963+(1.-amount)*1.75
		var direction := Vector3(cos(theta),.24+float(i%5)*.13,sin(theta)).normalized()
		var distance := lerpf(3.9+float(i%4)*.35,.03,amount)
		var length := lerpf(.78,.10,amount)
		var basis := Basis(Quaternion(Vector3.UP,direction)).scaled_local(Vector3(.044,length,.044))
		charge_streams.multimesh.set_instance_transform(i,Transform3D(basis,port+direction*(distance+length*.5)))
	core_light.emission = Color("ff2618")
	core_light.emission_energy_multiplier = lerpf(1.6,5.0,amount)
	charge_light.position = (center if radial else charge_ports.multimesh.get_instance_transform(0).origin)+Vector3.UP*.7
	charge_light.light_energy = lerpf(.32,2.2,amount)
	charge_light.show()

func shield_impact(at: Vector3, incoming: Vector2) -> void:
	shield.flash(world.to_global(at), world.global_basis * Vector3(incoming.x, 0.0, incoming.y))

func _legacy_mark(i: int) -> MeshInstance3D:
	var mark:=MeshInstance3D.new()
	mark.name="LockMark%d"%(i+1)
	var mesh:=TorusMesh.new()
	mesh.inner_radius=.88
	mesh.outer_radius=1.02
	mesh.rings=32
	mesh.ring_segments=6
	mark.mesh=mesh
	mark.material_override=_material(Color(1,.055,.015,.72),2.)
	mark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	mark.hide()
	return mark

func _warning(label: String, circle: bool) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=label
	var plane:=PlaneMesh.new()
	plane.size=Vector2.ONE
	node.mesh=plane
	var material:=ShaderMaterial.new()
	material.shader=WARNING
	material.set_shader_parameter("circular",circle)
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.hide()
	return node

func _warning_size(node: MeshInstance3D, half: Vector2) -> void:
	node.scale=Vector3(half.x*2+WARNING_MARGIN*2,1,half.y*2+WARNING_MARGIN*2)
	(node.material_override as ShaderMaterial).set_shader_parameter("half_size",half)

func charge_warning(progress: float) -> void:
	if not soft_warnings:return
	if lane.visible:(lane.material_override as ShaderMaterial).set_shader_parameter("charge",clampf(progress,0.,1.))
	if marks[0].visible:charge_mark(0,progress)

func charge_mark(index: int, progress: float) -> void:
	if soft_warnings:(marks[index].material_override as ShaderMaterial).set_shader_parameter("charge",clampf(progress,0.,1.))

func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=color
	material.emission_enabled=true
	material.emission=Color(color,1.)
	material.emission_energy_multiplier=energy
	if color.a<1:material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _box(label: String, material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=label
	node.mesh=BoxMesh.new()
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.hide()
	return node

func _laser_beam(label: String, strip: QuadMesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = strip
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = LASER_BEAM_RADIUS
	node.hide()
	add_child(node)
	return node

func warn_line(a: Vector2, b: Vector2, width: float, progress := 1.0) -> void:
	var direction:=b-a
	lane.position=Vector3((a.x+b.x)*.5,.035,(a.y+b.y)*.5)
	lane.rotation.y=atan2(direction.x,direction.y)
	if soft_warnings:
		_warning_size(lane,Vector2(width*.5,maxf(.01,direction.length())*.5))
		(lane.material_override as ShaderMaterial).set_shader_parameter("charge",clampf(progress,0.,1.))
	else:lane.scale=Vector3(width,.022,maxf(.01,direction.length()))
	lane.show()

func warn_barrage_row(index: int, area: Rect2) -> void:
	var row := salvo_rows[index]
	var center := area.get_center()
	row.position = Vector3(center.x,.049,center.y)
	row.rotation.y = PI*.5
	if soft_warnings:
		_warning_size(row,Vector2(area.size.y,area.size.x)*.5)
	else:
		row.scale = Vector3(area.size.y,.022,area.size.x)
	row.show()

func charge_barrage_row(index: int, progress: float) -> void:
	if soft_warnings:
		(salvo_rows[index].material_override as ShaderMaterial).set_shader_parameter("charge",clampf(progress,0.,1.))

func available_lock_mark() -> int:
	# Slot zero belongs to jump and stomp warnings.
	for i in range(1, marks.size()):
		if not marks[i].visible:return i
	return -1

func available_rocket() -> int:
	for i in missiles.size():
		if not missiles[i].visible:return i
	return -1

func mark(index: int, at: Vector2, radius: float = 1.7) -> void:
	marks[index].position=Vector3(at.x,.055,at.y)
	if soft_warnings:_warning_size(marks[index],Vector2.ONE*radius)
	else:marks[index].scale=Vector3(radius,.32,radius)
	marks[index].show()

func set_laser(a: Vector3, b: Vector3, index: int, wall_side: float, max_range: float,
		contact_normal: Vector2, age: float, radial: bool) -> void:
	var clipped_end := b
	if is_instance_valid(_lift):
		b = _lift.set_laser_illumination(a,b,index,wall_side,max_range)
	var wall_hit := b != clipped_end
	var segment := b-a
	var visual := beam if index == 0 else extra_beams[index-1]
	var span := segment.length()
	if span < .032:
		visual.hide()
		laser_contacts.hide_ray(index)
		return
	var direction := segment / span
	visual.position = (a+b)*.5
	visual.quaternion = Quaternion(Vector3.UP,direction)
	visual.scale = Vector3(LASER_BEAM_RADIUS,span,LASER_BEAM_RADIUS)
	visual.set_instance_shader_parameter("sweep", Vector3(age,float(index)*2.17,.66 if radial else 1.0))
	visual.show()
	var normal := Vector3(-wall_side,0,0) if wall_hit else Vector3(contact_normal.x,0,contact_normal.y)
	laser_contacts.set_ray(index,a,direction,b,normal,age,radial,wall_hit)

func apply_laser_illumination(ray_count: int) -> void:
	if is_instance_valid(_lift): _lift.apply_laser_illumination(ray_count)

func muzzle(at: Vector3, direction: Vector3) -> void:
	world._firearm_fx().muzzle(at,direction,&"shotgun")

func exhaust(at: Vector3, direction: Vector3, count := 3) -> void:
	var effects: Node3D=BURN.install(world).effects
	effects.emit_smoke(effects.to_local(at-direction*.30),count,.55)

func barrage_impact(at: Vector2, large: bool) -> void:
	var point := world.to_global(Vector3(at.x,.14,at.y))
	world._firearm_fx().impact(point,Vector3.UP,&"solid",.88,.55)
	if large:
		explosion(at,.90)

func explosion(at: Vector2, strength: float, height: float = .15) -> void:
	var effects: Node3D=BURN.install(world).effects
	effects.explode(effects.to_local(world.to_global(Vector3(at.x,height,at.y))),strength)
	world.SFX.play_world_sfx_3d(&"explosion",world.to_global(Vector3(at.x,height,at.y)),0.,40.)

func landing(at: Vector3, feet: Array, radius := 2.25) -> void:
	landing_dust(world,at,feet,radius)
	smoke_bursts+=1

func stomp(at: Vector3) -> void:
	var effects: Node3D = BURN.install(world).effects
	effects.emit_smoke(effects.to_local(world.to_global(at+Vector3.UP*.14)), 8, 1.5)

func hide_lasers() -> void:
	beam.hide()
	for node in extra_beams: node.hide()
	laser_contacts.hide_flares()
	apply_laser_illumination(0)

func clear_windup() -> void:
	lane.hide()
	hide_lasers()
	marks[0].hide()
	charge_streams.hide()
	charge_ports.hide()
	charge_light.hide()

func clear() -> void:
	clear_windup()
	laser_contacts.clear()
	for node in marks:node.hide()
	for row in salvo_rows:row.hide()
	if is_instance_valid(core): core.hide()
	shell.hide()
	for node in missiles:node.hide()
