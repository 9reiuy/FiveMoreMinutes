extends SceneTree

const CONFIG_RESOURCE := preload("res://resources/demo_config.tres")
const DEMO_CONFIG := preload("res://scripts/data/demo_config.gd")
const DEPTH_BRIDGE_SCRIPT := preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_tests")

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		printerr("FAIL: ", msg)
	else:
		print("PASS: ", msg)

func _run_tests() -> void:
	print("--- Running Character Lighting Scale Tests ---")

	# 1. Config Check
	var cfg = DEMO_CONFIG.new()
	_assert(is_equal_approx(cfg.character_light_scale, 0.50), "DemoConfig default character_light_scale is 0.50 (got %f)" % cfg.character_light_scale)
	_assert(is_equal_approx(CONFIG_RESOURCE.character_light_scale, 0.50), "demo_config.tres character_light_scale is 0.50 (got %f)" % CONFIG_RESOURCE.character_light_scale)

	# 2. Player Depth Bridge Check
	var player_node := Node2D.new()
	player_node.name = "Player"
	player_node.add_to_group(&"dream_player")
	var vis := Node2D.new()
	vis.name = "CharacterVisual"
	player_node.add_child(vis)
	root.add_child(player_node)

	var world_root := Node3D.new()
	root.add_child(world_root)

	var vp_player := SubViewport.new()
	root.add_child(vp_player)
	var player_bridge: Node3D = DEPTH_BRIDGE_SCRIPT.new()
	world_root.add_child(player_bridge)
	player_bridge.call("configure", player_node, vp_player, player_node)

	var player_sprite: Sprite3D = player_bridge.get_node_or_null("DepthVisual") as Sprite3D
	_assert(player_sprite != null, "Player DepthVisual sprite created")
	var player_mat := player_sprite.material_override as ShaderMaterial
	_assert(player_mat != null, "Player sprite uses ShaderMaterial")
	var player_scale: Variant = player_mat.get_shader_parameter("character_light_scale")
	_assert(player_scale != null and is_equal_approx(float(player_scale), 0.50), "Player lit_material character_light_scale is 0.50 (got %s)" % str(player_scale))

	# Check ShadowProxy independence
	var player_shadow_proxy: Sprite3D = player_bridge.get_node_or_null("ShadowProxy") as Sprite3D
	_assert(player_shadow_proxy != null, "Player ShadowProxy exists")
	_assert(player_shadow_proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "ShadowProxy cast_shadow is SHADOWS_ONLY")
	_assert(player_shadow_proxy.shaded == false, "ShadowProxy is unshaded (shaded == false, independent from lit_material)")

	# 3. Enemy Depth Bridge Check
	var enemy_node := Node2D.new()
	enemy_node.name = "Enemy"
	enemy_node.add_to_group(&"dream_enemies")
	var enemy_vis := Node2D.new()
	enemy_vis.name = "CharacterVisual"
	enemy_node.add_child(enemy_vis)
	root.add_child(enemy_node)

	var vp_enemy := SubViewport.new()
	root.add_child(vp_enemy)
	var enemy_bridge: Node3D = DEPTH_BRIDGE_SCRIPT.new()
	world_root.add_child(enemy_bridge)
	enemy_bridge.call("configure", enemy_node, vp_enemy, enemy_node)

	var enemy_sprite: Sprite3D = enemy_bridge.get_node_or_null("DepthVisual") as Sprite3D
	var enemy_mat := enemy_sprite.material_override as ShaderMaterial
	var enemy_scale: Variant = enemy_mat.get_shader_parameter("character_light_scale")
	_assert(enemy_scale != null and is_equal_approx(float(enemy_scale), 0.50), "Enemy lit_material character_light_scale is 0.50 (got %s)" % str(enemy_scale))

	# 4. Prop / Non-Character Check
	var prop_node := Node2D.new()
	prop_node.name = "TableProp"
	prop_node.add_to_group(&"damageable_props")
	root.add_child(prop_node)

	var vp_prop := SubViewport.new()
	root.add_child(vp_prop)
	var prop_bridge: Node3D = DEPTH_BRIDGE_SCRIPT.new()
	world_root.add_child(prop_bridge)
	prop_bridge.call("configure", prop_node, vp_prop, prop_node)

	var prop_sprite: Sprite3D = prop_bridge.get_node_or_null("DepthVisual") as Sprite3D
	var prop_mat := prop_sprite.material_override as ShaderMaterial
	var prop_scale: Variant = prop_mat.get_shader_parameter("character_light_scale")
	_assert(prop_scale != null and is_equal_approx(float(prop_scale), 1.0), "Prop lit_material character_light_scale remains 1.0 (got %s)" % str(prop_scale))

	# Clean up
	player_bridge.queue_free()
	vp_player.queue_free()
	player_node.queue_free()
	enemy_bridge.queue_free()
	vp_enemy.queue_free()
	enemy_node.queue_free()
	prop_bridge.queue_free()
	vp_prop.queue_free()
	prop_node.queue_free()
	world_root.queue_free()

	if failures.is_empty():
		print("--- ALL Character Lighting Scale Tests PASSED! ---")
		quit(0)
	else:
		printerr("--- FAILED with %d errors ---" % failures.size())
		quit(1)
