extends SceneTree
func _initialize()->void: call_deferred("run")
func run()->void:
	var world=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	world.set_meta(&"test_floor_reflections_disabled",true)
	root.add_child(world); await process_frame
	if not world.regenerate(90210): world.free(); quit(1); return
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.set_meta(&"test_profile_shared_wall_breach",true)
	var keys: Array[String]=[]
	for key in world.wall_edges:
		if world.SHARED_WALL_BREACH.wall_for_key(world,key)!=null: keys.append(key)
	for i in mini(3,keys.size()):
		world._commit_dash_wall_breaches([keys[i]],world.get_current_floor_token(),Vector2.RIGHT)
	world.free(); await process_frame
	quit(0)
