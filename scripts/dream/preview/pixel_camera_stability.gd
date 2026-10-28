extends RefCounted
## Preview-only projection offset. Never writes actor/physics coordinates.
static func apply(camera: Camera3D, anchor: Vector3) -> float:
	camera.h_offset=0.; camera.v_offset=0.
	var depth:=-(camera.global_transform.affine_inverse()*anchor).z
	if depth<=camera.near: return 0.
	var pixel:=camera.unproject_position(anchor)
	var delta:=pixel.round()-pixel
	var correction:=camera.project_position(pixel+delta,depth)-camera.project_position(pixel,depth)
	camera.h_offset=-correction.dot(camera.global_basis.x)
	camera.v_offset=-correction.dot(camera.global_basis.y)
	return camera.unproject_position(anchor).distance_to(pixel.round())
