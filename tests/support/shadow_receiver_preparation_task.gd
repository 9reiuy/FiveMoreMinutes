extends Node
var finished:=false
var result: Dictionary={}
func begin(world: Node3D) -> void:
	result=await preload("res://tests/support/shadow_receiver_preparation_probe.gd").run(get_tree(),world)
	finished=true
