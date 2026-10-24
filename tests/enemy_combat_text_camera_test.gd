extends SceneTree
const OUT="res://.runtime/enemy_combat_text_20261023"
var main: Node
var world: Node
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=2) -> void:
	for i in n: await process_frame
func settle() -> void:
	while main.transition_running: await process_frame
	await frames(12)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
func red_pixels(image: Image,area: Rect2i) -> int:
	var count:=0
	for y in range(maxi(0,area.position.y),mini(image.get_height(),area.end.y)):
		for x in range(maxi(0,area.position.x),mini(image.get_width(),area.end.x)):
			var c:=image.get_pixel(x,y)
			if c.r>.65 and c.g<.35 and c.b<.35: count+=1
	return count
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
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await settle()
	main.persistent_day_state=main._create_initial_state(); main._show_dream("basic"); await settle()
	world=main._supported_dream_world
	while world.floor_transition_in_progress: await process_frame
	for enemy in world.enemy_root.get_children(): enemy.set_physics_process(false)
	world.player.set_physics_process(false); world.player.critical_chance=0
	world.player.run_damage_multiplier=1; world.player.critical_damage_multiplier=2
	var enemy: Node=world._spawn_regular_employee(world.current_room_id,world.player.global_position+Vector2(38,-12),&"employee",false,"luger")
	enemy.maximum_health=1000; enemy.current_health=1000; enemy.set_physics_process(false); enemy.set_process(false)
	var fx: Node=world.floor_root.get_node("EnemyCombatText"); fx.set_process(false)
	var id:=enemy.get_instance_id()
	await frames(12)
	check(fx.layer.get_viewport()==root,"Production damage lettering renders in native clear HUD outside palette")
	world.resolve_player_hit(enemy,10,world.player.global_position,&"player_projectile_rifle")
	for i in 96:
		if i==8: world.resolve_player_hit(enemy,10,world.player.global_position,&"books")
		if i==17:
			world.player.critical_chance=1
			world.resolve_player_hit(enemy,20,world.player.global_position,&"player_projectile_rifle")
			world.player.critical_chance=0
		if i==29: world.resolve_player_hit(enemy,5,world.player.global_position,&"player_punch")
		if i==40: world.resolve_player_hit(enemy,2000,world.player.global_position,&"books")
		fx._process(.02)
		await frames(1); await shot("motion_%03d" % i)
		if i==25:
			check(fx.records.size()==1 and fx.records[id].text=="60","Formal camera sequence accumulates normal, melee and critical hits into one number")
			var canvas: Control=fx.critical_surfaces[id]
			var material: Material=canvas.material
			await RenderingServer.frame_post_draw
			var after: Image=root.get_texture().get_image()
			canvas.material=null; await frames(2); await RenderingServer.frame_post_draw
			var before: Image=root.get_texture().get_image()
			var position: Vector2=fx._screen_position(fx.records[id])+Vector2(0,-24)
			var scale: Vector2=Vector2(after.get_size())/root.get_visible_rect().size
			var area:=Rect2i((position-Vector2(36,32))*scale,Vector2(72,45)*scale)
			var red_before:=red_pixels(before,area); var red_after:=red_pixels(after,area)
			print("COMIC_CRITICAL_PIXELS before=",red_before," after=",red_after)
			check(red_after>red_before+15,"Final rendered critical glyph contains red halftone pixels with Palette 1 enabled")
			canvas.material=material; await frames(2); await shot("critical")
		if i==46:
			check(fx.records[id].killed and fx.records[id].text in fx.KILL_WORDS,"Formal lethal hit replaces number with readable praise")
			await shot("kill")
	check(fx.records.is_empty() and fx.critical_surfaces.is_empty() and not fx.layer.visible,"All text and halftone resources retire after capture")
	settings.set_setting(&"pixelation_enabled",false); settings.set_palette_enabled(false)
	var other: Node=world._spawn_regular_employee(world.current_room_id,world.player.global_position+Vector2(20,15),&"employee",false,"luger")
	other.maximum_health=100; other.current_health=100; other.set_physics_process(false); other.set_process(false)
	world.player.critical_chance=1; world.resolve_player_hit(other,5,world.player.global_position)
	fx._process(.12); await frames(3); await shot("native")
	check(fx.records.size()==1,"Same text also runs with both visual filters disabled")
	fx.clear(); main.free(); await frames(3)
	print("ENEMY_COMBAT_TEXT_CAMERA checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
