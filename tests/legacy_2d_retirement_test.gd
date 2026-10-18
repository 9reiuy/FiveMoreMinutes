extends SceneTree

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for file in ["scenes/dream/dream_world.tscn", "scripts/dream/dream_world.gd",
		"scripts/dream/dream_map_builder.gd", "scripts/dream/dream_room_manager.gd",
		"scripts/dream/dream_room_template.gd", "scenes/dream/rooms/room_start_01.tscn"]:
		_check(not FileAccess.file_exists("res://" + file), "Retired file remains: " + file)
	for file in ["scenes/app/main.tscn", "scenes/dream/Dream3D_RandomDungeon.tscn",
		"scenes/dream/Dream3D_TutorialRoom.tscn", "scenes/dream/Dream3D_ReceptionRoom.tscn",
		"scenes/dream/preview/SelectivePixelPreview.tscn", "scenes/dream/preview/OfficeSkeletonPreview.tscn",
		"scenes/entities/dream_player.tscn", "scenes/entities/employee_enemy.tscn",
		"scenes/dream/rooms/chair_01.gd", "scenes/dream/rooms/hurtbox.gd"]:
		_check(load("res://" + file) != null, "Preserved resource fails to load: " + file)
	var main_source := FileAccess.get_file_as_string("res://scripts/app/main.gd")
	_check(not main_source.contains('get_node("DreamClock")'), "Legacy entry fallback remains")
	_check(main_source.contains('Dream3D_TutorialRoom.tscn'), "Tutorial must be retained")
	_check(main_source.contains('Dream3D_ReceptionRoom.tscn'), "Reception must be retained")
	for failure in failures:
		push_error(failure)
	print("LEGACY 2D RETIREMENT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
