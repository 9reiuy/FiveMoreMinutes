extends RefCounted
## Cached, continuous stainless coupe; front +X and tyre contact at Y=0.
const MODEL := preload("res://scripts/testing/dmc12_detailed_mesh.gd")
static var _mesh: ArrayMesh


static func build() -> Node3D:
	if _mesh == null: _mesh = MODEL.create()
	var root := Node3D.new()
	root.name = "DMC12"
	var body := MeshInstance3D.new()
	body.name = "StainlessWedgeCoupe"
	body.mesh = _mesh
	root.add_child(body)
	return root
