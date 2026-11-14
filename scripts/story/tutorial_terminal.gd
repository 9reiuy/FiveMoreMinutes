extends Node2D
## Single proximity interaction authority for the tutorial television.
signal interaction_requested
var interaction_radius := 48.0
var interaction_enabled := true
var interaction_targeted := false

func _ready() -> void:
	add_to_group(&"tutorial_interaction_targets")

func is_interaction_available(_requester: Node) -> bool:
	return interaction_enabled and visible

func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled=enabled
	if not enabled:interaction_targeted=false

func set_interaction_targeted(targeted: bool) -> void:
	interaction_targeted=targeted and interaction_enabled

func request_interaction(requester: Node) -> void:
	if is_interaction_available(requester) and requester is Node2D and global_position.distance_to(requester.global_position)<=interaction_radius:
		interaction_requested.emit()
