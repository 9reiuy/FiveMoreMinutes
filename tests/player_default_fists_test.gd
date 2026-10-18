extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var player = load("res://scenes/entities/dream_player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var config = load("res://resources/demo_config.tres")
	player.equip_weapon("",config)
	check(player.left_hand_part.visible and player.right_hand_part.visible,"Empty loadout shows both fists")
	check(not player.held_weapon_sprite.visible,"No fake weapon when empty")
	check(player.left_hand_part.texture.region==Rect2(37,16,5,4),"Original left fist atlas preserved")
	check(player.right_hand_part.texture.region==Rect2(52,16,5,4),"Original right fist atlas preserved")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		player.set_meta("aim_direction_override",direction)
		player._update_direction_animation(Vector2.ZERO,1.0/60)
		check(player.left_hand_part.visible and player.right_hand_part.visible,"Fists visible in every facing")
		check(player.left_hand_part.position==player.left_hand_base_position+Vector2(0,-3),"Empty guard pose persists through direction changes")
	var overlay = player.get_node("HealOverlay/BodyPivot/LeftHand")
	check(overlay.position==player.left_hand_part.position and overlay.visible,"Heal capture mirrors fist pose")
	player.left_hand_part.hide()
	player.right_hand_part.hide()
	player.set_attacking_enabled(false)
	check(player.left_hand_part.visible and player.right_hand_part.visible,"Cabin/dialogue attack lock keeps fists visible even without world group")
	check(not player._start_punch(),"Disabled combat still prevents punch")
	player.set_attacking_enabled(true)
	player.equip_weapon("basic",config)
	check(not player.left_hand_part.visible and not player.right_hand_part.visible,"Armed display keeps existing held-weapon pose")
	check(player.left_hand_part.position==player.left_hand_base_position,"Armed state does not keep fist guard offset")
	player.equip_weapon("",config)
	check(player.left_hand_part.visible and player.right_hand_part.visible,"Removing last weapon restores fists immediately")
	player.punch_left_hand_offset = Vector2(8,-1)
	player._update_hands_visibility()
	check(player.left_hand_part.position==player.left_hand_base_position+Vector2(8,-4),"Punch offset adds to fist guard without changing combat")
	player.dead = true
	player._update_hands_visibility()
	check(not player.left_hand_part.visible and not overlay.visible,"Dead player does not resurrect fist overlay")
	player.queue_free()
	for i in 4: await process_frame
	print("DEFAULT_FISTS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
