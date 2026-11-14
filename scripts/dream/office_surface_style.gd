extends Node3D
## Floor-owned approved material, toon, brush and lit-rim composition.
const NODE_NAME:=&"OfficeSurfaceStyle"
const MATERIALS=preload("res://scripts/dream/office_style_materials.gd")
const RIM=preload("res://scripts/dream/office_style_rim.gd")
const COMPOSITION=preload("res://scripts/dream/office_style_composition.gd")
var world:Node3D
var materials:RefCounted
var rim:RefCounted
var composition:RefCounted
var enabled:=true
var pending:Array[Dictionary]=[]
var hooks:Array[Dictionary]=[]
var restored:=false
var refresh_count:=0
var setup_ms:Dictionary={}

static func install(owner_world:Node3D,force:=false) -> Node3D:
	if not owner_world.has_method("get_current_floor_token") or not owner_world.approved_sample_art_enabled:return null
	if not force and bool(owner_world.get_meta(&"test_office_surface_style_disabled",false)):return null
	var existing:Node3D=owner_world.floor_root.get_node_or_null(NodePath(NODE_NAME))
	if existing!=null:return existing
	var component:Node3D=load("res://scripts/dream/office_surface_style.gd").new()
	component.name=NODE_NAME;owner_world.floor_root.add_child(component);component.configure(owner_world)
	return component

static func uninstall(owner_world:Node3D) -> void:
	var host:Node=owner_world.get("floor_root")
	if not is_instance_valid(host):return
	var component:Node=host.get_node_or_null(NodePath(NODE_NAME))
	if component!=null:component.restore();component.free()

func configure(owner_world:Node3D) -> void:
	world=owner_world;process_priority=160
	var instances:=capture_instances()
	var started:=Time.get_ticks_usec()
	materials=MATERIALS.new();materials.setup(world)
	setup_ms.materials=float(Time.get_ticks_usec()-started)/1000.0;started=Time.get_ticks_usec()
	rim=RIM.new();rim.setup(world)
	setup_ms.rim=float(Time.get_ticks_usec()-started)/1000.0;started=Time.get_ticks_usec()
	composition=COMPOSITION.new();composition.setup(world)
	setup_ms.composition=float(Time.get_ticks_usec()-started)/1000.0
	restore_instances(instances,true)
	for wall in world.wall_root.get_children():
		if not wall.has_method("set_office_cutaway_profile"):continue
		var mesh:MeshInstance3D=wall.get("wall_mesh")
		if mesh==null:continue
		hooks.append({"mesh":weakref(mesh),"original":mesh.get_meta(&"office_surface_decorator",Callable())})
		mesh.set_meta(&"office_surface_decorator",refresh_wall)
	get_tree().node_added.connect(on_node_added)

func set_enabled(value:bool) -> void:
	if enabled==value:return
	var instances:=capture_instances()
	enabled=value
	if value:
		materials.set_enabled(true);rim.set_enabled(true);composition.set_enabled(true)
		for record:Dictionary in hooks:
			var mesh:MeshInstance3D=record.mesh.get_ref()
			if is_instance_valid(mesh):refresh_wall(mesh)
	else:
		composition.set_enabled(false);rim.set_enabled(false);materials.set_enabled(false)
	restore_instances(instances,value)

func capture_instances() -> Array[Dictionary]:
	var states:Array[Dictionary]=[]
	for node in world.find_children("*","MeshInstance3D",true,false):
		var values:Dictionary={}
		for field in node.get_property_list():
			if String(field.name).begins_with("instance_shader_parameters/") and not String(field.name).contains("material_bounds_"):values[field.name]=node.get(field.name)
		if not values.is_empty():states.append({"node":weakref(node),"values":values})
	return states

func restore_instances(states:Array[Dictionary],_active:bool) -> void:
	for state:Dictionary in states:
		var node:MeshInstance3D=state.node.get_ref()
		if not is_instance_valid(node):continue
		for key in state.values:node.set(key,state.values[key])

func refresh_wall(mesh:MeshInstance3D) -> void:
	if restored:return
	if enabled:style_mesh_materials(mesh)
	rim.rebind_mesh(mesh);refresh_count+=1

func style_mesh_materials(mesh:MeshInstance3D) -> void:
	if mesh.mesh==null or mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:return
	var candidates:Array=[]
	if mesh.material_override!=null:candidates.append(mesh.material_override)
	else:
		for surface in mesh.mesh.get_surface_count():candidates.append(mesh.get_active_material(surface))
	for material in candidates:
		if not material is ShaderMaterial or material.shader==null:continue
		if rim.eligible(material):
			rim.register(material)
			for record:Dictionary in rim.records:
				if record.material==material:
					apply_shader(material,record.decorated);material.set_shader_parameter("edge_style_rim",true);break
		composition.register(material)
		for record:Dictionary in composition.records:
			if record.material==material:
				apply_shader(material,record.combined)
				material.set_shader_parameter("stack_toon_enabled",true)
				if record.edge:material.set_shader_parameter("edge_style_rim",true)
				if record.furniture:material.set_shader_parameter("comparison_brush_enabled",true)
				break

func apply_shader(material:ShaderMaterial,shader:Shader) -> void:
	if material.shader==shader:return
	var values:Dictionary={}
	for field in material.shader.get_shader_uniform_list():
		var value:Variant=material.get_shader_parameter(field.name)
		if value!=null:values[field.name]=value
	material.shader=shader
	for field in values:material.set_shader_parameter(field,values[field])

func register_late_finish(mesh:MeshInstance3D) -> void:
	var ancestor:Node=mesh
	var actor:Node2D=null
	while ancestor!=null and ancestor!=world:
		if ancestor is Furniture3DVisual:actor=ancestor.source_actor;break
		ancestor=ancestor.get_parent()
	if not is_instance_valid(actor):return
	var kind:String=actor.get_meta(&"office_furniture_kind","")
	if kind=="desk":kind="workstation"
	elif kind=="cabinet_open":kind="cabinet"
	if kind not in ["workstation","cabinet","server","shelf","copier","water_dispenser","fridge","counter","appliance_counter","table","coffee_table","sorting_table","dining_table","reception"]:return
	var face:Dictionary={}
	for coordinator in world.find_children("FurnitureTextureReviewCoordinator","Node",true,false):
		for item:Dictionary in coordinator.records:
			if item.node.get_ref()==mesh:face=item;break
	var candidates:Array=[]
	if mesh.material_override!=null:candidates.append(mesh.material_override)
	elif mesh.mesh!=null:
		for surface in mesh.mesh.get_surface_count():candidates.append(mesh.get_active_material(surface))
	for material in candidates:materials.register(material,mesh,actor,kind,face)

func on_node_added(node:Node) -> void:
	if node is MeshInstance3D and world.is_ancestor_of(node):pending.append({"node":weakref(node),"frame":Engine.get_process_frames()})

func _process(_delta:float) -> void:
	if not enabled:return
	for tick in mini(12,pending.size()):
		var record:Dictionary=pending.pop_front()
		var mesh:MeshInstance3D=record.node.get_ref()
		if not is_instance_valid(mesh) or not mesh.is_inside_tree() or not world.is_ancestor_of(mesh):continue
		if Engine.get_process_frames()-int(record.frame)<2:pending.append(record);continue
		register_late_finish(mesh);style_mesh_materials(mesh);rim.rebind_mesh(mesh)

func restore() -> void:
	if restored:return
	restored=true;set_process(false)
	if is_inside_tree() and get_tree().node_added.is_connected(on_node_added):get_tree().node_added.disconnect(on_node_added)
	for record:Dictionary in hooks:
		var mesh:MeshInstance3D=record.mesh.get_ref()
		if is_instance_valid(mesh):
			if record.original.is_valid():mesh.set_meta(&"office_surface_decorator",record.original)
			else:mesh.remove_meta(&"office_surface_decorator")
	hooks.clear();pending.clear()
	if composition!=null:composition.restore()
	if rim!=null:rim.restore()
	if materials!=null:materials.restore()

func _exit_tree() -> void:
	if is_instance_valid(world) and world.has_meta(&"display_reparenting"):return
	restore()
