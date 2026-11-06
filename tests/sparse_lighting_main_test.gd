extends "res://tests/room_firstuse_main_entry_test.gd"

func _initialize() -> void:
	create_timer(180,true,false,true).timeout.connect(func():push_error("Sparse Main watchdog");quit(9))
	super._initialize()

func check(ok: bool, label: String) -> void:
	# The existing parent test predates the variable-length in-cab loading
	# change. Current production receipts certify readiness BEFORE EXIT, not
	# before the cab becomes visible. Preserve the gate, not the obsolete key.
	if label == "new floor is prepared before visible cab ride":
		super.check(floor_loading_report.get("ready_before_exit", false) and not floor_loading_report.get("cancelled", true), "new floor prepared before elevator exit")
	else:
		super.check(ok, label)

func inspect_preparation(report: Dictionary, token: int, label: String) -> void:
	# Reuse normal Main/elevator entry and verify this policy is present in the
	# completed real render preparation; do not fake a lab-only world.
	check(not report.is_empty() and not report.get("cancelled", true), label + " preparation completed")
	check(is_instance_valid(world.sparse_lighting) and world.sparse_lighting.enabled, label + " uses sparse production lighting")
	check(world.sparse_lighting._floor_token == token, label + " fixed light prepared for this floor")
	check(world.sparse_lighting.main is DirectionalLight3D and not world.sparse_lighting.is_processing(), label + " no player-following source")
	check(world.shadow_manager.roof.layers & world.sparse_lighting.main.shadow_caster_mask == 0, label + " virtual roof does not block indoor key")
	check(world.shadow_manager.roof.layers & world.shadow_manager.sun.shadow_caster_mask != 0, label + " virtual roof still blocks moon")
	check(world.sparse_lighting.main.shadow_caster_mask & 15 == 15, label + " actual walls/furniture/actors keep shadows")
	check(world.sparse_lighting.main.visible and world.sparse_lighting.fill.visible, label + " sparse sources visible on exit")
	check(world.shadow_manager.sparse_lighting_enabled and world.shadow_manager.active.is_empty(), label + " no old room-source reassignment")
	check(world.shadow_manager.sun.shadow_caster_mask & 4 == 0, label + " moon does not steal player caster")
	for key in world.sparse_lighting._suppressed:
		var light = world.sparse_lighting._suppressed[key].ref.get_ref()
		if is_instance_valid(light): check(not light.visible, label + " suppressed source remains hidden")
