extends SceneTree
## Actual Main/tutorial Camera plus real player bridge, not a substitute sprite.
var OUT:="res://.runtime/player_eight_facing_20261030"
const ATLAS=preload("res://scripts/data/player_character_atlas.gd")
var checks:=0
var failures:=0
var main: Node
func _initialize() -> void: call_deferred("run")
func frames(n: int=4) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
	AudioServer.set_bus_mute(0,true)
	create_timer(120.,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(OUT+"/camera")
	main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(75)
	main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.resume(); await frames(140)
	var world: Node=main._supported_dream_world
	var actor: Node2D=world.player
	actor.position=Vector2(4,20)*32.; actor.set_physics_process(false)
	world.set_process(false); world._update_camera_and_projection(0.)
	actor.attacking_enabled=false; actor._update_hands_visibility()
	var bridge: Node=world.player_depth_bridge
	var hair: Node=actor.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
	hair.set_physics_process(false)
	var saved_position: Vector2=actor.position
	var collision_position: Vector2=actor.body_collision.position
	var marker_position: Vector2=actor.projectile_origin.position
	var rgba: Image=ATLAS.ART.get_image()
	check(rgba.get_size()==Vector2i(280,250),"new authored 280 by 250 canvas loads without resizing")
	check(not rgba.has_mipmaps(),"authored pixel atlas has no mipmaps")
	var expected: Array[Rect2]=[Rect2(192,0,32,32),Rect2(160,0,32,32),Rect2(128,0,32,32),Rect2(96,0,32,32),Rect2(64,0,32,32),Rect2(96,128,32,32),Rect2(128,128,32,32),Rect2(160,128,32,32)]
	var rendered_regions: Dictionary={}
	var assembled: Array[Image]=[]
	for index in 8:
		var wanted:=Vector2.from_angle(index*PI*.25)
		var origin: Vector3=bridge.actor_sprite.global_position
		var screen: Vector2=world.camera_3d.unproject_position(origin)
		var a: Vector3=world.camera_3d.project_ray_origin(screen+wanted*80.)
		var ray: Vector3=world.camera_3d.project_ray_normal(screen+wanted*80.)
		var target: Vector3=a+ray*((origin.y-a.y)/ray.y)
		var direction3: Vector3=world.global_basis.inverse()*(target-origin)
		var direction:=Vector2(direction3.x,direction3.z).normalized()
		actor.set_meta(&"aim_direction_override",direction)
		actor.idle_animation_time=0.; actor._update_direction_animation(Vector2.ZERO,0.)
		actor._set_player_head_frame(0); hair.step_actor(1./60.); bridge._process(0.)
		await frames(4); await RenderingServer.frame_post_draw
		check(actor.character_facing_index==index,"Camera screen direction chooses authored view %d"%index)
		check((actor.head_part.texture as AtlasTexture).region==expected[index],"view %d uses exact authored cell"%index)
		check(not actor.body_part.visible and actor.body_part.texture==null,"view %d has one combined upper body"%index)
		check(hair.visible,"view %d has the requested view-specific strand"%index)
		check(hair.z_index==(-1 if index in [0,5,6,7] else 1) and hair.overlay.z_index==hair.z_index,"view %d uses correct front/rear hair layer including healing overlay"%index)
		check(hair.position==[Vector2(10,14),Vector2(26,14),Vector2(23,14),Vector2(20,14),Vector2(14,14),Vector2(25,15),Vector2(24,15),Vector2(22,15)][index],"view %d has its own authored attachment"%index)
		if index in [1,5,6,7]:
			check(hair.position.x>16 and hair.scale.x>0,"view %d keeps its strand on the requested right-hand side instead of mirroring to the left"%index)
		var copy: Node=bridge.render_root.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
		check(copy.z_index==hair.z_index,"view %d retains hair layer in the real GPU capture"%index)
		var foot: AtlasTexture=actor.left_leg.texture
		check(foot.region==Rect2(43,140 if index in [5,6,7] else 76,4,9),"view %d uses correct front/rear legs"%index)
		var foot_shift: int=[3,3,0,0,0,3,2,0][index]
		check(actor.left_leg.position==Vector2(-6+foot_shift,-9) and actor.right_leg.position==Vector2(-1+foot_shift,-9),"view %d feet use the correct non-accumulating attachment"%index)
		var hem_image: Image=actor.head_part.texture.get_image()
		var hem_left:=32; var hem_right:=-1
		for x in 32:
			if hem_image.get_pixel(x,28).a>.99: hem_left=mini(hem_left,x); hem_right=maxi(hem_right,x)
		var feet_centre: float=(actor.left_leg.position.x+actor.right_leg.position.x+4.)*.5-actor.head_base_position.x
		check(absf(feet_centre-(hem_left+hem_right+1.)*.5)<=1.,"view %d leg centre aligns with the actual painted lower body"%index)
		check(actor.heal_overlay.get_node("LeftFoot").position==actor.left_leg.position and actor.heal_overlay.get_node("RightFoot").position==actor.right_leg.position,"view %d healing feet share the corrected anchors"%index)
		if index==3:
			var assembled_root: Vector2i=Vector2i(actor.body_base_position+actor.head_base_position+hair.position+Vector2(-1,0)+Vector2(16,32))
			var agrees:=true
			for y in 3:
				for x in 4:
					var pixel:=rgba.get_pixel(46+x,43+y)
					if pixel.a>.0 and pixel!=rgba.get_pixel(assembled_root.x+x,assembled_root.y+y): agrees=false
			check(agrees and assembled_root==Vector2i(19,13),"DL fringe root pixels match the artist's assembled reference exactly")
		if index==1:
			# Check the common idle pose after the existing spring has settled.
			for tick in 360: hair.step_actor(1./60.)
			bridge._process(0.); await frames(3); await RenderingServer.frame_post_draw
		var texture: AtlasTexture=actor.head_part.texture
		rendered_regions[str(texture.region)]=true
		var frame: Image=bridge.render_viewport.get_texture().get_image()
		frame.save_png(OUT+"/camera/capture_%d.png"%index)
		if index==1:
			frame.save_png(OUT+"/camera/idle_after.png")
			hair.visible=false; hair.overlay.visible=false; bridge._process(0.)
			await frames(3); await RenderingServer.frame_post_draw
			var eye_reference: Image=bridge.render_viewport.get_texture().get_image()
			var eye_head: Sprite2D=bridge.render_root.get_node("CharacterVisual/BodyPivot/Head")
			var eye_changes:=0
			for y in range(14,20):
				for x in range(8,25):
					var pixel:=Vector2i(eye_head.to_global(Vector2(x+.5,y+.5)))
					if frame.get_pixelv(pixel)!=eye_reference.get_pixelv(pixel): eye_changes+=1
			check(eye_changes==0,"down-right idle strand leaves the entire eye region unchanged")
			# Same real rig/Camera with the previous attachment for direct review.
			hair.visible=true; hair.overlay.visible=true
			hair.position=Vector2(24,14); hair.overlay.transform=hair.transform; bridge._process(0.)
			await frames(3); await RenderingServer.frame_post_draw
			bridge.render_viewport.get_texture().get_image().save_png(OUT+"/camera/idle_before.png")
			hair.step_actor(1./60.); bridge._process(0.)
			await frames(3); await RenderingServer.frame_post_draw
		if index in [0,5,6,7]:
			hair.visible=false; hair.overlay.visible=false; bridge._process(0.)
			await frames(3); await RenderingServer.frame_post_draw
			var without: Image=bridge.render_viewport.get_texture().get_image()
			var head_copy: Sprite2D=bridge.render_root.get_node("CharacterVisual/BodyPivot/Head")
			var head_image: Image=head_copy.texture.get_image()
			var covered_changes:=0
			for y in 32:
				for x in 32:
					if head_image.get_pixel(x,y).a<.99: continue
					var pixel:=Vector2i(head_copy.to_global(Vector2(x+.5,y+.5)))
					if frame.get_pixelv(pixel)!=without.get_pixelv(pixel): covered_changes+=1
			var visible_tip:=0
			for y in frame.get_height():
				for x in frame.get_width():
					if frame.get_pixel(x,y)!=without.get_pixel(x,y): visible_tip+=1
			check(covered_changes==0,"view %d rear strand cannot paint over opaque head/face pixels"%index)
			check(visible_tip>2,"view %d rear strand still exposes a real tip outside the head"%index)
			hair.visible=true; hair.overlay.visible=true; bridge._process(0.)
			await frames(3); await RenderingServer.frame_post_draw
		var target_point: Vector2=world.camera_3d.unproject_position(bridge.actor_sprite.global_position)
		var image: Image=world.camera_3d.get_viewport().get_texture().get_image()
		image.save_png(OUT+"/camera/world_%d.png"%index)
		# Also retain a nearest-neighbour crop of the actual world Camera.
		var crop:=Rect2i(Vector2i(target_point)-Vector2i(32,8),Vector2i(64,64))
		if Rect2i(Vector2i.ZERO,image.get_size()).encloses(crop):
			image.get_region(crop).save_png(OUT+"/camera/world_actor_%d.png"%index)
		for blink in 3:
			actor._set_player_head_frame(blink)
			check((actor.head_part.texture as AtlasTexture).region==ATLAS.upper_region(index,blink),"view %d blink %d keeps head and torso in same cell"%[index,blink])
	check(rendered_regions.size()==8,"all eight views are distinct authored images")
	check(actor.visual.scale.x>0.,"right-facing art is not mirrored from left-facing art")
	check(actor.position==saved_position and actor.body_collision.position==collision_position and actor.projectile_origin.position==marker_position,"rerig changes no gameplay origin collision or muzzle marker")
	check((hair.get_node("Strand").texture as AtlasTexture).region==Rect2(46,43,4,11),"curved fringe uses relocated second-column pixels")
	check(hair.z_index==-1 and hair.overlay.z_index==-1,"last rear view keeps the same behind-head order in the healing overlay")
	var hit_point: Vector3=bridge.get_hit_feedback_world_position()
	check(hit_point.is_finite(),"hit feedback keeps a valid torso point with hidden old Body sprite")
	# Real actor's gait and facing, held at a clear tutorial spot for comparison.
	DirAccess.make_dir_recursive_absolute(OUT+"/walk")
	var timeline: Array=[]
	var previous:=Time.get_ticks_usec()
	var gait_centres_correct:=true
	for step in 128:
		var index:=int(step/16)
		var wanted:=Vector2.from_angle(index*PI*.25)
		var point: Vector3=bridge.actor_sprite.global_position
		var screen: Vector2=world.camera_3d.unproject_position(point)+wanted*80.
		var ray_origin: Vector3=world.camera_3d.project_ray_origin(screen)
		var ray: Vector3=world.camera_3d.project_ray_normal(screen)
		var target: Vector3=ray_origin+ray*((point.y-ray_origin.y)/ray.y)
		var map: Vector3=world.global_basis.inverse()*(target-point)
		var motion:=Vector2(map.x,map.z).normalized()
		actor.set_meta(&"aim_direction_override",motion)
		await create_timer(1./30.,true,false,true).timeout
		var now:=Time.get_ticks_usec()
		var dt: float=(now-previous)/1000000.; previous=now
		actor.velocity=motion*actor.movement_speed
		actor._update_direction_animation(motion,dt); hair.step_actor(dt); bridge._process(dt)
		gait_centres_correct=gait_centres_correct and absf((actor.left_leg.position.x+actor.right_leg.position.x-actor.left_leg_base_position.x-actor.right_leg_base_position.x)*.5)<.6
		await RenderingServer.frame_post_draw
		world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/walk/%03d.png"%step)
		timeline.append(Time.get_ticks_msec())
	actor.velocity=Vector2.ZERO; actor._update_direction_animation(Vector2.ZERO,.016)
	check(gait_centres_correct,"walking keeps both legs centred on each view rather than resetting to the old common anchor")
	check(actor.left_leg.position==actor.left_leg_base_position and actor.right_leg.position==actor.right_leg_base_position,"stopping returns both feet to the current view attachment")
	check(actor.position==saved_position,"gait preview never moves gameplay/collision origin")
	FileAccess.open(OUT+"/walk/times.json",FileAccess.WRITE).store_string(JSON.stringify(timeline))
	# Check armed presentation in the same real Camera.
	actor.attacking_enabled=true; actor.configure_weapon("basic",actor.runtime_config)
	actor._update_hands_visibility(); actor._update_held_weapon_aim(); bridge._process(0.)
	await frames(4); await RenderingServer.frame_post_draw
	check(actor.hand_presentation.grip_root.visible and not actor.left_hand_part.visible,"held weapon uses grip hands without a second pair")
	world.camera_3d.get_viewport().get_texture().get_image().save_png(OUT+"/camera/armed.png")
	# Follow the actual Main Tab entry in the reception room, including zoom.
	main._show_reception("basic"); await frames(100)
	var phone: Node=main.game_phone
	check(phone.can_open(),"formal reception phone entry is available")
	var tab:=InputEventKey.new(); tab.keycode=KEY_TAB; tab.physical_keycode=KEY_TAB; tab.pressed=true
	root.push_input(tab,true)
	DirAccess.make_dir_recursive_absolute(OUT+"/phone")
	var phone_times: Array=[]
	for step in 62:
		if step==48: root.push_input(tab.duplicate(),true)
		await create_timer(1./30.,true,false,true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"/phone/%03d.png"%step)
		phone_times.append(Time.get_ticks_msec())
		if step==30:
			check(phone.is_open() and paused,"Tab opens the real phone and pauses gameplay")
			check(phone.character_presentation.frame_index in [4,5],"original phone loop runs while world is paused")
			check(not main._supported_dream_world.player.body_pivot.visible,"phone hides the newly rigged upper body during use")
	await frames(24)
	check(not phone.is_open() and not paused,"second Tab restores input and pause state")
	check(main._supported_dream_world.player.body_pivot.visible and not main._supported_dream_world.player.body_part.visible,"closing restores combined upper body without old torso")
	FileAccess.open(OUT+"/phone/times.json",FileAccess.WRITE).store_string(JSON.stringify(phone_times))
	main.queue_free(); await frames(8)
	# The independent coast walker consumes the same atlas, including saved editor nodes.
	var coast: Node3D=load("res://scenes/preview/night_coast.tscn").instantiate()
	var viewport:=SubViewport.new(); viewport.size=Vector2i(640,360); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport); viewport.add_child(coast); coast.external_step=true
	await frames(6)
	coast.walker.elapsed=1.
	for index in 8:
		coast.walker.advance(.1,.1,Vector2.from_angle(index*PI*.25))
		check(coast.walker.head.region_rect==ATLAS.upper_region(index,0),"coast walker uses authored facing %d"%index)
		check(coast.walker.fringe.visible and not coast.walker.coat.visible,"coast has no duplicate hair or torso %d"%index)
		check(coast.walker.fringe.z_index==(-1 if index in [0,5,6,7] else 1),"coast view %d keeps front/back strand order"%index)
	coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0.,true)
	coast.walker.advance(.2,.2,Vector2(1,1)); await frames(4); await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT+"/camera/coast.png")
	viewport.queue_free(); await frames(6)
	FileAccess.open(OUT+"/camera/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"gpu":RenderingServer.get_video_adapter_name()},"\t"))
	print("PLAYER_EIGHT_CAMERA checks=",checks," failures=",failures)
	quit(1 if failures else 0)

