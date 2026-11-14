extends RefCounted
static func apply(effect: BlackBloodEffect, start: Vector2, finish: Vector2, width: float, intensity: float) -> Dictionary:
	return preload("res://scripts/dream/pixel_blood_drag.gd").apply(effect,start,finish,width,intensity)
