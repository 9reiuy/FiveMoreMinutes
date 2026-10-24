extends SceneTree
const HANDS = preload("res://scripts/entities/player_hand_presentation.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var player = load("res://scenes/entities/dream_player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	check(player.hand_presentation != null, "Real player creates production grip display")
	var hands = player.hand_presentation
	var original_speed: float = player.movement_speed
	for id in ["lucille", "basic", "assault_rifle", "shotgun", "books", ""]:
		player.configure_weapon(id, load("res://resources/demo_config.tres"), {})
		for index in 8:
			var aim := Vector2.from_angle(index * TAU / 8.0)
			player.last_aim_direction = aim
			player.set_meta(&"aim_direction_override", aim)
			player._update_direction_animation(Vector2.ZERO, 1.0 / 60.0)
			player._update_held_weapon_aim()
			var origin: Vector2 = player.get_projectile_origin()
			var collision: Transform2D = player.body_collision.transform
			hands.apply()
			check(player.get_projectile_origin().is_equal_approx(origin) and player.body_collision.transform == collision, "Presentation preserves gameplay geometry %s/%d" % [id, index])
			check(hands.grip_root.visible == not id.is_empty(), "Held hands follow real inventory %s/%d" % [id, index])
			if id == "lucille":
				var sprite: Sprite2D = player.held_weapon_sprite
				var contact: Vector2 = sprite.transform * (HANDS.bat_grip(sprite) + sprite.offset)
				check(contact.distance_to(hands.grip_right.position) < 0.001, "Bat hand uses actual handle pixels %d" % index)
				check(hands.grip_left.position.distance_to(contact) > 2.0 and hands.grip_left.position.distance_to(contact) < 4.0, "Two hands are stacked along handle %d" % index)
				check(absf(sprite.rotation) > 0.8 and not sprite.flip_h, "Bat is raised and holds the left wooden grip, not the right wire head %d" % index)
			elif id == "":
				check(player.left_hand_part.visible and player.right_hand_part.visible, "Fists remain visible after weapon removal")
				check(player.left_hand_part.get_parent() == player.body_pivot, "Original hierarchy remains intact")
			else:
				check(not player.held_weapon_sprite.flip_h and player.held_weapon_sprite.offset == Vector2.ZERO and player.held_weapon_sprite.rotation == 0.0, "Switching restores original non-bat art transform %s" % id)
	player.dead = true
	hands.apply()
	check(not hands.grip_root.visible, "Death hides grip display")
	check(player.movement_speed == original_speed, "Player movement speed unchanged")
	print("PLAYER_HAND_PRESENTATION checks=", checks, " failures=", failures.size())
	player.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
