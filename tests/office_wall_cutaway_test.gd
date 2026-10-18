extends SceneTree
const WALL=preload("res://scenes/dream/3d/WallStraight3D.tscn")
const SERVICE=preload("res://scripts/dream/office_wall_cutaway.gd")
const ART=preload("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")
var checks:=0
var failures:=0
class MockWorld extends Node3D:
	var wall_root:=Node3D.new()
func _initialize()->void: call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value: failures+=1; push_error(message)
func material(style:String)->ShaderMaterial:
	var result:=ShaderMaterial.new(); result.shader=preload("res://shaders/dream3d/office_low_pixel.gdshader")
	result.set_shader_parameter("atlas",ImageTexture.create_from_image(ART.wall_image(style,2.6)))
	return result
func run()->void:
	var world:=MockWorld.new(); root.add_child(world); world.add_child(world.wall_root)
	var front:=material("archive"); var back:=material("server")
	var shadows: Array=[]
	for i in 3:
		var wall=WALL.instantiate(); wall.position=Vector3(i+.5,0,0)
		world.wall_root.add_child(wall); wall.configure_wall(2.6,.5); wall.set_wall_materials(front,back)
		shadows.append(wall.shadow_mesh.mesh)
	var service:=SERVICE.new(); service.configure(world)
	for enabled in [true,false,true]:
		for wall in world.wall_root.get_children(): wall.set_cutaway_mode(enabled)
		service.refresh()
		for i in 3:
			var wall=world.wall_root.get_child(i)
			check(wall.wall_mesh.get_active_material(0)==front and wall.wall_mesh.get_active_material(1)==back,"Opposite room faces retain their distinct material identities after mode changes")
			check(wall.wall_mesh.get_active_material(0).get_shader_parameter("atlas")==front.get_shader_parameter("atlas"),"Original front atlas binding survives")
			check(wall.wall_mesh.get_active_material(1).get_shader_parameter("atlas")==back.get_shader_parameter("atlas"),"Original back atlas binding survives")
			check(wall.shadow_mesh.mesh==shadows[i] and is_equal_approx(wall.wall_thickness,.5),"Original full shadow and authoritative thickness survive")
			check(wall.wall_mesh.mesh==(wall.office_cut_mesh if enabled else wall.office_full_mesh),"Room mode selects the persistent production geometry profile")
		var middle: Mesh=world.wall_root.get_child(1).wall_mesh.mesh
		check(is_equal_approx(middle.get_aabb().end.y,.12 if enabled else 2.6),"Middle geometry switches between low root and full wall")
	var refreshed:=material("pantry")
	for wall in world.wall_root.get_children():
		wall.set_wall_materials(refreshed,back)
		check(wall.wall_mesh.get_active_material(0)==refreshed and wall.wall_mesh.get_active_material(1)==back,"Late approved-art refresh preserves the new face and the other room face")
		check(wall.wall_mesh.get_active_material(2)==wall.office_section_material,"Late art refresh cannot replace the cut section")
	world.free()
	print("OFFICE_WALL_CUTAWAY_UNIT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
