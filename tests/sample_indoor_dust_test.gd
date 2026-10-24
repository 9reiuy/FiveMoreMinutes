extends SceneTree
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func run() -> void:
	create_timer(100,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true)
	var world: Node=load("res://scenes/dream/preview/FurnitureTextureReview.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false
	root.add_child(world); check(world.regenerate(120),"Independent sample generates")
	world.player.set_physics_process(false); await frames()
	var dust: Node=world.get_node("SampleIndoorDust"); dust.set_process(false)
	check(dust.records.size()>0 and dust.records.size()<=dust.LIMIT,"Mote count is nonzero and bounded")
	check(dust.pool.get_parent()==world.floor_root,"All motes are owned by current sample floor")
	check(dust.pool.find_children("*","CollisionObject3D",true,false).is_empty() and dust.pool.find_children("*","CollisionObject2D",true,false).is_empty(),"Dust adds no collision or gameplay body")
	check(dust.pool.find_children("*","SubViewport",true,false).is_empty(),"Dust uses no capture viewport or screen overlay")
	for record in dust.records:
		check(world.floor_cells.has(record.cell) and int(world.room_cells.get(record.cell,-1))==record.room,"Dust belongs to a true indoor room cell")
		check(dust.path_inside_room(record.room,record.start,record.finish,record.bend),"Full randomized curved envelope and its clearance stay inside room")
		var initial: Dictionary=dust.mote_state(record,0)
		var mid_time: float=fposmod(.35-record.custom.r,1.0)*initial.life
		var a: Dictionary=dust.mote_state(record,mid_time)
		var b: Dictionary=dust.mote_state(record,mid_time+.5)
		check(a.position.distance_to(b.position)>.045,"Mote travels forward rather than oscillating almost in place")
	var quadrants: Dictionary={}; var velocity_sum:=Vector2.ZERO; var turns:=0
	for record in dust.records:
		var state: Dictionary=dust.mote_state(record,0)
		var time: float=fposmod(.30-record.custom.r,1.0)*state.life
		var a: Vector3=dust.mote_state(record,time).position
		var b: Vector3=dust.mote_state(record,time+.20).position
		var c: Vector3=dust.mote_state(record,time+.70).position
		var v:=Vector2(b.x-a.x,b.z-a.z).normalized()
		quadrants[Vector2i(1 if v.x>=0 else -1,1 if v.y>=0 else -1)]=true
		velocity_sum+=v
		if absf(v.angle_to(Vector2(c.x-b.x,c.z-b.z).normalized()))>.015: turns+=1
	check(quadrants.size()==4 and velocity_sum.length()/dust.records.size()<.3,"Live velocities cover every direction, not a coherent room-wide wind")
	check(turns>dust.records.size()/2,"Most motes smoothly change heading along their own curve")
	var bright_times:=0; var maximum_simultaneous:=0
	for tick in 80:
		var bright:=0
		for record in dust.records:
			if dust.mote_state(record,tick*.05).glint>.35: bright+=1
		bright_times+=bright; maximum_simultaneous=maxi(maximum_simultaneous,bright)
	check(bright_times>0 and maximum_simultaneous<dust.records.size()/4,"Glints occur sparsely at independent times, never as a whole-floor strobe")
	for batch in dust.pool.get_children():
		check(batch is MultiMeshInstance3D and batch.multimesh.instance_count<=dust.ROOM_LIMIT,"Room particles share one bounded draw batch")
		check(batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Tiny dust never adds shadow casters")
	var topology: Dictionary=world.floor_cells.duplicate()
	var health: float=world.player.current_health
	seed(812); var expected:=randi(); seed(812); dust.rebuild()
	check(randi()==expected,"Dust generation does not advance gameplay RNG")
	var snapshot: Array=dust.records.duplicate(true); dust.rebuild()
	check(dust.records==snapshot,"Same sample seed yields stable particle distribution")
	dust._process(.5)
	check(dust.elapsed==.5 and dust.material.get_shader_parameter("dust_clock")==.5,"Animation advances one uniform rather than per-mote CPU nodes")
	dust.set_enabled(false); dust._process(.5)
	check(not dust.pool.visible and dust.elapsed==.5,"A/B disabled mode freezes and hides particles")
	dust.set_enabled(true)
	dust.set_process(true); paused=true; var at: float=dust.elapsed; await frames()
	check(dust.elapsed==at,"Pause cannot advance indoor dust")
	paused=false; dust.set_process(false)
	world.floor_transition_in_progress=true; dust._process(.1)
	check(not dust.pool.visible,"Transition hides old-floor dust")
	world.floor_transition_in_progress=false; dust._process(.1)
	check(dust.pool.visible and world.floor_cells==topology and world.player.current_health==health,"Resume changes no floor topology or player health")
	var old: WeakRef=weakref(dust.pool)
	check(world.regenerate(121),"Sample regenerates")
	await frames(); dust._process(.1); await frames()
	check(old.get_ref()==null and dust.pool.get_parent()==world.floor_root and dust.built_seed==121,"Regeneration frees prior dust and uses new floor ownership")
	world.free(); await frames()
	var formal: Node=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	check(formal.get_node_or_null("SampleIndoorDust")==null,"Formal random floor does not opt into sample effect")
	formal.free()
	print("SAMPLE_INDOOR_DUST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
