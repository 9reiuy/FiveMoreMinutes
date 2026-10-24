extends Node
## Briefly replace actual model materials, never muzzle FX or the silhouette.
var parts: Array[Dictionary]=[]
var left:=0.0
var white: ShaderMaterial
func configure(model: Node3D) -> void:
	white=ShaderMaterial.new()
	white.shader=preload("res://shaders/dream3d/special_unit_hit_flash.gdshader")
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if mesh.find_parent("MuzzleFire")!=null: continue
		parts.append({"mesh":weakref(mesh),"rest":mesh.material_override})
	set_process(false)
func hit(duration: float) -> void:
	left=maxf(duration,.01)
	apply(true); set_process(true)
func apply(active: bool) -> void:
	for part in parts:
		var mesh: MeshInstance3D=part.mesh.get_ref()
		if is_instance_valid(mesh): mesh.material_override=white if active else part.rest
func _process(delta: float) -> void:
	left=maxf(0,left-delta)
	if left<=0: apply(false); set_process(false)
func _exit_tree() -> void:
	apply(false)
