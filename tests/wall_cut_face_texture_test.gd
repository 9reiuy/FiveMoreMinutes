extends SceneTree
const SAMPLE=preload("res://scripts/dream/preview/wall_cut_face_texture_sample.gd")
const WALL=preload("res://scenes/dream/3d/WallStraight3D.tscn")
var checks:=0
var failures:=0
class SampleWorld extends Node3D:
	var wall_root:=Node3D.new()
	var door_root:=Node3D.new()
	var floor_root:=Node3D.new()
	var wall_height:=2.6
	var wall_thickness:=.5
	var room_cells: Dictionary={Vector2i.ZERO:0}
	func _edge_side_cells(_edge: Dictionary) -> Array: return [Vector2i.ZERO]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func mesh_signature(node: Node) -> Array:
	var result: Array=[]
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		result.append([mesh.get_instance_id(),mesh.mesh.get_rid(),mesh.mesh.get_surface_count(),mesh.transform,mesh.cast_shadow])
	return result
func run() -> void:
	for angle in [0.0,-PI*.25]:
		for cut in [false,true]:
			var world:=SampleWorld.new(); root.add_child(world); world.rotation.y=angle
			for child in [world.wall_root,world.door_root,world.floor_root]: world.add_child(child)
			var wall=WALL.instantiate(); wall.set_meta("edge",{"axis":"H","x":0,"y":0})
			world.wall_root.add_child(wall); wall.configure_wall(2.6,.5); wall.set_cutaway_mode(cut)
			if absf(angle)>.1:
				var material:=ShaderMaterial.new()
				material.shader=preload("res://shaders/dream3d/office_low_pixel.gdshader")
				var atlas_image:=Image.create(32,32,false,Image.FORMAT_RGBA8)
				atlas_image.fill(Color(.4,.5,.6))
				material.set_shader_parameter("atlas",ImageTexture.create_from_image(atlas_image))
				wall.set_wall_materials(material)
				wall.set_window_variant(true)
				wall.set_cutaway_mode(cut)
			var before:=mesh_signature(world)
			var original: Array=[]
			for index in 3: original.append(wall.wall_mesh.get_surface_override_material(index))
			var sample:=SAMPLE.new(); world.add_child(sample); sample.apply(world,0)
			check(mesh_signature(world)==before,"Texture sample adds no MeshInstances and preserves all mesh resources, transforms and shadow flags")
			check(wall.wall_mesh.mesh.get_surface_count()==3,"Original front/end, back and top surfaces remain intact")
			check(wall.cutaway_mode==cut,"Texture sample preserves production full/cut state")
			var texture: Texture2D=sample.section_texture
			check(texture!=null,"A real shared section texture is assigned")
			if texture!=null:
				var image: Image=texture.get_image()
				check(image!=null and image.get_width()>2 and image.get_height()>2,"Section texture contains actual pixel data")
				var edge: Color=image.get_pixel(0,image.get_height()/2)
				var core: Color=image.get_pixel(image.get_width()/2,image.get_height()/2)
				check(edge.get_luminance()>core.get_luminance(),"Exposed section has a brighter border than its solid core")
			var source: ShaderMaterial=original[0]
			var patched: ShaderMaterial=wall.wall_mesh.get_surface_override_material(0)
			check(patched!=source,"Section changes are isolated from the original wall material")
			check(patched.get_shader_parameter("albedo_texture")==source.get_shader_parameter("albedo_texture"),"Original broad wall face keeps its authored texture")
			check(patched.get_shader_parameter("atlas")==source.get_shader_parameter("atlas"),"Production pixel-wall atlas binding remains unchanged")
			check(is_equal_approx(float(patched.get_shader_parameter("section_thickness")),wall.wall_mesh.mesh.get_aabb().size.z),"Full window frame and cut wall use their actual mesh thickness for UVs")
			var applied: Texture2D=patched.get_shader_parameter("section_pixels")
			check(applied.get_width()==roundi(wall.wall_mesh.mesh.get_aabb().size.z*32),"Section texture density remains 32 pixels per world unit")
			check(wall.shadow_mesh.mesh.get_aabb().size.y>=2.599,"Cut state retains original full-height light blocker")
			sample.restore()
			check(mesh_signature(world)==before,"Restore leaves original geometry untouched")
			for index in 3:
				check(wall.wall_mesh.get_surface_override_material(index)==original[index],"Restore returns the original surface material")
			world.free()
	print("WALL_CUT_FACE_TEXTURE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
