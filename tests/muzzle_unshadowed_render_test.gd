extends SceneTree
## Real office Camera check, not an FPS benchmark. Never writes profile/settings.
const WORLD = preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
const DISPLAY_PATH = "res://scenes/dream/preview/SelectivePixelPreview.tscn"
const BRIDGE = preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
const BULLET = preload("res://scenes/entities/basic_projectile.tscn")
const RULES = preload("res://scripts/dream/dream_firearm_rules.gd")
const OUTPUT = "res://.runtime/muzzle_shadow_simplification_20261102"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func settle() -> void:
	for frame in 4:
		await RenderingServer.frame_post_draw

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	preload("res://tests/support/background_gpu.gd").start(self)
	create_timer(90.0, true).timeout.connect(func() -> void:
		push_error("Muzzle Camera validation timed out")
		quit(3))
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WORLD.instantiate()
	world.generate_on_ready = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	# The preview references autoloads: load after SceneTree initialization.
	var display: Control = load(DISPLAY_PATH).instantiate()
	display.world = world
	display.preview_mode = false
	root.add_child(display)
	paused = true
	check(world.regenerate(41001), "Formal floor generates")
	world._set_building_exterior_visible(true)
	world.night_lighting.set_process(false)
	for room in world.rooms:
		if room.get("archetype", "") == "open_office":
			world.player.global_position = world.get_player_root_position_for_cell(room.center_cell)
			world.set_current_room_id(int(room.id))
			world.activate_room(int(room.id))
			break
	world.player.set_meta(&"aim_direction_override", Vector2.RIGHT)
	world.player._update_held_weapon_aim()
	world._update_camera_and_actor_projection(0.0)
	world.shadow_manager.set_quality("high")
	world.shadow_manager.prepare_loading_selection()
	world.shadow_manager.set_process(false)
	world.player_depth_bridge._process(0.0)
	for bridge in world.actor_depth_bridges_root.get_children():
		if bridge is BRIDGE:
			bridge._process(0.0)
	display.set_selective_enabled(true)
	display.set_palette_enabled(true)
	display._process(0.0)
	await settle()
	var interior: Array = []
	for light in world.shadow_manager.candidates:
		interior.append([light, light.shadow_enabled, light.light_energy])
	var actor: Node2D = world.player
	var enemy: Node2D = null
	for candidate in world.enemy_root.get_children():
		if candidate is Node2D and candidate.has_method("get_projectile_origin"):
			enemy = candidate
			break
	check(enemy != null, "Actual enemy available for shared muzzle entry")
	for source in [actor, enemy]:
		if source == null:
			continue
		for kind in [&"pistol", &"assault_rifle", &"shotgun"]:
			world.spawn_weapon_muzzle(source.get_projectile_origin(), Vector2.RIGHT, kind, source)
			for light in world.night_lighting.muzzle_lights:
				check(not light.shadow_enabled, "Player/enemy shot enabled muzzle shadows")
	var burning: Node3D = world.floor_root.get_node("BurningEffects")
	burning.effects.step(0.02)
	var bullet := BULLET.instantiate() as Node2D
	bullet.process_mode = Node.PROCESS_MODE_DISABLED
	RULES.setup_projectile(bullet, Vector2.RIGHT, 0.0, 1024.0, 1500.0, &"player", actor, &"assault_rifle")
	bullet.global_position = actor.get_projectile_origin() + Vector2(24, 0)
	world.add_projectile(bullet, actor)
	world._update_projectile_local_lights()
	check(not world.projectile_light_assignments.is_empty(), "Live projectile retained local illumination")
	for light in world.projectile_local_light_pool:
		check(not light.shadow_enabled, "Projectile enabled dynamic shadows")
	await settle()
	var lit: Image = display.world_viewport.get_texture().get_image()
	check(not lit.is_empty(), "Actual Camera rendered")
	check(lit.save_png(OUTPUT.path_join("camera_shot.png")) == OK, "Camera capture saved")
	var lit_count := 0
	for light in world.night_lighting.muzzle_lights:
		if light.visible and light.light_energy > 0.0:
			lit_count += 1
		light.visible = false
	check(lit_count > 0, "Muzzle illumination remains visible during shot")
	await settle()
	var unlit: Image = display.world_viewport.get_texture().get_image()
	check(unlit.save_png(OUTPUT.path_join("camera_same_shot_without_pulse.png")) == OK, "Illumination control saved")
	check(lit.get_data() != unlit.get_data(), "Muzzle pulse still changes actual Camera lighting")
	for state in interior:
		check(state[0].shadow_enabled == state[1] and state[0].light_energy == state[2], "Shot altered interior lamp policy")
	check(world.night_lighting.flashlight.shadow_enabled, "Shot altered flashlight shadow policy")
	print("MUZZLE_UNSHADOWED_RENDER_CHECKS=", checks, " FAILURES=", failures, " lit_pulses=", lit_count)
	display.queue_free()
	paused = false
	for frame in 4:
		await process_frame
	quit(1 if failures else 0)
