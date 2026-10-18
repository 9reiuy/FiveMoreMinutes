extends SceneTree

const DUNGEON_SCENE = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")

const VAULTABLE_PROPS := [
	"res://scenes/dream/props/parcel_box_01.tscn",
	"res://scenes/dream/props/trash_can_01.tscn",
	"res://scenes/dream/props/small_table_01.tscn",
	"res://scenes/dream/props/sticker_parcel_box_01.tscn",
	"res://scenes/dream/props/side_table_01.tscn",
	"res://scenes/dream/props/desk.tscn",
	"res://scenes/dream/props/chair_02.tscn",
	"res://scenes/dream/props/floor_lamp_01.tscn",
	"res://scenes/dream/props/office_chair_01.tscn",
	"res://scenes/dream/props/chair.tscn",
]

const NON_VAULTABLE_PROPS := [
	"res://scenes/dream/props/filing_cabinet_01.tscn",
	"res://scenes/dream/props/storage_cabinet_01.tscn",
	"res://scenes/dream/props/wardrobe_01.tscn",
	"res://scenes/dream/props/fridge_01.tscn",
	"res://scenes/dream/props/bed_01.tscn",
]

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== STARTING VAULT MECHANICS & ZERO SELF-DAMAGE TEST ===")
	var world = DUNGEON_SCENE.instantiate()
	world.generate_on_ready = false
	root.add_child(world)
	world.regenerate(42001)
	for i in range(10):
		await process_frame

	var player = world.player
	var base_pos = player.global_position

	# 1. Test all vaultable props: Must produce vault segment and cause 0 damage
	for path in VAULTABLE_PROPS:
		player.global_position = base_pos
		player.current_health = 100.0
		player.dash_charges = player.max_dash_charges
		player.dash_cooldown_left = 0.0
		player.dashing = false
		player.vault_active = false
		var prop_scene: PackedScene = load(path)
		var prop: RigidBody2D = prop_scene.instantiate()
		
		# Place prop 35px to the right of player
		prop.global_position = base_pos + Vector2(35.0, 0.0)
		world.furniture_root.add_child(prop)
		for i in range(5):
			await process_frame

		var path_res = player.resolve_dash_path(Vector2.RIGHT)
		var segments = path_res.get("segments", [])
		var has_vault := false
		for seg in segments:
			if seg.get("kind") == &"vault":
				has_vault = true
				break
		check(has_vault, "Vault segment generated for %s" % path.get_file())

		# Execute dash/vault
		var init_hp = player.current_health
		player._commit_dash_path(path_res)
		var timeout := 0
		while player.dashing and timeout < 150:
			await process_frame
			timeout += 1
		
		check(player.current_health == init_hp, "0 self-damage on %s (HP: %s)" % [path.get_file(), player.current_health])
		check(player.global_position.x > prop.global_position.x, "Player successfully vaulted across %s (X: %.1f > %.1f)" % [path.get_file(), player.global_position.x, prop.global_position.x])

		prop.queue_free()
		for i in range(2):
			await process_frame

	# 2. Test non-vaultable props: Must NOT produce vault segment, and dashing into it causes 0 damage
	for path in NON_VAULTABLE_PROPS:
		player.global_position = base_pos
		player.current_health = 100.0
		player.dash_charges = player.max_dash_charges
		player.dash_cooldown_left = 0.0
		player.dashing = false
		player.vault_active = false
		var prop_scene: PackedScene = load(path)
		var prop: RigidBody2D = prop_scene.instantiate()
		
		prop.global_position = base_pos + Vector2(35.0, 0.0)
		world.furniture_root.add_child(prop)
		for i in range(5):
			await process_frame

		var path_res = player.resolve_dash_path(Vector2.RIGHT)
		var segments = path_res.get("segments", [])
		var has_vault := false
		for seg in segments:
			if seg.get("kind") == &"vault":
				has_vault = true
				break
		check(not has_vault, "Non-vaultable %s produces NO vault segment" % path.get_file())

		var init_hp = player.current_health
		player._commit_dash_path(path_res)
		var timeout := 0
		while player.dashing and timeout < 150:
			await process_frame
			timeout += 1

		check(player.current_health == init_hp, "0 self-damage on non-vaultable %s (HP: %s)" % [path.get_file(), player.current_health])

		prop.queue_free()
		for i in range(2):
			await process_frame

	print("\n=== SUMMARY: %d FAILURES ===" % failures.size())
	if not failures.is_empty():
		for f in failures:
			print("  - ", f)
	quit()
