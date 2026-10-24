extends SceneTree
## Isolated GPU preview of the production smoke controller, not Main acceptance.
const SYSTEM=preload("res://scripts/dream/fire_extinguisher_system.gd")
const OUT="res://.runtime/extinguisher_cloud_halftone_20261024"
class World extends Node3D:
	var floor_root:=Node3D.new()
	var door_root:=Node3D.new()
	var key_root:=Node2D.new()
	var actor_depth_bridges_root:=Node3D.new()
	var camera_3d: Camera3D
	var floor_transition_in_progress:=false
	var floor_cells: Dictionary={}
	var wall_edges: Dictionary={}
	var glass_wall_edges: Dictionary={}
	var window_wall_edges: Dictionary={}
	var door_opening_edges: Dictionary={}
	var room_cells: Dictionary={}
	var pit_cells: Dictionary={}
	var rooms: Array=[{"type":"office"}]
	var active_seed:=331
	func _ready() -> void:
		for node in [floor_root,door_root,key_root,actor_depth_bridges_root]:add_child(node)
	func get_gameplay_world_position(at: Vector2,height: float) -> Vector3:return to_global(Vector3(at.x/32,height,at.y/32))
	func _cell_for_gameplay_position(at: Vector2) -> Vector2i:return Vector2i((at/32).round())
	func _edge_key(edge: Dictionary) -> String:return "%s:%d:%d" % [edge.axis,edge.x,edge.y]
	func _edge_from_cell_direction(cell: Vector2i,d: Vector2i) -> Dictionary:
		return {"axis":"H","x":cell.x,"y":cell.y+(1 if d.y>0 else 0)} if d.y!=0 else {"axis":"V","x":cell.x+(1 if d.x>0 else 0),"y":cell.y}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	preload("res://tests/support/background_gpu.gd").start(self)
	var monitor:=root.get_node_or_null("PerformanceMonitor")
	if monitor!=null:monitor.current_mode=0;monitor._update_display_mode()
	root.size=Vector2i(960,540);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport:=SubViewport.new();viewport.size=Vector2i(480,270);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var world:=World.new();viewport.add_child(world)
	for y in range(-2,3):
		for x in range(-3,4):
			world.floor_cells[Vector2i(x,y)]="room";world.room_cells[Vector2i(x,y)]=0
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("151e34");world.add_child(env)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.4
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-20,0);sun.light_energy=1.0;sun.shadow_enabled=true;world.add_child(sun)
	var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(8,.1,6);floor_mesh.mesh=box;floor_mesh.position.y=-.05
	var floor_mat:=StandardMaterial3D.new();floor_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;floor_mat.albedo_color=Color("364760")
	floor_mesh.material_override=floor_mat;world.add_child(floor_mesh)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9
	world.add_child(camera);camera.position=Vector3(6,7,9);camera.look_at(Vector3(0,.6,0));camera.current=true;world.camera_3d=camera
	var display:=TextureRect.new();display.texture=viewport.get_texture();display.size=Vector2(960,540);display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(display)
	var palette:=ColorRect.new();palette.size=Vector2(960,540);var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/palette_quantize.gdshader");palette.material=material;root.add_child(palette)
	var system:=SYSTEM.install(world);system.set_physics_process(false);system.discharge(Vector2.ZERO)
	var max_puffs:=0
	for frame in 66:
		system.advance(.2);max_puffs=maxi(max_puffs,system.banks[0].visible_instance_count)
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"/cloud_%02d.png" % frame)
	print("CLOUD_PREVIEW scope=isolated_production_controller palette=on max_puffs=",max_puffs," cleared=",system.cells.is_empty()," final_instances=",system.banks[0].visible_instance_count)
	var valid: bool=system.cells.is_empty() and system.banks[0].visible_instance_count==0 and max_puffs<=192
	display.free();palette.free();viewport.free();await process_frame
	quit(0 if valid else 1)
