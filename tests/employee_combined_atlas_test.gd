extends SceneTree
const ART=preload("res://art/Dream/enemy/Employee_men_32x32.png")
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
	check(not enemy.body.visible and enemy.head.visible,"live enemy draws one upper body without old torso")
	check(enemy.head.position==Vector2(-16,-17) and enemy.left_hand.position.y==6,"new upper body and hands match assembled reference anchors")
	check(enemy.left_leg.position==Vector2(-5,-9) and enemy.right_leg.position==Vector2(0,-9),"foot sockets stay aligned with authored legs")
	enemy.configure_archetype(&"waitress")
	check(enemy.body.visible and not enemy.combined_upper_body,"waitress retains its separate torso")
	check((enemy.head.texture as AtlasTexture).region==Rect2(32,0,28,32) and (enemy.body.texture as AtlasTexture).region==Rect2(64,0,32,32),"waitress retains its previous atlas regions")
	check(enemy.head.position==Vector2(-16,-20) and enemy.body.position==Vector2(-16,-8) and enemy.left_hand.position.y==7,"waitress retains original rig positions after post-ready configuration")
	enemy.configure_archetype(&"employee")
	check(not enemy.body.visible and enemy.head_base_position==Vector2(-16,-17) and enemy.body_base_position==Vector2(-16,6),"switching back refreshes animation bases and combined torso visibility")
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
	arena.queue_free(); await process_frame; await process_frame
	print("EMPLOYEE_COMBINED checks=",checks," failures=",failures)
	quit(1 if failures else 0)
