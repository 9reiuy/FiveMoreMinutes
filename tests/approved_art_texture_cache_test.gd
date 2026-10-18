extends SceneTree

const FLOOR = preload("res://scripts/dream/preview/sample_floor_texture_review.gd")
const WALL = preload("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")
class Fixture extends Node:
	var active_seed := 1
	var wall_height := 3.0
	var rooms: Array[Dictionary]=[{"archetype":"office"}]

var checks := 0
var failures := 0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func pixels(material: ShaderMaterial,parameter: StringName) -> PackedByteArray:
	var texture: Texture2D=material.get_shader_parameter(parameter)
	return texture.get_image().get_data() if texture!=null else PackedByteArray()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if "--background-gpu" in OS.get_cmdline_user_args(): preload("res://tests/support/background_gpu.gd").start(self)
	if DisplayServer.get_name()=="headless":
		push_error("Texture byte parity requires a real renderer"); quit(1); return
	var fixture:=Fixture.new()
	root.add_child(fixture)
	FLOOR.floor_texture_cache.clear(); WALL.wall_texture_cache.clear()
	for key in ["office","conference","manager","archive","server","pantry","restroom","lounge","reception","corridor"]:
		for seed in [1,2,3,4,5,6]:
			fixture.active_seed=seed
			var room: Dictionary={"archetype":key}
			fixture.set_meta(&"test_approved_art_texture_cache",false)
			var original:=FLOOR.new(); original.production_mode=true; original.world=fixture
			var before: ShaderMaterial=original.floor_material(room)
			fixture.set_meta(&"test_approved_art_texture_cache",true)
			var cached:=FLOOR.new(); cached.production_mode=true; cached.world=fixture
			var after: ShaderMaterial=cached.floor_material(room)
			check(not pixels(before,&"atlas").is_empty() and pixels(before,&"atlas")==pixels(after,&"atlas"),"Floor pixels "+key)
			check(pixels(before,&"review_bevel")==pixels(after,&"review_bevel"),"Floor normal pixels "+key)
			before.set_shader_parameter("office_dither_enabled",false)
			check(after.get_shader_parameter("office_dither_enabled")==true,"Floor materials remain independent")
			original.free(); cached.free()
	var wall:=Node3D.new(); wall.set_meta(&"edge",{"axis":"H"}); wall.position.x=7.0
	for key in ["office","conference","manager","archive","server","pantry","restroom","lounge","reception","corridor"]:
		for height in [2.0,3.0,3.01,4.0]:
			fixture.rooms=[{"archetype":key}]; fixture.wall_height=height
			fixture.set_meta(&"test_approved_art_texture_cache",false)
			var original:=WALL.new(); original.production_mode=true; original.world=fixture
			var before: ShaderMaterial=original._wall_material(0,wall)
			fixture.set_meta(&"test_approved_art_texture_cache",true)
			var cached:=WALL.new(); cached.production_mode=true; cached.world=fixture
			var after: ShaderMaterial=cached._wall_material(0,wall)
			check(not pixels(before,&"atlas").is_empty() and pixels(before,&"atlas")==pixels(after,&"atlas"),"Wall pixels "+key)
			check(after.get_shader_parameter("review_phase")==7.0 and after.get_shader_parameter("review_height")==height,"Wall placement parameters retained")
			before.set_shader_parameter("review_phase",99.0)
			check(after.get_shader_parameter("review_phase")==7.0,"Wall material uniforms independent")
			original.free(); cached.free()
	check(FLOOR.floor_texture_cache.size()<=FLOOR.FLOOR_TEXTURE_CACHE_LIMIT,"Floor cache is bounded")
	check(WALL.wall_texture_cache.size()<=WALL.WALL_TEXTURE_CACHE_LIMIT,"Wall cache is bounded")
	for style in ["solid","window","glass"]:
		for width in [1.0,1.01,1.5,2.0]:
			for index in [0,1]:
				var size:=Vector3(width,2.5,.2)
				var baseline: Texture2D=WALL._door_texture(size,style,index,false)
				var cached: Texture2D=WALL._door_texture(size,style,index,true)
				check(not baseline.get_image().is_empty() and baseline.get_image().get_data()==cached.get_image().get_data(),"Door atlas exact pixels "+style)
				check(WALL._door_shader(false).code==WALL._door_shader(true).code,"Door shader code unchanged")
	var glass_before: ShaderMaterial=WALL._glass_material(Vector2(1.5,2.0),false)
	var glass_after: ShaderMaterial=WALL._glass_material(Vector2(1.5,2.0),true)
	check(pixels(glass_before,&"glass_pixels")==pixels(glass_after,&"glass_pixels"),"Door glass exact pixels")
	check(glass_before.shader.code==glass_after.shader.code,"Glass shader code unchanged")
	glass_after.set_shader_parameter("architecture_cutaway",false)
	glass_before.set_shader_parameter("architecture_cutaway",true)
	check(glass_before.get_instance_id()!=glass_after.get_instance_id() and glass_after.get_shader_parameter("architecture_cutaway")==false,"Glass material cutaway independent")
	var coordinator:=WALL.new(); coordinator.world=fixture; coordinator.production_mode=true
	var leaf_a:=MeshInstance3D.new(); var leaf_b:=MeshInstance3D.new()
	var old_mesh:=BoxMesh.new(); var new_mesh:=BoxMesh.new(); var old_mat:=StandardMaterial3D.new()
	var saved_transform:=Transform3D(Basis.IDENTITY,Vector3(1,2,3))
	var record: Dictionary={"style":"solid","leaves":[]}
	for node in [leaf_a,leaf_b]:
		record.leaves.append({"node":weakref(node),"size":Vector3(1.5,2.5,.2),"index":0,"new_mesh":new_mesh,"old_mesh":old_mesh,"old_mat":old_mat,"old_transform":saved_transform,"handle":null,"glass":null,"caster":null})
	coordinator._apply_door(record)
	var mat_a: ShaderMaterial=leaf_a.material_override; var mat_b: ShaderMaterial=leaf_b.material_override
	check(mat_a!=mat_b and mat_a.shader==mat_b.shader,"Shared door shader with independent materials")
	mat_b.set_shader_parameter("architecture_cutaway",false)
	mat_a.set_shader_parameter("review_door_size",Vector3.ONE)
	mat_a.set_shader_parameter("architecture_cutaway",true)
	check(mat_b.get_shader_parameter("review_door_size")==Vector3(1.5,2.5,.2) and mat_b.get_shader_parameter("architecture_cutaway")==false,"Door size/cutaway uniforms independent")
	coordinator.enabled=false; coordinator._apply_door(record)
	check(leaf_a.mesh==old_mesh and leaf_a.material_override==old_mat and leaf_a.transform==saved_transform,"Door mode restores original resources/transform")
	coordinator.enabled=true; coordinator._apply_door(record)
	check(leaf_a.mesh==new_mesh and leaf_a.transform==Transform3D.IDENTITY and pixels(leaf_a.material_override,&"atlas")==pixels(mat_b,&"atlas"),"Door mode reapplies cached pixels")
	for number in 70:
		WALL._door_texture(Vector3(1+float(number)/32,2.5,.2),"solid",0,true)
		WALL._glass_material(Vector2(1+float(number)/32,2),true)
	check(WALL.door_texture_cache.size()<=WALL.DETAIL_TEXTURE_CACHE_LIMIT,"Door cache bounded")
	check(WALL.glass_texture_cache.size()<=WALL.DETAIL_TEXTURE_CACHE_LIMIT,"Glass cache bounded")
	leaf_a.free(); leaf_b.free(); coordinator.free()
	wall.free(); fixture.free()
	print("APPROVED_ART_TEXTURE_CACHE checks=",checks," failures=",failures)
	quit(1 if failures>0 else 0)
