extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=preload("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false
	world.enable_game_start_cab_exit=false; root.add_child(world)
	check(world.regenerate(41001),"Generate floor")
	var bridge: Node3D=preload("res://scenes/dream/3d/ActorDepthBridge3D.tscn").instantiate()
	world.actor_depth_bridges_root.add_child(bridge)
	for legacy in [false,true]:
		world.set_meta(&"test_legacy_furniture_scan",legacy)
		var source:=Node2D.new()
		world.world_effects_root.add_child(source); source.add_to_group(&"damageable_props")
		bridge.source_actor=source
		source.free()
		world._begin_cutout_query_snapshot()
		check(not world._cutout_query_furniture.has(bridge),"Freed source rejected before cast")
		world._end_cutout_query_snapshot()
		check(world._cutout_query_furniture.is_empty(),"Snapshot cleared")
	var source:=Node2D.new()
	world.world_effects_root.add_child(source); source.add_to_group(&"damageable_props")
	bridge.source_actor=source
	var sprite:=Sprite3D.new(); bridge.add_child(sprite); bridge.actor_sprite=sprite
	world.set_meta(&"test_legacy_furniture_scan",false)
	world._begin_cutout_query_snapshot()
	check(world._cutout_query_furniture.has(bridge),"Live source included")
	check(world._cutout_furniture_visuals.has(sprite),"Live visual included")
	world._end_cutout_query_snapshot()
	sprite.free()
	world._begin_cutout_query_snapshot()
	check(world._cutout_query_furniture.has(bridge),"Source survives visual disposal")
	var index: int=world._cutout_query_furniture.find(bridge)
	check(index>=0 and world._cutout_furniture_visuals[index]==null,"Freed visual yields null without a cast error")
	world._end_cutout_query_snapshot()
	source.queue_free()
	world._begin_cutout_query_snapshot()
	check(not world._cutout_query_furniture.has(bridge),"Queued source excluded")
	world._end_cutout_query_snapshot()
	bridge.queue_free()
	world._begin_cutout_query_snapshot()
	check(not world._cutout_query_furniture.has(bridge),"Queued carrier excluded")
	world._end_cutout_query_snapshot()
	world.queue_free(); for frame in 3: await process_frame
	print("CUTOUT_LIFETIME checks=",checks," failures=",failures)
	quit(1 if failures else 0)
