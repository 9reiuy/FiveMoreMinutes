extends "res://tests/dream3d_combat_parity_test.gd"

## Phase C 验收：击飞恢复周期保护（Damage/Knock 双门，诊断用后删）。
## 第一次合法 Knock 允许 → Airborne/Down/GetUp/站起后保护期间
## Damage=0 且再次 Knock=0（velocity/recovery 不重置）→ 保护结束恢复正常。

func _run() -> void:
	world = SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.show_debug_markers = false
	root.add_child(world)
	await frames(2)
	world.regenerate(41004)
	player = world.player
	player.set_physics_process(false)
	var anchor := Vector2(world.rooms[int(world.spawn_room_id)]["center_cell"]) * 32.0
	player.global_position = anchor
	player.equip_weapon("basic", CONFIG, {})

	var hp0: float = player.current_health

	# —— 第一次合法 Knock：允许 ——
	player.apply_external_knockback(Vector2.RIGHT, 220.0)
	check(player.airborne_knockback == true, "first knock allowed (airborne)")
	await frames(5)

	# —— Airborne 期间：Damage=0 + 再次 Knock 被拒（velocity 不重置）——
	var hp_mid_air: float = player.current_health
	var vel_mid_x: float = player.velocity.x
	player.apply_external_knockback(Vector2.LEFT, 220.0)
	check(player.airborne_knockback == true, "still airborne after re-knock attempt")
	check(player.velocity.x > 0.0, "knock direction preserved against re-entry")
	var hp_after_reknock: float = player.current_health
	check(hp_after_reknock == hp_mid_air, "airborne direct damage rejected")
	player.receive_damage(10.0, &"enemy_melee")
	check(player.current_health == hp_after_reknock, "airborne receive_damage rejected")

	# —— 落地 + Down/GetUp/站起后保护全程：Damage 与 Knock 全部拒绝 ——
	var waited := 0
	var saw_recovery := false
	var slam_rejected_seen := false
	while waited < 900:
		waited += 10
		var in_protection: bool = (player.airborne_knockback
			or player.knockback_recovery_left > 0.0
			or (player.invulnerability_left > 0.0 and player.invulnerability_reason == &"knockdown_recovery"))
		if player.airborne_knockback == false and player.knockback_recovery_left > 0.0:
			saw_recovery = true
		var hp_now: float = player.current_health
		var vel_before: Vector2 = player.velocity
		var air_before: bool = player.airborne_knockback
		player.receive_damage(10.0, &"enemy_melee")
		player._apply_secondary_collision_damage(8.0)
		player.apply_external_knockback(Vector2.LEFT, 220.0)
		check(player.current_health == hp_now, "all damage rejected during protection (t=%dms)" % waited)
		if not air_before:
			check(player.airborne_knockback == false, "no re-launch after landing (t=%dms)" % waited)
			check(player.velocity == vel_before, "velocity untouched during protection (t=%dms)" % waited)
		else:
			slam_rejected_seen = true
		await frames(10)
		if not (player.airborne_knockback or player.knockback_recovery_left > 0.0
				or (player.invulnerability_left > 0.0 and player.invulnerability_reason == &"knockdown_recovery")):
			break
	check(saw_recovery, "recovery phase observed")

	# —— 保护结束：Damage/Knock 恢复正常 ——
	var guard := 0
	while guard < 1200:
		var still: bool = (player.airborne_knockback or player.knockback_recovery_left > 0.0
			or (player.invulnerability_left > 0.0 and player.invulnerability_reason == &"knockdown_recovery"))
		if not still:
			break
		await frames(10)
		guard += 10
	var hp_end: float = player.current_health
	player.receive_damage(10.0, &"enemy_melee")
	check(player.current_health < hp_end, "damage works again after protection ends")
	player.apply_external_knockback(Vector2.RIGHT, 220.0)
	check(player.airborne_knockback == true, "knock works again after protection ends")
	await frames(5)

	print("PHASE C checks=%d failures=%d slam_rejected_seen=%s" % [checks, failures, slam_rejected_seen])
	world.free()
	await frames(25)
	quit(1 if failures.size() > 0 else 0)


func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + label + ".png")
