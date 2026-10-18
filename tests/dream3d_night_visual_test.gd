extends "res://tests/dream3d_combat_parity_test.gd"
func _run() -> void:
	world=SCENE.instantiate()
	world.generate_on_ready=false
	world.spawn_content=false
	world.persist_profile=false
	root.add_child(world)
	await frames(2)
	world.regenerate(41002)
	player=world.player
	player.set_physics_process(false)
	world.target_highlight.set_physics_process(false)
	var selected: Dictionary={}
	for room in world.rooms:
		if room.shape==&"rectangle" and room.is_large:
			selected=room
			break
	anchor=Vector2(selected.center_cell)*32
	player.position=anchor-Vector2(95,0)
	player.equip_weapon("basic",CONFIG,{})
	var enemy:=enemy_at(anchor,10000)
	var furniture:=prop_at(anchor+Vector2(45,-55))
	var door: Node3D=DOOR.instantiate()
	door.configure(1.84,3,0.1,"left",998)
	door.position=Vector3((anchor.x+150)/32,0,(anchor.y+10)/32)
	world.add_child(door)
	door.set_target_highlight(true)
	await frames(120)
	var aim:=anchor+Vector2(250,0)
	Input.warp_mouse(world.camera_3d.unproject_position(Vector3(aim.x/32,0,aim.y/32)))
	# A background test window must not depend on the user's live desktop mouse.
	# The exact same light aiming function receives this controlled ground point.
	world.night_lighting.set_process(false)
	world.night_lighting.aim_flashlight(player.position,aim)
	await frames(60)
	await capture("night_detail")
	var enemy_bridge: Node=enemy.get_meta("depth_visual_bridge").get_ref()
	var furniture_bridge: Node=furniture.get_meta("depth_visual_bridge").get_ref()
	enemy_bridge.actor_sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	furniture_bridge.actor_sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await frames(4)
	await capture("night_without_actor_shadows")
	enemy_bridge.actor_sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	furniture_bridge.actor_sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	player.auto_weapon._fire(Vector2.RIGHT,false)
	await process_frame
	await capture("night_muzzle_flash")
	print("NIGHT VISUAL FPS=",Engine.get_frames_per_second())
	world.free()
	await frames(25)
	quit()
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+label+".png")
