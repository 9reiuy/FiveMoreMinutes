extends "res://scripts/dream/breakable_glass_window_3d.gd"
## One continuous pane/frame/collider per run; normal game glass is untouched.
var run_width := 1.0

func configure_window(edge: Dictionary, key: String, height: float, thickness: float, collision_parent: Node2D) -> void:
	run_width = float(edge.get("preview_run_width",1))
	super.configure_window(edge,key,height,thickness,collision_parent)
	for mesh in [frame_root.get_node("FloorTrack"),frame_root.get_node("WindowHeader")]:
		mesh.mesh.size.x = run_width
	glass_pane.mesh.size.x = run_width - .04
	for child in frame_root.get_children():
		if child is MeshInstance3D and absf(child.position.x) > .4:
			child.position.x = signf(child.position.x)*(run_width*.5-.025)
	if collision_shape_2d != null:
		var size := Vector2(thickness*32.0,run_width*32.0) if String(edge.axis) == "V" else Vector2(run_width*32.0,thickness*32.0)
		collision_shape_2d.shape.size = size
		var offset := (run_width-1.0)*16.0
		collision_body_2d.position += Vector2(0,offset) if String(edge.axis) == "V" else Vector2(offset,0)

func set_cutaway_mode(enabled: bool) -> void:
	super.set_cutaway_mode(enabled)
	for cap in cutaway_caps:
		cap.position.x = signf(cap.position.x)*(run_width*.5-.025)
