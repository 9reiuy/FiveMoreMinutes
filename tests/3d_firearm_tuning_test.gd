extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const EMPLOYEE_SCENE: PackedScene = preload("res://scenes/entities/employee_enemy.tscn")
const SHARED_CONFIG: DemoConfig = preload("res://resources/demo_config.tres")

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[FAIL] " + label)
	else:
		print("[PASS] ", label)


func _close(actual: float, expected: float, label: String) -> void:
	_check(is_equal_approx(actual, expected), label + " (%.4f / %.4f)" % [actual, expected])


func _check_profile(world: Node3D, source: DemoConfig, label: String) -> void:
	_check(world.config != source, label + ": run owns a distinct config")
	_close(world.config.basic_weapon_attack_interval, 1.0 / 4.2, label + ": pistol interval")
	_close(world.config.assault_rifle_attack_interval, 1.0 / 9.0, label + ": rifle interval")
	_close(world.config.shotgun_attack_interval, 1.0 / 2.4, label + ": shotgun interval")
	_close(world.config.basic_projectile_speed, 1500.0, label + ": pistol speed")
	_close(world.config.assault_rifle_projectile_speed, 1500.0, label + ": rifle speed")
	_close(world.config.shotgun_projectile_speed, 1500.0, label + ": shotgun speed")
	_close(world.config.basic_weapon_range, source.basic_weapon_range * (1024.0 / 350.0), label + ": pistol range")
	_close(world.config.assault_rifle_range, source.assault_rifle_range * (1536.0 / 500.0), label + ": rifle range")
	_close(world.config.shotgun_max_distance, source.shotgun_max_distance * (640.0 / 220.0), label + ": shotgun range")
	_close(world.config.employee_vision_range, source.employee_vision_range, label + ": AI vision unchanged")
	_close(world.config.basic_weapon_damage, source.basic_weapon_damage, label + ": damage unchanged")


func _run() -> void:
	var source := SHARED_CONFIG.duplicate(true) as DemoConfig
	source.basic_weapon_attack_interval = 0.41
	source.assault_rifle_attack_interval = 0.19
	source.shotgun_attack_interval = 0.91
	source.basic_projectile_speed = 601.0
	source.assault_rifle_projectile_speed = 603.0
	source.shotgun_projectile_speed = 607.0
	source.weapon_fire_rate_multiplier = 1.25
	var world := WORLD_SCENE.instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	var available: Array[String] = ["basic", "assault_rifle", "shotgun"]
	world.configure_campaign_run("basic", available, source, {"permanent_upgrades": {"prefrontal": 2,"visual_cortex":2}}, 1, false, false, 0)
	_check_profile(world, source, "campaign before ready")
	root.add_child(world)
	await process_frame
	_check_profile(world, source, "campaign after ready")
	_check(world.player.runtime_config == world.config, "player retains the 3D run config after HUD setup")
	var upgrade_speed: float = 1.0 + 2.0 * source.prefrontal_attack_speed_per_level
	_close(world.player.auto_weapon.attack_interval, world.config.weapon_interval_for_rate(world.config.basic_weapon_attack_interval) / upgrade_speed, "player pistol keeps upgrade stacking")
	_close(world.player.assault_rifle_weapon.attack_interval, world.config.weapon_interval_for_rate(world.config.assault_rifle_attack_interval) / upgrade_speed, "player rifle keeps upgrade stacking")
	_close(world.player.shotgun_weapon.attack_interval, world.config.weapon_interval_for_rate(world.config.shotgun_attack_interval) / upgrade_speed, "player shotgun keeps upgrade stacking")
	_close(world.player.auto_weapon.projectile_speed, world.config.basic_projectile_speed, "player pistol uses run speed")
	_close(world.player.assault_rifle_weapon.projectile_speed, world.config.assault_rifle_projectile_speed, "player rifle uses run speed")
	_close(world.player.shotgun_weapon.projectile_speed, world.config.shotgun_projectile_speed, "player shotgun uses run speed")
	_close(world.player.auto_weapon.attack_range,world.config.basic_weapon_range+2*source.visual_cortex_range_per_level,"pistol retains range upgrades")
	_close(world.player.assault_rifle_weapon.attack_range,world.config.assault_rifle_range+2*source.visual_cortex_range_per_level,"rifle retains range upgrades")
	_close(world.player.shotgun_weapon.attack_range,world.config.shotgun_max_distance+2*source.visual_cortex_range_per_level,"shotgun retains range upgrades")
	var enemy := EMPLOYEE_SCENE.instantiate()
	world.enemy_root.add_child(enemy)
	enemy.configure(world.player, 100.0, 0.0, Rect2(-128.0, -128.0, 256.0, 256.0), 0.0, 0.0, world.config)
	_check(enemy.feedback_config == world.config, "enemy uses the same 3D run config")
	_close(enemy._cfg("basic_projectile_speed", 0.0), world.config.basic_projectile_speed, "enemy pistol speed")
	_close(enemy._cfg("assault_rifle_projectile_speed", 0.0), world.config.assault_rifle_projectile_speed, "enemy rifle speed")
	_close(enemy._cfg("shotgun_projectile_speed", 0.0), world.config.shotgun_projectile_speed, "enemy shotgun speed")
	var saved_jitter: float = world.config.employee_attack_cadence_jitter_ratio
	world.config.employee_attack_cadence_jitter_ratio = 0.0
	for entry in [["basic_weapon_attack_interval",4.2],["assault_rifle_attack_interval",9.0],["shotgun_attack_interval",2.4]]:
		var interval: float = enemy._cfg(entry[0],0.0)
		_close(interval,1.0 / float(entry[1]),"enemy shared base interval " + String(entry[0]))
		enemy._set_weapon_attack_cooldown(interval)
		_close(enemy.attack_cooldown_left,world.config.weapon_interval_for_rate(interval),"enemy actual cooldown keeps global multiplier " + String(entry[0]))
	world.config.employee_attack_cadence_jitter_ratio = saved_jitter
	enemy.queue_free()
	world._apply_3d_firearm_profile(world.config)
	_check_profile(world, source, "idempotent application")
	_check(world.regenerate(60321), "first floor generation")
	world.floor_index = 1
	_check(world.regenerate(60322), "next floor generation")
	_check_profile(world, source, "after elevator-style floor rebuild")
	_check(world.player.runtime_config == world.config, "player still owns the same run config on next floor")
	_close(source.basic_weapon_attack_interval, 0.41, "campaign source interval unchanged")
	_close(source.basic_projectile_speed, 601.0, "campaign source speed unchanged")
	_close(SHARED_CONFIG.basic_weapon_attack_interval, 0.30, "shared legacy pistol interval unchanged")
	_close(SHARED_CONFIG.basic_projectile_speed, 550.0, "shared legacy pistol speed unchanged")
	_close(SHARED_CONFIG.assault_rifle_attack_interval, 0.15, "shared legacy rifle interval unchanged")
	_close(SHARED_CONFIG.shotgun_attack_interval, 0.80, "shared legacy shotgun interval unchanged")
	_close(SHARED_CONFIG.assault_rifle_projectile_speed, 550.0, "shared legacy rifle speed unchanged")
	_close(SHARED_CONFIG.shotgun_projectile_speed, 550.0, "shared legacy shotgun speed unchanged")
	world.queue_free()
	await process_frame
	var standalone := WORLD_SCENE.instantiate()
	standalone.generate_on_ready = false
	standalone.spawn_content = false
	standalone.persist_profile = false
	standalone.enable_game_start_cab_exit = false
	root.add_child(standalone)
	await process_frame
	_check_profile(standalone, SHARED_CONFIG, "standalone 3D")
	_close(standalone.config.basic_weapon_attack_interval, 1.0 / 4.2, "default 3D pistol interval")
	_close(standalone.config.assault_rifle_attack_interval, 1.0 / 9.0, "default 3D rifle interval")
	_close(standalone.config.shotgun_attack_interval, 1.0 / 2.4, "default 3D shotgun interval")
	_close(standalone.config.basic_projectile_speed, 1500.0, "default 3D pistol projectile speed")
	_close(standalone.config.assault_rifle_projectile_speed, 1500.0, "default 3D rifle projectile speed")
	_close(standalone.config.shotgun_projectile_speed, 1500.0, "default 3D shotgun projectile speed")
	_close(standalone.config.basic_weapon_range, 1024.0, "default pistol range")
	_close(standalone.config.assault_rifle_range, 1536.0, "default rifle range")
	_close(standalone.config.shotgun_max_distance, 640.0, "default shotgun range")
	_close(SHARED_CONFIG.basic_weapon_range, 350.0, "old 2D pistol range")
	_close(SHARED_CONFIG.assault_rifle_range, 500.0, "old 2D rifle range")
	_close(SHARED_CONFIG.shotgun_max_distance, 220.0, "old 2D shotgun range")
	standalone.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	print("3D firearm tuning: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
