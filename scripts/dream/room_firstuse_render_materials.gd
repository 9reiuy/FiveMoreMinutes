extends RefCounted
## Loading-only representatives for measured room-entry shader families.
## Keep exact source resources and uniforms; only the private warmup view draws
## them. Selection follows semantic owners, not cached shader hashes.
const OUTLINE=preload("res://scripts/dream/units/special_unit_outline.gd")

static func _role(node:GeometryInstance3D,path:String)->String:
	if path.begins_with("GeneratedBuildingRoot/DoorRoot/") and "/ObservationGlass" in path:return "door_observation_glass"
	if path.begins_with("HotelRobotVisuals/") and node.name in [&"Body",&"Plinth"] and not "/UnitSilhouetteOutline/" in path:return "robot_body"
	var parent:Node=node.get_parent()
	var unit_owner:bool=path.begins_with("HotelRobotVisuals/") or path.begins_with("ExteriorPatrolDrones/")
	if unit_owner and parent!=null and parent.get_script()==OUTLINE and parent.get("border")==node:return "special_unit_silhouette"
	if path.begins_with("GeneratedBuildingRoot/FloorRoot/ApprovedRandomRoomFixtures_"):
		if "/WallFixture_fire/" in path:return "approved_extinguisher_fixture"
		if "/WallFixture_sign" in path or "/WallFixture_whiteboard" in path:return "approved_wall_fixtures"
	return ""

static func collect(world:Node3D)->Dictionary:
	var selected:Dictionary={}
	var records:Array=[]
	var materials:Array[Material]=[]
	var flat:Material
	var flat_path:=""
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion():return {"materials":materials,"report":{"shader_families":0,"flat_found":false,"records":records}}
	for node in world.find_children("*","GeometryInstance3D",true,false):
		if node.is_queued_for_deletion():continue
		var path:=String(world.get_path_to(node))
		var role:=_role(node,path)
		var candidates:Array[Material]=[]
		if node.material_override!=null:candidates.append(node.material_override)
		else:
			var mesh:Mesh
			if node is MeshInstance3D:mesh=node.mesh
			elif node is MultiMeshInstance3D and node.multimesh!=null:mesh=node.multimesh.mesh
			if mesh!=null:
				for surface in mesh.get_surface_count():
					var material:Material=node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
					if material!=null:candidates.append(material)
		for material:Material in candidates:
			if flat==null and path.begins_with("GeneratedBuildingRoot/WallRoot/") and material is BaseMaterial3D and node.name==&"ShadowCasterMesh" and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)==null:
				flat=material;flat_path=path
			if role.is_empty() or not material is ShaderMaterial or material.shader==null or material.shader.code.is_empty():continue
			var key:String=material.shader.code.sha256_text()
			if selected.has(key):continue
			selected[key]=true;materials.append(material)
			records.append({"role":role,"code_sha256":key,"path":path})
	if flat!=null:
		materials.append(flat);records.append({"role":"native_unshaded_flat","path":flat_path})
	return {"materials":materials,"report":{"shader_families":selected.size(),"flat_found":flat!=null,"records":records}}
