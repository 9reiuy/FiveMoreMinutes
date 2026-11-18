extends SceneTree
const KIT := preload("res://scripts/testing/h06_chapter/h06_materials.gd")
var checks:Array[Dictionary]=[]

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func check(value:bool,label:String) -> void:
	checks.append({"pass":value,"label":label})
	print("PASS " if value else "FAIL ",label)

func build() -> Dictionary:
	var kit:=KIT.new(null,Transform3D.IDENTITY,true)
	kit.prepare_window_finishes()
	kit.prepare_atrium_finishes()
	kit.prepare_atrium_weathering()
	var result:Dictionary={}
	for key:String in ["endfield_yellow_emit","endfield_white_tube","glass_corridor_rail","endfield_yellow","stencil_backing","dark_bulkhead","burgundy_placard","steel_mullion","steel_rail","steel_beam","door_frame","door_leaf","decal_oil_stain","decal_scuff_streak","decal_wall_drip","decal_rust_patch","decal_crack"]:result[key]=kit.get(key)
	result["directory_board"]=kit.make_directory_board_material()
	return result

func same(a:StandardMaterial3D,b:StandardMaterial3D) -> bool:
	for property:Dictionary in a.get_property_list():
		var key:String=property.name
		if not int(property.usage)&PROPERTY_USAGE_STORAGE or key.begins_with("resource_") or key=="script":continue
		var left:Variant=a.get(key)
		var right:Variant=b.get(key)
		if left is Texture2D:
			if not right is Texture2D or left.get_image().get_data()!=right.get_image().get_data():return false
		elif left!=right:return false
	return true

func run() -> void:
	var folder:=OS.get_environment("FORKLIFT_EVIDENCE")
	KIT.procedural_cache_enabled=false
	var original:=build()
	KIT.procedural_cache_enabled=true
	var cold:=build()
	var started:=Time.get_ticks_usec()
	var cached:=build()
	var elapsed:float=(Time.get_ticks_usec()-started)*0.001
	for key:String in original:
		check(same(original[key],cold[key]) and same(original[key],cached[key]),"exact texture bytes and material properties preserved: "+key)
		check(cold[key]!=cached[key] and cold[key].albedo_texture==cached[key].albedo_texture,"independent material with shared immutable image: "+key)
	cached.endfield_yellow.roughness=0.123
	cached.endfield_yellow.albedo_color=Color.MAGENTA
	var again:=build()
	check(same(original.endfield_yellow,again.endfield_yellow),"editing one region does not contaminate another region or the prototype")
	check(elapsed<10.0,"cached material creation avoids the repeated pixel-generation stall")
	var failures:Array=checks.filter(func(row:Dictionary)->bool:return not row.pass)
	FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cached_build_ms":elapsed,"pid":OS.get_process_id()},"\t"))
	print("H06_MATERIAL_REUSE checks=",checks.size()," failures=",failures.size()," cached_ms=",elapsed)
	quit(0 if failures.is_empty() else 1)
