extends Node

const CONFIG := preload("res://resources/demo_config.tres")
const PLAYER_SCENE := preload("res://scenes/entities/dream_player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/entities/basic_projectile.tscn")
const PROP_CASES := [
	{"path": "res://scenes/dream/props/office_chair_01.tscn", "region": Rect2(389, 276, 22, 42), "hp": 30.0, "mass": 1.25, "knockback": 95.0},
	{"path": "res://scenes/dream/props/filing_cabinet_01.tscn", "region": Rect2(485, 131, 22, 60), "hp": 80.0, "mass": 6.5, "knockback": 55.0},
	{"path": "res://scenes/dream/props/storage_cabinet_01.tscn", "region": Rect2(138, 32, 44, 64), "hp": 100.0, "mass": 8.0, "knockback": 45.0},
	{"path": "res://scenes/dream/props/trash_can_01.tscn", "region": Rect2(136, 388, 16, 26), "hp": 25.0, "mass": 1.0, "knockback": 110.0},
	{"path": "res://scenes/dream/props/small_table_01.tscn", "region": Rect2(13, 291, 38, 27), "hp": 50.0, "mass": 2.5, "knockback": 70.0},
]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_reload_state_and_visual()
	await _test_breakable_props()
	if failures.is_empty():
		print("RELOAD BREAKABLE PROPS TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_reload_state_and_visual() -> void:
	_assert(is_equal_approx(CONFIG.weapon_reload_duration, 0.75), "The shared reload duration is not 0.75 seconds")
	_assert(InputMap.has_action("reload_weapon"), "reload_weapon action is missing")
	var has_r := false
	for event in InputMap.action_get_events("reload_weapon"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_R:
			has_r = true
	_assert(has_r, "reload_weapon is not bound to physical R")

	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_assert(player.get_node_or_null("WeaponRoot/HandAnchor/WeaponMotion/ReloadVisualPivot") != null, "ReloadVisualPivot is missing")
	_assert(int(player.get_ammo_status().current) == 12, "Pistol did not start at 12/12")

	_assert(player.request_reload(), "Full magazine did not accept active reload")
	var full_reload: Dictionary = player.get_ammo_status()
	_assert(bool(full_reload.reloading), "Full magazine active reload did not enter shared reload state")
	var reload_left_before_repeat := float(full_reload.reload_left)
	_assert(not player.request_reload(), "Repeated R restarted an active reload")
	_assert(is_equal_approx(float(player.get_ammo_status().reload_left), reload_left_before_repeat), "Repeated R changed reload time")
	_assert(not player.try_consume_ammo_for_attack(), "Weapon fired during reload")
	_assert(player.reload_visual_tween != null, "Active reload did not start the visual spin tween")
	player._update_ammo(CONFIG.weapon_reload_duration)
	_assert(int(player.get_ammo_status().current) == 12 and not bool(player.get_ammo_status().reloading), "Full magazine reload did not finish at 12/12")
	_assert(is_zero_approx(player.reload_visual_pivot.rotation), "Reload visual did not reset to zero rotation")

	for _shot in range(7):
		_assert(player.try_consume_ammo_for_attack(), "Failed to consume a pistol round before partial reload")
	_assert(int(player.get_ammo_status().current) == 5, "Partial magazine setup did not reach 5/12")
	_assert(player.request_reload(), "5/12 active reload was rejected")
	player._update_ammo(CONFIG.weapon_reload_duration)
	_assert(int(player.get_ammo_status().current) == 12 and not bool(player.get_ammo_status().reloading), "5/12 active reload did not restore 12/12")

	for _shot in range(12):
		_assert(player.try_consume_ammo_for_attack(), "Failed to consume a round while testing automatic reload")
	_assert(int(player.get_ammo_status().current) == 0 and bool(player.get_ammo_status().reloading), "Empty magazine automatic reload regressed")
	player._update_ammo(CONFIG.weapon_reload_duration)
	_assert(int(player.get_ammo_status().current) == 12, "Automatic reload did not refill the magazine")

	player._update_direction_animation(Vector2.UP, 0.016)
	var aim_before: float = player.hand_anchor.rotation
	_assert(player.request_reload(), "Back-facing active reload was rejected")
	_assert(player.weapon_root.show_behind_parent, "Back-facing reload broke weapon-behind-body drawing")
	_assert(is_equal_approx(player.hand_anchor.rotation, aim_before), "Reload spin changed the AimPivot rotation")
	_assert(player.reload_visual_pivot.get_parent() == player.weapon_motion, "Reload spin is not isolated below WeaponMotion")
	player._cancel_all_reloads()
	player.queue_free()


func _test_breakable_props() -> void:
	var test_world := Node2D.new()
	test_world.name = "PropTestWorld"
	add_child(test_world)
	var debris_root := Node2D.new()
	debris_root.name = "GroundDebrisRoot"
	debris_root.add_to_group("ground_debris_root")
	test_world.add_child(debris_root)
	var props_root := Node2D.new()
	props_root.name = "PropsRoot"
	props_root.y_sort_enabled = true
	test_world.add_child(props_root)

	var previous_flash_material: ShaderMaterial
	for index in range(PROP_CASES.size()):
		var case: Dictionary = PROP_CASES[index]
		var expected_region: Rect2 = case.get("region", Rect2())
		var prop := (load(String(case.path)) as PackedScene).instantiate() as RigidBody2D
		prop.position = Vector2(80.0 + index * 90.0, 160.0)
		props_root.add_child(prop)
		await get_tree().process_frame
		await get_tree().physics_frame
		var sprite := prop.get_node("Sprite2D") as Sprite2D
		var atlas := sprite.texture as AtlasTexture
		_assert(atlas != null and atlas.region == expected_region, "%s does not serialize the expected AtlasTexture region" % case.path)
		_assert(atlas != null and atlas.filter_clip, "%s AtlasTexture does not use filter clipping" % case.path)
		_assert(prop.is_in_group("damageable_props") and prop.is_in_group("pushable_prop"), "%s is missing generic prop groups" % case.path)
		_assert(not prop.is_in_group("ground_debris_root"), "%s incorrectly claims to be the room debris root" % case.path)
		_assert(int(prop.collision_layer) == 8 and int(prop.collision_mask) == 13, "%s has incorrect prop collision layers" % case.path)
		_assert((prop.get_node("CollisionShape2D") as CollisionShape2D).shape != null and (prop.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).shape != null, "%s is missing body or Hurtbox collision" % case.path)
		_assert(is_equal_approx(prop.mass, float(case.mass)), "%s mass mismatch" % case.path)
		_assert(is_equal_approx(float(prop.get("max_hp")), float(case.hp)) and is_equal_approx(float(prop.get("bullet_knockback")), float(case.knockback)), "%s HP/knockback mismatch" % case.path)
		var flash_material := sprite.material as ShaderMaterial
		_assert(flash_material != null and flash_material.shader.resource_path == "res://shaders/sprite_alpha_outline.gdshader", "%s does not reuse the white hit-flash shader" % case.path)
		_assert(previous_flash_material == null or flash_material != previous_flash_material, "%s shares a mutable hit-flash material with another furniture instance" % case.path)
		previous_flash_material = flash_material
		_assert((prop.get_node("Shadow") as Sprite2D).material != flash_material, "%s incorrectly applies hit flash to its shadow" % case.path)

		var hp_before: float = float(prop.get("hp"))
		var shot := PROJECTILE_SCENE.instantiate()
		test_world.add_child(shot)
		shot.global_position = (prop.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).global_position
		shot.setup(Vector2.RIGHT, 10.0)
		shot._process(0.0)
		_assert(is_equal_approx(float(prop.get("hp")), hp_before - 10.0), "%s did not take exactly one pistol hit" % case.path)
		_assert(float(flash_material.get_shader_parameter("flash_amount")) > 0.9, "%s did not turn white on a real hit" % case.path)
		prop._set_hit_flash_amount(0.0)
		await get_tree().physics_frame
		_assert(prop.linear_velocity.x > 0.0, "%s did not receive rightward bullet impulse (velocity=%s sleeping=%s)" % [case.path, prop.linear_velocity, prop.sleeping])
		_assert((prop.get_node("HitParticles") as CPUParticles2D).emitting, "%s did not play hit particles" % case.path)

		var debris_before := debris_root.get_child_count()
		var lethal_shot := PROJECTILE_SCENE.instantiate()
		test_world.add_child(lethal_shot)
		lethal_shot.global_position = (prop.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).global_position
		lethal_shot.setup(Vector2.RIGHT, 999.0)
		lethal_shot._process(0.0)
		_assert(bool(prop.get("destroyed")) and not sprite.visible and not (prop.get_node("Shadow") as Sprite2D).visible, "%s did not hide itself and its shadow on destruction" % case.path)
		_assert(debris_root.get_child_count() > debris_before, "%s did not create temporary texture debris" % case.path)
		var previous_disappear_delay := -1.0
		for piece_index in range(debris_before, debris_root.get_child_count()):
			var piece := debris_root.get_child(piece_index)
			var piece_sprite := piece.get_node("Sprite2D") as Sprite2D
			var piece_atlas := piece_sprite.texture as AtlasTexture
			_assert(piece_atlas != null and expected_region.encloses(piece_atlas.region), "%s produced a fragment outside its own atlas region" % case.path)
			_assert(piece_atlas == null or piece_atlas.filter_clip, "%s produced a fragment without filter clipping" % case.path)
			var disappear_delay := float(piece.get("disappear_left"))
			_assert(disappear_delay >= 0.79, "%s schedules debris before the 0.8 second start delay" % case.path)
			if previous_disappear_delay >= 0.0:
				var gap := disappear_delay - previous_disappear_delay
				_assert(gap >= 0.029 and gap <= 0.081, "%s debris does not disappear sequentially at 0.03-0.08 second intervals" % case.path)
			previous_disappear_delay = disappear_delay
		# 验证每块最终独立queue_free，而不是永久残留或整批同帧消失。
		if index == 0 and debris_root.get_child_count() - debris_before >= 2:
			var first_piece := debris_root.get_child(debris_before)
			var second_piece := debris_root.get_child(debris_before + 1)
			first_piece._process(float(first_piece.get("disappear_left")) + 0.01)
			await get_tree().process_frame
			_assert(not is_instance_valid(first_piece), "First debris piece did not queue_free at its scheduled time")
			_assert(is_instance_valid(second_piece), "All debris pieces disappeared together instead of sequentially")
		await get_tree().physics_frame
		_assert((prop.get_node("CollisionShape2D") as CollisionShape2D).disabled, "%s body collision remained after destruction" % case.path)
		_assert((prop.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).disabled, "%s Hurtbox remained after destruction" % case.path)
		prop.queue_free()
		await get_tree().process_frame

	test_world.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
