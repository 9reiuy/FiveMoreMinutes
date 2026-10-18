extends SceneTree
## GPU diagnostic only: isolate categories, restore everything, no shipping hook.
var world: Node3D
var display: Control
var states: Dictionary = {}
var groups: Dictionary = {"wall_visible": [], "wall_shadow": [], "other_shadow_only": [], "positional_shadows": []}
func _initialize() -> void: call_deferred("run")
func percentile(values: Array) -> Dictionary:
	values.sort()
	return {"median": values[values.size()/2], "p95": values[floori(values.size()*.95)]}
func restore() -> void:
	for node in states:
		if node is Light3D: node.shadow_enabled = states[node]
		else: node.visible = states[node]
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false; world.persist_profile = false; world.enable_game_start_cab_exit = false
	display = load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world = world; display.preview_mode = false
	root.add_child(display)
	if not world.regenerate(41001): quit(1); return
	for index in 30: await process_frame
	world.player.invulnerability_left = 999
	world.player.global_position = world.enemy_root.get_child(0).global_position + Vector2(96,0)
	world.transition_phase = &"IDLE"; world.camera_aim_offset = Vector3.ZERO
	world._update_camera_and_actor_projection(0.0)
	display.set_selective_enabled(true); display.set_palette_enabled(true); display._process(0.0)
	world.room_visibility._update_outside_mask()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec()-start < 10000000: await RenderingServer.frame_post_draw
	paused = true
	var shines: Dictionary = {}
	for node in world.find_children("*", "CanvasItem", true, false):
		var material: ShaderMaterial = node.material as ShaderMaterial
		if material != null and material.shader != null and "uniform bool shine_enabled" in material.shader.code:
			if not shines.has(material): shines[material] = material.get_shader_parameter("shine_enabled")
			material.set_shader_parameter("shine_enabled", false)
	for wall in world.wall_root.get_children():
		for name in ["WallMesh", "ShadowCasterMesh"]:
			var mesh: Node3D = wall.get_node_or_null(name)
			if mesh != null:
				groups["wall_visible" if name == "WallMesh" else "wall_shadow"].append(mesh)
				states[mesh] = mesh.visible
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and not states.has(node):
			groups.other_shadow_only.append(node); states[node] = node.visible
	for node in world.find_children("*", "Light3D", true, false):
		if not node is DirectionalLight3D and node.shadow_enabled:
			groups.positional_shadows.append(node); states[node] = node.shadow_enabled
	var probe: Node = load("res://tests/support/frame_phase_probe.gd").new()
	root.add_child(probe)
	print("RENDER_CATEGORY_COUNTS ", JSON.stringify({"wall_visible":groups.wall_visible.size(),"wall_shadow":groups.wall_shadow.size(),"other_shadow_only":groups.other_shadow_only.size(),"positional_shadows":groups.positional_shadows.size()}))
	for category in ["original", "wall_visible", "wall_shadow", "other_shadow_only", "positional_shadows", "original_repeat"]:
		restore()
		if groups.has(category):
			for node in groups[category]:
				if node is Light3D: node.shadow_enabled = false
				else: node.visible = false
		start = Time.get_ticks_usec()
		while Time.get_ticks_usec()-start < 2000000: await RenderingServer.frame_post_draw
		var frames: Array = []; var draws: Array = []
		start = Time.get_ticks_usec(); var previous := start; probe.begin()
		while Time.get_ticks_usec()-start < 8000000:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("RENDER_CATEGORY_COST ", JSON.stringify({"disabled":category,"frame_ms":percentile(frames),"draw_calls":percentile(draws),"phases":probe.finish(),"frozen_gameplay":true,"gpu":RenderingServer.get_video_adapter_name()}))
	restore()
	for material in shines: material.set_shader_parameter("shine_enabled", shines[material])
	paused = false; display.queue_free(); probe.queue_free()
	for index in 4: await process_frame
	print("RENDER_CATEGORY_PROBE_DONE restored=true")
	quit(0)
