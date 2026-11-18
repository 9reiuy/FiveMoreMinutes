extends "res://scripts/testing/h06_chapter/chapter_world.gd"
## Direct practice entry; the production chapter's progression is untouched.
const ATTACKS := preload("res://scripts/testing/h06_chapter/crawler_attacks.gd")
signal special_practice_finished
var selected_attack := -1
var attacks_paused := false
var replay_boarding := false

func _checkpoint_region(_save: int) -> PLAN.Visit:
	return PLAN.Visit.ARENA

func _restore_checkpoint(_save: int) -> void:
	checkpoint=Save.ARENA
	stage=Stage.APPROACH if replay_boarding else Stage.BOSS
	_spotlight_triggered = true
	_set_lower(true)
	var bridge := PLAN.ARENA_BRIDGE
	_place_feet(Vector2(bridge.get_center().x,bridge.end.y-1.25) if replay_boarding else PLAN.LIFT_ENTRY+Vector2(0,-1.7))
	blockout.set_gate("arena",true)
	blockout.set_gate("boarding",not replay_boarding)
	blockout.ensure_chase_crawler()
	blockout.mech.visible=not replay_boarding
	blockout.mech.position=Vector3(PLAN.BOSS_MARK.x,0,PLAN.BOSS_MARK.y)
	_sync_height_immediate()

func _setup_chapter_session() -> void:
	if _session_initialized:return
	super._setup_chapter_session()
	if not _session_initialized:return
	player.equip_weapon("assault_rifle",config,permanent_upgrades)
	if replay_boarding:
		chase_distance=mech_path.get_baked_length()
		ramp_distance=escape_path.get_baked_length()
		_prompt("登上货运平台")
	else:
		crawler_motion.teleport(Vector3(PLAN.BOSS_MARK.x,0,PLAN.BOSS_MARK.y),0.)
		blockout.inclined_lift.start_ascent()
		_begin_crawler_boss()
		_prompt("绕到 H06 后方攻击　·　F5 重开")

func _begin_crawler_boss() -> void:
	super._begin_crawler_boss()
	boss.attacks.event.connect(_attack_event)

func _attack_event(kind: StringName, _data: Dictionary) -> void:
	if kind != &"recovered" or selected_attack < 0: return
	if ATTACKS.CYCLE.has(selected_attack):
		boss.attacks.next_attack=selected_attack
	else:
		selected_attack = -1
		special_practice_finished.emit()

func select_attack(index: int) -> void:
	if not is_instance_valid(boss) or boss.dead:return
	selected_attack=clampi(index,-1,ATTACKS.Attack.size()-1)
	var director=boss.attacks
	director.finish_stun(&"practice")
	director.cancel_projectiles()
	director.hit_left=0
	director.rig.reset()
	crawler_motion.hull.rotation=0
	crawler_motion.teleport(Vector3(PLAN.BOSS_MARK.x,0,PLAN.BOSS_MARK.y),0.)
	director.state=director.State.REST
	director.practice_single=selected_attack >= 0
	if selected_attack < 0: director.health_changed(boss.current_health/boss.MAX_HEALTH)
	director.next_attack=ATTACKS.Attack.CANNON
	set_attacks_paused(false)
	if selected_attack == ATTACKS.Attack.STOMP:
		_place_feet(PLAN.BOSS_MARK+Vector2(2.8,3.2))
	if selected_attack == ATTACKS.Attack.BURST:
		if boss.current_health >= boss.MAX_HEALTH*.5:
			boss.take_damage(boss.current_health-(boss.MAX_HEALTH*.5-1.0))
		# The training button can replay the same one-shot phase transition.
		director.burst_used = false
		_place_feet(PLAN.BOSS_MARK+Vector2(0,8.8))
	elif selected_attack != ATTACKS.Attack.STOMP:
		# A practice reset has to leave enough space for the chassis and the player.
		if _feet().distance_to(PLAN.BOSS_MARK) < PLAN.CRAWLER_RADIUS:
			_place_feet(PLAN.BOSS_MARK+Vector2(0,8.8))
	if selected_attack == ATTACKS.Attack.STOMP or selected_attack == ATTACKS.Attack.BURST:
		director.practice_single = false
	director.begin(maxi(0,selected_attack))

func set_attacks_paused(value: bool) -> void:
	attacks_paused=value
	if is_instance_valid(boss) and not boss.dead:boss.set_physics_process(not value)
	if is_instance_valid(crawler_motion) and not crawler_motion.dead:crawler_motion.set_physics_process(not value)

