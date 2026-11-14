extends SceneTree
const DEST := "res://art/preview/screen_wall/avatar/"
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("AVATAR_ASSET_PID=",OS.get_process_id())
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEST + "pose_manifest.json"))
	var editable: Node3D = load(DEST + "ung35_editable_pose.scn").instantiate()
	var rig: Skeleton3D = editable.find_children("*","Skeleton3D",true,false)[0]
	var pose_error := 0.0
	for name in metadata.anchors:
		var value: Array = metadata.anchors[name]
		var expected := Vector3(value[0],value[1],value[2])
		pose_error = maxf(pose_error,rig.get_bone_global_pose(rig.find_bone(name)).origin.distance_to(expected))
	var length_error := 0.0
	var knee_alignment := 1.0
	var sole_alignment := 1.0
	for side in ["Left","Right"]:
		var hip := rig.find_bone(side + " leg")
		var knee := rig.find_bone(side + " knee")
		var ankle := rig.find_bone(side + " ankle")
		var thigh := rig.get_bone_global_pose(knee).origin - rig.get_bone_global_pose(hip).origin
		var calf := rig.get_bone_global_pose(ankle).origin - rig.get_bone_global_pose(knee).origin
		length_error = maxf(length_error,absf(thigh.length() - rig.get_bone_global_rest(knee).origin.distance_to(rig.get_bone_global_rest(hip).origin)))
		length_error = maxf(length_error,absf(calf.length() - rig.get_bone_global_rest(ankle).origin.distance_to(rig.get_bone_global_rest(knee).origin)))
		var cap := rig.get_bone_global_pose(hip).basis * Vector3.FORWARD
		var plane := -(calf - thigh.normalized() * calf.dot(thigh.normalized())).normalized()
		knee_alignment = minf(knee_alignment,cap.normalized().dot(plane))
		sole_alignment = minf(sole_alignment,(rig.get_bone_global_pose(ankle).basis * Vector3.UP).dot(Vector3.UP))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(DEST + "ung35_folded_pose.glb",state)
	var imported: Node = document.generate_scene(state) if error == OK else null
	var mesh_count := imported.find_children("*","MeshInstance3D",true,false).size() if imported != null else 0
	var original_ok: bool = FileAccess.get_sha256(metadata.source_path) == metadata.source_sha256
	var dependencies := ResourceLoader.get_dependencies(DEST + "ung35_folded_pose.scn")
	var passed: bool = rig.get_bone_count() == 111 and pose_error < 0.0001 and length_error < 0.0001 and knee_alignment > 0.995 and sole_alignment > 0.999 and error == OK and mesh_count == 11 and original_ok and dependencies.is_empty()
	var report := {"pid":OS.get_process_id(),"bones":rig.get_bone_count(),"pose_error":pose_error,"leg_length_error":length_error,"knee_plane_alignment":knee_alignment,"sole_alignment":sole_alignment,"glb_error":error,"glb_meshes":mesh_count,"original_unchanged":original_ok,"runtime_dependencies":Array(dependencies),"passed":passed}
	var file := FileAccess.open("res://.runtime/screen_wall_avatar_20261107/asset_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("AVATAR_ASSET_RESULT ",report," exit=",0 if passed else 1)
	editable.free()
	if imported != null: imported.free()
	state = null
	document = null
	await process_frame
	quit(0 if passed else 1)
