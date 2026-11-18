extends SceneTree
const ART=preload("res://art/Dream/enemy/Employee_men_32x32.png")
const WAITRESS=preload("res://art/Dream/enemy/waitress.png")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var arena:=Node2D.new(); root.add_child(arena)
	var enemy=load("res://scenes/entities/employee_enemy.tscn").instantiate(); arena.add_child(enemy)
	enemy.set_physics_process(false); enemy.set_process(false)
	var origin: Vector2=enemy.position
	var collider: Vector2=enemy.body_collision.position
	var atlas: Image=ART.get_image()
	for i in 3:
		enemy._set_enemy_head_frame(i)
		check(enemy.head.texture.get_image().get_data()==atlas.get_region(Rect2i(32,i*32,32,32)).get_data(),"live frame %d uses every authored upper-body pixel"%i)
	var back_pixels := atlas.get_region(Rect2i(64, 32, 32, 32)).get_data()
	enemy._apply_live_facing(Vector2.UP)
	for i in 3:
		enemy._set_enemy_head_frame(i)
		check(enemy.head.texture.get_image().get_data() == back_pixels, "back-facing pose keeps the authored pixels during blinking")
	enemy._apply_live_facing(Vector2.DOWN)
	check((enemy.head.texture as AtlasTexture).region == Rect2(32, 64, 32, 32), "turning front restores the selected front frame")
	check(not enemy.body.visible and enemy.head.visible,"live enemy draws one upper body without old torso")
	check(enemy.head.position==Vector2(-16,-17) and enemy.left_hand_base_position.y==6,"new upper body and hands match assembled reference anchors")
	check(enemy.left_leg.position==Vector2(-5,-9) and enemy.right_leg.position==Vector2(0,-9),"foot sockets stay aligned with authored legs")
	enemy.configure_archetype(&"waitress")
	enemy._apply_live_facing(Vector2.UP)
	var waitress_pixels:=WAITRESS.get_image()
	check(not enemy.body.visible and enemy.combined_upper_body,"waitress draws the combined upper body once")
	for frame in 3:
		enemy._set_enemy_head_frame(frame)
		check(enemy.head.texture.get_image().get_data()==waitress_pixels.get_region(Rect2i(64,0,32,32)).get_data(),"waitress blinking preserves the authored back "+str(frame))
	check(enemy.head.offset==Vector2(-3,0) and enemy.body.offset==enemy.head.offset,"rear hem registration also applies to the ragdoll torso")
	enemy._apply_live_facing(Vector2.DOWN)
	for frame in 3:
		enemy._set_enemy_head_frame(frame)
		check(enemy.head.texture.get_image().get_data()==waitress_pixels.get_region(Rect2i(32,frame*32,32,32)).get_data(),"waitress uses every authored front and blink pixel "+str(frame))
	check(enemy.head.offset==Vector2.ZERO and enemy.head.position==Vector2(-16,-17) and enemy.body.position==Vector2(-16,6),"front restores the combined upper-body registration")
	check(enemy.left_leg.position==Vector2(-6,-6) and enemy.right_leg.position==Vector2(-1,-6) and enemy.left_leg_base_position==enemy.left_leg.position and enemy.right_leg_base_position==enemy.right_leg.position,"post-ready waitress configuration refreshes both foot anchors")
	for spec in [[enemy.left_leg,Rect2i(108,76,4,9)],[enemy.right_leg,Rect2i(113,76,4,9)],[enemy.left_hand,Rect2i(102,47,5,4)],[enemy.right_hand,Rect2i(117,47,5,4)]]:
		check(spec[0].texture.get_image().get_data()==waitress_pixels.get_region(spec[1]).get_data(),"waitress limb uses its new authored cell "+str(spec[1]))
	enemy._apply_live_facing(Vector2.UP)
	enemy.configure_archetype(&"employee")
	check(not enemy.body.visible and enemy.head_base_position==Vector2(-16,-17) and enemy.body_base_position==Vector2(-16,6),"switching back refreshes animation bases and combined torso visibility")
	check(enemy.head.offset==Vector2.ZERO and enemy.left_leg_base_position==Vector2(-5,-9) and enemy.right_leg_base_position==Vector2(0,-9),"switching back restores the employee rear registration and foot sockets")
	enemy.velocity=Vector2(80,0)
	var walking_correct:=true
	for i in 30:
		enemy._update_human_animation(1./60.)
		walking_correct=walking_correct and not enemy.body.visible and (enemy.head.texture as AtlasTexture).region.size==Vector2(32,32)
	check(walking_correct,"walking never redraws a duplicate or cropped live upper body")
	check(enemy.position==origin and enemy.body_collision.position==collider,"visual update changes no collision or actor origin")
	enemy._die(); enemy.set_physics_process(false); enemy.set_process(false)
	check(enemy.dead and enemy.ragdoll_active and enemy.corpse_upper_parts_active,"real death path prepares existing ragdoll from new pixels")
	check(enemy.body.visible and not enemy.get_meta(&"character_combined_upper_body"),"death enables the real torso socket and restores corpse semantic lookup")
	var stitched:=Image.create(32,32,false,Image.FORMAT_RGBA8)
	stitched.blit_rect(enemy.head.texture.get_image(),Rect2i(0,0,32,23),Vector2i.ZERO)
	stitched.blit_rect(enemy.body.texture.get_image(),Rect2i(0,0,32,9),Vector2i(0,23))
	check(stitched.get_data()==atlas.get_region(Rect2i(32,64,32,32)).get_data(),"head and torso death crops reconstruct the exact closed-eye cell with no duplicate or missing pixels")
	enemy._set_back_facing(true); enemy._update_enemy_blink(.1)
	check((enemy.head.texture as AtlasTexture).region==Rect2(32,64,32,23),"corpse callbacks retain closed eyes and never restore combined body")
	for i in 12: enemy._update_death_presentation(1./60.)
	check(enemy.head.position.is_finite() and enemy.body.position==enemy.body_base_position,"ragdoll keeps a valid neck and torso transform")
	var rear := load("res://scenes/entities/employee_enemy.tscn").instantiate() as EmployeeEnemy
	arena.add_child(rear)
	rear._apply_live_facing(Vector2.UP)
	rear._die()
	rear.set_physics_process(false)
	rear.set_process(false)
	rear._set_back_facing(false)
	rear._update_enemy_blink(.1)
	check(rear.head.texture.get_image().get_data() == atlas.get_region(Rect2i(64, 32, 32, 23)).get_data()
		and rear.body.texture.get_image().get_data() == atlas.get_region(Rect2i(64, 55, 32, 9)).get_data(),
		"the rear ragdoll preserves the back head and torso through later callbacks")
	for back: bool in [false,true]:
		var waitress:=load("res://scenes/entities/employee_enemy.tscn").instantiate() as EmployeeEnemy
		arena.add_child(waitress)
		waitress.configure_archetype(&"waitress")
		waitress._apply_live_facing(Vector2.UP if back else Vector2.DOWN)
		waitress._die()
		waitress.set_physics_process(false)
		waitress.set_process(false)
		waitress._set_back_facing(not back)
		waitress._update_enemy_blink(.1)
		var expected:=Rect2i(64,0,32,32) if back else Rect2i(32,64,32,32)
		var whole:=Image.create(32,32,false,Image.FORMAT_RGBA8)
		whole.blit_rect(waitress.head.texture.get_image(),Rect2i(0,0,32,23),Vector2i.ZERO)
		whole.blit_rect(waitress.body.texture.get_image(),Rect2i(0,0,32,9),Vector2i(0,23))
		check(waitress.dead and waitress.corpse_upper_parts_active and whole.get_data()==waitress_pixels.get_region(expected).get_data(),"waitress death reconstructs the original upper cell, rear="+str(back))
		check(waitress.head.offset==waitress.body.offset and waitress.head.offset==(Vector2(-3,0) if back else Vector2.ZERO),"waitress death preserves rear registration, rear="+str(back))
	EmployeeEnemy.SFX.stop_event(&"enemy_kill")
	arena.queue_free(); await process_frame; await process_frame
	await create_timer(.12).timeout
	print("EMPLOYEE_COMBINED checks=",checks," failures=",failures)
	quit(1 if failures else 0)
