extends RefCounted
static func pulse(parent: Node3D, point: Vector3, color: Color) -> void:
	var ring:=MeshInstance3D.new(); var mesh:=TorusMesh.new()
	mesh.inner_radius=.40; mesh.outer_radius=.44; mesh.rings=16; mesh.ring_segments=6
	ring.mesh=mesh; ring.position=point+Vector3(0,.03,0); parent.add_child(ring)
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=color
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; ring.material_override=material; ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween:=ring.create_tween(); tween.set_parallel(true)
	tween.tween_property(ring,"scale",Vector3(2.5,.15,2.5),.65)
	tween.tween_property(material,"albedo_color:a",0.,.65)
	tween.chain().tween_callback(ring.queue_free)
