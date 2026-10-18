extends Node3D
## Floor-owned presentation. One shared render; no duplicated gameplay actors.
const EXCLUDED:=1<<19
const CAPTURE_FLAG:=1<<18
const SURFACE_INCLUDE="res://shaders/dream3d/floor_reflection_surface.gdshaderinc"
const PROFILES={
	"restroom":Vector4(.23,1.15,.24,.55), "pantry":Vector4(.20,1.25,.20,.60),
	"reception":Vector4(.28,1.45,.26,.48), "corridor":Vector4(.10,2.0,.10,.72),
	"conference":Vector4(.045,2.1,.055,.78), "manager":Vector4(.045,2.1,.055,.78),
	"lounge":Vector4(.035,2.2,.04,.82), "office":Vector4(0,0,0,1)}
var world:Node3D
var camera:Camera3D
var viewport:SubViewport
var original_camera_mask:=0
var original_token:=-1
var enabled:=true
var update_hz:=15.0
var renders:=0
var cpu_usec:=0
var restored:=false
var surfaces:Array[Dictionary]=[]
var layers:Array[Dictionary]=[]
var lights:Array[Dictionary]=[]
var actor_shaders:Array[Dictionary]=[]
var actor_materials:Array[ShaderMaterial]=[]
var surface_shaders:Dictionary={}
var carrier_shaders:Dictionary={}
var installed_ids:Dictionary={}
var production_mode:=false
var dungeon:=false
var floor_materials:Array[ShaderMaterial]=[]
var floor_variants:Dictionary={}
var static_variants:Dictionary={}
var replacements:Array[Dictionary]=[]
var pending:Array[WeakRef]=[]
var actor_bindings:Array[Dictionary]=[]
var last_render_usec:=0
var cleanup_elapsed:=0.0

static func install(owner_world:Node3D)->Node3D:
	if bool(owner_world.get_meta(&"test_floor_reflections_disabled",false)): return null
	if owner_world.has_method("get_current_floor_token") and (not owner_world.approved_sample_art_enabled or owner_world.use_authored_office_sample): return null
	var existing:=owner_world.get_node_or_null("FloorReflections")
	if is_instance_valid(existing): return existing
	var component:=load("res://scripts/dream/floor_reflections.gd").new() as Node3D
	component.name="FloorReflections"; component.production_mode=true
	owner_world.add_child(component); component.configure(owner_world)
	return component

static func uninstall(owner_world:Node3D)->void:
	var component:=owner_world.get_node_or_null("FloorReflections")
	if is_instance_valid(component): component.restore(); component.free()

func _token()->int:
	return world.get_current_floor_token() if dungeon else 0

func _transitioning()->bool:
	return world.floor_transition_in_progress if dungeon else world.elevator_transition_in_progress

static func profile(key:String)->Vector4: return PROFILES.get(key,Vector4(.025,2.0,.035,.86))

func configure(owner_world:Node3D)->void:
	world=owner_world; dungeon=world.has_method("get_current_floor_token"); original_token=_token()
	original_camera_mask=world.camera_3d.cull_mask
	world.camera_3d.cull_mask=(original_camera_mask|EXCLUDED)&~CAPTURE_FLAG
	viewport=SubViewport.new(); viewport.name="FloorReflectionViewport"
	viewport.size=Vector2i(256,144); viewport.world_3d=world.get_world_3d()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	# Main lighting/shadows stay untouched. The blurred secondary colour view
	# uses existing lights without a second positional shadow atlas.
	viewport.positional_shadow_atlas_size=0; viewport.msaa_3d=Viewport.MSAA_DISABLED
	add_child(viewport)
	camera=Camera3D.new(); camera.name="FloorReflectionCamera"; viewport.add_child(camera)
	camera.cull_mask=(original_camera_mask&~EXCLUDED)|CAPTURE_FLAG
	camera.current=true
	var env:WorldEnvironment=world.get_node_or_null("Lighting/WorldEnvironment")
	if env!=null:
		camera.environment=env.environment.duplicate()
		camera.environment.background_mode=Environment.BG_COLOR
		camera.environment.background_color=Color.BLACK
	_install_surfaces()
	_install_scene_carriers()
	for light in world.find_children("*","Light3D",true,false): _register_light(light)
	process_priority=120
	RenderingServer.frame_pre_draw.connect(_before_draw)
	get_tree().node_added.connect(_on_node_added)

func _register_light(light:Light3D)->void:
	if installed_ids.has(light.get_instance_id()): return
	installed_ids[light.get_instance_id()]=weakref(light)
	lights.append({"node":weakref(light),"old":light.light_cull_mask})
	light.light_cull_mask|=EXCLUDED

func _on_node_added(node:Node)->void:
	if world.is_ancestor_of(node) and (node is GeometryInstance3D or node is Light3D) and not installed_ids.has(node.get_instance_id()):
		pending.append(weakref(node))

func _register_visual(node:GeometryInstance3D)->void:
	if installed_ids.has(node.get_instance_id()): return
	if node is Sprite3D:
		var bridge:Node=node.get_parent()
		if bridge!=null and bridge.get_script()==preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd") and bridge.character_projection and (node==bridge.actor_sprite or node==bridge.weapon_sprite):
			_replace_material(node,true)
		else: _exclude(node)
	elif node is MeshInstance3D:
		if node.name.begins_with("FloorBatch_"): return
		_replace_material(node,false)

func _install_surfaces()->void:
	for mesh in world.floor_root.get_children():
		if not mesh is MeshInstance3D or not mesh.name.begins_with("FloorBatch_"): continue
		_exclude(mesh)
		for index in mesh.mesh.get_surface_count():
			var source:Material=mesh.get_active_material(index)
			if not source is ShaderMaterial: continue
			var key:String=source.get_meta(&"floor_surface_style","office")
			var material:ShaderMaterial
			if floor_variants.has(source.get_instance_id()): material=floor_variants[source.get_instance_id()]
			else:
				material=source.duplicate() as ShaderMaterial
				material.shader=_surface_shader(source.shader)
				_bind_surface(material,key)
				floor_variants[source.get_instance_id()]=material
			surfaces.append({"node":weakref(mesh),"index":index,"old":mesh.get_surface_override_material(index),"material":material,"style":key})
			mesh.set_surface_override_material(index,material)

func _bind_surface(material:ShaderMaterial,key:String)->void:
	var values:=profile(key)
	material.set_shader_parameter("sample_reflection_texture",viewport.get_texture())
	material.set_shader_parameter("sample_reflection_size",Vector2(viewport.size))
	material.set_shader_parameter("sample_reflection_strength",values.x)
	material.set_shader_parameter("sample_reflection_blur",values.y)
	material.set_shader_parameter("sample_surface_gloss",values.z)
	material.set_shader_parameter("sample_surface_roughness",values.w)
	material.set_shader_parameter("sample_surface_enabled",enabled)
	floor_materials.append(material)

func _surface_shader(source:Shader)->Shader:
	var shader_key:=source.code.hash()
	if surface_shaders.has(shader_key): return surface_shaders[shader_key]
	var code:=source.code.replace("shader_type spatial;","shader_type spatial;\n#include \""+SURFACE_INCLUDE+"\"")
	code=code.replace("ALBEDO = texture(atlas, atlas_uv).rgb;","ALBEDO = texture(atlas, atlas_uv).rgb;\nEMISSION += sample_surface_reflection(architecture_world, ALBEDO);")
	# Preserve the approved ordered diffuse path and its existing shadow attenuation.
	var start:=code.find("void light()")
	if start>=0:
		var open:=code.find("{",start); var end:=open+1; var depth:=1
		while depth>0 and end<code.length():
			if code[end]=="{": depth+=1
			elif code[end]=="}": depth-=1
			end+=1
		code=code.insert(end-1,"\nSPECULAR_LIGHT += sample_surface_highlight(NORMAL,LIGHT,VIEW,LIGHT_COLOR,ATTENUATION,architecture_world,ALBEDO);\n")
	var shader:=Shader.new(); shader.code=code; surface_shaders[shader_key]=shader
	return shader

func set_preview_style(key:String,original_style:String="office")->void:
	# Controlled sample: the actual room stays intact while its existing floor
	# uses another approved room's exact texture/normal material for comparison.
	floor_materials.clear()
	var coordinator:Node=world.office_art_root.get_node("ApprovedOfficeArt").floors
	var source:ShaderMaterial=coordinator.floor_material({"archetype":key})
	for record in surfaces:
		if record.style!=original_style: continue
		var material:=source.duplicate() as ShaderMaterial
		material.shader=_surface_shader(source.shader)
		_bind_surface(material,key)
		record.material=material
		var node:Node=record.node.get_ref()
		if is_instance_valid(node): node.set_surface_override_material(record.index,material)
	for record in surfaces:
		if not floor_materials.has(record.material): floor_materials.append(record.material)

func _exclude(node:VisualInstance3D)->void:
	if installed_ids.has(node.get_instance_id()): return
	installed_ids[node.get_instance_id()]=weakref(node)
	layers.append({"node":weakref(node),"old":node.layers}); node.layers=EXCLUDED

func _install_scene_carriers()->void:
	var art:Node=world.office_art_root.get_node_or_null("ApprovedOfficeArt") if dungeon else null
	var city:Node=art.city.scene_root if art!=null else null
	if is_instance_valid(city):
		for visual in city.find_children("*","VisualInstance3D",true,false): _exclude(visual)
	var bridges:Array=world.actor_depth_bridges_root.get_children()
	if is_instance_valid(world.player_depth_bridge) and not bridges.has(world.player_depth_bridge): bridges.append(world.player_depth_bridge)
	for bridge in bridges:
		if bridge.get("character_projection")==true:
			for name in ["actor_sprite","weapon_sprite"]:
				var sprite:Sprite3D=bridge.get(name)
				if sprite!=null: _replace_material(sprite,true)
			if bridge.get("attachment_sprite")!=null: _exclude(bridge.attachment_sprite)
		else:
			for sprite in bridge.find_children("*","Sprite3D",true,false): _exclude(sprite)
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		if installed_ids.has(mesh.get_instance_id()): continue
		_replace_material(mesh,false)
	# Ground blood, shell carriers and native smoke must not reflect recursively.
	for sprite in world.find_children("*","Sprite3D",true,false):
		if not installed_ids.has(sprite.get_instance_id()): _exclude(sprite)

func _replace_material(node:GeometryInstance3D,actor:bool)->void:
	if installed_ids.has(node.get_instance_id()): return
	installed_ids[node.get_instance_id()]=weakref(node)
	var source:Material=node.material_override
	if not source is ShaderMaterial: return
	var code:String=source.shader.code
	if not code.begins_with("shader_type spatial;"): return
	# Raw swatches/atlases are process-wide caches. A queued old scene can
	# coexist with the next scene for one frame, so never mutate those caches.
	# Actor, dither, wall-cutaway and aperture materials are owner-local and
	# must keep their references for ongoing uniform writes.
	var raw_swatch:bool=source.shader==preload("res://shaders/dream3d/office_pixel_surface.gdshader") or source.shader==preload("res://shaders/dream3d/office_low_pixel.gdshader")
	var live:bool=not raw_swatch and (actor or source.has_meta(&"dither_origin") or code.contains("architecture_cutaway") or code.contains("world_to_door"))
	if not live:
		var old:Material=source
		if not static_variants.has(old.get_instance_id()):
			var local:ShaderMaterial=source.duplicate()
			local.set_meta(&"dither_origin",false)
			static_variants[old.get_instance_id()]=local
		source=static_variants[old.get_instance_id()]
		node.material_override=source
		replacements.append({"node":weakref(node),"old":old})
		code=source.shader.code
	if source.shader.code.contains("sample_capture_pass"):
		if actor:
			actor_bindings.append({"node":weakref(node),"material":source})
			if not actor_materials.has(source): actor_materials.append(source)
		return
	var material:ShaderMaterial
	if not code.contains("sample_capture_pass"):
		material=source
		var header:="\nuniform vec3 sample_primary_eye;\nvarying float sample_capture_pass;\n"
		header+="varying vec3 sample_capture_world;\n"
		var vertex:="sample_capture_pass=(CAMERA_VISIBLE_LAYERS & 262144u)!=0u ? 1.0 : 0.0;\n"
		if actor and code.contains("character_reference_depth.gdshaderinc"):
			vertex+="if(sample_capture_pass>0.5 && reference_depth_enabled){ vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; vec3 ray=p-sample_primary_eye; float d=dot(reference_plane_normal,ray); if(abs(d)>0.00001){ float t=dot(reference_plane_normal,reference_plane_origin-sample_primary_eye)/d; if(t>0.0){ VERTEX=(inverse(MODEL_MATRIX)*vec4(sample_primary_eye+ray*t,1.0)).xyz; } } }\n"
		vertex+="sample_capture_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;\n"
		code=code.replace("shader_type spatial;","shader_type spatial;"+header)
		var function:=RegEx.new(); function.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var function_match:=function.search(code)
		if function_match!=null: code=code.insert(function_match.get_end(),"\n"+vertex)
		else: code+="\nvoid vertex(){"+vertex+"}\n"
		function.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
		function_match=function.search(code)
		if function_match!=null:
			code=code.insert(function_match.get_end(),"\nif(sample_capture_pass>0.5 && sample_capture_world.y<0.005){discard;}\n")
		code=code.replace("combined_cutout(SCREEN_UV)","(sample_capture_pass>0.5 ? 1.0 : combined_cutout(SCREEN_UV))")
		var shader_key:=code.hash()
		if not carrier_shaders.has(shader_key):
			var shader:=Shader.new(); shader.code=code; carrier_shaders[shader_key]=shader
		actor_shaders.append({"material":weakref(source),"shader":source.shader})
		material.shader=carrier_shaders[shader_key]
	if actor:
		# The actor bridge continues writing live depth-plane uniforms to this
		# exact material. Replacing its resource would freeze moving actors.
		actor_bindings.append({"node":weakref(node),"material":source})
		if not actor_materials.has(source): actor_materials.append(source)

func set_enabled(value:bool)->void:
	enabled=value
	for record in surfaces: record.material.set_shader_parameter("sample_surface_enabled",value)
	if not value: viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	else: last_render_usec=0

func _process(delta:float)->void:
	if not is_instance_valid(world) or _token()!=original_token:
		restore(); queue_free(); return
	if _transitioning() and not production_mode:
		restore(); queue_free(); return
	# New carriers/lights only; never rescan a whole floor during combat.
	for i in mini(24,pending.size()):
		var node:Node=pending.pop_front().get_ref()
		if not is_instance_valid(node): continue
		if node is Light3D: _register_light(node)
		else: _register_visual(node)
	cleanup_elapsed+=delta
	if cleanup_elapsed>=1.0:
		cleanup_elapsed=0.0
		actor_bindings=actor_bindings.filter(func(r:Dictionary)->bool:return is_instance_valid(r.node.get_ref()))
		actor_materials.clear()
		for record in actor_bindings:
			if not actor_materials.has(record.material): actor_materials.append(record.material)
		actor_shaders=actor_shaders.filter(func(r:Dictionary)->bool:return is_instance_valid(r.material.get_ref()))
		layers=layers.filter(func(r:Dictionary)->bool:return is_instance_valid(r.node.get_ref()))
		lights=lights.filter(func(r:Dictionary)->bool:return is_instance_valid(r.node.get_ref()))
		for id in installed_ids.keys():
			if not is_instance_valid(installed_ids[id].get_ref()): installed_ids.erase(id)

func _before_draw()->void:
	if restored or not enabled: return
	var exiting:bool=dungeon and world.transition_phase==&"EXITING"
	var covered_exit:bool=exiting and get_tree().root.has_node("FloorExitRenderPreparationCover")
	# The existing paused arrival cover already submits the final floor pose.
	# Warm its reflection there, so opening the doors does not reveal black
	# reflections that suddenly appear only after the scripted walk finishes.
	if not can_process() and not covered_exit: return
	if production_mode and _transitioning() and not exiting: return
	var started:=Time.get_ticks_usec()
	if started-last_render_usec<1000000.0/update_hz: return
	last_render_usec=started
	if viewport.world_3d!=world.get_world_3d(): viewport.world_3d=world.get_world_3d()
	for record in lights:
		var light:Light3D=record.node.get_ref()
		if is_instance_valid(light) and light.light_cull_mask&EXCLUDED==0: light.light_cull_mask|=EXCLUDED
	var main:Camera3D=world.camera_3d
	var transform:=main.global_transform
	var eye:=transform.origin; eye.y=-eye.y
	var forward:=-transform.basis.z; forward.y=-forward.y
	var up:=transform.basis.y; up.y=-up.y
	camera.global_transform=Transform3D(Basis.looking_at(forward,up),eye)
	camera.projection=main.projection; camera.fov=main.fov; camera.size=main.size
	var focus:Vector3=world.get_gameplay_world_position(world.player.global_position,0.0)
	camera.near=main.near; camera.far=minf(main.far,main.global_position.distance_to(focus)+7.0); camera.keep_aspect=main.keep_aspect
	for material in actor_materials: material.set_shader_parameter("sample_primary_eye",main.global_position)
	var reflection_view:Transform3D=camera.global_transform.affine_inverse()
	var reflection_projection:Projection=camera.get_camera_projection()
	for material in floor_materials:
		material.set_shader_parameter("sample_reflection_view",reflection_view)
		material.set_shader_parameter("sample_reflection_projection",reflection_projection)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	renders+=1; cpu_usec+=Time.get_ticks_usec()-started

func restore()->void:
	if restored: return
	restored=true
	if RenderingServer.frame_pre_draw.is_connected(_before_draw): RenderingServer.frame_pre_draw.disconnect(_before_draw)
	if get_tree()!=null and get_tree().node_added.is_connected(_on_node_added): get_tree().node_added.disconnect(_on_node_added)
	if is_instance_valid(world) and is_instance_valid(world.camera_3d): world.camera_3d.cull_mask=original_camera_mask
	for record in surfaces:
		var node:Node=record.node.get_ref()
		if is_instance_valid(node): node.set_surface_override_material(record.index,record.old)
	for record in replacements:
		var node:Node=record.node.get_ref()
		if is_instance_valid(node): node.material_override=record.old
	for record in actor_shaders:
		var material:ShaderMaterial=record.material.get_ref()
		if material!=null: material.shader=record.shader
	for record in layers:
		var node:Node=record.node.get_ref()
		if is_instance_valid(node): node.layers=record.old
	for record in lights:
		var node:Node=record.node.get_ref()
		if is_instance_valid(node): node.light_cull_mask=record.old
	if is_instance_valid(viewport): viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _exit_tree()->void:
	# The display wrapper moves the live world into its pixel viewport once.
	# This is the same world, not a scene exit or a floor transaction.
	if is_instance_valid(world) and world.has_meta(&"display_reparenting"): return
	restore()
