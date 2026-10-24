extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func fixed_lengths(hair:Node)->bool:
	for i in 3:
		if not is_equal_approx(hair.centerline[i].distance_to(hair.centerline[i+1]),hair.SECTION_LENGTHS[i]):return false
	return true
func run()->void:
	AudioServer.set_bus_mute(0,true)
	var player=load("res://scenes/entities/dream_player.tscn").instantiate();root.add_child(player)
	player.set_physics_process(false)
	var hair=player.get_node("CharacterVisual/BodyPivot/Head/SideBangs")
	hair.set_physics_process(false)
	check(hair.z_as_relative and hair.z_index>player.get_node("CharacterVisual/BodyPivot/Body").z_index,"Hair draws above clothing within the actor rather than changing world sorting")
	check(hair.segmented_enabled and is_instance_valid(hair.curve) and is_instance_valid(hair.overlay_curve),"Formal player initializes approved curve and healing overlay without preview setup")
	hair.set_segmented_enabled(true)
	check(hair.overlay.z_as_relative and hair.overlay.z_index==hair.z_index,"Healing overlay preserves the same foreground hair layer")
	hair.step(1.0/60,Vector2.ZERO,0,false,false,false,false)
	check(hair.curve is Polygon2D and not hair.get_node("Strand").visible,"Sample uses one connected textured strip instead of the rigid card")
	check(hair.curve.texture.get_image().get_data()==hair.get_node("Strand").texture.get_image().get_data(),"Clamped texture reuses the exact original strand pixels without repainting")
	check(hair.curve.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Nearest pixel sampling preserved")
	check(hair.segment_angles is Vector3 and hair.curve.polygons.size()==44 and hair.curve.polygon.size()==46,"Three simulated sections drive one smooth half-pixel tessellated ribbon")
	check(hair.curve.polygon[0]==Vector2(-1,0) and hair.curve.polygon[1]==Vector2(3,0),"Root row stays at original sprite attachment")
	check(hair.curve.texture.get_size()==Vector2(4,11) and hair.curve.uv[0]==Vector2.ZERO and hair.curve.uv[-1]==Vector2(4,11),"UVs clamp to the isolated 4 by 11 original strand instead of adjacent atlas texels")
	var uv:PackedVector2Array=hair.curve.uv.duplicate()
	for i in 50:hair.step(1.0/60,Vector2(290,0),0,false,false,false,false)
	check(absf(hair.segment_angles.z-hair.segment_angles.x)>.1,"Moving strand has a curved profile rather than three equal rigid angles")
	check(hair.segment_angles.x>0 and hair.segment_angles.z>hair.segment_angles.x,"Root bends less than tip during normal motion")
	check(fixed_lengths(hair),"Centerline preserves 3+4+4=11 pixel length while bending")
	var rendered_length:=0.0
	var gentle:=true
	for i in hair.render_centerline.size()-1:
		rendered_length+=hair.render_centerline[i].distance_to(hair.render_centerline[i+1])
		if i>0:
			var a:Vector2=hair.render_centerline[i]-hair.render_centerline[i-1]
			var b:Vector2=hair.render_centerline[i+1]-hair.render_centerline[i]
			gentle=gentle and absf(a.angle_to(b))<.3
	check(absf(rendered_length-11.0)<.00001,"Rendered smooth curve preserves actual 11 pixel arc length")
	check(gentle,"Visible tangent changes smoothly across old section boundaries")
	check(absf(Vector2.DOWN.angle_to(hair.centerline[3]-hair.centerline[0])-hair.segment_angles.z)<0.00001,"Curve preserves overall tip swing instead of shrinking the approved range")
	check(hair.rotation==0.0,"Sample no longer rotates the entire card at the root")
	check(hair.curve.polygon[0]==Vector2(-1,0) and hair.curve.polygon[1]==Vector2(3,0),"Movement never shifts the root row")
	check(hair.curve.uv==uv,"Animation does not scroll or stretch atlas UV ranges")
	check(hair.overlay_curve.polygon==hair.curve.polygon and hair.overlay.transform==hair.transform,"Heal overlay shares the exact curve and attachment without a second simulation")
	var previous:Vector3=hair.segment_angles
	hair.step(1.0/60,Vector2.ZERO,0,false,false,false,false)
	check(hair.segment_angles.z>0 and hair.segment_angles!=previous,"Stopping keeps a continuous delayed tip response")
	for i in 360:hair.step(1.0/60,Vector2.ZERO,0,false,false,false,false)
	check(hair.segment_angles.length()<.001 and hair.segment_velocities.length()<.001,"All sections settle after stopping without idle twitch")
	for i in 160:hair.step(1.0/60,Vector2(290,0),PI,true,false,false,false)
	var world_tip:Vector2=hair.transform.basis_xform(hair.centerline[3]-hair.centerline[0])
	check(world_tip.x<0,"Right-facing mirrored hair trails rightward movement instead of leading it")
	for i in 160:hair.step(1.0/60,Vector2(-290,0),PI,true,false,false,false)
	world_tip=hair.transform.basis_xform(hair.centerline[3]-hair.centerline[0])
	check(world_tip.x>0,"Mirrored strand trails leftward movement too")
	var stable:=true
	for i in 480:
		hair.step(1.0/20,Vector2(5000 if i%50<25 else -5000,0),PI,true,false,false,false)
		stable=stable and fixed_lengths(hair) and hair.segment_angles.is_finite()
		for j in 3:stable=stable and absf(hair.segment_angles[j])<=hair.MAX_ANGLE+0.000001
		for triangle in hair.curve.polygons:
			var a:Vector2=hair.curve.polygon[triangle[0]]
			var b:Vector2=hair.curve.polygon[triangle[1]]
			var c:Vector2=hair.curve.polygon[triangle[2]]
			stable=stable and (b-a).cross(c-a)>0.0
	check(stable,"Low-frame-rate hard reversals stay finite, length-constrained and inside original swing limits")
	hair.step(1.0/60,Vector2.ZERO,0,false,true,false,false)
	check(not hair.visible and not hair.overlay.visible,"Rear-facing hair retains existing hide rule")
	var bridge=load("res://scripts/dream/dream_3d_actor_depth_bridge.gd").new()
	var copy:Node2D=bridge._make_visual_copy(hair)
	bridge._sync_node(hair,copy)
	check(copy.get_node("CurvedStrand").polygon==hair.curve.polygon and copy.get_node("CurvedStrand").uv==uv,"Production 3D capture copies curve vertices and original UVs")
	copy.free();bridge.free()
	hair.set_segmented_enabled(false)
	check(hair.get_node("Strand").visible and not hair.curve.visible,"Preview can return to unchanged rigid visual")
	player.queue_free();for i in 4:await process_frame
	print("SIDE_BANGS_CURVE checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
