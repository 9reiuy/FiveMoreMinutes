extends SceneTree

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var packed: PackedScene = load("res://scenes/dream/Dream3D_RandomDungeon.tscn")
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var lighting := scene.get_node_or_null("NightLighting") as Node3D
	var light := lighting.get("flashlight") as SpotLight3D if lighting != null else null
	var player := scene.get("player") as Node2D
	var aim: Vector2 = scene.call("get_gameplay_aim_position") if scene != null else Vector2.ZERO
	print("PROBE lighting=", lighting, " flashlight=", light)
	if light != null:
		print("PROBE visible=", light.visible, "energy=", light.light_energy, "range=", light.spot_range, "angle=", light.spot_angle, "mask=", light.light_cull_mask, "pos=", light.global_position, "basis=", light.global_basis)
	if player != null:
		print("PROBE player=", player.global_position, "aim=", aim)
	print("PROBE floor_children=", scene.get_node("GeneratedBuildingRoot/FloorRoot").get_child_count())
	quit()
