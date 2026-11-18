extends "res://tests/extinguisher_stylized_cloud_test.gd"
## Real locomotion + actual Camera; capture windows are outside timings.
const EVIDENCE:="res://.runtime/extinguisher_cloud_recovery_20261117"
var phase:="after"
var measurements:Array[Dictionary]=[]

func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EVIDENCE+"/"+phase+"_"+label+".png")

func baseline()->Dictionary:
	var renderer:Node3D=smoke.cloud_renderer
	var values:Dictionary={}
	for record:Dictionary in renderer.slots.values():
		var index:int=record.index
		if index>=renderer.MAIN_COUNT:continue
		values[index]={"at":renderer.field.points[index],"size":renderer.field.sizes[index]}
	return values

func deviation(rest:Dictionary)->Dictionary:
	var distances:Array[float]=[]
	var smallest_ratio:=1.0
	var field:RefCounted=smoke.cloud_renderer.field
	for index:int in rest:
		# During initial spread, fitted anchors can move as neighbours arrive.
		# Recovery means returning to the current anchor, not its old layout.
		var anchor:Color=field.anchors.get_pixel(index,0)
		distances.append(Vector3(anchor.r,anchor.g,anchor.b).distance_to(field.points[index]))
		if float(rest[index].size)>.15:smallest_ratio=minf(smallest_ratio,float(field.sizes[index])/float(rest[index].size))
	distances.sort()
	return {"p95_offset":distances[maxi(0,ceili(distances.size()*.95)-1)] if not distances.is_empty() else 0.0,"max_offset":distances.back() if not distances.is_empty() else 0.0,"minimum_size_ratio":smallest_ratio}

func motion_case(art:bool,roll:bool)->void:
	await open_lab(true,art)
	if phase=="before":
		# Isolated control uses byte-preserved pre-change code, with only its
		# private FIELD import redirected to the preserved reference script.
		smoke.cloud_renderer.free()
		smoke.cloud_renderer=load(EVIDENCE+"/before/renderer_control.gd").new()
		smoke.add_child(smoke.cloud_renderer)
		smoke.cloud_renderer.configure(smoke)
	var player:Node2D=lab.world.player
	var center:=player.global_position
	break_tank(center)
	await create_timer(.6,true,false,true).timeout
	player.global_position=center-Vector2(64,0)
	player.velocity=Vector2.ZERO
	smoke.cloud_renderer.last_positions.clear()
	await frames(4)
	var rest:=baseline()
	var label:=("art" if art else "whitebox")+"_"+("roll" if roll else "walk")
	await shot(label+"_rest")
	var minimum_ratio:=1.0
	var peak_offset:=0.0
	var stale:=0
	if roll:
		player.dash_charges=player.max_dash_charges
		player.dash_cooldown_left=0.0
		check(player.try_start_phase_dash(Vector2.RIGHT,true),label+": uses the real dive roll")
	else:player.set_scripted_locomotion(Vector2.RIGHT,player.movement_speed)
	for frame in 42:
		await physics_frame
		await process_frame
		var state:=deviation(rest)
		minimum_ratio=minf(minimum_ratio,float(state.minimum_size_ratio))
		peak_offset=maxf(peak_offset,float(state.max_offset))
		if not smoke.contains(player.global_position) and player.get_meta(&"extinguisher_smoke",false):stale+=1
		if frame%6==0:await shot(label+"_motion_%02d"%frame)
	player.clear_scripted_locomotion()
	# Include natural deceleration; start the recovery clock after motion ends.
	for frame in 18:
		await physics_frame
		await process_frame
		if not player.dashing and player.velocity.length()<.1:break
	var started:float=smoke.clock
	var samples:Array[Dictionary]=[]
	var recovered_at:=-1.0
	var next_capture:=0
	while smoke.clock-started<.80:
		await physics_frame
		await process_frame
		var state:=deviation(rest)
		state.elapsed=smoke.clock-started
		samples.append(state)
		if recovered_at<0.0 and float(state.max_offset)<.05 and float(state.minimum_size_ratio)>.9:recovered_at=state.elapsed
		if state.elapsed>=next_capture*.10:
			await shot(label+"_recover_%02d"%next_capture)
			next_capture+=1
	check(peak_offset>.05,label+": locomotion visibly displaces the existing cloud")
	check(minimum_ratio>.65,label+": moving through gas does not shrink the puffs away")
	check(recovered_at>=0.0 and recovered_at<=.65,label+": cloud returns within 0.65 seconds after motion stops")
	check(stale==0,label+": visual gaps retain synchronized gameplay occupancy")
	measurements.append({"label":label,"peak_offset":peak_offset,"minimum_size_ratio_during_motion":minimum_ratio,"recovered_seconds":recovered_at,"samples":samples})

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/") or not AudioServer.is_bus_mute(0):
		AudioServer.set_bus_mute(0,true)
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg=="before":phase="before"
	create_timer(150,true,false,true).timeout.connect(func():quit(2))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var last:Array[int]=[Time.get_ticks_usec()]
	process_frame.connect(func()->void:
		var now:=Time.get_ticks_usec()
		RenderingServer.force_draw(false,clampf(float(now-last[0])/1000000.0,0.0,.05))
		last[0]=now)
	root.size=Vector2i(1280,720)
	settings=root.get_node("SettingsManager")
	await motion_case(false,false)
	await motion_case(false,true)
	await motion_case(true,false)
	await motion_case(true,true)
	var record:Dictionary={"checks":checks,"failures":failures,"measurements":measurements,"pid":OS.get_process_id(),"scope":"real walk and roll, whitebox and production art, native Camera; recovery samples contain screenshots and are not performance measurements"}
	FileAccess.open(EVIDENCE+"/"+phase+"_result.json",FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	lab.free()
	await frames(6)
	print("CLOUD_RECOVERY checks=",checks," failures=",failures," pid=",OS.get_process_id())
	quit(0 if failures.is_empty() else 1)
