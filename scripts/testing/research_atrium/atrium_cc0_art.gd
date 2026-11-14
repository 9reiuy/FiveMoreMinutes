extends RefCounted
const L := preload("res://scripts/testing/research_atrium/atrium_layout.gd")
const LIB := preload("res://scripts/testing/research_atrium/cc0_architecture.gd")
const M := preload("res://scripts/testing/maintenance_environment.gd")
const CUTOUT := preload("res://scripts/dream/authored_occlusion_cutout.gd")
const OPTICS := preload("res://scripts/dream/office_light_optics.gd")
const MODEL := "res://art/Dream/H06/crawler_h06.glb"
const ACTOR_EDGE := 1<<6
const CENTRE := Vector2.ZERO
const DISPLAY_SIDE := 10.0
const GROUND_FLOOR := 0.0
const BASE_RECT := Rect2(Vector2(-10,-10),Vector2(24,22))
const ENCLOSURE_HEIGHT := 3.2
const WALL_BASE := L.BOTTOM-.20
const WALL_TOP := L.TOP+ENCLOSURE_HEIGHT
var world: Node3D
var root: Node3D
var mech: Node3D
var animation: AnimationPlayer
var cutout:=CUTOUT.new()
var library: LIB
var _fixtures: Array[Node3D]=[]
var _support_count:=0
var _glass_count:=0

func _init(owner: Node3D) -> void:
	world=owner
	library=LIB.new(bool(world.get_meta(&"test_level11_whitebox",false)))

func _module(model: String,title: String,at: Vector3,size: Vector3,angles:=Vector3.ZERO,blocker:=false) -> Node3D:
	var result:=library.place(root,model,title,at,size,angles)
	if title in ["ContinuousOuterLaboratoryWall","EntranceSideWall"]:
		for mesh in LIB.meshes(result):
			for surface in mesh.mesh.get_surface_count():
				var original:=mesh.mesh.surface_get_material(surface)
				if original!=null and original.resource_name=="MI_Trim_02":mesh.set_surface_override_material(surface,cutout.top_black)
	if blocker:
		for mesh in LIB.meshes(result):cutout.register_mesh(mesh,false,true)
	return result

func build() -> void:
	root=Node3D.new()
	root.name="ResearchAtrium11_CC0"
	world.floor_root.add_child(root)
	_build_base_and_display()
	_build_walkways()
	_build_enclosure()
	_build_boundaries()
	if not world.get_meta(&"test_level11_without_mech",false):_build_mech()

func _tiled_floor(title: String,rect: Rect2,height: float) -> void:
	var z:=rect.position.y
	while z<rect.end.y-.001:
		var depth:=minf(4.0,rect.end.y-z)
		var x:=rect.position.x
		while x<rect.end.x-.001:
			var width:=minf(4.0,rect.end.x-x)
			_module("Platform_Simple2",title,Vector3(x+width*.5,height,z+depth*.5),Vector3(width,0,depth))
			x+=width
		z+=depth

func _wall_line(title: String,a: Vector2,b: Vector2,base: float,height: float,model: String) -> void:
	var direction: Vector2=(b-a).normalized()
	var length:=a.distance_to(b)
	var yaw:=atan2(direction.x,direction.y)
	var t:=0.0
	while t<length-.001:
		var span:=minf(4.0,length-t)
		var p:=a+direction*(t+span*.5)
		_module(model,title,Vector3(p.x,base+height*.5,p.y),Vector3(.16,height,span),Vector3(0,yaw,0),true)
		t+=span

func _perimeter(title: String,rect: Rect2,base: float,height: float,model: String) -> void:
	var a:=rect.position
	var b:=Vector2(rect.end.x,rect.position.y)
	var c:=rect.end
	var d:=Vector2(rect.position.x,rect.end.y)
	_wall_line(title,a,b,base,height,model)
	_wall_line(title,b,c,base,height,model)
	_wall_line(title,c,d,base,height,model)
	_wall_line(title,d,a,base,height,model)

func _build_base_and_display() -> void:
	_tiled_floor("LowerStructuralPlatform",BASE_RECT,0.0)
	_perimeter("BasePlatformFascia",BASE_RECT,-.45,.45,"ShortWall_WhitePlate2_Straight")
	# One continuous first floor under the mech and the elevated walkways.

func _flat_run(a: Vector2,b: Vector2,height: float) -> void:
	var direction: Vector2=(b-a).normalized()
	var yaw:=atan2(direction.x,direction.y)
	var length:=a.distance_to(b)
	var t:=0.0
	while t<length-.001:
		var span:=minf(4.0,length-t)
		var p:=a+direction*(t+span*.5)
		_module("Platform_Simple2","WalkwayFloor",Vector3(p.x,height,p.y),Vector3(L.WIDTH,0,span),Vector3(0,yaw,0))
		t+=span

func _build_walkways() -> void:
	for i in range(L.PATH.size()-1):
		var a: Vector2=L.PATH[i]
		var b: Vector2=L.PATH[i+1]
		var direction: Vector2=(b-a).normalized()
		var out:=Vector2(-direction.y,direction.x)
		var length:=a.distance_to(b)
		var end:=length+1.5 if i==L.PATH.size()-2 else length-1.5
		var flight: int=L.flight_index(i)
		if flight<0:
			_flat_run(a-direction*1.5,a+direction*end,L.TOP)
		else:
			var first: float=(length-L.FLIGHT_LENGTH)*.5
			var base: float=L.TOP-flight*L.DROP
			_flat_run(a-direction*1.5,a+direction*first,base)
			var p:=a+direction*(first+L.FLIGHT_LENGTH*.5)
			# Author ramp rises towards local -Z; align that high end with the start.
			_module("Platform_Ramp_2","DescendingCC0Ramp",Vector3(p.x,base-L.DROP*.5,p.y),Vector3(L.WIDTH,L.DROP,L.FLIGHT_LENGTH),Vector3(0,atan2(direction.x,direction.y),0))
			_flat_run(a+direction*(first+L.FLIGHT_LENGTH),a+direction*end,base-L.DROP)
		for side: float in [-1,1]:
			var t:=-1.5
			while t<end-.001:
				var span:=minf(4.0,end-t)
				var point:=a+direction*(t+span*.5)+out*side*1.43
				var h: float=L.height_on(i,t+span*.5)
				_module("ShortWall_WhitePlate2_Straight","WalkwayStructuralFascia",Vector3(point.x,h-.20,point.y),Vector3(.14,.4,span),Vector3(0,atan2(direction.x,direction.y),0))
				t+=span
	# Four structural supports, shared by the continuous beams and first floor.
	for p: Vector2 in [Vector2(7,6),Vector2(7,-7),Vector2(0,-7),Vector2(-7,-7)]:
		var height: float=L.height_at(p)-.22
		_module("Column_Astra","WalkwaySupportToBase",Vector3(p.x,height*.5,p.y),Vector3(.65,height,.65))
		_support_count+=1

func _continuous_wall(title: String,a: Vector2,b: Vector2) -> void:
	var delta:=b-a
	var at:=(a+b)*.5
	_module("WallAstra_Straight_Flat",title,Vector3(at.x,(WALL_TOP+WALL_BASE)*.5,at.y),Vector3(.16,WALL_TOP-WALL_BASE,delta.length()),Vector3(0,atan2(delta.x,delta.y),0),true)

func _build_enclosure() -> void:
	for i: int in L.FLIGHT_SEGMENTS:
		var a: Vector2=L.PATH[i]
		var b: Vector2=L.PATH[i+1]
		var direction: Vector2=(b-a).normalized()
		var out:=Vector2(-direction.y,direction.x)
		var length:=a.distance_to(b)
		var outer_start:=1.5 if i==1 else -1.5
		var outer_end:=length+1.5
		_continuous_wall("ContinuousOuterLaboratoryWall",a+direction*outer_start+out*1.57,a+direction*outer_end+out*1.57)
		var inner_start:=-1.5 if i==1 else 1.5
		var inner_end:=length-1.5 if i==1 else length+1.5
		var inner:=a+direction*((inner_start+inner_end)*.5)-out*1.48
		_glass_wall(inner,direction,inner_end-inner_start,WALL_BASE,WALL_TOP-WALL_BASE)
		for fraction: float in [.18,.50,.82]:
			var p:=a.lerp(b,fraction)
			var h: float=L.height_at(p)
			var fixture:=_module("Prop_Light_Wide","ImportedRecessedFixture",Vector3(p.x,h+2.94,p.y),Vector3(1.32,.18,.45),Vector3(0,atan2(direction.x,direction.y),0))
			_fixtures.append(fixture)
	# The short entrance is enclosed on its sides, without a wall across either opening.
	_continuous_wall("EntranceSideWall",Vector2(11.5,8.5),Vector2(8.5,8.5))
	_continuous_wall("EntranceSideWall",Vector2(8.5,5.5),Vector2(11.5,5.5))
	_glass_wall(Vector2(7,8.5),Vector2.RIGHT,3,WALL_BASE,WALL_TOP-WALL_BASE)

func _glass_wall(at: Vector2,direction: Vector2,span: float,base: float,height: float) -> void:
	var yaw:=atan2(direction.x,direction.y)
	var pane:=_module("OriginalGlassSurface","LeftAtriumGlass",Vector3(at.x,base+height*.5,at.y),Vector3(0,height,span),Vector3(0,yaw,0))
	for mesh in LIB.meshes(pane):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var divisions:=ceili(span/6.5)
	for index in range(divisions+1):
		var p:=at+direction*span*(float(index)/divisions-.5)
		_module("Column_Simple","AtriumGlassMullion",Vector3(p.x,base+height*.5,p.y),Vector3(.065,height,.065))
	for y: float in [base+.06,base+height-.03]:
		_module("Column_Simple","AtriumGlassHorizontalFrame",Vector3(at.x,y,at.y),Vector3(.065,span,.065),Vector3(PI*.5,yaw,0))
	_glass_count+=1

func _build_boundaries() -> void:
	var cells: Dictionary=L.cells()
	var rails:=StaticBody2D.new()
	rails.name="AtriumGuardrails"
	rails.collision_layer=ACTOR_EDGE
	rails.collision_mask=0
	world.collision_root.add_child(rails)
	for cell: Vector2i in cells:
		for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(cell+direction):continue
			var at:=Vector2(cell)+Vector2(direction)*.5
			var shape:=RectangleShape2D.new()
			shape.size=Vector2(.12,1.02)*32 if direction.x!=0 else Vector2(1.02,.12)*32
			var collision:=CollisionShape2D.new()
			collision.shape=shape
			collision.position=at*32
			rails.add_child(collision)
	var display:=StaticBody2D.new()
	display.name="AtriumVoidBoundary"
	display.position=CENTRE*32
	display.collision_layer=4|ACTOR_EDGE
	display.collision_mask=0
	var collision:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2.ONE*DISPLAY_SIDE*32
	collision.shape=shape
	display.add_child(collision)
	world.collision_root.add_child(display)

func _build_mech() -> void:
	mech=(load(MODEL) as PackedScene).instantiate()
	mech.name="H06_TacticalCrawler"
	mech.position=Vector3(CENTRE.x,GROUND_FLOOR,CENTRE.y)
	mech.rotation.y=.65
	mech.scale=Vector3.ONE*1.35
	root.add_child(mech)
	var players:=mech.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		animation=players[0]
		if animation.has_animation(&"Deployment"):
			animation.play(&"Deployment")
			animation.seek(2.1333,true)
			animation.pause()
	for mesh: MeshInstance3D in mech.find_children("*","MeshInstance3D",true,false):cutout.register_mesh(mesh,true,true)

func build_lighting(parent: Node3D) -> void:
	# The same environment and fixture optics as levels 0-1 through 0-6.
	M.configure_environment(world)
	var environment: Environment=world.get_node(^"Lighting/WorldEnvironment").environment.duplicate()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color.BLACK
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b5bdcb")
	environment.ambient_light_energy=.075
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled=true
	environment.glow_intensity=.22
	environment.glow_bloom=.08
	environment.ssao_enabled=true
	environment.ssao_intensity=.75
	environment.ssr_enabled=true
	environment.volumetric_fog_enabled=true
	environment.volumetric_fog_density=.003
	environment.volumetric_fog_albedo=Color("b5bdcb")
	world.get_node(^"Lighting/WorldEnvironment").environment=environment
	world.get_node(^"Lighting/KeyLight").hide()
	var bounce:=DirectionalLight3D.new()
	bounce.name="FormalActorFill"
	bounce.rotation_degrees=Vector3(-57,26,0)
	bounce.light_color=Color.WHITE
	bounce.light_color=Color("c6d7dc")
	bounce.light_energy=.34
	bounce.light_cull_mask=2|8
	bounce.shadow_enabled=false
	parent.add_child(bounce)
	for fixture in _fixtures:
		var light:=OmniLight3D.new()
		light.name="CC0CeilingPool"
		light.position=fixture.position-Vector3.UP*.20
		light.light_color=Color("d7dce5")
		light.light_energy=2.7
		light.omni_range=5.8
		light.omni_attenuation=1.4
		light.shadow_enabled=parent.get_child_count()%3==0
		light.shadow_bias=.04
		light.light_cull_mask=15
		parent.add_child(light)
		OPTICS.mark_fixture(light,light,LIB.meshes(fixture))
	for x: float in [-4.0,2.0]:
		var light:=SpotLight3D.new()
		light.name="H06InspectionSpot"
		light.position=Vector3(x,7.0,2.5)
		light.rotation_degrees=Vector3(-80,0,0)
		light.light_color=Color("eeeeee")
		light.light_energy=5.0
		light.spot_range=14
		light.spot_angle=48
		light.shadow_enabled=true
		light.light_volumetric_fog_energy=.20
		parent.add_child(light)
