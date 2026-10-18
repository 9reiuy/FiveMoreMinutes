extends Node
var finished:=false
var result: Dictionary={}
func begin(world: Node3D) -> void:
	result=await preload("res://scripts/dream/firearm_render_preparation.gd").run(get_tree(),world)
	finished=true
