extends Node3D

var visual: MeshInstance3D
var caps: Array[MeshInstance3D] = []
var opening_width: float
var frame_thickness: float

func configure(width: float, height: float, thickness: float) -> void:
	opening_width = width
	frame_thickness = thickness
	visual = MeshInstance3D.new()
	visual.mesh = preload("res://scripts/dream/office_low_pixel_art.gd").opening_mesh(width, height, thickness)
	visual.material_override = preload("res://scripts/dream/office_low_pixel_art.gd").material().duplicate()
	add_child(visual)

func set_architectural_cutaway(enabled: bool, height: float) -> void:
	visual.material_override.set_shader_parameter("architecture_cutaway", enabled)
	visual.material_override.set_shader_parameter("architecture_wall_height", height)
	if enabled and caps.is_empty():
		for sign_x in [-1.0, 1.0]:
			var cap := preload("res://scripts/dream/architecture_slice_cap.gd").make(.0625, frame_thickness, height)
			cap.position.x = sign_x * (opening_width * .5 + .03125)
			add_child(cap)
			caps.append(cap)
	for cap in caps:
		cap.visible = enabled
