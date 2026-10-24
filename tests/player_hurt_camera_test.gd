extends SceneTree
const OUT="res://.runtime/player_hurt_20261023"
var main: Node
var world: Node
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=6) -> void:
	for i in n: await process_frame
func settle() -> void:
	var deadline:=Time.get_ticks_msec()+90000
	while main.transition_running and Time.get_ticks_msec()<deadline: await process_frame
	await frames(12)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func image_metrics(before: Image,after: Image) -> Dictionary:
	var difference:=0.0
	var edge_before:=0.0
	var edge_after:=0.0
	var samples:=0
	var edges:=0
	var fringe_before:=0
	var fringe_after:=0
	for y in range(0,before.get_height(),2):
		for x in range(0,before.get_width(),2):
			var a:=before.get_pixel(x,y); var b:=after.get_pixel(x,y)
			difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b); samples+=1
			if a.r>a.b+.04 and a.r>a.g+.04 or a.g>a.b+.04 and a.g>a.r+.04: fringe_before+=1
			if b.r>b.b+.04 and b.r>b.g+.04 or b.g>b.b+.04 and b.g>b.r+.04: fringe_after+=1
			if x<before.get_width()*.15 or x>before.get_width()*.85 or y<before.get_height()*.15 or y>before.get_height()*.85:
				edge_before+=a.r+a.g+a.b; edge_after+=b.r+b.g+b.b; edges+=1
	return {"mean_difference":difference/maxi(1,samples*3),"edge_ratio":edge_after/maxf(.001,edge_before),"fringe_before":fringe_before,"fringe_after":fringe_after}
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: quit(2))
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().replace("\\","/").contains("/.runtime/"): quit(2); return
	preload("res://tests/support/background_gpu.gd").start(self)
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(1280,720); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var settings:=root.get_node("SettingsManager")
	settings.set_setting(&"pixelation_enabled",true); settings.set_palette_enabled(true)
	settings.set_setting(&"screen_shake_enabled",true)
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main._show_reception("basic"); await settle()
	world=main._supported_dream_world
	world.player.set_physics_process(false); world.player.global_position=world.RECEPTION_DESK_POS_2D+Vector2(0,45)
	await frames(18); await shot("npc_near")
	check(world.npc_hint_bubble.visible and world.interaction_prompt.text=="交流","Near NPC shows tracked emotion and talk prompt")
	world.player.global_position=world.waitress_npc.global_position+Vector2(130,100)
	await frames(20); await shot("npc_far")
	check(not world.npc_hint_bubble.visible and not world.interaction_prompt.visible,"Leaving actual range hides both widgets")
	main._show_dream("basic"); await settle(); world=main._supported_dream_world
	while world.floor_transition_in_progress: await process_frame
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	world.player.set_physics_process(false); world.player.maximum_health=1000; world.player.current_health=1000
	world.player.invulnerability_left=0; world.player.dash_invulnerability_left=0; world.player.has_shield=false
	var fx: Node=world.floor_root.get_node("PlayerHurtPresentation")
	fx.set_process(false)
	world._update_camera_and_actor_projection(0.0); await frames(6); await shot("before")
	world.player.receive_damage(5,&"enemy_projectile",world.player.global_position-Vector2(50,0),Vector2.RIGHT)
	check(fx.emitted==1 and world.player.current_health==995,"Actual damage produces one formal effect")
	check(fx.post_layer.get_viewport()==world.get_viewport() and fx.layer.get_viewport()==root,"Color split stays in world viewport, words stay in crisp HUD")
	world.player._update_visual_feedback(); world.player_depth_bridge._process(0)
	world.set_process(false)
	var probe_layer:=CanvasLayer.new(); probe_layer.layer=99; root.add_child(probe_layer)
	var probe:=ColorRect.new(); probe.position=Vector2(12,12); probe.size=Vector2(12,12); probe.color=Color("28bf65"); probe_layer.add_child(probe)
	fx.post_rect.hide(); fx.post_copy.copy_mode=BackBufferCopy.COPY_MODE_DISABLED
	await frames(2); await RenderingServer.frame_post_draw
	var before_world: Image=world.get_viewport().get_texture().get_image()
	var before_hud: Image=root.get_texture().get_image()
	before_world.save_png(OUT+"/shock_off.png")
	fx._update_pose(); await frames(2); await RenderingServer.frame_post_draw
	var after_world: Image=world.get_viewport().get_texture().get_image()
	var after_hud: Image=root.get_texture().get_image()
	after_world.save_png(OUT+"/shock_on.png")
	var metrics:=image_metrics(before_world,after_world)
	print("HURT_PIXEL_METRICS ",JSON.stringify(metrics))
	check(metrics.mean_difference>.004,"Final world pixels visibly differ with shock enabled, not just its uniforms")
	check(metrics.edge_ratio<.95,"Final post-palette frame visibly darkens at its edges")
	check(metrics.fringe_after>metrics.fringe_before+20,"RGB fringes survive palette rather than being quantized back to blue")
	var probe_pixel:=Vector2i(Vector2(18,18)*Vector2(before_hud.get_size())/root.get_visible_rect().size)
	check(before_hud.get_pixelv(probe_pixel).is_equal_approx(after_hud.get_pixelv(probe_pixel)),"Native HUD color remains exactly unchanged by world shock")
	probe_layer.free()
	await frames(1); await shot("flash")
	check(world.player_depth_bridge.lit_material.get_shader_parameter("hurt_flash_amount")==1.0,"Actual player material enables white flash")
	fx._process(.1); await frames(1); await shot("stars_words")
	check(fx.phrase in fx.WORDS and fx.stars.size()==6,"Formal camera has Chinese word and six stars")
	fx._process(.2); await frames(1); await shot("recover")
	check(world.player.visual.scale.is_equal_approx(Vector2.ONE*world.player.character_visual_scale),"Character squash recovers")
	settings.set_setting(&"screen_shake_enabled",false); fx.age=0; fx._update_pose()
	check(fx.shock.get_shader_parameter("distort_strength")==0.0,"Disabled screen shake also disables visual warp")
	fx.clear()
	settings.set_setting(&"screen_shake_enabled",true)
	world.set_process(true)
	world.player.invulnerability_left=0; world.player.dash_invulnerability_left=0
	world.player.receive_damage(5,&"enemy_projectile",world.player.global_position-Vector2(50,0),Vector2.RIGHT)
	world.player.dash_invulnerability_left=10
	var birth: Vector3=fx.bursts[0].origin
	var start: Vector2=world.player.global_position
	var action: StringName=&"move_right"
	for entry in [[&"move_right",Vector2.RIGHT],[&"move_left",Vector2.LEFT],[&"move_down",Vector2.DOWN],[&"move_up",Vector2.UP]]:
		if not world.player.test_move(world.player.global_transform,entry[1]*80): action=entry[0]; break
	world.player.set_physics_process(true); Input.action_press(action)
	# Actual movement input with deterministic 20 ms effect steps. Not an FPS benchmark.
	for i in 45:
		fx._process(.02)
		await frames(1); await shot("motion_%02d" % i)
		if i==10:
			check(fx.bursts.size()>0 and fx.bursts[0].origin==birth,"Actual walking leaves words and stars at recorded impact origin")
	Input.action_release(action); world.player.set_physics_process(false)
	check(world.player.global_position.distance_to(start)>16,"Recording contains actual player movement away from impact")
	check(not fx.layer.visible and not fx.post_rect.visible,"Recorded feedback retires completely")
	settings.set_setting(&"pixelation_enabled",false); settings.set_palette_enabled(false)
	await frames(4); fx._on_damage(1); fx._process(.12); await frames(1); await shot("native")
	fx.clear(); main.free(); await frames(3)
	print("PLAYER_HURT_CAMERA checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
