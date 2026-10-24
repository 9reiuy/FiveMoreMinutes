extends Node3D
## One cropped silhouette per whole model, never inverted hulls per part.
## Camera frustum is a pixel-aligned crop of the real gameplay perspective.
var world: Node3D
var model: Node3D
var actor: Node2D
var center_offset:=Vector3.ZERO
var radius:=2.0
var capture: SubViewport
var camera: Camera3D
var border: MeshInstance3D
var material: ShaderMaterial
var records: Array[Dictionary]=[]
var aimed:=false
var melee:=false
var enabled:=true

func configure(owner_world: Node3D, source: Node3D, target: Node2D, offset: Vector3, bound: float) -> void:
	world=owner_world; model=source; actor=target; center_offset=offset; radius=bound
	name="UnitSilhouetteOutline"
	capture=SubViewport.new(); capture.size=Vector2i(256,256); capture.transparent_bg=true
	capture.world_3d=World3D.new(); capture.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(capture)
	camera=Camera3D.new(); capture.add_child(camera); camera.current=true
	var flat:=StandardMaterial3D.new(); flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; flat.albedo_color=Color.WHITE
	for raw in model.find_children("*","MeshInstance3D",true,false):
		var source_mesh: MeshInstance3D=raw
		source_mesh.material_overlay=null
		if source_mesh.mesh==null or source_mesh.find_parent("MuzzleFire")!=null: continue
		var copy:=MeshInstance3D.new(); copy.mesh=source_mesh.mesh; copy.material_override=flat
		copy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		capture.add_child(copy); records.append({"source":weakref(source_mesh),"copy":copy})
	border=MeshInstance3D.new(); border.mesh=QuadMesh.new(); border.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new(); material.shader=preload("res://shaders/dream3d/special_unit_silhouette.gdshader")
	material.set_shader_parameter("silhouette",capture.get_texture()); border.material_override=material; add_child(border)
	actor.set_meta(&"depth_visual_bridge",weakref(self))
	_connect_frame_sync()
	sync()

func _enter_tree() -> void:
	# Floor stash/rollback reparents the visual without configuring it again.
	if is_instance_valid(capture): _connect_frame_sync()

func _connect_frame_sync() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(sync): RenderingServer.frame_pre_draw.connect(sync)

func set_target_highlight_state(state: int) -> void: aimed=state==1
func set_combat_range_highlight(value: bool) -> void: melee=value
func set_enabled(value: bool) -> void:
	enabled=value
	if is_instance_valid(border): border.visible=value
	if is_instance_valid(capture): capture.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func sync() -> void:
	if not is_inside_tree() or not is_instance_valid(world) or not is_instance_valid(world.camera_3d): return
	if not enabled or not can_process() or not is_instance_valid(model) or not is_instance_valid(actor) or actor.get("dead")==true or actor.get_meta(&"smoke_hidden_from_player",false):
		border.hide(); capture.render_target_update_mode=SubViewport.UPDATE_DISABLED; return
	var real: Camera3D=world.camera_3d
	var center:=model.get_parent_node_3d().to_global(center_offset)
	var size:=real.get_viewport().get_visible_rect().size
	var pixel:=real.unproject_position(center).round()
	var projected_radius:=real.unproject_position(center+real.global_basis.x*radius).distance_to(pixel)
	var extent:=clampi(int(pow(2,ceil(log(maxf(projected_radius*2.0+8.0,64.0))/log(2.0)))),64,512)
	var on_screen:=not real.is_position_behind(center) and Rect2(Vector2.ZERO,size).grow(extent*.5).has_point(pixel)
	border.visible=on_screen
	capture.render_target_update_mode=SubViewport.UPDATE_ALWAYS if on_screen else SubViewport.UPDATE_DISABLED
	if not on_screen: return
	if capture.size!=Vector2i(extent,extent): capture.size=Vector2i(extent,extent)
	var inverse:=real.global_transform.affine_inverse()
	var depth:=maxf(.1,-(inverse*center).z)
	var half:=Vector2.ONE*float(extent)*.5
	var tl:=inverse*real.project_position(pixel-half,real.near)
	var br:=inverse*real.project_position(pixel+half,real.near)
	var near_center:=inverse*real.project_position(pixel,real.near)
	camera.global_transform=real.global_transform
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.set_frustum(tl.y-br.y,Vector2(near_center.x,near_center.y),real.near,real.far)
	var a:=real.project_position(pixel-half,depth)
	var b:=real.project_position(pixel+half,depth)
	border.mesh.size=Vector2(absf((inverse*b).x-(inverse*a).x),absf((inverse*b).y-(inverse*a).y))
	border.global_transform=Transform3D(real.global_basis,real.project_position(pixel,depth))
	material.set_shader_parameter("rim_color",Color.WHITE if aimed or melee else Color(.55,.58,.62))
	material.set_shader_parameter("pixel_width",maxf(1.0,size.y/360.0))
	for record in records:
		var source: Node3D=record.source.get_ref()
		if not is_instance_valid(source): record.copy.hide(); continue
		record.copy.global_transform=source.global_transform
		record.copy.visible=source.is_visible_in_tree()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync): RenderingServer.frame_pre_draw.disconnect(sync)
	if is_instance_valid(capture): capture.render_target_update_mode=SubViewport.UPDATE_DISABLED
