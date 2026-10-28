extends SceneTree
const PRESENTATION = preload("res://scripts/dream/player_phone_presentation.gd")
const FLICKER = preload("res://scripts/ui/screen_glow_flicker.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false; world.enable_game_start_cab_exit = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var actor: Node = world.player
	var position_before: Vector2 = actor.global_position
	var weapon_before: String = actor.selected_weapon_id
	var visible_before: Array[bool] = [actor.visual.get_node("LeftFoot").visible,actor.body_pivot.visible,actor.weapon_root.visible,actor.heal_overlay.visible]
	var art_before := FileAccess.get_sha256("res://art/Dream/dream_chr_32x32.png")
	var effect = PRESENTATION.new()
	effect.bind(world)
	check(effect.frames.size()==6 and effect.frame_index==0,"New six-frame phone art begins at first opening frame")
	check(effect.frames[4].region==Rect2(128,192,32,32) and effect.frames[5].region==Rect2(160,192,32,32),"Penultimate two character images are the approved looping pair")
	check(effect.mask.get_image().get_data()==PRESENTATION.ART.get_image().get_region(Rect2i(192,192,32,32)).get_data(),"Light mask uses exact semi-transparent blue pixels, excluding blank canvas margin")
	check(not actor.body_pivot.visible and not actor.weapon_root.visible and effect.pose.visible,"Phone art replaces normal body, hands, hair and held gun without duplicate limbs")
	for i in range(1,4):
		effect.advance(.08001)
		check(effect.frame_index==i,"Opening advances original authored frame %d" % i)
	effect.advance(.08001)
	check(effect.frame_index==4,"Opening transitions into first loop frame")
	effect.advance(.25)
	check(effect.frame_index==5,"Loop alternates to second loop frame")
	effect.advance(.25)
	check(effect.frame_index==4,"Loop returns without displaying blue mask as a body")
	var samples: Dictionary = {}
	seed(56331);var expected_global_random:=randf();seed(56331)
	for i in 40:
		effect.advance(.06)
		samples[snappedf(effect.glow_alpha,.0001)] = true
	check(samples.size()>5,"Only local mask brightness changes with irregular screen-video flicker")
	check(randf()==expected_global_random,"Phone flicker uses private RNG and does not change gameplay randomness")
	check(actor.global_position==position_before and actor.selected_weapon_id==weapon_before,"Phone presentation never moves actor or changes inventory")
	check(is_instance_valid(effect.emission_material) and effect.emission_material.get_shader_parameter("phone_glow_enabled"),"Real character material receives local mask emission")
	effect.begin_close(); effect.advance(.001)
	check(effect.frame_index==3,"Closing starts reverse opening rather than jumping to combat pose")
	effect.advance(.25)
	check(effect.frame_index==0,"Closing returns through original authored frames")
	effect.release()
	check([actor.visual.get_node("LeftFoot").visible,actor.body_pivot.visible,actor.weapon_root.visible,actor.heal_overlay.visible]==visible_before,"Closing restores all original branch visibility exactly")
	check(not world.player_depth_bridge.lit_material.get_shader_parameter("phone_glow_enabled") and not actor.visual.has_node("PhonePose"),"Closing removes temporary pose and disables screen light")
	check(FileAccess.get_sha256("res://art/Dream/dream_chr_32x32.png")==art_before,"Authored PNG was not modified")
	var config = preload("res://resources/demo_config.tres")
	var bedroom = load("res://scripts/bedroom/bedroom.gd").new()
	bedroom.config = config
	seed(7821); var expected: float = FLICKER.next_alpha(config,.75)
	seed(7821); var bedroom_alpha: float = bedroom._next_bedroom_chr_glow_alpha(.75)
	check(expected==bedroom_alpha,"Bedroom and game phone call the exact shared flicker algorithm")
	bedroom.free(); world.free()
	print("PLAYER_PHONE_ANIMATION checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
