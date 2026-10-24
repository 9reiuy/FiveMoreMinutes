extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var player = load("res://scenes/entities/dream_player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var hair = player.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
	hair.set_physics_process(false)
	# Keep the legacy spring fallback covered after the approved curve rollout.
	hair.set_segmented_enabled(false)
	var overlay = player.get_node("HealOverlay/BodyPivot/Head/SideBangs")
	var sprite: Sprite2D = hair.get_node("Strand")
	check(sprite.texture.region==Rect2(142,43,4,11),"Artist row 2 column 5 cropped inside the correct cell")
	check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Pixel sampling preserved")
	hair.step(1.0/60.0,Vector2.ZERO,0,false,false,false,false)
	check(hair.position==Vector2(22,17),"Left-side root attached to head")
	hair.step(1.0/60.0,Vector2(290,0),0,false,false,false,false)
	check(hair.transform.basis_xform(Vector2(0,10)).x<0.0,"Rightward acceleration moves the actual tip left")
	for i in 20: hair.step(1.0/60.0,Vector2(290,0),0,false,false,false,false)
	check(absf(hair.bend)<=hair.MAX_ANGLE,"Strand bending stays bounded")
	var moving_bend: float = hair.bend
	hair.step(1.0/60.0,Vector2.ZERO,0,false,false,false,false)
	check(not is_equal_approx(hair.bend,moving_bend),"Stop produces visual recovery")
	for i in 180: hair.step(1.0/60.0,Vector2.ZERO,0,false,false,false,false)
	check(absf(hair.bend)<0.001,"Idle settles without perpetual twitching")
	check(is_equal_approx(hair.MAX_ANGLE*2.0,deg_to_rad(135.0)),"Downward swing fan spans exactly 135 degrees")
	for i in 120: hair.step(1.0/60.0,Vector2(290,0),0,false,false,false,false)
	check(absf(hair.bend)>deg_to_rad(35.0),"Normal movement produces a visible large swing, not just a larger cap")
	for i in 120: hair.step(1.0/30.0,Vector2(5000,0),0,false,false,false,false)
	check(is_equal_approx(hair.bend,hair.MAX_ANGLE),"Rightward motion is limited to positive 67.5 degrees")
	for i in 120: hair.step(1.0/30.0,Vector2(-5000,0),0,false,false,false,false)
	check(is_equal_approx(hair.bend,-hair.MAX_ANGLE),"Leftward motion is limited to negative 67.5 degrees")
	check(hair.position==Vector2(22,17),"Full-range swing never moves the root")
	for i in 240: hair.step(1.0/60.0,Vector2.ZERO,0,false,false,false,false)
	check(absf(hair.bend)<0.001 and absf(hair.bend_velocity)<0.001,"Large swing settles after stopping")
	hair.step(1.0/60.0,Vector2.ZERO,PI,true,false,false,false)
	check(hair.position==Vector2(10,17) and hair.scale.x==-1,"Right face mirrors attachment only")
	check(hair.transform==overlay.transform,"Heal visual follows the same spring")
	for i in 120: hair.step(1.0/60.0,Vector2(290,0),PI,true,false,false,false)
	check(hair.transform.basis_xform(Vector2(0,10)).x<0.0,"Right-facing mirrored hair also trails rightward movement")
	for i in 120: hair.step(1.0/60.0,Vector2(-290,0),PI,true,false,false,false)
	check(hair.transform.basis_xform(Vector2(0,10)).x>0.0,"Leftward movement makes the actual tip trail right")
	var before_stop: float = hair.bend_velocity
	hair.step(1.0/60.0,Vector2.ZERO,PI,true,false,false,false)
	check(hair.bend_velocity<before_stop,"Stopping leftward motion applies the reversed recovery impulse")
	hair.step(1.0/30.0,Vector2(5000,0),PI,true,false,true,false)
	check(absf(hair.bend)<=hair.MAX_ANGLE,"Roll does not detach the root")
	hair.step(1.0/60.0,Vector2.ZERO,0,false,true,false,false)
	check(not hair.visible and not overlay.visible,"Rear head uses its existing full hair")
	check(hair.get_parent() is Sprite2D,"Roll and fake height inherit head transform")
	var pivot: Node2D = player.get_node("CharacterVisual/BodyPivot")
	pivot.rotation=PI/2.0
	check(is_equal_approx(hair.global_rotation,pivot.global_rotation+hair.rotation),"Roll rotates head and attached root together")
	var before: Vector2 = hair.global_position
	player.visual.position.y-=8.0
	check(is_equal_approx(hair.global_position.y,before.y-8.0),"Fake height moves the attached strand with the head")
	check(hair.find_children("*","CollisionObject2D",true,false).is_empty() and hair.find_children("*","CollisionShape2D",true,false).is_empty(),"Hair visuals add no collision body or shape")
	player.queue_free()
	for i in 4: await process_frame
	print("SIDE_BANGS_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
