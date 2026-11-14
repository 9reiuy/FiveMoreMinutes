extends SceneTree
## Private-data integration: retired settings cannot restore a colour filter;
## tutorial shares the accepted maintenance materials and lighting profile.
var artifact_dir := "res://.runtime/tutorial_rebuild_20261107/validation"
var checks: Array[Dictionary]=[]

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):artifact_dir=argument.trim_prefix("--artifact-dir=")
	call_deferred("_run")

func check(value: bool, title: String) -> void:
	checks.append({"pass":value,"description":title})
	print("PASS: " if value else "FAIL: ",title)

func _muted() -> bool:
	var master := AudioServer.get_bus_index(&"Master")
	var muted := master>=0 and AudioServer.is_bus_mute(master)
	if not muted and master>=0:AudioServer.set_bus_mute(master,true)
	return muted

func _run() -> void:
	await process_frame
	check(_muted(),"Private Master=0 before scene entry")
	var private_data := OS.get_user_data_dir().replace("\\","/").begins_with(ProjectSettings.globalize_path("res://.runtime/").replace("\\","/"))
	check(private_data,"Legacy settings tests use isolated tutorial data")
	if not _muted() or not private_data:quit(1);return
	var manager: Node=root.get_node("SettingsManager")
	var saved: Dictionary=manager.values.duplicate(true)
	check(not manager.defaults.has("palette_enabled") and not manager.defaults.has("palette_scheme"),"Retired filter settings are absent from the schema")
	check(not manager.has_method("get_palette_enabled") and not manager.has_method("set_palette_enabled") and not manager.has_method("set_palette_scheme"),"Old palette controls cannot be invoked")
	var old := ConfigFile.new()
	old.set_value("audio","master_volume",0)
	old.set_value("audio","music_volume",37)
	old.set_value("audio","sfx_volume",41)
	old.set_value("graphics","palette_enabled",true)
	old.set_value("graphics","palette_scheme",5)
	old.set_value("graphics","pixelation_enabled",false)
	old.save("user://retired_filter.cfg")
	manager._load_settings("user://retired_filter.cfg");manager._apply_all_audio()
	check(_muted(),"Old-config reload preserves Master=0")
	if not _muted():quit(1);return
	check(not manager.values.has("palette_enabled") and not manager.values.has("palette_scheme"),"Old enabled/scheme values cannot restore the filter")
	check(manager.get_volume(&"music_volume")==37 and not manager.get_setting(&"pixelation_enabled"),"Supported audio and pixelation preferences still load")
	manager._save_settings("user://retired_filter_roundtrip.cfg")
	var roundtrip := ConfigFile.new();roundtrip.load("user://retired_filter_roundtrip.cfg")
	check(not roundtrip.has_section_key("graphics","palette_enabled") and not roundtrip.has_section_key("graphics","palette_scheme"),"Saving settings removes the retired keys")
	var legacy := FileAccess.open("user://game_settings.json",FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"settings":{"master_volume":0,"music_volume":23,"sfx_volume":19,"palette_enabled":true,"palette_scheme":2}}));legacy.close()
	manager._load_settings("user://legacy_migration_target.cfg");manager._apply_all_audio()
	check(_muted(),"Legacy JSON migration preserves Master=0")
	if not _muted():quit(1);return
	check(not manager.values.has("palette_enabled") and not manager.values.has("palette_scheme") and manager.get_volume(&"music_volume")==23,"Legacy JSON retains valid audio and discards palette choices")
	manager.values=saved;manager._apply_all_audio();manager._save_settings()
	check(_muted(),"Restored test preferences remain muted")
	if not _muted():quit(1);return
	var settings: Control=load("res://scenes/ui/settings_panel.tscn").instantiate()
	root.add_child(settings);settings.hide()
	check(settings.find_child("PaletteScheme",true,false)==null and settings.find_child("Pixelation",true,false)!=null and settings.find_child("ShadowQuality",true,false)!=null,"Settings UI removes the palette row and retains supported graphics controls")
	var terminal: Control=load("res://scripts/ui/phone_settings_screen.gd").new()
	terminal._page=&"graphics"
	var graphics: Array=terminal._rows()
	check(graphics.size()==2 and graphics.all(func(row):return row[0]!=&"palette_enabled"),"Phone graphics menu has only pixelation and shadow quality")
	terminal.free();settings.queue_free()
	var display: Node=load("res://scenes/testing/TutorialMaintenanceDisplay.tscn").instantiate()
	root.add_child(display);current_scene=display
	for frame in 12:await process_frame
	var world: Node3D=display.world
	var training: Node=world.get_node("ChapterTraining")
	training.set_process(false);training.set_physics_process(false);world.player.set_physics_process(false)
	check(training.stage==training.Stage.INTRO and world.player.is_empty_handed(),"Tutorial starts at the television introduction without hidden weapons")
	check(display.world_viewport.size==Vector2i(640,360) and world.camera_3d.get_viewport()==display.world_viewport,"Tutorial uses the same 640x360 game display as 0-1")
	check(display.world_viewport.has_node("WorldSemanticLayer") and not display.world_viewport.has_node("WorldPaletteLayer") and not display.has_method("set_palette_enabled"),"The shared display contains colour-code resolution without a palette pass or toggle")
	var environment: Environment=world.get_node("Lighting/WorldEnvironment").environment
	check(environment.background_color==Color.BLACK and is_zero_approx(environment.ambient_light_energy) and environment.reflected_light_source==Environment.REFLECTION_SOURCE_DISABLED and environment.ssr_enabled and environment.ssao_enabled and environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC,"Tutorial uses a pure black background and no ambient fill while retaining its concrete reflection profile")
	check(not world.get_node("Lighting/KeyLight").visible and not world.night_lighting.flashlight_enabled,"No directional fill or default flashlight washes out the basement")
	var fixtures: Array=world.tutorial_ceiling_lights.find_children("ColdPool","OmniLight3D",true,false)
	check(fixtures.size()==5 and fixtures.all(func(light):return light.light_color.b>light.light_color.r and light.shadow_enabled),"Five real shadowed cold lamps use the 0-1 fixture factory")
	check(world.training_zone_states.get(0,false) and not world.training_zone_states.get(1,true) and not world.training_zone_states.get(2,true),"Teaching progress controls room lighting")
	var concrete := true
	for slab in world.floor_root.get_children():
		var material: ShaderMaterial=slab.material_override
		concrete=concrete and material.shader.resource_path=="res://shaders/dream3d/maintenance_concrete.gdshader" and is_equal_approx(float(material.get_shader_parameter("wetness")),.85)
	check(concrete and world.floor_root.get_child_count()==7,"All seven floor sections use the 0-1 concrete base")
	var layout: Node3D=world.get_node("TutorialGeometry/ChapterLayout")
	var props := layout.find_children("*","Node3D",true,false).filter(func(node):return node.has_meta(&"maintenance_kind"))
	check(props.size()==5 and layout.get_node("Preparation").get_child_count()==1 and layout.has_node("Preparation/TelevisionDesk"),"First room contains only one television desk; service props stay in later rooms")
	var station: Node3D=layout.get_node("Preparation/TelevisionDesk")
	check(station.has_node("Table/Top") and station.has_node("Television/CC0_CRT_Chassis") and station.get_meta(&"menu_tv_source","")=="res://art/preview/screen_wall/cc0/televisionvintage.glb" and is_equal_approx(station.rotation_degrees.y,90.0),"Reference placement uses a transverse table and the existing Main Menu television")
	var monitors: Node=world.monitor_feed
	check(monitors.stations.size()==3 and monitors.stations[1].has_node("WallMount") and monitors.stations[2].has_node("WallMount"),"Each room has one television; later-room wall mounts leave the floor route clear")
	var lamp_clearance := true;var housing_shadows := true
	for index in [1,2]:
		var housing: MeshInstance3D=monitors.stations[index].get_node("Television/CC0_CRT_Chassis")
		var bounds: AABB=housing.global_transform*housing.get_aabb()
		var lamp: OmniLight3D=world.tutorial_ceiling_lights.get_child(index).get_node("ColdPool")
		lamp_clearance=lamp_clearance and not bounds.has_point(lamp.global_position)
		housing_shadows=housing_shadows and housing.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	check(lamp_clearance and housing_shadows,"Cold lamps remain outside the wall TVs while solid housings retain their shadows")
	check(monitors.find_children("*","Camera3D",true,false).is_empty() and monitors.find_children("*","CharacterBody2D",true,false).is_empty(),"Monitor feed adds no extra camera or gameplay actors")
	check(monitors.source_camera==world.camera_3d and monitors.source_viewport==display.world_viewport,"Televisions read the actual game Camera output")
	check(monitors.stations.all(func(tv):return tv.screen_material.get_shader_parameter("camera_feed")==monitors.frame_cache.output),"All three televisions share one separate frame texture without reading their live render target")
	var old_player_position: Vector2=world.player.global_position
	# Isolated occupancy checks hold progression and explicitly supply room power.
	for television in monitors.stations:television.set_power_available(true)
	for index in 3:
		world.player.global_position=Vector2(4,21-index*8)*32.0;monitors.update_frame()
		var correct: bool=monitors.active_room==index
		for tv in 3:correct=correct and monitors.stations[tv].screen_active==(tv==index)
		check(correct,"Entering room %d powers only its own television"%(index+1))
	world.player.global_position=Vector2(11,11)*32.0;monitors.update_frame()
	check(monitors.stations.all(func(tv):return not tv.screen_active) and monitors.active_room==-1,"Leaving rooms switches all televisions off and stops their camera feed")
	world.player.global_position=old_player_position;monitors.update_frame()
	var strip: MeshInstance3D=layout.get_node("Movement/DashStrip")
	check(not strip.material_override.emission_enabled and strip.find_children("*","Light3D",true,false).is_empty() and strip.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"Unpowered floor strips have no light source or GI contribution")
	world.set_training_zone_enabled(1,true)
	check(strip.material_override.emission_enabled and strip.material_override.emission_energy_multiplier>1.0 and strip.find_children("*","Light3D",true,false).is_empty(),"Powered floor strips glow themselves without illuminating other surfaces")
	world.set_training_zone_enabled(1,false)
	check(not world.has_node("GameplayCanvas/GameplayWorld/TutorialGuide") and not world.has_node("GameplayCanvas/GameplayWorld/GuideSpawnTrigger"),"The first-room character and its spawn trigger are removed")
	var room_sizes: Array[Vector3] = []
	for index in 3:
		room_sizes.append(world.floor_root.get_child(index).mesh.size)
	check(room_sizes == [Vector3(8,.2,6), Vector3(8,.2,10), Vector3(8,.2,6)], "The middle room absorbs both gaps between the teaching rooms")
	var partitions := layout.get_node("Architecture").find_children("SharedWall_*", "Node3D", false, false)
	check(partitions.size() == 2, "Adjacent classrooms have exactly two shared walls")
	var company_wall_count := 0
	var authored_wall_count := 0
	for wall in layout.get_node("Architecture").get_children():
		if not wall.has_meta(&"cutaway"):
			continue
		authored_wall_count += 1
		var material := wall.wall_material_front as ShaderMaterial
		if material != null and material.shader.resource_path.ends_with("tutorial_company_wall.gdshader") and wall.wall_material_back == material:
			company_wall_count += 1
	check(authored_wall_count > 2 and company_wall_count == authored_wall_count, "Both faces of every classroom and corridor wall use the company paint and skirting")
	await physics_frame
	var space: PhysicsDirectSpaceState2D = world.gameplay_world.get_world_2d().direct_space_state
	for index in partitions.size():
		var wall: Node3D = partitions[index]
		var expected_z := 17.5 if index == 0 else 7.5
		var body: StaticBody2D = world.collision_root.get_node("Collage_" + wall.name)
		var shape: RectangleShape2D = body.get_child(0).shape
		var span: float = wall.wall_mesh.get_aabb().size.x * wall.scale.x
		check(is_equal_approx(wall.position.z, expected_z) and is_equal_approx(span, 8.0) and is_equal_approx(shape.size.x, 256.0), "Shared wall %d spans the entire classroom seam with a matching collision" % (index + 1))
		var blocked := true
		for x in [1.0, 4.5, 8.0]:
			var ray := PhysicsRayQueryParameters2D.create(Vector2(x, expected_z - .6) * 32.0, Vector2(x, expected_z + .6) * 32.0, 4)
			blocked = blocked and space.intersect_ray(ray).get("collider") == body
		check(blocked, "Shared wall %d blocks across the full seam" % (index + 1))
	var cabinet: MeshInstance3D = layout.get_node("Movement/EquipmentLocker").find_child("ElectricalEnclosure", true, false)
	var chassis: MeshInstance3D = monitors.stations[0].get_node("Television/CC0_CRT_Chassis")
	var floor_finish: ShaderMaterial = world.floor_root.get_child(1).material_override
	check(float(floor_finish.get_shader_parameter("wear_amount")) > 0.0 and cabinet.material_override is ShaderMaterial and chassis.get_surface_override_material(0) is ShaderMaterial, "Tutorial wear reaches the concrete, equipment and TV chassis")
	check(is_equal_approx(training._gate("EntryToDash").position.x,8.5) and is_equal_approx(training._gate("DashToRange").position.x,8.5),"Second-room hatch is flush with the same wall line as the other rooms")
	check(training.training_target.get_meta(&"training_model_source","")=="res://art/Dream/enemy/Human body model.png" and training.training_target.head.texture.region==Rect2(0,0,32,32),"Third room renders the requested mannequin source without the employee art")
	check(not world.has_node("OfficeDitherLighting"),"Tutorial material colours are not replaced by office presentation adapters")
	check(training.find_children("*","Control",true,false).is_empty() and not world.has_node("TutorialGeometry/TutorialFloorPrompt"),"Tutorial instruction, hit-count, armour and extra ammo prompts are removed")
	check(world.player_depth_bridge.office_linear_lighting==world.uses_office_night_lighting(),"Tutorial player uses the same colour/light carrier as 0-1")
	check(is_zero_approx(float(world.player_depth_bridge.lit_material.get_shader_parameter("character_emission_strength"))) and not world.player_depth_bridge.lit_material.get_shader_parameter("enemy_rim_self_emission") and is_equal_approx(float(world.player_depth_bridge.lit_material.get_shader_parameter("character_light_scale")),1.0),"Character and outline have no self-lit visibility floor")
	world.terminal.request_interaction(world.player)
	check(not training.talked,"The terminal cannot be answered remotely from the spawn point")
	world.interaction_prompt.present_hint(Vector2(320,120),"交谈")
	check(world.interaction_prompt.get_script().resource_path=="res://scripts/ui/dialogue/growing_dialogue_bubble.gd" and world.interaction_prompt.dialogue_label.text=="交谈","Interaction reuses the reception dialogue bubble with only 交谈")
	check(not training._gate("EntryToDash").is_open and not training._gate("DashToRange").is_open and not training._gate("Exit").is_open,"Progression gates still enforce the lessons")
	var gate: Node3D=training._gate("EntryToDash")
	check(not gate.status_light.visible and not gate.get_node("Indicator").material_override.emission_enabled,"Unavailable rooms keep their door lamps off")
	gate.set_indicator_power_enabled(true)
	check(gate.status_light.shadow_enabled and gate.status_light.omni_range>gate.height and gate.status_light.light_color.r>gate.status_light.light_color.g,"Locked red indicator has a real shadowed light reaching surrounding receivers")
	gate.set_open(true)
	check(gate.status_light.light_color.g>gate.status_light.light_color.r and gate.get_node("Indicator").material_override.emission_enabled,"Unlocked green indicator changes the real light and emissive strip together")
	gate.set_open(false)
	var main_resource: PackedScene=load("res://scenes/app/main.tscn")
	var app: Node=main_resource.instantiate()
	check(not app.has_node("FinalPaletteLayer"),"Formal app no longer contains a global palette overlay")
	app.free()
	var report := {"pid":OS.get_process_id(),"audio":AudioServer.get_driver_name(),"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"scope":"Headless legacy-settings/UI and native tutorial environment integration. Full lesson playthrough and appearance require the separate GPU route."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir))
	var file := FileAccess.open(artifact_dir.path_join("validation.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	var failed := checks.filter(func(item):return not item.pass).size()
	print("TUTORIAL_MAINTENANCE checks=",checks.size()," failures=",failed)
	current_scene=null;display.queue_free()
	for frame in 8:await process_frame
	quit(1 if failed else 0)
