extends "res://scripts/dream/elevator_floor_door_3d.gd"
## Lobby-only station lift. Existing door signals/collision own the journey;
## both leaves telescope to the right instead of splitting at the centre.
const STEEL=preload("res://shaders/dream3d/lobby_lift_steel.gdshader")
const STEEL_ALBEDO=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_BaseColor.png")
const STEEL_NORMAL=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Normal.png")
const STEEL_ROUGHNESS=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Roughness.png")
const STEEL_METALLIC=preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Metallic.png")
var status_text: Label3D
var floor_text: Label3D
var lobby_sensor: MeshInstance3D
var cheek_bodies: Array[StaticBody2D]=[]
var landing_bay_width:=4.0
var landing_identifier:=""

func _init(p_orientation: int=Orientation.UP,p_floor: int=0,p_bay_width: float=4.0) -> void:
	super(p_orientation,p_floor)
	landing_bay_width=p_bay_width
	configure_opening(2.0,.5)
	name="LobbySideOpeningLift"
	frame_root.hide();indicator_root.hide();card_reader_root.hide();camera_root.hide()
	industrial_facade.hide()
	industrial_facade.set_process(false)
	var steel:=ShaderMaterial.new();steel.shader=STEEL
	steel.set_shader_parameter("steel_albedo",STEEL_ALBEDO)
	steel.set_shader_parameter("steel_normal",STEEL_NORMAL)
	steel.set_shader_parameter("steel_roughness",STEEL_ROUGHNESS)
	steel.set_shader_parameter("steel_metallic",STEEL_METALLIC)
	var trim:=finish(Color("303638"),.68,.3)
	var surround:=finish(Color("aaa69a"),.85,0)
	var housing:=finish(Color("655f50"),.65,.25)
	for index in 2:
		var leaf: MeshInstance3D=left_door_mesh if index==0 else right_door_mesh
		leaf.material_override=steel
		leaf.position.z=.025 if index==0 else -.055
		for child in leaf.get_children():child.hide()
		_beveled_steel_face(leaf,steel)
		box(leaf,"WindowRebate",Vector3(.205,.84,.018),Vector3(0,.24,.041),trim)
		var glass:=finish(Color("0e191a"),.3,.1)
		box(leaf,"NarrowWiredWindow",Vector3(.135,.72,.012),Vector3(0,.24,.055),glass)
		box(leaf,"WindowMullion",Vector3(.012,.72,.008),Vector3(0,.24,.065),trim)
	var profile:=Node3D.new();profile.name="StationLiftSurround";add_child(profile)
	var cheek_width: float=(landing_bay_width-2.36)*.5
	for side in [-1.0,1.0]:
		box(profile,"StoneCheek",Vector3(cheek_width,3,.5),Vector3(side*(1.18+cheek_width*.5),1.5,0),surround)
		box(profile,"DeepJamb",Vector3(.18,2.65,.52),Vector3(side*1.09,1.325,.01),trim)
		box(profile,"SteelJambEdge",Vector3(.035,2.56,.055),Vector3(side*1.005,1.3,.295),steel)
	box(profile,"SolidLintel",Vector3(2.36,.21,.53),Vector3(0,2.67,.015),trim)
	box(profile,"Threshold",Vector3(2.08,.055,.53),Vector3(0,.0275,.015),steel)
	box(profile,"StatusHousing",Vector3(2.36,.30,.31),Vector3(0,2.88,.065),housing)
	box(profile,"StatusScreen",Vector3(1.92,.17,.018),Vector3(-.06,2.88,.23),finish(Color("06100a"),1,0))
	status_text=label(profile,"LiftStatus","LIFT  READY",Vector3(-.06,2.88,.247),Color("53ed83"),.0068)
	var panel_x:=1.39
	box(profile,"CallPanelBorder",Vector3(.30,1.14,.13),Vector3(panel_x,1.30,.30),trim)
	box(profile,"CallPanelSteel",Vector3(.24,1.08,.025),Vector3(panel_x,1.30,.38),steel)
	floor_text=label(profile,"FloorNumber","01",Vector3(panel_x,1.64,.4),Color("71e7a2"),.0055)
	box(profile,"CallButton",Vector3(.10,.14,.025),Vector3(panel_x,1.14,.41),trim)
	lobby_sensor=box(profile,"AccessIndicator",Vector3(.045,.025,.014),Vector3(panel_x,.94,.414),finish(Color("75b79b"),.8,0))
	for offset in [-.06,0,.06]:
		box(profile,"SpeakerSlot",Vector3(.10,.012,.008),Vector3(panel_x,1.43+offset,.403),trim)
	_update_lobby_status()

func _beveled_steel_face(leaf: MeshInstance3D, material: Material) -> void:
	# Small folded edges catch real light; keep the original leaf/proxy intact.
	var half: Vector2=Vector2(leaf.mesh.get_aabb().size.x,leaf.mesh.get_aabb().size.y)*.5
	var edge:=.025
	var outer:=[Vector2(-half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y),Vector2(half.x,-half.y)]
	var inner:=[Vector2(-half.x+edge,-half.y+edge),Vector2(-half.x+edge,half.y-edge),Vector2(half.x-edge,half.y-edge),Vector2(half.x-edge,-half.y+edge)]
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	_steel_triangle(builder,Vector3(inner[0].x,inner[0].y,.036),Vector3(inner[1].x,inner[1].y,.036),Vector3(inner[2].x,inner[2].y,.036))
	_steel_triangle(builder,Vector3(inner[0].x,inner[0].y,.036),Vector3(inner[2].x,inner[2].y,.036),Vector3(inner[3].x,inner[3].y,.036))
	for index in 4:
		var next: int=(index+1)%4
		var a:=Vector3(outer[index].x,outer[index].y,.031);var b:=Vector3(outer[next].x,outer[next].y,.031)
		var c:=Vector3(inner[next].x,inner[next].y,.036);var d:=Vector3(inner[index].x,inner[index].y,.036)
		_steel_triangle(builder,a,b,c);_steel_triangle(builder,a,c,d)
	builder.generate_tangents()
	var face:=MeshInstance3D.new();face.name="FoldedSteelFace";face.mesh=builder.commit();face.material_override=material
	face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;leaf.add_child(face)

func _steel_triangle(builder: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	var normal: Vector3=(c-a).cross(b-a).normalized()
	for point in [a,b,c]:
		builder.set_normal(normal);builder.set_uv(Vector2(point.x,-point.y));builder.add_vertex(point)

static func finish(colour: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=colour
	material.roughness=roughness;material.metallic=metallic;material.metallic_specular=.25
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material

func box(parent: Node3D,title: String,size: Vector3,point: Vector3,material: Material) -> MeshInstance3D:
	var visual:=MeshInstance3D.new();visual.name=title;visual.position=point
	var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh;visual.material_override=material
	# Room architecture and the door's existing solid leaf proxies own shadows.
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual);return visual

func label(parent: Node3D,title: String,text: String,point: Vector3,colour: Color,pixel: float) -> Label3D:
	var item:=Label3D.new();item.name=title;item.text=text;item.position=point
	item.font_size=28;item.pixel_size=pixel;item.modulate=colour;item.outline_size=0
	item.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;parent.add_child(item);return item

func setup_gameplay_2d(collision_parent: Node,trigger_parent: Node,door_position: Vector2) -> void:
	super.setup_gameplay_2d(collision_parent,trigger_parent,door_position)
	for body in cheek_bodies:
		if is_instance_valid(body):body.queue_free()
	cheek_bodies.clear()
	var angle:=get_inward_2d().angle()+PI*.5
	var cheek_width: float=(landing_bay_width-2.36)*.5
	for side in [-1.0,1.0]:
		var body:=StaticBody2D.new();body.name="LobbyLiftStoneCheekCollision"
		body.collision_layer=WORLD_WALL_LAYER;body.collision_mask=0
		body.position=door_position+Vector2(side*(1.18+cheek_width*.5)*CELL_PIXELS,0).rotated(angle);body.rotation=angle
		var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new()
		shape.size=Vector2(cheek_width,.5)*CELL_PIXELS;collision.shape=shape;body.add_child(collision)
		collision_parent.add_child(body);cheek_bodies.append(body)

func update_state(p_state: State) -> void:
	super.update_state(p_state);_update_lobby_status()

func update_indicator(floor_index: int) -> void:
	super.update_indicator(floor_index);_update_lobby_status()

func _update_lobby_status() -> void:
	if not is_instance_valid(status_text):return
	var suffix: String={State.LOCKED:"LOCKED",State.UNLOCKED:"READY",State.OPENING:"OPENING",State.OPEN:"OPEN",State.CLOSING:"CLOSING",State.CLOSED:"IN USE"}.get(current_state,"READY")
	status_text.text="LIFT  "+suffix
	status_text.modulate=Color("ef805c") if current_state==State.LOCKED else Color("53ed83")
	if is_instance_valid(floor_text):floor_text.text=landing_identifier if not landing_identifier.is_empty() else "%02d"%(current_floor_index+1)
	if is_instance_valid(lobby_sensor):
		lobby_sensor.material_override=finish(Color("cf6a52") if current_state==State.LOCKED else Color("75b79b"),.8,0)

func open_doors(duration: float=.45) -> Signal:
	if doors_open and current_state==State.OPEN:return doors_opened
	doors_open=true;update_state(State.OPENING)
	if is_instance_valid(door_collider_2d):door_collider_2d.set_deferred("collision_layer",0)
	if is_instance_valid(door_shape_2d):door_shape_2d.set_deferred("disabled",true)
	if door_tween!=null and door_tween.is_valid():door_tween.kill()
	door_tween=create_tween().set_parallel(true)
	var pocket:=opening_width*.75
	for leaf in [left_door_mesh,right_door_mesh]:
		door_tween.tween_property(leaf,"position:x",pocket,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.chain().tween_callback(func():update_state(State.OPEN);doors_opened.emit())
	return doors_opened

func close_doors(duration: float=.45) -> Signal:
	if not doors_open and current_state==State.CLOSED:return doors_closed
	doors_open=false;update_state(State.CLOSING)
	if door_tween!=null and door_tween.is_valid():door_tween.kill()
	door_tween=create_tween().set_parallel(true)
	door_tween.tween_property(left_door_mesh,"position:x",-opening_width*.25,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(right_door_mesh,"position:x",opening_width*.25,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.chain().tween_callback(func():
		update_state(State.CLOSED)
		if is_instance_valid(door_collider_2d):door_collider_2d.set_deferred("collision_layer",WORLD_WALL_LAYER)
		if is_instance_valid(door_shape_2d):door_shape_2d.set_deferred("disabled",false)
		doors_closed.emit())
	return doors_closed
