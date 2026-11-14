extends RefCounted
const FINISH=preload("res://scripts/dream/preview/furniture_direct_finish.gd")
const SOURCE_INCLUDE="res://shaders/dream3d/furniture_direct_finish.gdshaderinc"
const CANDIDATE_INCLUDE="res://shaders/dream3d/office_style_materials.gdshaderinc"
# Roughness, controlled direct-light reflectance, relief scale.
const PROFILES={
	"flat":Vector3(1.0,0.0,0.0),
	"wood":Vector3(.92,.025,2.2),
	"paint":Vector3(.55,.55,2.0),
	"bare_metal":Vector3(.50,.78,2.1),
	"plastic":Vector3(.52,.16,2.2),
	"fabric":Vector3(.98,.012,1.0),
	"leather":Vector3(.83,.045,1.2),
	"ceramic":Vector3(.64,.07,1.3),
}
var records:Array[Dictionary]=[]
var shaders:Dictionary={}
var face_counts:Dictionary={}
var skipped:Dictionary={}
var enabled:=false
var world:Node
var focus_actor:WeakRef
var bindings:Dictionary={}

func setup(owner_world:Node) -> int:
	world=owner_world
	var face_data:Dictionary={}
	for coordinator in world.find_children("FurnitureTextureReviewCoordinator","Node",true,false):
		for item in coordinator.records:
			var node:Node=item.node.get_ref()
			if is_instance_valid(node):face_data[node.get_instance_id()]=item
	for bridge in world.actor_depth_bridges_root.get_children():
		if not bridge is Furniture3DVisual or not is_instance_valid(bridge.source_actor):continue
		var kind:String=bridge.source_actor.get_meta(&"office_furniture_kind","")
		if kind=="desk":kind="workstation"
		elif kind=="cabinet_open":kind="cabinet"
		if kind not in ["workstation","cabinet","server","shelf","copier","water_dispenser","fridge","counter","appliance_counter","table","coffee_table","sorting_table","dining_table","reception"]:continue
		for mesh in bridge.visual_instance.find_children("*","MeshInstance3D",true,false):
			if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
			var candidates:Array[Material]=[]
			if mesh.material_override!=null:candidates.append(mesh.material_override)
			elif mesh.mesh!=null:
				for index in mesh.mesh.get_surface_count():candidates.append(mesh.get_active_material(index))
			for candidate in candidates:
				register(candidate,mesh,bridge.source_actor,kind,face_data.get(mesh.get_instance_id(),{}))
	set_enabled(true);return records.size()

func register(candidate:Material,mesh:MeshInstance3D,actor:Node2D,kind:String,item:Dictionary) -> void:
	if not candidate is ShaderMaterial or candidate.shader==null:return
	if records.any(func(r:Dictionary)->bool:return r.material==candidate):
		bindings[mesh.get_instance_id()]={"mesh":weakref(mesh),"bounds":mesh.get_aabb()}
		if enabled:apply_bounds(mesh)
		return
	var raw:String=candidate.shader.code
	var original_shader:Shader=candidate.shader
	if not raw.contains(SOURCE_INCLUDE):
		var prepared:Shader=FINISH._finish_shader(original_shader)
		if prepared==null:
			skipped[kind]=int(skipped.get(kind,0))+1;return
		raw=prepared.code
	var saved:Dictionary={}
	for uniform in candidate.shader.get_shader_uniform_list():
		var value:Variant=candidate.get_shader_parameter(uniform.name)
		if value!=null:saved[uniform.name]=value
	var profile:Vector3=PROFILES.flat
	if kind in ["cabinet","server","shelf","fridge","sink","counter"]:profile=PROFILES.paint
	elif kind in ["copier","water_dispenser"]:profile=PROFILES.plastic
	var uniform:Variant=candidate.get_shader_parameter("furniture_finish_uniform")
	if uniform is Vector2:
		for key in FINISH.PROFILES:
			if key=="flat":continue
			var old:Vector3=FINISH.PROFILES[key]
			if is_equal_approx(uniform.x,old.x) and is_equal_approx(uniform.y,old.y):profile=PROFILES[key];break
	if kind in ["copier","water_dispenser"] and item.is_empty():profile=PROFILES.plastic
	var atlas:Texture2D
	if not item.is_empty():atlas=build_atlas(item.result,kind,candidate.get_shader_parameter("furniture_finish_atlas"))
	if not shaders.has(raw):
		var code:=raw.replace(SOURCE_INCLUDE,CANDIDATE_INCLUDE)
		# Normal microdetail may fade with distance. Broad material response must not disappear with it.
		code=code.replace("vec2(data.b, data.a * detail)","vec2(data.b, data.a)")
		var vertex="material_local_point=VERTEX; material_local_normal=NORMAL; material_axis_x=normalize(MODELVIEW_NORMAL_MATRIX*vec3(1.0,0.0,0.0)); material_axis_y=normalize(MODELVIEW_NORMAL_MATRIX*vec3(0.0,1.0,0.0)); material_axis_z=normalize(MODELVIEW_NORMAL_MATRIX*vec3(0.0,0.0,1.0)); material_axis_scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));"
		code=code.replace("void vertex(){","void vertex() {")
		if code.contains("void vertex() {"):code=code.replace("void vertex() {","void vertex() {\n"+vertex)
		else:code+="\nvoid vertex(){"+vertex+"}\n"
		code=inject_body(code,"fragment","","\nif(!furniture_finish_atlas_enabled){furniture_direct_normal=material_box_normal(furniture_direct_normal,furniture_direct_finish);}\nif(material_family(furniture_direct_finish).z>.5){ALBEDO*=material_wood_occlusion(UV);}\n")
		code=inject_body(code,"light","\nvec3 material_prior_diffuse=DIFFUSE_LIGHT;\n","\nDIFFUSE_LIGHT=material_prior_diffuse+(DIFFUSE_LIGHT-material_prior_diffuse)*(1.0-.35*material_family(furniture_direct_finish).x);\n")
		var shader:=Shader.new();shader.code=code;shaders[raw]=shader
	bindings[mesh.get_instance_id()]={"mesh":weakref(mesh),"bounds":mesh.get_aabb()}
	var record:Dictionary={"material":candidate,"original_shader":original_shader,"candidate_shader":shaders[raw],"parameters":saved,"atlas":atlas,"uniform":Vector2(profile.x,profile.y),"mesh":weakref(mesh),"actor":weakref(actor),"kind":kind,"mesh_resource":mesh.mesh,"transform":mesh.transform}
	records.append(record)
	if enabled:apply_record(record);apply_bounds(mesh)

func inject_body(code:String,function:String,prefix:String,suffix:String) -> String:
	var start:=code.find("void "+function+"()")
	if start<0:return code
	var opening:=code.find("{",start);var ending:=opening+1;var depth:=1
	while depth>0 and ending<code.length():
		if code[ending]=="{":depth+=1
		elif code[ending]=="}":depth-=1
		ending+=1
	return code.substr(0,opening+1)+prefix+code.substr(opening+1,ending-opening-2)+suffix+code.substr(ending-1)

func build_atlas(result:Dictionary,kind:String,original:Texture2D) -> Texture2D:
	var image:Image=original.get_image().duplicate() if original!=null else Image.create(result.image.get_width(),result.image.get_height(),false,Image.FORMAT_RGBA8)
	if original==null:image.fill(Color(128.0/255.0,128.0/255.0,1.0,0.0))
	# The face metadata follows the live mesh UVs; never rebake the colour atlas or mesh.
	for face:Dictionary in result.faces:
		var key:String=FINISH.face_profile(kind,String(face.tile))
		var mixed_wood:bool=(String(face.tile) in ["paper","document"] and kind in ["workstation","table","coffee_table","dining_table","sorting_table","reception"] and face.normal.y>.5 and face.world_size.x*face.world_size.y>.45) or (key=="wood" and face.normal.y>.5)
		var background:=Color.TRANSPARENT
		if mixed_wood:
			key="wood"
			var counts:Dictionary={};var largest:=0
			var art:Image=face.image
			for row in art.get_height():
				for column in art.get_width():
					var color:=art.get_pixel(column,row)
					counts[color]=int(counts.get(color,0))+1
					if counts[color]>largest:largest=counts[color];background=color
			face_counts["wood_with_paper"]=int(face_counts.get("wood_with_paper",0))+1
		if key not in ["wood","paint","bare_metal","plastic"]:continue
		var profile:Vector3=PROFILES[key]
		face_counts[key]=int(face_counts.get(key,0))+1
		var box:Rect2i=face.rect
		var limits:=box.grow(2).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		for y in range(limits.position.y,limits.end.y):
			for x in range(limits.position.x,limits.end.x):
				var px:=clampi(x-box.position.x,0,box.size.x-1)
				var py:=clampi(y-box.position.y,0,box.size.y-1)
				if mixed_wood:
					var color:Color=face.image.get_pixel(px,py)
					if maxf(absf(color.r-background.r),maxf(absf(color.g-background.g),absf(color.b-background.b)))>3.0/255.0:
						image.set_pixel(x,y,Color(128.0/255.0,128.0/255.0,1.0,0.0));continue
				var slope:=Vector2.ZERO
				var band:=mini(3,mini(box.size.x,box.size.y)/6)
				if band>0 and profile.y>0.0:
					var edge:=.075*profile.z
					if px<band:slope.x-=edge*(1.0-float(px)/band)
					elif px>=box.size.x-band:slope.x+=edge*(1.0-float(box.size.x-1-px)/band)
					if py<band:slope.y-=edge*(1.0-float(py)/band)
					elif py>=box.size.y-band:slope.y+=edge*(1.0-float(box.size.y-1-py)/band)
				if key=="wood":slope.x+=.14*sin((float(px)+1.4*sin(float(py)*.11))*.6981317)
				elif key=="bare_metal" or (key=="paint" and absf(face.normal.y)<.5):slope.x+=(.028 if px%6<3 else -.028)
				image.set_pixel(x,y,Color((128.0+slope.x*127.0)/255.0,(128.0+slope.y*127.0)/255.0,profile.x,profile.y))
	image.generate_mipmaps();return ImageTexture.create_from_image(image)

func set_enabled(value:bool) -> void:
	enabled=value
	if not enabled:
		for binding in bindings.values():
			var mesh:MeshInstance3D=binding.mesh.get_ref()
			if is_instance_valid(mesh):
				mesh.set_instance_shader_parameter("material_bounds_min",null)
				mesh.set_instance_shader_parameter("material_bounds_size",null)
	for record in records:
		apply_record(record)
	if enabled:
		for binding in bindings.values():
			var mesh:MeshInstance3D=binding.mesh.get_ref()
			if is_instance_valid(mesh):
				mesh.set_instance_shader_parameter("material_bounds_min",binding.bounds.position)
				mesh.set_instance_shader_parameter("material_bounds_size",binding.bounds.size)

func apply_record(record:Dictionary) -> void:
	var material:ShaderMaterial=record.material
	# Cutaway flags, capture-camera state and power-driven screen values can
	# change after installation. Preserve their live values across style toggles.
	var current:Dictionary={}
	for field in material.shader.get_shader_uniform_list():
		var value:Variant=material.get_shader_parameter(field.name)
		if value!=null:current[field.name]=value
	material.shader=record.candidate_shader if enabled else record.original_shader
	for key in record.parameters:
		if key in ["furniture_finish_atlas","furniture_normal_atlas","furniture_finish_uniform"]:continue
		material.set_shader_parameter(key,current.get(key,record.parameters[key]))
	for key in current:
		if key not in record.parameters and key not in ["furniture_finish_atlas","furniture_normal_atlas","furniture_finish_uniform"]:material.set_shader_parameter(key,current[key])
	if enabled:
		if record.atlas!=null:
			material.set_shader_parameter("furniture_finish_atlas",record.atlas)
			material.set_shader_parameter("furniture_normal_atlas",record.atlas)
		else:material.set_shader_parameter("furniture_finish_uniform",record.uniform)
	else:
		for key in ["furniture_finish_atlas","furniture_normal_atlas","furniture_finish_uniform"]:material.set_shader_parameter(key,record.parameters.get(key))

func apply_bounds(mesh:MeshInstance3D) -> void:
	var bounds:=mesh.get_aabb()
	mesh.set_instance_shader_parameter("material_bounds_min",bounds.position)
	mesh.set_instance_shader_parameter("material_bounds_size",bounds.size)

func restore() -> void:
	set_enabled(false);records.clear();shaders.clear();bindings.clear()

func focus(kind:String) -> bool:
	var wanted:Array=["cabinet","server","shelf","water_dispenser","workstation","table"] if kind=="metal" else ["copier","water_dispenser","workstation","fridge"] if kind=="plastic" else ["table","coffee_table","dining_table","workstation"]
	for target in wanted:
		for record in records:
			if record.kind!=target:continue
			var actor:Node2D=record.actor.get_ref()
			if not is_instance_valid(actor):continue
			for offset in [Vector2.DOWN*80,Vector2.LEFT*80,Vector2.RIGHT*80,Vector2.UP*80]:
				var point:Vector2=actor.global_position+offset
				if not world._content_position_is_clear(point,12.0):continue
				world.player.global_position=point;world.player.velocity=Vector2.ZERO
				focus_actor=weakref(actor)
				world.activate_room(int(actor.get_meta(&"dream_room_id",0)))
				world._update_camera_and_actor_projection(0.0);return true
	return false
