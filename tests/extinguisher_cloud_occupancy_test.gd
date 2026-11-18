extends "res://tests/extinguisher_stylized_cloud_test.gd"
## Actual-Camera regression: visual clearing and gameplay must share occupancy.
const EVIDENCE:="res://.runtime/extinguisher_cloud_sync_20261117"
var mode_name:="after"

func snapshot(label:String)->void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EVIDENCE+"/"+mode_name+"_"+label+".png")

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg=="before":mode_name="before"
	create_timer(100,true,false,true).timeout.connect(func():quit(2))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var last:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf(float(now-last[0])/1000000.0,0.0,.05))
		last[0]=now)
	root.size=Vector2i(1280,720)
	settings=root.get_node("SettingsManager")
	await open_lab(true,false)
	var player:Node2D=lab.world.player
	var center:Vector2=player.global_position
	break_tank(center)
	await create_timer(.75,true,false,true).timeout
	check(smoke.contains(center),"visible undisturbed cloud contains its release center")
	check(smoke.blocks_sight(center-Vector2(64,0),center+Vector2(64,0)),"undisturbed visible cloud obstructs sight")
	await snapshot("dense")
	# Exercise the same impulse path used by walking / rolls, with a strong
	# bounded impulse to deterministically expose the old stale-cell bug.
	smoke.cloud_renderer.push_impulse(center,center,100.0,100.0,Vector3.ZERO)
	smoke.cloud_renderer.flush_motion()
	await frames(8)
	check(not smoke.contains(center),"visually dispersed cloud immediately releases gameplay occupancy")
	check(not player.get_meta(&"extinguisher_smoke",false) and not lab.world.player_depth_bridge.smoke_silhouette,"an empty visual gap restores the player's normal appearance")
	check(not smoke.blocks_sight(center-Vector2(64,0),center+Vector2(64,0)),"an empty cloud gap no longer blocks enemy sight")
	await snapshot("cleared")
	await create_timer(3.0,true,false,true).timeout
	check(smoke.contains(center),"occupancy returns only when the displaced cloud visibly reforms")
	await snapshot("reformed")
	# Use the real player locomotion and roll, rather than only injected
	# impulses. Clear previous positions so repositioning is not a fake wake.
	player.global_position=center-Vector2(80,0)
	player.velocity=Vector2.ZERO
	smoke.cloud_renderer.last_positions.clear()
	await frames(3)
	var motion_serial:int=smoke.cloud_renderer.serial
	var stale_frames:=0
	var clear_inside_mask:=0
	var walk_trace:Array[Dictionary]=[]
	player.set_scripted_locomotion(Vector2.RIGHT,player.movement_speed)
	for frame in 65:
		await physics_frame
		await process_frame
		var occupied:bool=smoke.contains(player.global_position)
		if not occupied and player.get_meta(&"extinguisher_smoke",false):stale_frames+=1
		if not occupied and smoke.cells.has(lab.world._cell_for_gameplay_position(player.global_position)):clear_inside_mask+=1
		walk_trace.append({"frame":frame,"at":str(player.global_position),"occupied":occupied,"meta":bool(player.get_meta(&"extinguisher_smoke",false)),"inside_release_mask":smoke.cells.has(lab.world._cell_for_gameplay_position(player.global_position)),"clock":smoke.clock})
	player.clear_scripted_locomotion()
	FileAccess.open(EVIDENCE+"/walk_trace.json",FileAccess.WRITE).store_string(JSON.stringify(walk_trace,"\t"))
	print("WALK_TRACE stale_frames=",stale_frames," clear_inside_mask=",clear_inside_mask)
	check(smoke.cloud_renderer.serial>motion_serial,"real walking still pushes the smoke parcels")
	# A dense, rapidly refilling wake need not expose a full empty frame.
	# The forced-clear case above guarantees an actual empty-gap test.
	check(stale_frames==0,"walking through visible gaps has no stale whole-cell smoke state")
	await snapshot("walk")
	player.global_position=center
	player.velocity=Vector2.ZERO
	smoke.cloud_renderer.last_positions.clear()
	player.dash_charges=player.max_dash_charges
	player.dash_cooldown_left=0.0
	var rolled:bool=player.try_start_phase_dash(Vector2.RIGHT,true)
	await create_timer(.9,true,false,true).timeout
	check(rolled and not player.dashing,"the normal dive roll still completes through the cloud")
	check(smoke.contains(player.global_position)==bool(player.get_meta(&"extinguisher_smoke",false)),"the roll endpoint uses current parcel occupancy")
	await snapshot("roll")
	# Real projectile dispersal must clear gameplay and geometry together.
	smoke.disperse_segment(center-Vector2(96,0),center+Vector2(96,0))
	await frames(4)
	check(not smoke.contains(center) and not smoke.blocks_sight(center-Vector2(96,0),center+Vector2(96,0)),"a projectile-cleared corridor does not retain invisible gas")
	for source:Dictionary in smoke.sources:source.age=smoke.DURATION-.01
	smoke.advance(.02)
	smoke.upload_puffs()
	await frames(4)
	check(smoke.cloud_renderer.live_count==0 and not player.get_meta(&"extinguisher_smoke",false),"expiry clears the parcel snapshot and player smoke state")
	var native:bool=lab.display.world_viewport.size==Vector2i(1280,720) and not lab.display.selective_enabled
	check(native and settings.is_music_suppressed(),"native display and whitebox music suppression remain active")
	var record:Dictionary={"checks":checks,"failures":failures,"pid":OS.get_process_id(),"phase":mode_name,"scope":"actual native Camera, visual clearing, silhouette, sight and recovery; bounded regression"}
	FileAccess.open(EVIDENCE+"/"+mode_name+"_result.json",FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	lab.free()
	await frames(8)
	print("CLOUD_OCCUPANCY ",mode_name," checks=",checks," failures=",failures," pid=",OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
