extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/dream_hud.tscn")
const CARD_SCENE := preload("res://scenes/ui/character_card.tscn")
const GUN_ATLAS := preload("res://scripts/data/dream_gun_atlas.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: ", label)


func _run() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	var panel := hud.get_node_or_null("PlayerInfoPanel") as Control
	check(panel != null, "DreamHUD owns the single PlayerInfoPanel")
	check(not hud.get_node("DashIndicator").visible, "legacy standalone DashIndicator is hidden")
	check(panel != null and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "panel does not consume gameplay input")
	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/player_combat_info_panel.gd")
	check(not panel_source.contains("func _process"), "combat panel is event-driven")
	check(panel_source.contains("res://art/Dream/chr_page.png"), "HUD portrait path is authoritative")
	check(not panel_source.contains("func _draw_panel"), "status cluster has no rectangular backdrop")
	if panel == null:
		quit(1)
		return

	# The panel is offset from the HUD's full-rect root, so it remains top-left
	# anchored at both the project's base and override viewport sizes.
	check(is_zero_approx(panel.position.x) and is_zero_approx(panel.position.y), "panel top-left position is stable")
	check(is_equal_approx(panel.offset_right, 244.0) and is_equal_approx(panel.offset_bottom, 244.0), "panel compact near-square footprint")
	for viewport_size in [Vector2i(640, 360), Vector2i(1280, 720)]:
		get_root().get_viewport().size = viewport_size
		await process_frame
		check(panel.global_position.is_equal_approx(Vector2.ZERO), "panel remains top-left at %s" % viewport_size)
		check(panel.get_global_rect().end.x <= viewport_size.x and panel.get_global_rect().end.y <= viewport_size.y, "panel fits viewport at %s" % viewport_size)

	hud.set_health(80.0, 80.0)
	check(is_equal_approx(float(panel.get("health")), 80.0), "full HP is published")
	check(is_equal_approx(float(panel.get("maximum_health")), 80.0), "maximum HP is published")
	hud.set_health(40.0, 80.0)
	check(is_equal_approx(float(panel.get("health")), 40.0), "partial HP is published")
	hud.set_health(0.0, 80.0)
	check(is_equal_approx(float(panel.get("health")), 0.0), "zero HP is published")
	hud.set_health(1.0, 120.0)
	check(is_equal_approx(float(panel.get("maximum_health")), 120.0), "changed maximum HP is published")

	hud.set_weapon_state("basic", "lucille", "basic", GUN_ATLAS.CATEGORY_RANGED)
	check(panel.get("ranged_weapon_id") == "basic", "ranged slot uses authoritative id")
	check(panel.get("melee_weapon_id") == "lucille", "melee slot uses authoritative id")
	check(panel.get("selected_weapon_id") == "basic", "selected ranged slot is authoritative")
	check(panel.get("active_weapon_category") == GUN_ATLAS.CATEGORY_RANGED, "active category is published")
	check(panel.get("ranged_icon") == GUN_ATLAS.get_icon("basic"), "ranged icon comes from DreamGunAtlas")
	check(panel.get("melee_icon") == GUN_ATLAS.get_icon("lucille"), "melee icon comes from DreamGunAtlas")
	hud.set_weapon_state("basic", "lucille", "lucille", GUN_ATLAS.CATEGORY_MELEE)
	check(panel.get("selected_weapon_id") == "lucille", "selected melee slot updates")
	hud.set_weapon_state("", "", "", GUN_ATLAS.CATEGORY_MELEE)
	check(panel.get("ranged_icon") == null and panel.get("melee_icon") == null, "empty weapon slots clear stale icons")
	check(panel.get("selected_weapon_id") == "", "empty selected id is preserved for fist selection")

	hud.set_dash_state(0.0, 2.0, false, 1, 1)
	check(int(panel.get("dash_charges")) == 1 and not bool(panel.get("dash_active")), "dash ready state is published")
	hud.set_dash_state(1.0, 2.0, true, 0, 1)
	check(bool(panel.get("dash_active")) and int(panel.get("dash_charges")) == 0, "dash active/cooldown state is published")
	hud.set_hungry_run(true)
	check(bool(panel.get("dash_hunger_disabled")), "hungry-run disables only dash presentation")
	hud.set_hungry_run(false)
	hud.set_flashlight_available(true)
	check(bool(panel.get("flashlight_available")), "3D flashlight availability is published")
	hud.set_flashlight_available(false)
	check(not bool(panel.get("flashlight_available")), "2D/dead flashlight slot is disabled")

	var card := CARD_SCENE.instantiate()
	root.add_child(card)
	await process_frame
	var portrait := card.get_node("CardPanel/Portrait") as TextureRect
	var name_label := card.get_node("CardPanel/NameLabel") as Label
	check(portrait.texture != null and portrait.texture.resource_path == "res://art/Dream/chr_page.png", "TAB portrait uses chr_page.png")
	check(not name_label.visible, "TAB character name is hidden")
	if "--render" in OS.get_cmdline_user_args():
		await _save_visual_snapshots(hud, card)

	card.queue_free()
	hud.queue_free()
	await process_frame
	print("PLAYER COMBAT INFO HUD CHECKS ", checks, " failures ", failures.size())
	for failure in failures:
		print("FAIL ", failure)
	quit(0 if failures.is_empty() else 1)


func _save_visual_snapshots(hud: Control, card: Control) -> void:
	# Optional visual evidence for the four acceptance states.  It is disabled
	# during normal regression runs so the test remains side-effect free.
	if get_root().get_texture() == null:
		print("HUD visual snapshots skipped: renderer has no viewport texture")
		return
	get_root().get_viewport().size = Vector2i(640, 360)
	hud.set_health(60.0, 80.0)
	hud.set_flashlight_available(true)
	var states := [
		["basic", "lucille", "basic", GUN_ATLAS.CATEGORY_RANGED, "hud_status_ranged.png"],
		["basic", "lucille", "lucille", GUN_ATLAS.CATEGORY_MELEE, "hud_status_melee.png"],
		["basic", "lucille", "", GUN_ATLAS.CATEGORY_MELEE, "hud_status_fist.png"],
		["", "", "", GUN_ATLAS.CATEGORY_MELEE, "hud_status_empty.png"],
	]
	for state in states:
		hud.set_weapon_state(state[0], state[1], state[2], state[3])
		await process_frame
		get_root().get_texture().get_image().save_png("res://tests/" + state[4])
	hud.set_weapon_state("basic", "lucille", "basic", GUN_ATLAS.CATEGORY_RANGED)
	get_root().get_viewport().size = Vector2i(1280, 720)
	await process_frame
	get_root().get_texture().get_image().save_png("res://tests/hud_status_ranged_1280.png")
	card.visible = true
	await process_frame
	get_root().get_texture().get_image().save_png("res://tests/hud_status_tab.png")
	card.visible = false
