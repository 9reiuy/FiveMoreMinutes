@tool
extends Node3D
## Editable static service equipment using the accepted 0-1 visual factory.
const MAINTENANCE = preload("res://scripts/testing/maintenance_environment.gd")
@export_enum("pump","case","switchgear","generator") var kind := "case":
	set(value):
		kind=value
		_request_rebuild()
@export var dimensions := Vector3(1.5,.8,1.0):
	set(value):
		dimensions=value.max(Vector3.ONE*.05)
		_request_rebuild()
var _visual: Node3D
var _rebuild_pending := false

func _ready() -> void:
	_request_rebuild()

func _request_rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending:return
	_rebuild_pending=true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_rebuild_pending=false
	if is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()
	_visual=MAINTENANCE.prop_visual(kind,dimensions)
	add_child(_visual)
