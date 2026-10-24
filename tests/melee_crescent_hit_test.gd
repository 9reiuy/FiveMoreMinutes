extends SceneTree
const FX := preload("res://scripts/dream/melee_crescent_hit_3d.gd")
var checks := 0
var failures := 0
var world: Node
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func effects() -> Array:
	return get_nodes_in_group(&"melee_crescent_hits").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
func enemy_at(at: Vector2) -> Node:
	var enemy: Node = world._spawn_regular_employee(world.current_room_id,at,&"employee",false,"luger")
	enemy.maximum_health = 100.0
	enemy.current_health = 100.0
	enemy.set_physics_process(false)
	enemy.set_process(false)
	return enemy
func clear_effects() -> void:
	for effect in effects(): effect.free()
func run() -> void:
	var diagnostic := root.get_node_or_null("_DroneGameDiag")
	if diagnostic != null: diagnostic.free()
	AudioServer.set_bus_mute(0,true)
	world = load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready = false
	world.spawn_content = false
	world.persist_profile = false
	world.enable_game_start_cab_exit = false
	world.approved_sample_art_enabled = false
	root.add_child(world)
	check(world.regenerate(42001),"Formal floor generates")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var origin: Vector2 = world.player.global_position
	for source in [&"lucille",&"books"]:
		for lethal in [false,true]:
			var enemy := enemy_at(origin+Vector2(35,0))
			var result: Dictionary = world.resolve_player_hit(enemy,1000.0 if lethal else 1.0,origin,source)
			check(not result.is_empty(),"Formal melee hit accepted")
			check(effects().size()==1,"One crescent on %s lethal=%s" % [source,lethal])
			var effect: Node = effects()[0]
			check(is_equal_approx(float(effect.material.get_shader_parameter("visual_scale")),1.5),"Crescent and cuts use 1.5x visual scale")
			check(effect.mesh.mesh.size.is_equal_approx(Vector2.ONE*5.25),"Expanded quad contains enlarged cuts without clipping")
			check(effect.get_parent()==world.floor_root,"Effect belongs to current floor")
			check(effect.line_count>=1 and effect.line_count<=3,"One to three random cuts")
			var bounded := true
			for cut: Vector4 in effect.cuts:
				bounded = bounded and cut.z>=64 and cut.z<=96 and absf(cut.w)<=3 and absf(Vector2(cut.x,cut.y).length()-1.0)<.001
			check(bounded,"Random cut lengths and directions fit pixel quad")
			check(effect.find_children("*","SubViewport",true,false).is_empty(),"No extra capture viewport")
			check(effect.mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Hit ink casts no rectangle shadow")
			check(bool(effect.material.get_shader_parameter("reference_depth_enabled")),"Formal body reference depth enabled")
			enemy.free()
			effect._process(0.0)
			effect._process(.15)
			check(not effect.is_queued_for_deletion(),"Hit ink persists beyond original 0.15 seconds")
			effect._process(.071)
			check(effect.is_queued_for_deletion(),"Effect expires safely after target freed")
			await process_frame
	# Punch only changes inside the phase-dash damage scope, not ordinary punch.
	for source in [&"player_punch",&"lucille",&"books"]:
		var enemy := enemy_at(origin+Vector2(30,0))
		var handled := {}
		var result: Dictionary = world.resolve_phase_dash_attack(origin,origin+Vector2(60,0),16.0,1.0,source,handled,false)
		check(int(result.hits)==1 and effects().size()==1,"Dash accepted hit creates one crescent: "+String(source))
		world.resolve_phase_dash_attack(origin,origin+Vector2(60,0),16.0,1.0,source,handled,false)
		check(effects().size()==1,"Same dash cannot duplicate target feedback")
		check(not world.is_resolving_phase_dash_hit(),"Dash damage scope cleared")
		enemy.free()
		clear_effects()
	var enemy := enemy_at(origin+Vector2(30,0))
	world.resolve_player_hit(enemy,1.0,origin,&"player_punch")
	check(effects().is_empty(),"Ordinary unarmed punch unchanged")
	world.resolve_player_hit(enemy,1.0,origin,&"player_projectile_basic")
	check(effects().is_empty(),"Gun feedback unchanged")
	world.resolve_phase_dash_attack(origin+Vector2(500,0),origin+Vector2(560,0),16.0,1.0,&"lucille",{},false)
	check(effects().is_empty(),"Empty dash has no hit crescent")
	enemy.free()
	var crowd: Array[Node] = []
	for distance in [30.0,70.0,110.0]: crowd.append(enemy_at(origin+Vector2(distance,0)))
	var crowd_handled := {}
	var crowd_result: Dictionary = world.resolve_phase_dash_attack(origin,origin+Vector2(140,0),16.0,1.0,&"lucille",crowd_handled,false)
	check(int(crowd_result.hits)==3 and effects().size()==3,"One dash creates one hit visual for each of three enemies")
	world.resolve_phase_dash_attack(origin,origin+Vector2(140,0),16.0,1.0,&"lucille",crowd_handled,false)
	check(effects().size()==3,"Overlapping dash segments do not duplicate any crowd feedback")
	for member in crowd: member.free()
	clear_effects()
	var lethal_target := enemy_at(origin+Vector2(30,0))
	world.resolve_phase_dash_attack(origin,origin+Vector2(60,0),16.0,1000.0,&"player_punch",{},false)
	check(bool(lethal_target.dead) and effects().size()==1,"Lethal unarmed dash also publishes crescent before death")
	lethal_target.free()
	clear_effects()
	# Visual randomness is isolated from the game's global RNG stream.
	seed(72521)
	var expected := randi()
	seed(72521)
	var fx := FX.new()
	world.floor_root.add_child(fx)
	fx.setup(world.camera_3d,Vector3.ZERO,Vector2.RIGHT,{"origin":Vector3.ZERO,"normal":Vector3.BACK})
	check(randi()==expected,"Presentation RNG does not alter gameplay RNG")
	var reflection: Node = load("res://scripts/dream/floor_reflections.gd").new()
	root.add_child(reflection)
	reflection.set_process(false)
	reflection._register_visual(fx.mesh)
	fx.material.set_shader_parameter("progress",.4)
	check(fx.mesh.material_override==fx.material and is_equal_approx(float(fx.mesh.material_override.get_shader_parameter("progress")),.4),"Reflection preserves animated material identity")
	reflection.restore()
	reflection.free()
	var effect_ref: WeakRef = weakref(fx)
	var previous_floor: int = world.floor_index
	world._stash_current_floor_for_rollback()
	check(not fx.can_process(),"Stashed floor suspends hit ink")
	world._rollback_failed_transition(world.transition_generation_token,previous_floor)
	check(is_instance_valid(fx) and fx.can_process(),"Rollback restores same hit ink without duplication")
	check(world.regenerate(42002),"Next floor generates")
	await process_frame
	await process_frame
	check(effect_ref.get_ref()==null,"Floor rebuild removes old hit ink")
	world.free()
	await process_frame
	print("MELEE_CRESCENT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
