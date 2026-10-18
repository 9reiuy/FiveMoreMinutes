extends SceneTree
## Live call-count: after floor gen + synthetic room commits, dressing group walks
## must be << cutaway flips (dedupe). DISPLAY=:7 godot --position -2400,-2400 -s this

const OUT := "/workspace/perf60/spike_callcount_live.json"
const WALL := preload("res://scripts/dream/wall_segment_3d.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var preview_scene: PackedScene = load("res://scenes/dream/preview/SelectivePixelPreview.tscn")
	var preview: Node = preview_scene.instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	var world: Node3D = preview.get_node_or_null("WorldHost/Dream3D_RandomDungeon")
	if world == null:
		for n in preview.find_children("*", "Node3D", true, false):
			if n.get_script() != null and String(n.get_script().resource_path).ends_with("dream_3d_random_dungeon.gd"):
				world = n
				break
	if world == null:
		# SelectivePixel builds world asynchronously — wait and search group
		for _i in 120:
			await process_frame
			var w = root.get_tree().get_first_node_in_group("dream_world")
			if w != null:
				world = w
				break
	if world == null:
		print("[SPIKE_CC] no world")
		quit(2)
		return
	if world.has_method("regenerate"):
		world.call("regenerate", 41001)
	for _i in 180:
		await process_frame
		if int(world.get("rooms").size()) if world.get("rooms") != null else 0 > 0:
			if world.has_method("is_generation_complete") and bool(world.call("is_generation_complete")):
				break
			# fallback: enemy_root populated
			if world.get("enemy_root") != null and world.enemy_root.get_child_count() > 0:
				break
	WALL.debug_dressing_group_walks = 0
	WALL.debug_dressing_cutaway_flips = 0
	var vis: Node = world.get_node_or_null("RoomVisibility")
	if vis == null:
		for c in world.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("dream_3d_room_visibility.gd"):
				vis = c
				break
	var commits := 0
	if vis != null and vis.has_method("_commit"):
		var room_ids: Array = []
		for rv in world.rooms:
			room_ids.append(int(rv.get("id", -1)))
		for rid in room_ids:
			if rid < 0:
				continue
			vis.call("_commit", rid, -1)
			commits += 1
			await process_frame
	var flips: int = WALL.debug_dressing_cutaway_flips
	var walks: int = WALL.debug_dressing_group_walks
	var report := {
		"commits": commits,
		"cutaway_flips": flips,
		"dressing_group_walks": walks,
		"pass": commits > 0 and flips > 0 and walks > 0 and walks <= commits + 2,
		"walk_per_commit": float(walks) / maxf(float(commits), 1.0),
		"legacy_would_walk_per_flip": flips,
		"reduction_factor": float(flips) / maxf(float(walks), 1.0),
	}
	DirAccess.make_dir_recursive_absolute("/workspace/perf60")
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("[SPIKE_CC] ", JSON.stringify(report))
	quit(0 if bool(report["pass"]) else 1)
