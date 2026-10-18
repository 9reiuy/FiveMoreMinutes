extends SceneTree

var passed_count := 0
var failed_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[TEST] Starting character atlas and facing tests...")
	test_atlas_texture_and_regions()
	await test_player_part_textures_initialized()
	await test_aim_facing_back()
	await test_aim_facing_left()
	await test_aim_facing_right()
	await test_blinking_for_left_and_right()
	
	print("[TEST] Summary: %d passed, %d failed" % [passed_count, failed_count])
	if failed_count > 0:
		quit(1)
	else:
		quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		passed_count += 1
	else:
		failed_count += 1
		printerr("FAILED: %s" % msg)

func assert_eq(a: Variant, b: Variant, msg: String) -> void:
	if a == b:
		passed_count += 1
	else:
		failed_count += 1
		printerr("FAILED: %s. Expected %s, got %s" % [msg, str(b), str(a)])

func test_atlas_texture_and_regions() -> void:
	var atlas_tex: Texture2D = load("res://art/Dream/dream_chr_32x32.png")
	assert_true(atlas_tex != null, "dream_chr_32x32.png must exist and load as Texture2D")
	if atlas_tex != null:
		assert_eq(atlas_tex.get_width(), 192, "Atlas width should be 192")
		assert_eq(atlas_tex.get_height(), 191, "Atlas height should be 191")

func test_player_part_textures_initialized() -> void:
	var player_scene: PackedScene = load("res://scenes/entities/dream_player.tscn")
	assert_true(player_scene != null, "dream_player.tscn should load")
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	for i in range(2):
		await process_frame
	
	# Verify player parts initialized
	assert_eq(player.player_head_left_frames.size(), 3, "Left head frames should have 3 frames")
	assert_eq(player.player_head_right_frames.size(), 3, "Right head frames should have 3 frames")
	assert_true(player.player_head_back_frame != null, "Back head frame must not be null")
	assert_eq(player.player_head_frames.size(), 3, "player_head_frames should default to 3 frames")
	
	# Verify regions
	var left_open := player.player_head_left_frames[0] as AtlasTexture
	var right_open := player.player_head_right_frames[0] as AtlasTexture
	var back_head := player.player_head_back_frame as AtlasTexture
	assert_eq(left_open.region, Rect2(64, 0, 32, 32), "Head Left Open region")
	assert_eq(right_open.region, Rect2(96, 0, 32, 32), "Head Right Open region")
	assert_eq(back_head.region, Rect2(64, 128, 32, 32), "Head Back region")
	
	player.queue_free()
	for i in range(2):
		await process_frame

func test_aim_facing_back() -> void:
	var player_scene: PackedScene = load("res://scenes/entities/dream_player.tscn")
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	for i in range(2):
		await process_frame
	
	# Simulate aiming up (top 90 degree sector)
	player.set_meta(&"aim_direction_override", Vector2(0, -1))
	player.call("_update_direction_animation", Vector2.ZERO, 0.016)
	
	assert_true(player.character_facing_back, "character_facing_back should be true when aiming up")
	assert_eq(player.head_part.texture, player.player_head_back_frame, "Head texture should be Head Back")
	
	var body_tex := player.body_part.texture as AtlasTexture
	assert_eq(body_tex.region, Rect2(128, 128, 32, 32), "Body texture should be Body Back")
	
	var left_leg_tex := player.left_leg.texture as AtlasTexture
	var right_leg_tex := player.right_leg.texture as AtlasTexture
	assert_eq(left_leg_tex.region, Rect2(171, 140, 4, 9), "Left leg should be Legs Back")
	assert_eq(right_leg_tex.region, Rect2(176, 140, 4, 9), "Right leg should be Legs Back")
	
	assert_eq(player.weapon_root.z_index, -1, "weapon_root.z_index should be -1 when facing back")
	
	player.queue_free()
	for i in range(2):
		await process_frame

func test_aim_facing_left() -> void:
	var player_scene: PackedScene = load("res://scenes/entities/dream_player.tscn")
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	for i in range(2):
		await process_frame
	
	# Simulate aiming left
	player.set_meta(&"aim_direction_override", Vector2(-1, 0))
	player.call("_update_direction_animation", Vector2.ZERO, 0.016)
	
	assert_true(not player.character_facing_back, "character_facing_back should be false when aiming left")
	assert_true(not player.character_facing_right, "character_facing_right should be false when aiming left")
	
	var head_tex := player.head_part.texture as AtlasTexture
	assert_eq(head_tex.region, Rect2(64, 0, 32, 32), "Head texture should be Head Left Open")
	
	var body_tex := player.body_part.texture as AtlasTexture
	assert_eq(body_tex.region, Rect2(128, 0, 32, 32), "Body texture should be Body Front")
	
	var left_leg_tex := player.left_leg.texture as AtlasTexture
	var right_leg_tex := player.right_leg.texture as AtlasTexture
	assert_eq(left_leg_tex.region, Rect2(171, 12, 4, 9), "Left leg should be Legs Front")
	assert_eq(right_leg_tex.region, Rect2(176, 12, 4, 9), "Right leg should be Legs Front")
	
	assert_eq(player.weapon_root.z_index, 0, "weapon_root.z_index should be 0 when facing left")
	assert_true(player.visual.scale.x > 0.0, "visual.scale.x must remain positive without flipping")
	
	player.queue_free()
	for i in range(2):
		await process_frame

func test_aim_facing_right() -> void:
	var player_scene: PackedScene = load("res://scenes/entities/dream_player.tscn")
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	for i in range(2):
		await process_frame
	
	# Simulate aiming right
	player.set_meta(&"aim_direction_override", Vector2(1, 0))
	player.call("_update_direction_animation", Vector2.ZERO, 0.016)
	
	assert_true(not player.character_facing_back, "character_facing_back should be false when aiming right")
	assert_true(player.character_facing_right, "character_facing_right should be true when aiming right")
	
	var head_tex := player.head_part.texture as AtlasTexture
	assert_eq(head_tex.region, Rect2(96, 0, 32, 32), "Head texture should be Head Right Open")
	
	var body_tex := player.body_part.texture as AtlasTexture
	assert_eq(body_tex.region, Rect2(128, 0, 32, 32), "Body texture should be Body Front")
	
	assert_eq(player.weapon_root.z_index, 0, "weapon_root.z_index should be 0 when facing right")
	assert_true(player.visual.scale.x > 0.0, "visual.scale.x must remain positive without flipping")
	
	player.queue_free()
	for i in range(2):
		await process_frame

func test_blinking_for_left_and_right() -> void:
	var player_scene: PackedScene = load("res://scenes/entities/dream_player.tscn")
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	root.add_child(player)
	for i in range(2):
		await process_frame
	
	# Test left blink
	player.set_meta(&"aim_direction_override", Vector2(-1, 0))
	player.call("_update_direction_animation", Vector2.ZERO, 0.016)
	player.call("_set_player_head_frame", 1)
	var left_blink := player.head_part.texture as AtlasTexture
	assert_eq(left_blink.region, Rect2(64, 32, 32, 32), "Left head blink frame 1")
	player.call("_set_player_head_frame", 2)
	var left_closed := player.head_part.texture as AtlasTexture
	assert_eq(left_closed.region, Rect2(64, 64, 32, 32), "Left head closed frame 2")
	
	# Test right blink
	player.set_meta(&"aim_direction_override", Vector2(1, 0))
	player.call("_update_direction_animation", Vector2.ZERO, 0.016)
	player.call("_set_player_head_frame", 1)
	var right_blink := player.head_part.texture as AtlasTexture
	assert_eq(right_blink.region, Rect2(96, 32, 32, 32), "Right head blink frame 1")
	player.call("_set_player_head_frame", 2)
	var right_closed := player.head_part.texture as AtlasTexture
	assert_eq(right_closed.region, Rect2(96, 64, 32, 32), "Right head closed frame 2")
	
	# Test back view suppresses blink
	player.set_meta(&"aim_direction_override", Vector2(0, -1))
	player.call("_update_direction_animation", Vector2.ZERO, 0.016)
	player.call("_set_player_head_frame", 1)
	assert_eq(player.head_part.texture, player.player_head_back_frame, "Back view should retain back head when blink called")
	
	player.queue_free()
	for i in range(2):
		await process_frame
