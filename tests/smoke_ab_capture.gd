extends SceneTree
## Smoke A/B capture: real Main entry, real generated office, real gameplay camera.
## Only the smoke texture style changes between runs (--smoke-style=), everything
## else (seed, room choice, actor placement, camera, clip timing) is identical.
class Walkers extends Node:
	var actors: Array=[]; var running:=false; var elapsed:=0.0
	func _physics_process(delta: float) -> void:
		elapsed+=delta
		for i in actors.size():
			var actor: Node=actors[i]
			if not is_instance_valid(actor) or actor.dead: continue
			actor.velocity=Vector2(42 if fmod(elapsed+i*.3,1.8)<.9 else -42,0) if running else Vector2.ZERO
			actor.move_and_slide()
			actor._process(delta)

var main: Node
var world: Node3D
var smoke: Node3D
var walkers: Walkers
var actors: Array=[]
var clips: Dictionary={}
var smoke_style:="pixel"
var palette_on:=true
var cluster:=1
var grow:=0.0
var aim_side:="right"
## Alternative cooling ramp, applied after the warm-up shot so the measured plume
## (not the throwaway one) uses it. Empty means production defaults.
var ramp_override: Array=[]
var cluster_set:=false
var grow_set:=false
var fade_set:=false
var cluster_variants: Array[Texture2D]=[]
var variant_pixel_size:=1.0/48.0
var fade_start:=0.75
## Per-puff age/alpha trace, so the fade can be proven from data and not just eyeballed.
var puff_trace: Array=[]
var output:="res://.runtime/smoke_ab_20261023/A_pixel"
var clip:=""
var started:=0
var captured:=0
var index:=0
var checks:=0
var failures: Array=[]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="): output=argument.trim_prefix("--artifact-dir=")
		if argument.begins_with("--smoke-style="): smoke_style=argument.trim_prefix("--smoke-style=")
		if argument.begins_with("--palette="): palette_on=argument.trim_prefix("--palette=")!="0"
		if argument.begins_with("--cluster="): cluster=int(argument.trim_prefix("--cluster=")); cluster_set=true
		if argument.begins_with("--grow="): grow=float(argument.trim_prefix("--grow=")); grow_set=true
		if argument.begins_with("--psize="): variant_pixel_size=float(argument.trim_prefix("--psize="))
		if argument.begins_with("--fade="): fade_start=float(argument.trim_prefix("--fade=")); fade_set=true
		if argument.begins_with("--aim="): aim_side=argument.trim_prefix("--aim=")
		if argument.begins_with("--ramp="): ramp_override=Array(argument.trim_prefix("--ramp=").split(","))
	node_added.connect(func(node: Node) -> void:
		if node.get_script()!=null and String(node.get_script().resource_path)=="res://scripts/dream/office_skeleton_world_base.gd": node.persist_profile=false)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)

func capture(force:=false) -> void:
	if clip.is_empty(): return
	var now:=Time.get_ticks_usec()
	if not force and now-captured<33000: return
	var image: Image=root.get_texture().get_image()
	var file:="%s_%04d.png"%[clip,index]; index+=1
	image.save_png(output+"/"+file)
	# The camera lags the actor, so the actor drifts on screen. Record where it was,
	# otherwise two runs crop different parts of the frame at the same timestamp.
	var screen:=Vector2(-1,-1)
	var camera: Camera3D=world.get("camera_3d")
	if camera!=null and is_instance_valid(world.player):
		screen=camera.unproject_position(world.get_gameplay_world_position(world.player.global_position,.06))
		# The preview renders at a low internal resolution and upscales, so camera-space
		# coordinates must be scaled into captured-image pixels before they are usable.
		var view: Vector2=camera.get_viewport().get_visible_rect().size
		screen*=float(image.get_width())/maxf(1.0,view.x)
	clips[clip].append({"file":file,"seconds":(now-started)/1000000.0,"player_px":[screen.x,screen.y]})
	mirror_puffs(file, image)
	if is_instance_valid(smoke):
		var alphas: Array=[]
		for puff in smoke.puffs:
			alphas.append(snappedf(smoke.sprites[int(puff.slot)].modulate.a,0.001))
		puff_trace.append({"file":file,"alphas":alphas})
	captured=now

## Projects every live muzzle puff into captured-image pixels. Without this the
## plume can only be judged by eye, and a full-frame diff is useless because the
## muzzle flash relights the whole room on the same frames.
func mirror_puffs(file: String, image: Image) -> void:
	if not is_instance_valid(world) or clip.is_empty(): return
	var node: Node=world.floor_root.get_node_or_null("MuzzleSmoke") if world.floor_root!=null else null
	if node==null: return
	var cam: Camera3D=world.get("camera_3d")
	if cam==null: return
	var view: Vector2=cam.get_viewport().get_visible_rect().size
	var k: float=float(image.get_width())/maxf(1.0,view.x)
	var rows: Array=[]
	for puff in node.puffs:
		var body: Vector3=(puff["origin"] as Vector3)+(puff.get("drift",Vector3.ZERO) as Vector3) \
			+Vector3.UP*(0.22*float(puff["age"])+0.30*float(puff.get("rise",0.0))*pow(float(puff["age"]),2.0))
		var s: Vector2=cam.unproject_position(body)*k
		rows.append({"white":bool(puff.get("white",false)),"x":snappedf(s.x,0.1),"y":snappedf(s.y,0.1),
			"scale":snappedf(node.fills[int(puff["slot"])].scale.x*float(node.fills[int(puff["slot"])].texture.get_width())*k,0.1),
			"step":ramp_name(node.BOUNDS,clampf(float(puff.get("cage",puff["age"]))/float(node.COLOR_LIFE),0.0,1.0))})
	clips[clip][-1]["puffs"]=rows
	var muzzle: Vector3=world.get_gameplay_world_position(world.player.global_position,0.72)
	var m: Vector2=cam.unproject_position(muzzle)*k
	clips[clip][-1]["muzzle_px"]=[snappedf(m.x,0.1),snappedf(m.y,0.1)]

## Human-readable name of the cooling step a puff is currently in.
func ramp_name(bounds: Array, t: float) -> String:
	var names: Array=["orange","yellow","purple","grey"]
	for i in names.size():
		if t<float(bounds[i+1]): return names[i]
	return names[names.size()-1]

func begin(label: String) -> void:
	clip=label; clips[label]=[]; started=Time.get_ticks_usec(); captured=0; capture(true)

func wait(seconds: float) -> void:
	var until:=Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec()<until:
		await RenderingServer.frame_post_draw
		capture()

func finish() -> void: capture(true); clip=""

func fire_assault() -> void:
	var p: Node=world.player
	p.equip_weapon("assault_rifle",world.config,{})
	p.set_attacking_enabled(false)
	for i in 3:
		await wait(.04)
		p.set_meta(&"aim_direction_override",p.get_projectile_origin().direction_to(actors[0].hurtbox_collision.global_position))
	p.assault_rifle_weapon._fire(p.get_projectile_origin().direction_to(actors[0].hurtbox_collision.global_position),false)

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	process_frame.connect(func() -> void:
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); Engine.max_fps=60; root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	load("res://scripts/dream/nyangeon_vfx_shapes.gd").set_smoke_style(smoke_style)
	var shapes: GDScript=load("res://scripts/dream/nyangeon_vfx_shapes.gd")
	if smoke_style=="default":
		# Production path: nothing is overridden, the shipped defaults are measured.
		pass
	elif smoke_style=="soft":
		shapes.set_smoke_style("soft")
	elif smoke_style=="soft_dust":
		# Same soft recipe, grey tint and lower peak: the "dust" reading instead of "light".
		shapes.set_soft_look(Color("7f858d"),.62)
		shapes.set_smoke_style("soft")
	elif smoke_style=="cluster_white":
		# Same merged cloud shapes, pure white fill instead of the unpacked beige.
		var packed_w: Array[Texture2D]=[]
		for i in 6:
			var path_w:="res://.runtime/smoke_ab_20261023/port/clusters_white/cluster_%d.png"%i
			var img_w:=Image.load_from_file(ProjectSettings.globalize_path(path_w))
			if img_w==null: continue
			img_w.convert(Image.FORMAT_RGBA8)
			packed_w.append(ImageTexture.create_from_image(img_w))
		cluster_variants=packed_w
		check(packed_w.size()==6,"Six white cloud shapes are readable")
	elif smoke_style=="cluster":
		# Pre-baked merged clouds: three circles fused, one continuous outline around
		# the union. This is what the reference gets from a layer-level outline effect.
		var packed: Array[Texture2D]=[]
		for i in 6:
			var path:="res://.runtime/smoke_ab_20261023/port/clusters/cluster_%d.png"%i
			var img:=Image.load_from_file(ProjectSettings.globalize_path(path))
			if img==null: continue
			img.convert(Image.FORMAT_RGBA8)
			packed.append(ImageTexture.create_from_image(img))
		cluster_variants=packed
		check(packed.size()==6,"Six baked cloud shapes are readable")
	elif smoke_style=="walkcircle":
		# The animation named "walk": an 11x9 stepped circle, one flat colour, plus
		# the effect's 1px black ring. Several of these overlap and scale up/down.
		var image_c:=Image.load_from_file(ProjectSettings.globalize_path("res://.runtime/smoke_ab_20261023/port/walk_circle_outlined_15.png"))
		check(image_c!=null,"walk circle frame is readable")
		if image_c!=null:
			image_c.convert(Image.FORMAT_RGBA8)
			shapes.set_texture_override(ImageTexture.create_from_image(image_c))
	elif smoke_style=="walkrun":
		# The animation the reference actually plays while walking: an 18x18 flat
		# off-white cloud (#D9CCBF, single colour) plus the effect's 1px black ring.
		var image_wr:=Image.load_from_file(ProjectSettings.globalize_path("res://.runtime/smoke_ab_20261023/port/walkrun_outlined_20.png"))
		check(image_wr!=null,"walkRun dust frame is readable")
		if image_wr!=null:
			image_wr.convert(Image.FORMAT_RGBA8)
			shapes.set_texture_override(ImageTexture.create_from_image(image_wr))
	elif smoke_style=="port_fill":
		# White fill, dark ring: the same unpacked silhouette and the same 4-per-step
		# cluster, but coloured for a dark floor instead of the reference's bright one.
		var image_f:=Image.load_from_file(ProjectSettings.globalize_path("res://.runtime/smoke_ab_20261023/port/dust_white_fill_11x11.png"))
		check(image_f!=null,"White-fill dust frame is readable")
		if image_f!=null:
			image_f.convert(Image.FORMAT_RGBA8)
			shapes.set_texture_override(ImageTexture.create_from_image(image_f))
	elif smoke_style=="port_white":
		# Same unpacked disc, but the OnePixelOutline ring drawn white: the effect colour
		# is a runtime parameter that data.json does not store, and white is what the
		# shipped game reads as on a bright floor.
		var image_w:=Image.load_from_file(ProjectSettings.globalize_path("res://.runtime/smoke_ab_20261023/port/dust_port_white_11x11.png"))
		check(image_w!=null,"White-ring dust frame is readable")
		if image_w!=null:
			image_w.convert(Image.FORMAT_RGBA8)
			shapes.set_texture_override(ImageTexture.create_from_image(image_w))
	elif smoke_style=="port":
		# Literal port: the unpacked dust frame itself (8x8, 3-tone ramp plus baked dark rim),
		# scaled 2x with nearest so texel size matches the existing 16x16 puff.
		var image:=Image.load_from_file(ProjectSettings.globalize_path("res://.runtime/smoke_ab_20261023/port/dust_port_11x11.png"))
		check(image!=null,"Unpacked dust frame is readable")
		if image!=null:
			image.convert(Image.FORMAT_RGBA8)
			shapes.set_texture_override(ImageTexture.create_from_image(image))
	print("SMOKE_AB_STYLE ",smoke_style)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main)
	main.persistent_day_state=main._create_initial_state(); main.persistent_day_state["tutorial_completed"]=true
	seed(120); main._show_dream("basic")
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		await RenderingServer.frame_post_draw
		if is_instance_valid(main._supported_dream_world): world=main._supported_dream_world
		if is_instance_valid(world) and not main.transition_running and not world.floor_transition_in_progress: break
	check(is_instance_valid(world) and not main.transition_running,"Actual Main entry is ready")
	if not is_instance_valid(world): quit(1); return
	var time_controller: Node=root.get_node_or_null("DreamTimeController")
	if time_controller!=null: time_controller.set_process(false)
	Engine.time_scale=1
	if not palette_on:
		# Runtime-only display toggle: SettingsManager persists to user://, so it is
		# never touched and the player's saved graphics settings stay intact.
		for node in root.find_children("*","",true,false):
			var script_path := String(node.get_script().resource_path) if node.get_script()!=null else ""
			if script_path.contains("selective_pixel_preview"): node.set_palette_enabled(false)
		# The unpaletted path can restore the native window size; keep both styles
		# on the exact same viewport so the crop lines up between runs.
		root.size=Vector2i(1920,1080)
	var origin:=Vector2.ZERO; var room_id:=-1
	for room in world.rooms:
		if String(room.get("archetype",""))!="open_office": continue
		for cell in room.get("usable_cells",[]):
			var point:=Vector2(cell)*32.0
			if world._content_position_is_clear(point,75.0): origin=point; room_id=int(room.id); break
		if room_id>=0: break
	check(room_id>=0,"A naturally generated clear office is used")
	if room_id<0: main.free(); quit(1); return
	world.activate_room(room_id)
	for enemy in world.enemy_root.get_children():
		enemy.process_mode=Node.PROCESS_MODE_DISABLED
		if enemy is CollisionObject2D: enemy.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		var hurtbox: Variant=enemy.get("hurtbox")
		if hurtbox is CollisionObject2D: hurtbox.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	world.player.global_position=origin+Vector2(-45,48)
	world.player.invulnerability_left=10000
	world.player.set_attacking_enabled(false)
	for offset in [Vector2(-25,-38),Vector2(20,-12),Vector2(62,-45)]:
		var enemy: Node=world._spawn_regular_employee(room_id,origin+offset,&"employee",false,"basic")
		enemy.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.hurtbox.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		enemy.process_mode=Node.PROCESS_MODE_DISABLED
		enemy.sky_drop_active=false; enemy.sky_drop_height=0; enemy.knockdown_height=0
		enemy.set_room_runtime_active(true); enemy.set_player_vision_visible(true)
		actors.append(enemy)
	walkers=Walkers.new(); world.add_child(walkers); walkers.actors=actors
	await wait(.7)
	smoke=world.floor_root.get_node("FootstepSmoke")
	if cluster_set: smoke.cluster=cluster
	if grow_set: smoke.grow_time=grow
	if fade_set: smoke.fade_start=fade_start
	if not cluster_variants.is_empty():
		smoke.variants=cluster_variants
		smoke.variant_pixel_size=variant_pixel_size
	check(smoke.get_child_count()==72,"Formal Main installs the bounded smoke pool")
	check(smoke.get_child_count()>0 and smoke.sprites[0].texture!=null,"Smoke carriers hold a texture")
	var expected_filter:=BaseMaterial3D.TEXTURE_FILTER_LINEAR if smoke_style.begins_with("soft") else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	check(smoke.sprites[0].texture_filter==expected_filter,"Smoke sampling matches the requested style")
	# Clip 1: player and enemies walking in the real gameplay camera.
	begin("walk_stop")
	walkers.running=true; world.player.set_scripted_locomotion(Vector2.RIGHT,70)
	await wait(.85)
	world.player.set_scripted_locomotion(Vector2.LEFT,70); await wait(.7)
	world.player.clear_scripted_locomotion(); walkers.running=false; await wait(.6)
	finish()
	check(smoke.emitted>6,"Movement produces visible smoke")
	# Clip 2: one real assault-rifle round into a real enemy hitbox.
	walkers.running=false
	for i in actors.size():
		actors[i].global_position=origin+Vector2(-45 if aim_side=="left" else 45,20+i*32)
		actors[i].current_health=1000; actors[i].set_physics_process(false)
	world.set_meta(&"debug_muzzle_aim",true)
	world.player.global_position=origin+Vector2(-50,20)
	var aim:=Vector2.LEFT if aim_side=="left" else Vector2.RIGHT
	world.player.set_meta(&"aim_direction_override",aim)
	# Diagnostics: compare where the aim points on screen with where the smoke goes.
	var cam: Camera3D=world.get("camera_3d")
	var aim_base: Vector3=world.get_gameplay_world_position(world.player.global_position,0.6)
	var aim_tip: Vector3=world.get_gameplay_world_position(world.player.global_position+aim*64.0,0.6)
	var aim_screen: Vector2=cam.unproject_position(aim_tip)-cam.unproject_position(aim_base)
	await wait(.5)
	# Warm-up shot. The first muzzle flash compiles shaders and stalls for about half
	# a second, which would otherwise swallow the orange head of the measured plume.
	await fire_assault(); await wait(1.4)
	if not ramp_override.is_empty():
		var mnode: Node=world.floor_root.get_node_or_null("MuzzleSmoke")
		if mnode!=null:
			var cols: Array=[]
			for hex_value in ramp_override: cols.append(Color(str(hex_value)))
			mnode.RAMP=cols
			print("RAMP_OVERRIDE ",ramp_override)
	begin("fire_assault_rifle")
	var before: float=actors[0].current_health
	await fire_assault(); await wait(.1)
	var muzzle_node: Node=world.floor_root.get_node_or_null("MuzzleSmoke")
	var smoke_screen: Vector2=Vector2.ZERO
	var counted:=0
	if muzzle_node!=null:
		var white_sum:=Vector3.ZERO; var colour_sum:=Vector3.ZERO
		var whites:=0; var colours:=0
		for puff in muzzle_node.puffs:
			if bool(puff.get("white",false)):
				white_sum+=puff["origin"]; whites+=1
			else:
				colour_sum+=puff["origin"]; colours+=1
		counted=colours
		if whites>0 and colours>0:
			var muzzle_proxy: Vector3=white_sum/float(whites)
			var colour_centre: Vector3=colour_sum/float(colours)
			smoke_screen=cam.unproject_position(colour_centre)-cam.unproject_position(muzzle_proxy)
			var ref_right: Vector3=world.get_gameplay_world_position(world.player.global_position+Vector2.RIGHT*64.0,0.6)
			var right_screen: Vector2=cam.unproject_position(ref_right)-cam.unproject_position(aim_base)
			print("AIM_DOT vs_left=",aim_screen.normalized().dot(smoke_screen.normalized())," vs_right=",right_screen.normalized().dot(smoke_screen.normalized()))
	print("AIM_DIAG aim=",aim," aim_screen=",aim_screen.normalized()," smoke_screen=",smoke_screen.normalized()," puffs=",counted)
	# How big does the overlay actually draw? A puff that lands at a few pixels is
	# invisible however correct its colours are, so measure the projection scale.
	if muzzle_node!=null:
		var probe: Vector3=aim_base
		var unit: float=cam.unproject_position(probe+cam.global_transform.basis.x).distance_to(cam.unproject_position(probe))
		var scales: Array[float]=[]
		var visible_px: Array[float]=[]
		for puff in muzzle_node.puffs:
			var s: Node2D=muzzle_node.fills[int(puff["slot"])]
			if not s.visible: continue
			scales.append(s.scale.x)
			visible_px.append(s.scale.x*float(s.texture.get_width()))
		if not scales.is_empty():
			print("MUZZLE_SCALE pixels_per_unit=",unit," scale_min=%.3f scale_max=%.3f px_min=%.1f px_max=%.1f"%[scales.min(),scales.max(),visible_px.min(),visible_px.max()])
		# Lifetime guard. SelectivePixelPreview reparents every CanvasLayer it finds
		# inside the world onto the root canvas unless it carries world_post_effect.
		# A reparented overlay outlives the world, which is what left the last plume
		# frozen on screen at the end of a run and stale at the start of the next one.
		var ov: CanvasLayer=muzzle_node.overlay
		var in_world: bool=world.is_ancestor_of(ov)
		print("MUZZLE_OVERLAY layer=",ov.layer," parent=",ov.get_parent().name,
			" world_post_effect=",bool(ov.get_meta(&"world_post_effect",false)),
			" in_world=",in_world,
			" custom_viewport=",ov.custom_viewport.name if ov.custom_viewport!=null else "NONE",
			" viewport_size=",cam.get_viewport().size)
		check(in_world,"Muzzle overlay stays inside the world so it dies with the run")
		check(bool(ov.get_meta(&"world_post_effect",false)),"Muzzle overlay is flagged so the preview never reparents it")
		check(ov.get_viewport()==cam.get_viewport(),"Muzzle overlay draws into the world viewport, above the palette pass")
	await wait(.7)
	finish()
	check(is_instance_valid(actors[0]) and actors[0].current_health<before,"A real projectile lands a nonlethal hit")
	var report:={"checks":checks,"failures":failures,"clips":clips,"smoke_style":smoke_style,"palette_on":palette_on,"cluster":cluster,"fade_start":fade_start,"puff_trace":puff_trace,
		"room_id":room_id,"origin":origin,"gpu":RenderingServer.get_video_adapter_name(),
		"smoke_texture_size":smoke.sprites[0].texture.get_size(),
		"scope":"Real Main entry, real generated office, real gameplay camera, minimized background GPU. Only the smoke texture style differs between runs."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SMOKE_AB_CAPTURE ",JSON.stringify({"checks":checks,"failures":failures,"clips":clips.keys(),"emitted":smoke.emitted,"room_id":room_id}))
	main.free(); quit(1 if failures.size() else 0)
