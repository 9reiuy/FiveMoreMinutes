extends SceneTree

const RESOLVER := preload("res://scripts/dream/dream_interaction_resolver.gd")
var checks := 0
var failures := 0

class Candidate extends Node2D:
	var interaction_radius := 100.0
	var targeted := false
	var available := true
	var free_on_query := false
	var free_on_highlight := false
	var remove_on_query: Node
	func is_interaction_available(_actor: Node2D) -> bool:
		if is_instance_valid(remove_on_query): remove_on_query.free()
		if free_on_query: queue_free()
		return available
	func set_interaction_targeted(enabled: bool) -> void:
		targeted = enabled
		if enabled and free_on_highlight: queue_free()

func _init() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func candidate(at: Vector2, group: StringName = &"freed_target_test") -> Candidate:
	var item := Candidate.new()
	root.add_child(item)
	item.position = at
	item.add_to_group(group)
	return item

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var actor := Node2D.new()
	root.add_child(actor)
	var resolver := RESOLVER.new()
	root.add_child(resolver)
	resolver.configure(actor,[&"freed_target_test"])
	var first := candidate(Vector2(4,0))
	var second := candidate(Vector2(10,0))
	check(resolver.update_target()==first,"Nearest candidate selected")
	check(first.targeted and not second.targeted,"One highlighted candidate")
	first.free()
	# Deliberately stay in the same process frame: exercise the actual cached
	# freed Variant that used to fail at the Node2D cast, not a refreshed list.
	check(resolver.update_target()==second,"Freed cached candidate skipped before cast")
	check(second.targeted,"Remaining live candidate highlighted")
	second.queue_free()
	check(resolver.update_target()==null,"Queued-for-deletion candidate rejected immediately")
	await process_frame
	var old := candidate(Vector2(8,0))
	resolver.configure(actor,[&"freed_target_test"])
	check(resolver.update_target()==old,"Reconfigure refreshes group membership immediately")
	var other := candidate(Vector2(12,0),&"freed_target_other")
	resolver.configure(actor,[&"freed_target_other"])
	check(not old.targeted,"Reconfigure clears old highlight")
	check(resolver.update_target()==other,"New group used in same frame, no stale group cache")
	other.process_mode = Node.PROCESS_MODE_DISABLED
	check(resolver.update_target()==null,"Stashed floor candidate cannot be selected")
	other.process_mode = Node.PROCESS_MODE_INHERIT
	check(resolver.update_target()==other,"Rollback re-enables same candidate")
	root.remove_child(other)
	check(resolver.update_target()==null,"Detached cached candidate ignored")
	other.free()
	old.free()
	var self_free := candidate(Vector2(5,0))
	self_free.free_on_query = true
	resolver.configure(actor,[&"freed_target_test"])
	check(resolver.update_target()==null,"Availability callback may queue candidate deletion safely")
	var selected := candidate(Vector2(3,0))
	var remover := candidate(Vector2(20,0))
	remover.remove_on_query = selected
	resolver.configure(actor,[&"freed_target_test"])
	check(resolver.update_target()==null,"Later callback may free provisional nearest safely")
	remover.free()
	var highlight_free := candidate(Vector2(5,0))
	highlight_free.free_on_highlight = true
	resolver.configure(actor,[&"freed_target_test"])
	check(resolver.update_target()==null,"Highlight callback may queue selected target deletion safely")
	actor.free()
	check(resolver.update_target()==null,"Freed actor clears resolver safely")
	resolver.free()
	await process_frame
	print("INTERACTION_FREED_TARGET checks=",checks," failures=",failures)
	quit(1 if failures else 0)
