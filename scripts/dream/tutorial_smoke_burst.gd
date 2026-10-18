class_name TutorialSmokeBurst
extends Node3D

signal finished

const PUFF_COUNT := 9
const DURATION := 0.42


func play_once() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id() * 7919
	var tween := create_tween().set_parallel(true)
	for index in PUFF_COUNT:
		var puff := MeshInstance3D.new()
		puff.name = "SmokePuff%02d" % index
		var mesh := BoxMesh.new()
		var size := rng.randf_range(0.16, 0.30)
		mesh.size = Vector3(size, size, size)
		puff.mesh = mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.70, 0.76, 0.82, 0.84)
		puff.material_override = material
		var angle := TAU * float(index) / float(PUFF_COUNT) + rng.randf_range(-0.25, 0.25)
		var start_radius := rng.randf_range(0.02, 0.12)
		var direction := Vector3(cos(angle), rng.randf_range(0.25, 0.75), sin(angle)).normalized()
		puff.position = direction * start_radius
		puff.scale = Vector3.ONE * 0.55
		add_child(puff)
		tween.tween_property(puff, "position", direction * rng.randf_range(0.55, 0.95), DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector3.ONE * rng.randf_range(1.2, 1.8), DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color", Color(0.55, 0.62, 0.70, 0.0), DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	finished.emit()
	queue_free()
