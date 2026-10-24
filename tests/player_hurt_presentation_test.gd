extends SceneTree
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frames(n: int=2) -> void:
	for i in n: await process_frame
func run() -> void:
	var diag:=root.get_node_or_null("_DroneGameDiag")
	if diag!=null: diag.free()
	AudioServer.set_bus_mute(0,true); root.size=Vector2i(640,360)
	var world: Node=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.spawn_content=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world); check(world.regenerate(42001),"Real floor generates with new player hurt presenter")
	await frames()
	var player: Node=world.player
	player.set_physics_process(false); player.maximum_health=1000; player.current_health=1000
	player.invulnerability_left=0; player.dash_invulnerability_left=0; player.has_shield=false
	var fx: Node=world.floor_root.get_node("PlayerHurtPresentation")
	fx.set_process(false)
	check(not fx.word_glyph_pose(.01,2).visible,"Later Chinese characters enter with a short stagger")
	check(fx.word_glyph_pose(.075,0).scale.x>2,"Comic word visibly overshoots to over twice native glyph size")
	check(fx.word_glyph_pose(.16,0).scale.x<fx.word_glyph_pose(.075,0).scale.x,"Word rebounds after pop rather than only drifting")
	check(fx.word_glyph_pose(.3,0).rotation*fx.word_glyph_pose(.3,1).rotation<0,"Characters retain alternating comic tilt")
	check(fx.word_glyph_pose(.8,0).alpha<.3,"Comic text fades before bounded retirement")
	check(fx.word_shadow.material is ShaderMaterial and fx.word_shadow.get_index()<fx.surface.get_index(),"Dedicated halftone pass sits behind bold letters, never stars or world")
	check(fx!=null and player.get_meta(&"stylized_player_hurt").get_ref()==fx,"One floor-owned presenter claims player")
	var original_position: Vector2=player.global_position
	var shape_before: Vector2=player.body_collision.shape.get_rect().size
	player.receive_damage(5,&"enemy_projectile",player.global_position-Vector2(50,0),Vector2.RIGHT)
	check(player.current_health==995 and fx.emitted==1,"Actual health loss emits exactly one presentation")
	check(is_equal_approx(player.invulnerability_left,player.hurt_invulnerability_seconds),"Original invulnerability timing is untouched")
	check(fx.stars.size()==6 and fx.phrase in fx.WORDS,"Hurt creates bounded stars and approved Chinese phrase")
	check(player.visual.scale.x>player.character_visual_scale and player.visual.scale.y<player.character_visual_scale,"First hurt pose squashes without moving collider")
	check(player.global_position==original_position and player.body_collision.shape.get_rect().size==shape_before,"Hurt art never changes 2D position or collision geometry")
	check(fx.shock.get_shader_parameter("strength")==1.0 and fx.post_rect.visible,"World-only shock starts immediately")
	check(fx.post_layer.layer==19 and fx.post_copy.copy_mode==BackBufferCopy.COPY_MODE_VIEWPORT,"Shock samples explicit finished post-palette copy at layer 19")
	var burst: Dictionary=fx.bursts[0]
	var anchor: Vector3=burst.origin
	var star_at: Vector3=fx.star_world_position(burst,burst.stars[0])
	var word_at: Vector3=fx.word_world_position(burst)
	player.global_position+=Vector2(180,0)
	check(burst.origin==anchor and fx.star_world_position(burst,burst.stars[0])==star_at and fx.word_world_position(burst)==word_at,"Moving player does not drag impact origin, star or word")
	var before_projection: Vector2=fx.project_feedback(word_at)
	world.camera_3d.global_position+=world.camera_3d.global_basis.x
	check(fx.project_feedback(word_at).distance_to(before_projection)>1,"Camera movement reprojects fixed world feedback rather than pinning it to HUD")
	world.camera_3d.global_position-=world.camera_3d.global_basis.x
	fx._on_damage(1)
	check(fx.bursts.size()==2 and fx.bursts[0].origin==anchor and fx.bursts[1].origin.distance_to(anchor)>1,"A new hit preserves the old impact batch at its separate world position")
	check(fx.post_layer.get_meta(&"world_post_effect",false) and fx.post_layer.get_parent()==fx,"World postprocess is excluded from crisp HUD reparenting")
	var emitted_before: int=fx.emitted
	player.receive_damage(5)
	check(fx.emitted==emitted_before and player.current_health==995,"Invulnerable damage creates neither loss nor duplicate feedback")
	player.effective_damage_taken.emit(0.0)
	check(fx.emitted==emitted_before,"Zero effective damage produces no feedback")
	fx._process(.12)
	check(player.visual.scale.y>player.character_visual_scale,"Squash rebounds before settling")
	fx._process(.2)
	check(player.visual.scale.is_equal_approx(Vector2.ONE*player.character_visual_scale) and not fx.post_rect.visible,"Pose and short color split recover without locking movement")
	fx._process(.6)
	check(not fx.layer.visible and fx.stars.is_empty(),"Words and stars retire within bounded lifetime")
	player.invulnerability_left=0; player.has_shield=true
	player.receive_damage(5)
	check(player.current_health==995 and fx.emitted==emitted_before,"Shield hit does not play health-loss presentation")
	player.has_shield=false
	for i in 12:
		var previous: String=fx.phrase
		fx._on_damage(1)
		check(fx.phrase!=previous,"Consecutive Chinese interjections never repeat")
	check(fx.bursts.size()<=4,"Overlapping impacts have a bounded batch count")
	seed(325)
	var expected:=randi()
	seed(325); fx._on_damage(1)
	check(randi()==expected,"Presentation random choice never advances gameplay RNG")
	for phrase in fx.WORDS:
		for character in phrase:
			check(fx.FONT.get_font().has_char(character.unicode_at(0)),"Chinese hurt glyph exists: "+character)
	paused=true; fx._process(.01)
	check(not fx.layer.visible and not fx.post_rect.visible,"Pause clears words, stars and world shock")
	paused=false
	fx._on_damage(1)
	var old_fx: Node=fx
	var old_floor: int=world.floor_index
	world.floor_transition_in_progress=true; world._stash_current_floor_for_rollback(); await frames()
	check(not old_fx._active() and not old_fx.layer.visible,"Stashed floor cannot keep a damage HUD active")
	world._reset_layout_data(); world._rollback_failed_transition(world.transition_generation_token,old_floor); await frames()
	world.floor_transition_in_progress=false
	check(is_instance_valid(old_fx) and player.get_meta(&"stylized_player_hurt").get_ref()==old_fx,"Rollback restores the same single presenter")
	check(world.regenerate(42002),"New floor generates")
	await frames()
	check(not is_instance_valid(old_fx),"Previous floor hurt presenter is freed")
	check(player.get_meta(&"stylized_player_hurt").get_ref()==world.floor_root.get_node("PlayerHurtPresentation"),"New floor owns a fresh presenter, not a stale callback")
	world.free(); await frames()
	print("PLAYER_HURT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
