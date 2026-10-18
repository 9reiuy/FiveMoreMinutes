extends SceneTree
## Real formal random floor, normal AI/collision/VFX. Muted diagnostic only.
var world: Node3D
var shots := {"player":0,"enemy":0}
var shooters: Dictionary={}
var failures:=0
var legacy_tracer_steps := false
var legacy_ground_redraw := false
var bounded_route: Array[Vector2]=[]
var measured_capture_viewports: Array[SubViewport]=[]
var enabled_capture_ids: Dictionary={}
var capture_timer_active := false
var capture_timer_kind := "all"
var resource_events: Dictionary={"added":{},"removed":{}}
var furniture_sleep_candidate := false
var shadow_trace: Node
var artifact_dir: String="res://.runtime/perf_delivery_20261013"
var bridge_transform_optimized:=false
func tag_bridge_transform_optimization(node: Node) -> void:
	if node.get_script()==preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd"):
		node.set_meta(&"test_capture_transform_optimization",bridge_transform_optimized)
func save_diagnostic(name: String,report: Dictionary,fixture_seed: int) -> void:
	report["seed"]=fixture_seed
	report["skeleton"]=world.preview_topology
	report["live_transform_optimized"]=bridge_transform_optimized
	report["gpu"]=RenderingServer.get_video_adapter_name()
	var output: FileAccess=FileAccess.open(artifact_dir.path_join("%s_%s_%d.json" % [name,world.preview_topology,fixture_seed]),FileAccess.WRITE)
	if output==null: failures+=1; push_error("Cannot write diagnostic artifact "+name); return
	output.store_string(JSON.stringify(report,"\t"))
func run_post_sample_diagnostics(fixture_seed: int,viewport: Viewport) -> void:
	if "--bridge-transform-parity" in OS.get_cmdline_user_args():
		var transform_report: Dictionary=await preload("res://tests/support/bridge_transform_camera_parity.gd").run(self,world)
		save_diagnostic("bridge_transform_parity",transform_report,fixture_seed)
		if not bool(transform_report.get("candidate_exact",false)) or not bool(transform_report.get("restore_exact",false)):
			failures+=1; push_error("Frozen formal Camera transform parity failed")
	if "--volume-shadow-diagnostic" in OS.get_cmdline_user_args():
		var volume_report: Dictionary=await preload("res://tests/support/volume_shadow_draw_diagnostic.gd").run(self,world,viewport)
		save_diagnostic("volume_shadow_diagnostic",volume_report,fixture_seed)
		if not bool(volume_report.get("restore_image_exact",false)):
			failures+=1; push_error("Shadow diagnostic did not restore exact frozen Camera image")
func slow_frame_context() -> Dictionary:
	var result: Dictionary={"lights":preload("res://tests/support/render_state_snapshot.gd").lights(world),
		"player_position":str(world.player.global_position),"shots":shots.duplicate(),
		"sources":world.world_effects_root.get_child_count(),
		"bridges":world.actor_depth_bridges_root.get_child_count()}
	if is_instance_valid(shadow_trace): result["shadow_selection_trace"]=shadow_trace.context()
	return result
func tag_bridge_timing(node: Node) -> void:
	if node.get_script()!=preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd"): return
	var saved: Dictionary={}
	for property in node.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE: saved[property.name]=node.get(property.name)
	node.set_script(preload("res://tests/support/bridge_method_timing_probe.gd"))
	for key in saved: node.set(key,saved[key])
func tag_furniture_sleep(node: Node) -> void:
	if node.get_script()==preload("res://scenes/dream/rooms/chair_01.gd"):
		node.set_meta(&"test_skip_unchanged_furniture_velocity",furniture_sleep_candidate)
func record_resource_added(node: Node) -> void:
	record_resource_event(node,"added")
func record_resource_removed(node: Node) -> void:
	record_resource_event(node,"removed")
func record_resource_event(node: Node,operation: String) -> void:
	var script: Script=node.get_script()
	var category: String=script.resource_path.get_file() if script!=null else node.get_class()
	if "--destruction-family-events" in OS.get_cmdline_user_args():
		var parent:=node.get_parent()
		if parent!=null and parent.name in [&"GlassShards",&"DoorShards"]:
			category=String(parent.name)+"/"+category
		elif node.name in [&"GlassShards",&"DoorShards"]:
			category=String(node.name)
	var events: Dictionary=resource_events[operation]
	events[category]=int(events.get(category,0))+1
	if node is Furniture3DVisual and operation=="removed" and "--destruction-location-probe" in OS.get_cmdline_user_args():
		var visual: Furniture3DVisual=node
		var kind := String(visual.get_meta(&"test_destruction_kind", "untracked"))
		print("FURNITURE_DESTRUCTION_LOCATION ",JSON.stringify({"kind":kind,"position":visual.position}))
func enable_capture_timer(viewport: Variant) -> void:
	if not is_instance_valid(viewport) or not viewport is SubViewport: return
	var bridge: Node=viewport.get_parent()
	if capture_timer_kind=="shell" and not bridge.has_meta(&"shell_capture_pool_slot") and not viewport.has_meta(&"shell_capture_atlas_page"): return
	if capture_timer_kind=="character" and bridge.get("character_projection")!=true: return
	if capture_timer_kind=="firearm" and not bridge.has_meta(&"projectile_capture_pool_slot") and not bridge.has_meta(&"muzzle_capture_pool_slot"): return
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	enabled_capture_ids[viewport.get_instance_id()]=true
func register_capture_viewport(node: Node) -> void:
	if node is SubViewport and (node.get_parent().has_method("set_world_camera") or node.has_meta(&"shell_capture_atlas_page")):
		measured_capture_viewports.append(node)
		if capture_timer_active: call_deferred("enable_capture_timer",node)
func capture_render_sample() -> Dictionary:
	var result: Dictionary={}
	for viewport in measured_capture_viewports:
		if not is_instance_valid(viewport) or not enabled_capture_ids.has(viewport.get_instance_id()): continue
		var bridge: Node=viewport.get_parent()
		var source: Node=bridge.get("source_actor")
		var kind: String="idle"
		if viewport.has_meta(&"shell_capture_atlas_page"): kind="shell_atlas_page"
		if is_instance_valid(source):
			if bool(bridge.get("character_projection")):
				kind="character_body" if viewport==bridge.get("render_viewport") else "character_weapon" if viewport.name==&"WeaponCapture" else "character_attachment"
			elif source.is_in_group(&"dream_projectiles"): kind="projectile"
			elif bridge.has_meta(&"muzzle_capture_pool_slot"): kind="muzzle"
			elif source is DreamShellEffect: kind="shell"
			else: kind="other"
		var mode: int=viewport.render_target_update_mode
		var key: String=kind+"_"+("always" if mode==SubViewport.UPDATE_ALWAYS else "disabled" if mode==SubViewport.UPDATE_DISABLED else "other")
		if not result.has(key): result[key]={"count":0,"cpu_last_ms":0.0,"gpu_last_ms":0.0}
		result[key].count+=1
		result[key].cpu_last_ms+=RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
		result[key].gpu_last_ms+=RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
	return result
func summary(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)]}
func _initialize() -> void:
	bridge_transform_optimized=not ("--legacy-bridge-transform" in OS.get_cmdline_user_args())
	# Connect before the formal world enters the tree, including pooled and
	# later gameplay-created captures.
	node_added.connect(tag_bridge_transform_optimization)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): artifact_dir=argument.trim_prefix("--artifact-dir=").replace("\\","/").trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir.path_join("camera")))
	call_deferred("run")
func count_projectile(node: Node) -> void:
	if node is BlackBloodEffect:
		node.set_meta(&"test_legacy_ground_redraw",legacy_ground_redraw)
		node.set_meta(&"test_ground_redraw_stats",{"copies":0,"redraws":0})
	if not node.is_in_group(&"dream_projectiles"): return
	node.set_meta(&"test_legacy_tracer_steps", legacy_tracer_steps)
	var shooter: int=node.get("shooter_instance_id")
	if shooter==world.player.get_instance_id(): shots.player+=1
	else: shots.enemy+=1; shooters[shooter]=true
func drive(seconds: float) -> void:
	if bounded_route.size()==2:
		var delta: Vector2=bounded_route[int(floor(seconds*2.0))%2]-world.player.global_position
		var input:=Vector2.ZERO
		if delta.length()>4.0:
			var right: Vector2=world.player._camera_relative_movement_input(Vector2.RIGHT)
			var down: Vector2=world.player._camera_relative_movement_input(Vector2.DOWN)
			input=Transform2D(right,down,Vector2.ZERO).basis_xform_inv(delta.normalized()).normalized()
		for pair in [["move_right",maxf(input.x,0.0)],["move_left",maxf(-input.x,0.0)],["move_down",maxf(input.y,0.0)],["move_up",maxf(-input.y,0.0)]]:
			if float(pair[1])>0.01: Input.action_press(pair[0],float(pair[1]))
			else: Input.action_release(pair[0])
		return
	if fmod(seconds,1.0)<0.5:
		Input.action_release("move_down"); Input.action_press("move_up")
	else:
		Input.action_release("move_up"); Input.action_press("move_down")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var background := "--background-gpu" in OS.get_cmdline_user_args()
	if background: preload("res://tests/support/background_gpu.gd").start(self)
	if "--output-1080" in OS.get_cmdline_user_args():
		if not background: root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1920,1080)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var actual_output:=root.get_texture().get_image().get_size()
		print("RANDOM_ACTUAL_OUTPUT ",actual_output)
		if actual_output!=Vector2i(1920,1080):
			push_error("Actual GPU output is not 1920x1080")
			quit(2); return
	if "--bridge-method-profile" in OS.get_cmdline_user_args(): node_added.connect(tag_bridge_timing)
	var phase_probe: Node
	if "--phase-profile" in OS.get_cmdline_user_args():
		phase_probe=preload("res://tests/support/frame_phase_probe.gd").new()
		root.add_child(phase_probe)
	var material_probe: Node
	if "--destruction-shader-probe" in OS.get_cmdline_user_args():
		material_probe=preload("res://tests/support/destruction_shader_probe.gd").new()
		root.add_child(material_probe); node_added.connect(material_probe.inspect_mesh)
	if "--render-watchdog" in OS.get_cmdline_user_args():
		root.add_child(preload("res://tests/support/render_progress_watchdog.gd").new())
	if "--frame-sync-ab" in OS.get_cmdline_user_args():
		push_error("Frame coalescing candidate was withdrawn after representative-load regression; this comparison is unavailable")
		quit(2); return
	var saved: Dictionary=root.get_node("SettingsManager").values.duplicate(true)
	world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	if "--world-method-profile" in OS.get_cmdline_user_args():
		var original_world_script: Script=world.get_script()
		var profiler_script: Script=preload("res://tests/support/world_method_timing_probe.gd")
		var base: Script=profiler_script.get_base_script()
		while base!=null and base!=original_world_script: base=base.get_base_script()
		if base==null:
			push_error("World profiler must inherit the actual formal world generator")
			world.free(); quit(2); return
		var exports: Dictionary={}
		for property in world.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage)&PROPERTY_USAGE_EDITOR:
				exports[property.name]=world.get(property.name)
		world.set_script(preload("res://tests/support/world_method_timing_probe.gd"))
		for key in exports: world.set(key,exports[key])
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--skeleton="):
			var requested := argument.trim_prefix("--skeleton=")
			if requested not in ["A1","B2","C3","V3"]: push_error("Unknown skeleton"); quit(2); return
			world.native_skeleton_type=requested
	var display: Control=load("res://scenes/dream/preview/SelectivePixelPreview.tscn").instantiate()
	display.world=world; display.preview_mode=false
	root.add_child(display)
	display.set_selective_enabled(true); display.set_palette_enabled(true)
	if "--shadow-selection-trace" in OS.get_cmdline_user_args():
		if phase_probe==null:
			push_error("Shadow selection trace requires frame phase profile"); quit(2); return
		shadow_trace=preload("res://tests/support/shadow_selection_trace.gd").new()
		shadow_trace.world=world; shadow_trace.phase_probe=phase_probe
		root.add_child(shadow_trace)
	var render_profile := "--render-profile" in OS.get_cmdline_user_args()
	var resource_profile := "--resource-profile" in OS.get_cmdline_user_args()
	render_profile=render_profile or resource_profile
	if resource_profile or "--cold-frame-profile" in OS.get_cmdline_user_args():
		node_added.connect(record_resource_added); node_removed.connect(record_resource_removed)
	var capture_profile := "--capture-render-profile" in OS.get_cmdline_user_args()
	if "--capture-render-kind=shell" in OS.get_cmdline_user_args(): capture_timer_kind="shell"
	if "--capture-render-kind=character" in OS.get_cmdline_user_args(): capture_timer_kind="character"
	if "--capture-render-kind=firearm" in OS.get_cmdline_user_args(): capture_timer_kind="firearm"
	if capture_profile: node_added.connect(register_capture_viewport)
	var physics_profile := "--physics-profile" in OS.get_cmdline_user_args()
	var engine_profile := "--engine-profile" in OS.get_cmdline_user_args()
	if render_profile:
		RenderingServer.viewport_set_measure_render_time(display.world_viewport.get_viewport_rid(), true)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=60 if "--acceptance" in OS.get_cmdline_user_args() else 0
	var snapshot_only := "--snapshot-ab" in OS.get_cmdline_user_args()
	var refresh_only := "--refresh-ab" in OS.get_cmdline_user_args()
	var scan_only := "--wall-scan-ab" in OS.get_cmdline_user_args()
	var tracer_only := "--tracer-steps-ab" in OS.get_cmdline_user_args()
	var ground_only := "--ground-redraw-ab" in OS.get_cmdline_user_args()
	var offscreen_only := "--offscreen-capture-ab" in OS.get_cmdline_user_args()
	var shell_only := "--shell-capture-ab" in OS.get_cmdline_user_args()
	var atlas_only := "--shell-atlas-ab" in OS.get_cmdline_user_args()
	shell_only=shell_only or atlas_only
	var furniture_only := "--furniture-scan-ab" in OS.get_cmdline_user_args()
	var feedback_only := "--feedback-capture-ab" in OS.get_cmdline_user_args()
	var blood_merge_only := "--blood-merge-ab" in OS.get_cmdline_user_args()
	var blood_query_only := "--blood-query-ab" in OS.get_cmdline_user_args()
	var blood_carrier_only := "--blood-carrier-ab" in OS.get_cmdline_user_args()
	var goal_search_only := "--goal-search-ab" in OS.get_cmdline_user_args()
	var mixed_warm_only := "--mixed-light-warm-ab" in OS.get_cmdline_user_args()
	var furniture_sleep_only := "--furniture-sleep-ab" in OS.get_cmdline_user_args()
	var shadow_receiver_only := "--shadow-receiver-ab" in OS.get_cmdline_user_args()
	if shadow_receiver_only and (not "--controlled-start" in OS.get_cmdline_user_args() or not "--prepare-firearm-rendering" in OS.get_cmdline_user_args()):
		push_error("Shadow receiver comparison requires controlled start and production firearm preparation"); quit(2); return
	if furniture_sleep_only:
		node_added.connect(tag_furniture_sleep)
		physics_profile = true
	# Diagnostic only: freeze AI during setup, then reuse the first group's
	# authored initial timer values. Health, AI rules and spawns are untouched.
	var controlled_start := "--controlled-start" in OS.get_cmdline_user_args()
	var initial_enemy_timers: Array[Dictionary]=[]
	var initial_enemy_identities: Array[int]=[]
	var initial_player_state: Dictionary={}
	var controlled_fingerprint := ""
	var shell_group_loads: Array[Dictionary]=[]
	var fixture_seed := 41001
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): fixture_seed=int(argument.trim_prefix("--seed="))
	for legacy in ([true,false,true] if snapshot_only or refresh_only or scan_only or tracer_only or ground_only or offscreen_only or shell_only or furniture_only or feedback_only or blood_merge_only or blood_query_only or blood_carrier_only or goal_search_only or mixed_warm_only or furniture_sleep_only or shadow_receiver_only or "--ab" in OS.get_cmdline_user_args() else [false]):
		furniture_sleep_candidate = furniture_sleep_only and not legacy
		var other_legacy: bool=legacy and not shadow_receiver_only and not furniture_sleep_only and not mixed_warm_only and not shell_only and not furniture_only and not feedback_only and not blood_merge_only and not blood_query_only and not blood_carrier_only and not goal_search_only
		world.set_meta(&"test_legacy_goal_search",legacy and goal_search_only)
		world.set_meta(&"test_legacy_blood_ground_capture",legacy and blood_carrier_only)
		world.set_meta(&"test_legacy_blood_queries",legacy and blood_query_only)
		world.set_meta(&"test_legacy_feedback_capture",legacy and feedback_only)
		world.set_meta(&"test_legacy_ground_merge",legacy and blood_merge_only)
		world.set_meta(&"test_legacy_furniture_scan", legacy and furniture_only)
		world.set_meta(&"test_legacy_shell_capture",legacy and ((shell_only and not atlas_only) or "--ab" in OS.get_cmdline_user_args()))
		world.set_meta(&"test_legacy_shell_atlas",legacy and atlas_only)
		seed(fixture_seed)
		legacy_tracer_steps = legacy and (tracer_only or "--ab" in OS.get_cmdline_user_args())
		legacy_ground_redraw = legacy and (ground_only or "--ab" in OS.get_cmdline_user_args())
		world.set_meta(&"test_legacy_wall_scan",legacy if scan_only else false)
		for key in [&"test_legacy_projectile_capture",&"test_legacy_muzzle_capture",&"test_legacy_occlusion_query",&"test_legacy_shot_snapshot"]: world.set_meta(key,other_legacy and not snapshot_only and not refresh_only and not scan_only and not tracer_only and not ground_only and not offscreen_only)
		if controlled_start: paused=true
		if mixed_warm_only: Furniture3DDebris.shader_variant_anchors.clear()
		if not world.regenerate(fixture_seed): paused=false; failures+=1; break
		if "--prepare-firearm-rendering" in OS.get_cmdline_user_args():
			var preparation_pause := paused
			paused=true
			world.begin_firearm_render_preparation()
			print("LIVE_FIREARM_PREPARATION ",JSON.stringify(await preload("res://scripts/dream/firearm_render_preparation.gd").run(self,world)))
			if "--prepare-shadow-receivers" in OS.get_cmdline_user_args() or (shadow_receiver_only and not legacy):
				print("LIVE_SHADOW_RECEIVER_PREPARATION ",JSON.stringify(await preload("res://tests/support/shadow_receiver_preparation_probe.gd").run(self,world,"--reset-shadow-atlas" in OS.get_cmdline_user_args())))
			paused=preparation_pause
		if "--prewarm-parallel-destruction" in OS.get_cmdline_user_args():
			print("PARALLEL_DESTRUCTION_WARM ",JSON.stringify(await preload("res://tests/support/destruction_parallel_variant_probe.gd").run(self,world)))
		if "--prewarm-mixed-light-destruction" in OS.get_cmdline_user_args() or (mixed_warm_only and not legacy):
			print("MIXED_LIGHT_DESTRUCTION_WARM ",JSON.stringify(await preload("res://tests/support/destruction_mixed_light_probe.gd").run(self,world)))
		if "--prewarm-world-destruction" in OS.get_cmdline_user_args():
			print("WORLD_DESTRUCTION_WARM ",JSON.stringify(await preload("res://tests/support/destruction_world_warm_probe.gd").run(self,world,"--prewarm-world-shadow-variants" in OS.get_cmdline_user_args())))
		if "--destruction-location-probe" in OS.get_cmdline_user_args():
			for visual in world.actor_depth_bridges_root.get_children():
				if visual is Furniture3DVisual and is_instance_valid(visual.target_furniture):
					visual.set_meta(&"test_destruction_kind",visual.target_furniture.get_meta(&"office_furniture_kind",""))
		if "--prewarm-destruction-materials" in OS.get_cmdline_user_args():
			var image:=Image.create(4,4,false,Image.FORMAT_RGBA8); image.fill(Color(.5,.4,.3))
			var variants: bool="--prewarm-light-variants" in OS.get_cmdline_user_args()
			var result: Dictionary=await preload("res://tests/support/destruction_material_warm_probe.gd").run(self,ImageTexture.create_from_image(image),false,variants,world.get_world_3d().environment)
			print("DESTRUCTION_LOAD_PROBE ",JSON.stringify(result))
			if not result.viewport_released: failures+=1
			if material_probe!=null:
				for textured in [false,true]: material_probe.inspect_material(Furniture3DDebris.shader_variant_anchors[textured],"warm_anchor",Vector3.ZERO)
		for index in 30: await process_frame
		if atlas_only:
			var shell_pool: Node=world._get_shell_capture_pool()
			print("RANDOM_SHELL_ATLAS_START ",JSON.stringify({"legacy":legacy,"atlas_enabled":shell_pool.use_atlas}))
			if shell_pool.use_atlas==legacy:
				paused=false; failures+=1; push_error("Atlas comparison did not switch the actual pool"); break
		var character_bridges: Array[Node]=[world.player_depth_bridge]
		for bridge in world.actor_depth_bridges_root.get_children():
			if bridge.get("character_projection") == true:
				character_bridges.append(bridge)
				bridge.set_meta(&"test_legacy_contact_scan", other_legacy and not snapshot_only and not refresh_only and not scan_only and not tracer_only and not ground_only and not offscreen_only)
				bridge.set_meta(&"test_legacy_snapshot_sync", other_legacy and not refresh_only and not scan_only and not tracer_only and not ground_only and not offscreen_only)
				bridge.set_meta(&"test_legacy_pending_refresh", other_legacy and not scan_only and not tracer_only and not ground_only and not offscreen_only)
				bridge.set_meta(&"test_legacy_offscreen_capture_sync",legacy and (offscreen_only or "--ab" in OS.get_cmdline_user_args()))
		world.player_depth_bridge.set_meta(&"test_legacy_contact_scan", other_legacy and not snapshot_only and not refresh_only and not scan_only and not tracer_only and not ground_only and not offscreen_only)
		world.player_depth_bridge.set_meta(&"test_legacy_snapshot_sync", other_legacy and not refresh_only and not scan_only and not tracer_only and not ground_only and not offscreen_only)
		world.player_depth_bridge.set_meta(&"test_legacy_pending_refresh", other_legacy and not scan_only and not tracer_only and not ground_only and not offscreen_only)
		world.player_depth_bridge.set_meta(&"test_legacy_offscreen_capture_sync",legacy and (offscreen_only or "--ab" in OS.get_cmdline_user_args()))
		if offscreen_only:
			for bridge in character_bridges: bridge.set_meta(&"test_capture_sync_skipped", false)
		var enemies: Array=world.enemy_root.get_children()
		if enemies.is_empty(): failures+=1; break
		if "--identity-profile" in OS.get_cmdline_user_args():
			var identities: Array=[]
			for enemy in enemies:
				var identity: int=enemy.get_instance_id()
				identities.append({"id":identity,"side_parity":identity%2,"perception_phase":identity%17})
			print("RANDOM_ENEMY_IDENTITY ",JSON.stringify({"legacy":legacy,"identities":identities}))
		if controlled_start and not initial_enemy_timers.is_empty() and initial_enemy_timers.size()!=enemies.size():
			paused=false; failures+=1; push_error("Controlled start enemy count changed"); break
		for index in enemies.size():
			if controlled_start:
				if "--stable-identities" in OS.get_cmdline_user_args() or "--canonical-identities" in OS.get_cmdline_user_args():
					if initial_enemy_identities.size()<=index:
						# --stable-identities alone only matches passes within this
						# process. Optional canonical IDs also match separate runs,
						# regardless of diagnostic/preparation node allocations.
						initial_enemy_identities.append(10000+index if "--canonical-identities" in OS.get_cmdline_user_args() else enemies[index].get_instance_id())
					enemies[index].set_meta(&"test_steering_identity",initial_enemy_identities[index])
				if "--canonical-identities" in OS.get_cmdline_user_args():
					# Repeat production initial-clock distributions after assigning
					# the reproducible identity; never change AI or timing rules.
					enemies[index].random.seed=19000+index
					enemies[index]._schedule_perception_update()
					enemies[index].enemy_blink_time_left=enemies[index]._get_next_enemy_blink_delay()
					enemies[index].neutral_emoji_cooldown=enemies[index].random.randf_range(4.0,8.0)
					enemies[index].neutral_room_travel_cooldown_left=enemies[index].random.randf_range(2.0,5.0)
					enemies[index].separation_query_left=enemies[index].random.randf_range(0.0,0.16)
				var values: Dictionary={}
				for property in [&"enemy_blink_time_left",&"neutral_emoji_cooldown",&"neutral_room_travel_cooldown_left",&"separation_query_left",&"perception_update_left"]:
					if initial_enemy_timers.size()<=index: values[property]=enemies[index].get(property)
					else: enemies[index].set(property,initial_enemy_timers[index][property])
				if initial_enemy_timers.size()<=index: initial_enemy_timers.append(values)
			if not controlled_start or not "--canonical-identities" in OS.get_cmdline_user_args(): enemies[index].random.seed=19000+index
		var origin: Vector2=enemies[0].global_position
		# Choose a naturally populated combat room, rather than whichever enemy
		# happened to be created first. Do not teleport enemies or change their AI.
		var room_counts: Dictionary={}
		var room_firearms: Dictionary={}
		for enemy in enemies:
			var room_id: int=int(enemy.get_meta(&"dream_room_id",-1))
			room_counts[room_id]=int(room_counts.get(room_id,0))+1
			if String(enemy.held_weapon_id) not in ["lucille","books",""]:
				room_firearms[room_id]=int(room_firearms.get(room_id,0))+1
		var best_count:=0
		var best_score:=-1
		for enemy in enemies:
			var room_id: int=int(enemy.get_meta(&"dream_room_id",-1))
			var score:=int(room_firearms.get(room_id,0))*100+int(room_counts.get(room_id,0))
			if room_id>=0 and score>best_score:
				best_score=score; best_count=int(room_counts[room_id]); origin=enemy.global_position
		var start_found:=false
		for offset in [Vector2(96,0),Vector2(-96,0),Vector2(0,96),Vector2(0,-96),Vector2(64,64),Vector2(-64,64),Vector2(64,-64),Vector2(-64,-64)]:
			if world._content_position_is_clear(origin+offset,12.0): world.player.global_position=origin+offset; start_found=true; break
		if not start_found: failures+=1; push_error("No valid combat start; do not sample a safe reception"); break
		world.player.invulnerability_left=999.0
		world.player.equip_weapon("assault_rifle",world.config)
		if controlled_start:
			if initial_player_state.is_empty():
				initial_player_state[&"ammo_states"]=world.player.ammo_states.duplicate(true)
				initial_player_state[&"rifle_cooldown"]=world.player.assault_rifle_weapon.cooldown_left
				for property in [&"external_knockback_velocity",&"external_knockback_left",&"knockback_recovery_left",&"airborne_knockback",&"knockback_height",&"knockback_vertical_velocity"]:
					initial_player_state[property]=world.player.get(property)
			else:
				world.player.ammo_states=initial_player_state[&"ammo_states"].duplicate(true)
				world.player.assault_rifle_weapon.cooldown_left=initial_player_state[&"rifle_cooldown"]
				for property in [&"external_knockback_velocity",&"external_knockback_left",&"knockback_recovery_left",&"airborne_knockback",&"knockback_height",&"knockback_vertical_velocity"]:
					world.player.set(property,initial_player_state[property])
			seed(fixture_seed)
		bounded_route.clear()
		if "--bounded-route" in OS.get_cmdline_user_args():
			for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(1,-1).normalized()]:
				var clear := true
				for step in [-32,-16,0,16,32]:
					clear=clear and world._content_position_is_clear(world.player.global_position+direction*float(step),12.0)
				if clear:
					bounded_route.assign([world.player.global_position-direction*32.0,world.player.global_position+direction*32.0]); break
			if bounded_route.is_empty(): paused=false; failures+=1; push_error("No clear bounded combat route"); break
		print("RANDOM_COMBAT_START ",JSON.stringify({"controlled_start":controlled_start,"position":world.player.global_position,"bounded_route":bounded_route}))
		var aim_offset:=Vector2(160,0) if "--aim-right" in OS.get_cmdline_user_args() else Vector2(-160,0)
		var aim: Vector2=world.player.global_position+aim_offset
		if "--aim-wall" in OS.get_cmdline_user_args():
			var nearest:=INF
			var wall_target:=Vector2.ZERO
			for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
				var query:=PhysicsRayQueryParameters2D.create(world.player.global_position,world.player.global_position+direction*2048.0,world.WORLD_WALL_LAYER)
				var hit: Dictionary=world.player.get_world_2d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or not hit.collider.has_meta(&"generated_wall_edge"): continue
				var distance_to_wall: float=world.player.global_position.distance_to(hit.position)
				if distance_to_wall<nearest:
					nearest=distance_to_wall; wall_target=hit.position+direction*8.0
			if not is_finite(nearest): paused=false; failures+=1; push_error("No solid wall aim target"); break
			aim=wall_target
			print("RANDOM_SUSTAINED_WALL_AIM ",JSON.stringify({"target":aim,"distance_to_wall":nearest,"enemy_health_and_ai_unchanged":true}))
		world.player.set_meta(&"presentation_pointer_position",func()->Vector2:return world.camera_3d.unproject_position(world.to_global(Vector3(aim.x/32.0,.8,aim.y/32.0))))
		world.player.set_meta(&"force_weapon_attack",true)
		if controlled_start:
			world._update_camera_and_actor_projection(0.0)
			world.room_visibility._update_outside_mask()
			var start_state: Array=[world.player.global_position,world.player.ammo_states.duplicate(true),world.player.assault_rifle_weapon.cooldown_left]
			for enemy in enemies:
				var values: Array=[enemy.global_position,enemy.current_health,enemy.held_weapon_id,enemy.random.state,enemy._steering_identity() if "--stable-identities" in OS.get_cmdline_user_args() or "--canonical-identities" in OS.get_cmdline_user_args() else 0]
				for property in [&"enemy_blink_time_left",&"neutral_emoji_cooldown",&"neutral_room_travel_cooldown_left",&"separation_query_left",&"perception_update_left"]: values.append(enemy.get(property))
				start_state.append(values)
			var fingerprint:=JSON.stringify(start_state)
			if controlled_fingerprint.is_empty(): controlled_fingerprint=fingerprint
			elif fingerprint!=controlled_fingerprint:
				paused=false; failures+=1; push_error("Controlled combat starting state differs"); break
			print("RANDOM_CONTROLLED_START same_initial_state=true")
			print("RANDOM_CONTROLLED_START_FINGERPRINT ",JSON.stringify({"seed":fixture_seed,"skeleton":world.preview_topology,"canonical":"--canonical-identities" in OS.get_cmdline_user_args(),"sha256":fingerprint.sha256_text(),"clock_semantics":"production distributions replayed from fixture RNG and identity"}))
			if "--start-check" in OS.get_cmdline_user_args(): print("RANDOM_CONTROLLED_START_STATE ",fingerprint)
			paused=false
		if "--world-method-profile" in OS.get_cmdline_user_args():
			print("PROFILE_FORMAL_LAYOUT ",JSON.stringify({"type":world.preview_topology,"floor_cells":world.floor_cells.size(),"rooms":world.rooms.size(),"native_generator":world.use_native_office_skeletons}))
		if "--start-check" in OS.get_cmdline_user_args():
			if not controlled_start: failures+=1; push_error("Start check requires controlled start")
			world.player.remove_meta(&"force_weapon_attack")
			continue
		if paused:
			failures+=1; push_error("Live combat measurement must restore gameplay before warmup"); break
		shots={"player":0,"enemy":0}; shooters.clear()
		world.world_effects_root.child_entered_tree.connect(count_projectile)
		var start:=Time.get_ticks_usec()
		var cold_profile: bool="--cold-frame-profile" in OS.get_cmdline_user_args()
		var cold_previous:=start
		var cold_samples: Array=[]; var cold_slow: Array=[]
		if cold_profile: resource_events={"added":{},"removed":{}}
		while Time.get_ticks_usec()-start<10000000:
			drive(float(Time.get_ticks_usec()-start)/1000000.0)
			await RenderingServer.frame_post_draw
			if cold_profile:
				var cold_now:=Time.get_ticks_usec()
				var cold_ms:=float(cold_now-cold_previous)/1000.0; cold_previous=cold_now
				cold_samples.append(cold_ms)
				if cold_ms>=25.0:
					cold_slow.append({"sample":cold_samples.size()-1,"elapsed_ms":cold_ms,"events":resource_events,"lights":preload("res://tests/support/render_state_snapshot.gd").lights(world)})
				resource_events={"added":{},"removed":{}}
		if cold_profile:
			cold_samples.sort()
			print("RANDOM_COLD_FRAME_PROFILE ",JSON.stringify({"seconds":10,"frames":cold_samples.size(),"median_ms":cold_samples[cold_samples.size()/2],"p95_ms":cold_samples[floori(cold_samples.size()*.95)],"max_ms":cold_samples.back(),"slow_frames":cold_slow,"semantics":"actual first ten gameplay seconds; separate from prewarmed sixty-second performance"}))
		print("RANDOM_COMBAT_WARMUP ",JSON.stringify({"seed":fixture_seed,"start_policy":"populated_room","room_enemy_count":best_count,"shots":shots,"enemy_shooters":shooters.size()}))
		if "--occlusion-burst-profile" in OS.get_cmdline_user_args():
			if not world.has_method("timing_begin"):
				push_error("Occlusion burst requires formal world method profiler"); quit(2); return
			paused=true; world.timing_begin()
			for query in range(200): world._update_occlusion_cutouts()
			print("OCCLUSION_BURST_BREAKDOWN ",JSON.stringify(world.timing_finish()))
			paused=false
		if "--preflight" in OS.get_cmdline_user_args() or "--occlusion-burst-profile" in OS.get_cmdline_user_args() or "--diagnostics-only" in OS.get_cmdline_user_args():
			world.world_effects_root.child_entered_tree.disconnect(count_projectile)
			for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)
			world.player.remove_meta(&"force_weapon_attack")
			if "--diagnostics-only" in OS.get_cmdline_user_args():
				await run_post_sample_diagnostics(fixture_seed,display.world_viewport)
				print("RANDOM_DIAGNOSTICS_ONLY scope=ten-second natural combat then frozen Camera diagnostics; not performance acceptance")
			var valid:=int(shots.enemy)>=10 and shooters.size()>=2
			root.get_node("SettingsManager").values=saved; display.queue_free()
			for index in 4: await process_frame
			print("RANDOM_COMBAT_PREFLIGHT valid=",valid); quit(0 if valid and failures==0 else 1); return
		shots={"player":0,"enemy":0}; shooters.clear()
		if capture_profile:
			# Do not instrument hundreds of first captures during generation:
			# Compatibility has a finite timestamp-query budget per frame.
			capture_timer_active=true
			for viewport in measured_capture_viewports: enable_capture_timer(viewport)
		if engine_profile:
			if not EngineDebugger.is_active(): push_error("Engine profile needs --remote-debug"); quit(1); return
			EngineDebugger.profiler_enable(&"servers", true, [2048,true])
		var samples: Array[float]=[]; var draws: Array[float]=[]
		var skipped_captures: Array=[]
		var capture_render_samples: Array=[]
		var render_frame_intervals: Array[float]=[]
		var resource_rows: Array=[]
		resource_events={"added":{},"removed":{}}
		var next_load_window := 10000000
		var load_windows: Array=[]
		var window_shots: Dictionary={"player":0,"enemy":0}
		# Godot Main reports these two monitors once per second using that
		# window's maximum. Sampling every frame does not make them frame timings.
		var timings := {"monitor_process_window_max_ms":[],"monitor_physics_window_max_ms":[],"world_render_cpu_ms":[],"world_render_gpu_ms":[],"root_render_cpu_ms":[],"root_render_gpu_ms":[]}
		var physics_activity := {"active_2d":[],"pairs_2d":[],"islands_2d":[],"active_3d":[],"pairs_3d":[],"islands_3d":[],"monitor_physics_window_max_ms":[]}
		var distance:=0.0; var peak:=0; var previous_position: Vector2=world.player.global_position
		var route_error_max := 0.0
		start=Time.get_ticks_usec(); var previous:=start
		if phase_probe!=null:
			if "--phase-context" in OS.get_cmdline_user_args():
				phase_probe.watched_root=world
				phase_probe.context_provider=slow_frame_context
			phase_probe.begin()
		if world.has_method("timing_begin"): world.timing_begin()
		if "--bridge-method-profile" in OS.get_cmdline_user_args(): preload("res://tests/support/bridge_method_timing_probe.gd").timing_begin()
		while Time.get_ticks_usec()-start<60000000:
			drive(float(Time.get_ticks_usec()-start)/1000000.0)
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			if (shell_only or furniture_only or feedback_only or blood_merge_only or blood_query_only or blood_carrier_only or goal_search_only or engine_profile or capture_profile) and now-start>=next_load_window:
				var living := 0
				var dead := 0
				for enemy in world.enemy_root.get_children():
					if bool(enemy.get("dead")): dead+=1
					else: living+=1
				load_windows.append({"seconds":float(now-start)/1000000.0,"living":living,"dead":dead,"player_shots":int(shots.player)-int(window_shots.player),"enemy_shots":int(shots.enemy)-int(window_shots.enemy),"player_position":world.player.global_position})
				window_shots=shots.duplicate()
				next_load_window+=10000000
			samples.append(float(now-previous)/1000.0); previous=now
			if capture_profile and samples.size()%15==0:
				capture_render_samples.append(capture_render_sample())
			draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			if offscreen_only:
				var skipped:=0
				for bridge in character_bridges:
					if is_instance_valid(bridge) and bool(bridge.get_meta(&"test_capture_sync_skipped",false)): skipped+=1
				skipped_captures.append(skipped)
			if physics_profile:
				physics_activity.active_2d.append(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
				physics_activity.pairs_2d.append(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
				physics_activity.islands_2d.append(Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT))
				physics_activity.active_3d.append(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
				physics_activity.pairs_3d.append(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
				physics_activity.islands_3d.append(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))
				physics_activity.monitor_physics_window_max_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			if render_profile:
				render_frame_intervals.append(samples.back())
				if resource_profile:
					resource_rows.append({"sample":samples.size()-1,"elapsed_ms":samples.back(),"events":resource_events,
						"texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
						"buffer_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
						"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
					resource_events={"added":{},"removed":{}}
					if "--render-state-profile" in OS.get_cmdline_user_args():
						resource_rows.back()["lights"]=preload("res://tests/support/render_state_snapshot.gd").lights(world)
				timings.monitor_process_window_max_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				timings.monitor_physics_window_max_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
				timings.world_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(display.world_viewport.get_viewport_rid()))
				timings.world_render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(display.world_viewport.get_viewport_rid()))
				timings.root_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				timings.root_render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			distance+=previous_position.distance_to(world.player.global_position); previous_position=world.player.global_position
			if bounded_route.size()==2:
				route_error_max=maxf(route_error_max,world.player.global_position.distance_to((bounded_route[0]+bounded_route[1])*0.5))
			peak=maxi(peak,get_nodes_in_group(&"dream_projectiles").size())
		world.world_effects_root.child_entered_tree.disconnect(count_projectile)
		if phase_probe!=null: print("RANDOM_FRAME_PHASE_PROFILE ",JSON.stringify(phase_probe.finish()))
		if world.has_method("timing_finish"): print("WORLD_METHOD_PROFILE ",JSON.stringify(world.timing_finish()))
		if "--bridge-method-profile" in OS.get_cmdline_user_args(): print("BRIDGE_METHOD_PROFILE ",JSON.stringify(preload("res://tests/support/bridge_method_timing_probe.gd").timing_finish()))
		if engine_profile:
			EngineDebugger.profiler_enable(&"servers", false)
			EngineDebugger.send_message(&"diagnostic:profile_finished", [])
		for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)
		world.player.remove_meta(&"force_weapon_attack")
		if shell_only: print("RANDOM_SHELL_LOAD_WINDOWS ",JSON.stringify({"legacy":legacy,"windows":load_windows}))
		elif furniture_only: print("RANDOM_FURNITURE_LOAD_WINDOWS ",JSON.stringify({"legacy":legacy,"windows":load_windows}))
		elif feedback_only: print("RANDOM_FEEDBACK_LOAD_WINDOWS ",JSON.stringify({"legacy":legacy,"windows":load_windows}))
		elif blood_merge_only: print("RANDOM_BLOOD_MERGE_LOAD_WINDOWS ",JSON.stringify({"legacy":legacy,"windows":load_windows}))
		elif blood_query_only: print("RANDOM_BLOOD_QUERY_LOAD_WINDOWS ",JSON.stringify({"legacy":legacy,"windows":load_windows}))
		elif blood_carrier_only: print("RANDOM_BLOOD_CARRIER_LOAD_WINDOWS ",JSON.stringify({"legacy":legacy,"windows":load_windows}))
		elif goal_search_only: print("RANDOM_GOAL_SEARCH_LOAD_WINDOWS ",JSON.stringify({"legacy":legacy,"windows":load_windows}))
		elif engine_profile or capture_profile: print("RANDOM_PROFILE_LOAD_WINDOWS ",JSON.stringify({"windows":load_windows}))
		if bounded_route.size()==2:
			print("RANDOM_BOUNDED_ROUTE ",JSON.stringify({"legacy":legacy,"max_distance_from_centre":route_error_max,"limit":96.0}))
			if route_error_max>96.0: failures+=1; push_error("Bounded combat route drifted out of encounter")
		if shell_only or furniture_only or feedback_only or blood_merge_only or blood_query_only or blood_carrier_only or goal_search_only or mixed_warm_only or furniture_sleep_only or shadow_receiver_only:
			shell_group_loads.append({"enemy_shots":int(shots.enemy),"player_shots":int(shots.player),"shooters":shooters.size()})
		if shots.player<10 or shots.enemy<10 or shooters.size()<2 or distance<500: failures+=1; push_error("Random performance workload insufficient")
		var budget_good := 0
		for frame_ms in samples:
			if frame_ms <= 18.0: budget_good += 1
		var budget_ratio := float(budget_good) / maxi(samples.size(),1)
		samples.sort(); draws.sort()
		if "--acceptance" in OS.get_cmdline_user_args():
			var passed: bool = budget_ratio >= 0.99 and samples.back() <= 33.3
			print("RANDOM_COMBAT_ACCEPTANCE ",JSON.stringify({"skeleton":world.preview_topology,"at_or_below_18ms_ratio":budget_ratio,"max_ms":samples.back(),"fixed_fps":Engine.max_fps,"passed":passed,"scope":"direct formal world fixture; Main lifecycle measured separately"}))
			if not passed: failures+=1; push_error("60 FPS acceptance budget exceeded")
		print("RANDOM_COMBAT_PERF ",JSON.stringify({"legacy":legacy,"seed":fixture_seed,"warmup_seconds":10,"seconds":60,"enemy_count_start":enemies.size(),"enemy_shooters":shooters.size(),"shots":shots,"distance":distance,"peak_projectiles":peak,"frames":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[floori(samples.size()*.95)],"p99_ms":samples[floori(samples.size()*.99)],"max_ms":samples.back(),"draw_calls_median":draws[draws.size()/2],"output":root.get_texture().get_image().get_size(),"world_viewport":display.world_viewport.size,"gpu":RenderingServer.get_video_adapter_name()}))
		var ground_stats := {"copies":0,"redraws":0,"effects":0}
		for effect in world.world_effects_root.get_children():
			if effect is BlackBloodEffect and effect.has_meta(&"test_ground_redraw_stats"):
				var stats: Dictionary = effect.get_meta(&"test_ground_redraw_stats")
				ground_stats.copies += int(stats.copies)
				ground_stats.redraws += int(stats.redraws)
				ground_stats.effects += 1
		print("RANDOM_GROUND_REDRAW_STATS ",JSON.stringify(ground_stats))
		if offscreen_only: print("RANDOM_OFFSCREEN_CAPTURE_STATS ",JSON.stringify({"skipped_per_frame":summary(skipped_captures),"characters_start":character_bridges.size()}))
		if render_profile:
			var result: Dictionary = {}
			# Timestamp results are the last resolved GPU query, not guaranteed to
			# describe the same display frame. Keep neighbours and report that limit.
			var slow_indices: Dictionary={}
			for index in render_frame_intervals.size():
				if render_frame_intervals[index]<40.0: continue
				var radius:=8 if resource_profile else 2
				for neighbour in range(maxi(0,index-radius),mini(render_frame_intervals.size(),index+radius+1)):
					slow_indices[neighbour]=true
			var slow_rows: Array=[]
			for index in slow_indices:
				var row: Dictionary={"sample":index,"elapsed_ms":render_frame_intervals[index]}
				for key in timings:
					if not key.begins_with("monitor_"): row[key]=timings[key][index]
				slow_rows.append(row)
			print("RANDOM_SLOW_RENDER_WINDOWS ",JSON.stringify({"semantics":"last_resolved_timestamp_queries; may lag display frame; neighbours included; not additive total frame costs","rows":slow_rows}))
			if resource_profile:
				var output:=FileAccess.open("res://.runtime/resource_profile_frames.jsonl",FileAccess.WRITE)
				for row in resource_rows: output.store_line(JSON.stringify(row))
				output.close()
				var resource_slow: Array=[]
				for index in slow_indices: resource_slow.append(resource_rows[index])
				print("RANDOM_SLOW_RESOURCE_WINDOWS ",JSON.stringify({"rows":resource_slow,"semantics":"node events and net renderer memory; not exact native allocation or compile timings"}))
			for key in timings: result[key] = summary(timings[key])
			result["monitor_semantics"] = "one_second_window_max_repeated_each_frame_not_per_frame_cpu_times"
			print("RANDOM_RENDER_PROFILE ", JSON.stringify(result))
		if capture_profile:
			var capture_values: Dictionary={}
			for sample in capture_render_samples:
				for category in sample:
					if not capture_values.has(category): capture_values[category]={"count":[],"cpu_last_ms":[],"gpu_last_ms":[]}
					for metric in capture_values[category]: capture_values[category][metric].append(sample[category][metric])
			var capture_results: Dictionary={}
			for category in capture_values:
				capture_results[category]={}
				for metric in capture_values[category]: capture_results[category][metric]=summary(capture_values[category][metric])
			print("CAPTURE_RENDER_PROFILE ",JSON.stringify({"filter":capture_timer_kind,"samples":capture_render_samples.size(),"sample_every_display_frames":15,"semantics":"last_rendered_viewport_measurements; disabled/other may be stale; always categories only are recurring; not total frame time","categories":capture_results}))
		if physics_profile:
			var activity_summary: Dictionary = {}
			for key in physics_activity: activity_summary[key] = summary(physics_activity[key])
			activity_summary["monitor_semantics"] = "physics_time_is_one_second_window_max_not_last_step_time"
			print("RANDOM_PHYSICS_PROFILE ", JSON.stringify(activity_summary))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(artifact_dir.path_join("camera/random_combat_"+str(legacy)+".png"))
		if "--acceptance" in OS.get_cmdline_user_args():
			root.get_texture().get_image().save_png(artifact_dir.path_join("camera/combat_%s_%d.png" % [world.preview_topology,fixture_seed]))
		# Diagnostics run only after the completed 60-second live sample and its
		# Camera evidence. Their frozen/hiding states cannot enter FPS samples.
		await run_post_sample_diagnostics(fixture_seed,display.world_viewport)
		if "--combat-render-categories" in OS.get_cmdline_user_args():
			var category_probe: Node = preload("res://tests/support/combat_render_category_probe.gd").new()
			root.add_child(category_probe)
			await category_probe.run(world)
			category_probe.queue_free()
	if (shell_only or furniture_only or feedback_only or blood_merge_only or blood_query_only or blood_carrier_only or goal_search_only or mixed_warm_only or furniture_sleep_only or shadow_receiver_only) and shell_group_loads.size()==3:
		var enemy_min: int=mini(shell_group_loads[0].enemy_shots,mini(shell_group_loads[1].enemy_shots,shell_group_loads[2].enemy_shots))
		var enemy_max: int=maxi(shell_group_loads[0].enemy_shots,maxi(shell_group_loads[1].enemy_shots,shell_group_loads[2].enemy_shots))
		var matched: bool=enemy_max>0 and float(enemy_min)/float(enemy_max)>=0.8
		for record in shell_group_loads: matched=matched and int(record.shooters)>=2
		var load_label: String="RANDOM_GOAL_SEARCH_MATCHED_WORKLOAD " if goal_search_only else "RANDOM_BLOOD_CARRIER_MATCHED_WORKLOAD " if blood_carrier_only else "RANDOM_BLOOD_QUERY_MATCHED_WORKLOAD " if blood_query_only else "RANDOM_BLOOD_MERGE_MATCHED_WORKLOAD " if blood_merge_only else "RANDOM_FEEDBACK_MATCHED_WORKLOAD " if feedback_only else "RANDOM_FURNITURE_MATCHED_WORKLOAD " if furniture_only else "RANDOM_SHELL_MATCHED_WORKLOAD "
		if mixed_warm_only: load_label="RANDOM_MIXED_LIGHT_WARM_MATCHED_WORKLOAD "
		if furniture_sleep_only: load_label="RANDOM_FURNITURE_SLEEP_MATCHED_WORKLOAD "
		if shadow_receiver_only: load_label="RANDOM_SHADOW_RECEIVER_MATCHED_WORKLOAD "
		print(load_label,JSON.stringify({"controlled_start":controlled_start,"matched":matched,"enemy_shots_min":enemy_min,"enemy_shots_max":enemy_max,"min_ratio_required":0.8}))
		if not matched: failures+=1; push_error("Comparison firing load differs; no overall performance claim")
	root.get_node("SettingsManager").values=saved
	if node_added.is_connected(tag_bridge_transform_optimization): node_added.disconnect(tag_bridge_transform_optimization)
	if phase_probe!=null: phase_probe.queue_free()
	if is_instance_valid(shadow_trace): shadow_trace.queue_free()
	if furniture_sleep_only: node_added.disconnect(tag_furniture_sleep)
	if resource_profile:
		node_added.disconnect(record_resource_added); node_removed.disconnect(record_resource_removed)
	if capture_profile: node_added.disconnect(register_capture_viewport)
	capture_timer_active=false
	measured_capture_viewports.clear()
	enabled_capture_ids.clear()
	display.queue_free()
	for index in 4: await process_frame
	print("RANDOM_COMBAT_RESULT failures=",failures)
	quit(1 if failures>0 else 0)

