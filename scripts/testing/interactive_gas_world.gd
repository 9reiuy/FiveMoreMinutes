extends "res://scripts/testing/lab_world.gd"
var interactive_gas: Node3D

func apply_whitebox() -> void:
	super.apply_whitebox()
	# Darker neutral receivers expose pale smoke without changing shared art.
	var floor_paint:=StandardMaterial3D.new()
	floor_paint.albedo_color=Color("35414a")
	floor_paint.roughness=1.0
	_paint_static(floor_root,floor_paint)
	var wall_paint:=StandardMaterial3D.new()
	wall_paint.albedo_color=Color("737f87")
	wall_paint.roughness=1.0
	for wall in wall_root.get_children():
		if not wall.has_method("shatter"): _paint_static(wall,wall_paint)

func disperse_smoke_segment(from: Vector2,to: Vector2) -> void:
	if is_instance_valid(interactive_gas):
		interactive_gas.push_shot(from,to)
	super.disperse_smoke_segment(from,to)
