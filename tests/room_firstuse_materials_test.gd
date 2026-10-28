extends SceneTree
const COLLECT=preload("res://scripts/dream/room_firstuse_render_materials.gd")
const OUTLINE=preload("res://scripts/dream/units/special_unit_outline.gd")
var checks:=0
var failures:Array=[]

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)

func group(parent:Node,name:String)->Node3D:
	var node:=Node3D.new();node.name=name;parent.add_child(node);return node

func shader(value:float)->ShaderMaterial:
	var code:=Shader.new();code.code="shader_type spatial; uniform float gain=1.0; void fragment(){ALBEDO=vec3(%s)*gain;}"%value
	var material:=ShaderMaterial.new();material.shader=code;material.set_shader_parameter("gain",.8);return material

func mesh(parent:Node,name:String,material:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=name;node.mesh=BoxMesh.new();node.material_override=material;parent.add_child(node);return node

func _initialize()->void:call_deferred("run")

func run()->void:
	check(COLLECT.collect(null).materials.is_empty(),"null world safe")
	var detached:=Node3D.new();check(COLLECT.collect(detached).materials.is_empty(),"detached world excluded");detached.free()
	var world:=group(root,"Owner")
	check(COLLECT.collect(world).materials.is_empty(),"empty world has no fabricated samples")
	var generated:=group(world,"GeneratedBuildingRoot")
	var doors:=group(generated,"DoorRoot");var walls:=group(generated,"WallRoot");var floors:=group(generated,"FloorRoot")
	var door_mat:=shader(.1);var robot_mat:=shader(.2);var rim_mat:=shader(.3);var sign_mat:=shader(.4);var fire_mat:=shader(.5)
	var observation:=mesh(group(group(doors,"Door"),"DoorVisual"),"ObservationGlass",door_mat)
	var ignored_surface:=shader(.9);observation.mesh.material=ignored_surface
	var robots:=group(world,"HotelRobotVisuals");var robot:=group(robots,"Robot");var model:=group(robot,"RobotModel")
	mesh(model,"Plinth",robot_mat)
	var outline:=OUTLINE.new();outline.name="UnitSilhouetteOutline";robot.add_child(outline)
	outline.border=mesh(outline,"Border",rim_mat)
	var fixtures:=group(floors,"ApprovedRandomRoomFixtures_0")
	mesh(fixtures,"WallFixture_sign",sign_mat)
	var duplicate_sign:=shader(.4);mesh(fixtures,"WallFixture_whiteboard",duplicate_sign)
	mesh(group(fixtures,"WallFixture_fire"),"Body",fire_mat)
	var flat:=StandardMaterial3D.new();flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh(walls,"ShadowCasterMesh",flat)
	var foreign:=group(root,"Foreign");mesh(foreign,"ObservationGlass",shader(.7))
	var stash:=group(world,"FloorRollbackStash");var old_outline:=OUTLINE.new();stash.add_child(old_outline);old_outline.border=mesh(old_outline,"Border",shader(.8))
	var before:=var_to_bytes([door_mat.get_instance_id(),door_mat.shader.get_instance_id(),door_mat.shader.code,door_mat.get_shader_parameter("gain"),world.get_child_count()])
	var selected:Dictionary=COLLECT.collect(world)
	check(selected.materials.size()==6,"five shader families and one native flat")
	check(selected.report.shader_families==5 and selected.report.flat_found,"family report matches actual samples")
	for material in [door_mat,robot_mat,rim_mat,sign_mat,fire_mat,flat]:check(material in selected.materials,"exact source resource retained")
	check(not duplicate_sign in selected.materials,"equal shader code deduplicated across material instances")
	check(not ignored_surface in selected.materials,"override hides unused surface material")
	check(not old_outline.border.material_override in selected.materials,"retained-floor outline excluded")
	check(var_to_bytes([door_mat.get_instance_id(),door_mat.shader.get_instance_id(),door_mat.shader.code,door_mat.get_shader_parameter("gain"),world.get_child_count()])==before,"source nodes/material/shader/uniform unchanged")
	var base_mesh:=BoxMesh.new();base_mesh.material=robot_mat
	var multi:=MultiMeshInstance3D.new();multi.name="Body";multi.multimesh=MultiMesh.new();multi.multimesh.transform_format=MultiMesh.TRANSFORM_3D;multi.multimesh.mesh=base_mesh;multi.multimesh.instance_count=1;model.add_child(multi)
	check(COLLECT.collect(world).materials.size()==6,"MultiMesh surface uses the same source family")
	var empty:=ShaderMaterial.new();empty.shader=Shader.new();observation.material_override=empty
	check(COLLECT.collect(world).report.shader_families==4,"empty shader excluded")
	observation.material_override=door_mat
	world.queue_free();check(COLLECT.collect(world).materials.is_empty(),"queued owner excluded")
	foreign.free();await process_frame
	print("ROOM_FIRSTUSE_MATERIALS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
