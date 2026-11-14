extends "res://tests/firearm_shared_rules_test.gd"
const ATLAS := preload("res://scripts/data/dream_gun_atlas.gd")
const PLAYER := preload("res://scenes/entities/dream_player.tscn")
const PICKUP := preload("res://scenes/dream/world_weapon_pickup.tscn")
const WORLD := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const CATALOG := preload("res://scripts/data/upgrade_catalog.gd")

func _run() -> void:
	if not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0, true); quit(8); return
	var formal := WORLD.new()
	formal._apply_3d_firearm_profile(CONFIG)
	var tuned: DemoConfig = formal.config
	formal.free()
	var world := ShotWorld.new()
	root.add_child(world); world.add_to_group(&"dream_world")
	var shooter := Shooter.new()
	world.add_child(shooter)
	var rifle := RIFLE.new()
	var mp5 := RIFLE.new()
	mp5.weapon_id = "mp5"
	shooter.add_child(rifle); shooter.add_child(mp5)
	rifle.set_process(false); mp5.set_process(false)
	check(ATLAS.has_weapon("mp5") and ATLAS.has_firearm("mp5") and ATLAS.is_automatic_weapon("mp5"), "MP5 is a registered automatic firearm")
	check(ATLAS.get_display_name("mp5") == "MP5冲锋枪", "MP5 is named as an SMG")
	check(ATLAS.get_held("mp5").resource_path.ends_with("/Guns/MP5.png"), "Provided MP5 sprite is retained")
	check(ATLAS.get_projectile("mp5") == ATLAS.get_projectile("assault_rifle") and ATLAS.get_shell("mp5") == ATLAS.get_shell("assault_rifle"), "MP5 shares rifle bullet and shell assets")
	check(CATALOG._weapon_entry("mp5", tuned).weapon_id == "mp5", "MP5 reward retains its own inventory identity")
	var metadata: Dictionary = {}
	for config: DemoConfig in [CONFIG, tuned]:
		var label := "formal_3d" if config == tuned else "source"
		var data := RULES.parameters(config, &"mp5")
		var reference := RULES.parameters(config, &"assault_rifle")
		check(is_equal_approx(data.interval * 2.0, reference.interval), label + ": twice rifle rate")
		check(is_equal_approx(data.range * 2.0, reference.range), label + ": half rifle range")
		check(data.damage == reference.damage and data.speed == reference.speed and data.pellets == reference.pellets, label + ": same rifle bullet damage, speed and count")
		for weapon: Node in [rifle, mp5]: weapon.configure_weapon(config)
		check(is_equal_approx(mp5.attack_interval * 2.0, rifle.attack_interval), label + ": actual Player node rate")
		check(is_equal_approx(mp5.attack_range * 2.0, rifle.attack_range), label + ": actual Player node range")
		metadata[label] = {"rate":1.0/mp5.attack_interval,"range":mp5.attack_range,"damage":mp5.damage,"speed":mp5.projectile_speed}
		for weapon: Node in [rifle, mp5]: weapon.configure_weapon(config, {"prefrontal":3, "visual_cortex":3})
		check(is_equal_approx(mp5.attack_interval * 2.0, rifle.attack_interval), label + ": upgraded rate ratio")
		check(is_equal_approx(mp5.attack_range * 2.0, rifle.attack_range), label + ": permanent range upgrades preserve half range")
		rifle.apply_range_upgrade(37); mp5.apply_range_upgrade(37)
		check(is_equal_approx(mp5.attack_range * 2.0, rifle.attack_range), label + ": acquired range upgrades preserve half range")
	rifle.configure_weapon(tuned); mp5.configure_weapon(tuned)
	for i in 32:
		rifle.active = false; rifle.active = true
		mp5.active = false; mp5.active = true
		seed(7543 + i); rifle._fire(Vector2.RIGHT, false)
		var first: Node2D = world.shots.back()
		var angle: float = first.direction.angle()
		seed(7543 + i); mp5._fire(Vector2.RIGHT, false)
		var second: Node2D = world.shots.back()
		check(is_equal_approx(second.direction.angle(), angle * 2.0), "Seeded actual bullet doubles first-shot scatter " + str(i))
		check(second.source_weapon_id == &"mp5" and second.damage == first.damage and second.speed == first.speed, "Real MP5 bullet identity and rifle ballistics " + str(i))
		check(second.get_node("BulletSprite").scale.is_equal_approx(first.get_node("BulletSprite").scale), "Same rendered rifle bullet scale " + str(i))
		world.clear_shots()
	rifle.active = false; rifle.active = true
	mp5.active = false; mp5.active = true
	for i in 8:
		rifle._fire(Vector2.RIGHT, false); mp5._fire(Vector2.RIGHT, false)
		check(is_equal_approx(mp5.current_spread_degrees, rifle.current_spread_degrees * 2.0), "Sustained spread doubles growth and ceiling " + str(i))
		world.clear_shots()
	shooter.pressed = false
	rifle.cooldown_left = 10; mp5.cooldown_left = 10
	rifle._process(.125); mp5._process(.125)
	check(is_equal_approx(mp5.current_spread_degrees, rifle.current_spread_degrees * 2.0), "Half recovery preserves double scatter")
	rifle._process(.125); mp5._process(.125)
	check(is_equal_approx(mp5.current_spread_degrees, 4.0) and is_equal_approx(rifle.current_spread_degrees, 2.0), "Both recover in the existing 0.25 seconds")
	var shot_counts: Array[int] = []
	for weapon: Node in [rifle, mp5]:
		weapon.configure_weapon(tuned); weapon.active = true; weapon.cooldown_left = 0
		shooter.ammo = 1000; shooter.pressed = true
		for tick in 720: weapon._process(1.0/720.0)
		shot_counts.append(world.shots.size()); world.clear_shots()
		weapon.active = false
	check(shot_counts == [9,18], "One second of actual held trigger produces 9 rifle / 18 MP5 shots")
	metadata["shots_per_second"] = shot_counts
	var enemy := ENEMY.instantiate()
	world.add_child(enemy)
	var config := tuned.duplicate(true) as DemoConfig
	config.employee_attack_cadence_jitter_ratio = 0
	enemy.configure(shooter, 100, 0, Rect2(-1000,-1000,2000,2000), 0, 0, config)
	enemy.set_physics_process(false); enemy.set_process(false)
	enemy.can_see_target = true; enemy.has_last_known_target_position = true
	enemy.last_known_target_position = Vector2(500,0)
	enemy.equip_weapon("assault_rifle"); enemy.burst_shot_count = 0
	var enemy_spread: float = enemy._get_current_weapon_spread_degrees()
	enemy.equip_weapon("mp5"); enemy.burst_shot_count = 0
	check(is_equal_approx(enemy._get_current_weapon_spread_degrees(), enemy_spread * 2), "Human enemy spread doubles rifle spread")
	check(is_equal_approx(enemy._weapon_max_range(), mp5.attack_range), "Human enemy uses the same half range")
	check(enemy.magazine_capacity == tuned.assault_rifle_magazine_size, "Human enemy keeps rifle magazine capacity")
	enemy.pickup_pause_left = 0; enemy.reload_left = 0
	enemy._fire_held_weapon()
	check(world.shots.size() == 1 and world.shots[0].source_weapon_id == &"mp5", "Human enemy creates one MP5 bullet")
	check(is_equal_approx(enemy.attack_cooldown_left, mp5.attack_interval), "Human enemy uses the same MP5 cadence")
	check(enemy.current_ammo == enemy.magazine_capacity - 1, "Human enemy consumes real MP5 ammo")
	check(enemy.ranged_attack_magazine_primed, "Human enemy continues automatic magazine fire")
	world.clear_shots()
	var player: Node2D = PLAYER.instantiate()
	world.add_child(player); player.set_physics_process(false); player.set_process(false)
	player.equip_weapon("mp5", tuned)
	check(player.get_active_weapon() == player.mp5_weapon and player.mp5_weapon.active and not player.assault_rifle_weapon.active, "Real Player selects its independent MP5 node")
	check(player.get_ammo_status().capacity == tuned.assault_rifle_magazine_size, "Real Player gets rifle magazine capacity")
	for i in 5: check(player.try_consume_ammo_for_attack(), "MP5 consumes ammunition " + str(i))
	check(player.request_reload() and player.get_ammo_status().reloading, "MP5 reload starts")
	player._update_ammo(tuned.weapon_reload_duration + .1)
	check(player.get_ammo_status().current == tuned.assault_rifle_magazine_size and not player.get_ammo_status().reloading, "MP5 reload finishes")
	player.equip_weapon("assault_rifle", tuned)
	check(player.get_active_weapon() == player.assault_rifle_weapon and not player.mp5_weapon.active, "Switch back preserves the original rifle")
	player.try_consume_ammo_for_attack()
	player.equip_weapon("mp5", tuned)
	check(player.get_ammo_status().current == tuned.assault_rifle_magazine_size, "MP5 and rifle do not share magazine state")
	var pickup: Node2D = PICKUP.instantiate()
	pickup.weapon_id = "mp5"; world.add_child(pickup)
	check(pickup.weapon_sprite.texture == ATLAS.get_held("mp5"), "MP5 pickup has the correct sprite")
	check(not pickup.shadow.visible and pickup.shadow.texture == null, "MP5 retains the removed fixed-shadow policy")
	pickup.set_thrown(Vector2(180,0),10,40,player.get_instance_id())
	check(pickup.thrown_active and pickup.weapon_id == "mp5", "Thrown MP5 retains its identity and normal physics")
	check(is_equal_approx(RULES.body_recoil_after_shot(tuned,&"mp5",Vector2.RIGHT,Vector2.ZERO,1.5).length(),RULES.body_recoil_after_shot(tuned,&"assault_rifle",Vector2.RIGHT,Vector2.ZERO,1.5).length()), "MP5 retains real rifle recoil per shot")
	world.free()
	preload("res://scripts/audio/sfx_manager.gd").stop_event(&"gunshot")
	await process_frame; await process_frame
	check(AudioServer.is_bus_mute(0), "Test mute retained")
	if not OS.get_cmdline_user_args().is_empty():
		FileAccess.open(OS.get_cmdline_user_args()[0].path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"parameters":metadata,"scope":"Shared rules, actual Player and human enemy nodes, emitted projectiles, ammo, upgrades, scatter, pickup/throw and fixed-shadow regression."}))
	print("MP5_WEAPON checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
