extends SceneTree
const SMOKE=preload("res://scripts/dream/nyangeon_footstep_smoke.gd")
const WORLD=preload("res://scripts/dream/dream_3d_random_dungeon.gd")
class Actor extends CharacterBody2D:
	var dead:=false
	var knockback_height:=0.0
class Fixture extends Node3D:
	var player: Node2D
	var enemy_root: Node2D
	var camera_3d: Camera3D
	var floor_transition_in_progress:=false
	var token:=1
	func get_current_floor_token()->int: return token
	func get_gameplay_world_position(at:Vector2,height:float)->Vector3: return Vector3(at.x/32,height,at.y/32)
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run()->void:
	var fixture:=Fixture.new(); root.add_child(fixture)
	var actor:=Actor.new(); fixture.add_child(actor); fixture.player=actor
	var contact:=Node2D.new(); contact.name="CollisionShape2D"; contact.position=Vector2(0,-13); actor.add_child(contact)
	var smoke:=SMOKE.new(); fixture.add_child(smoke); smoke.configure(fixture); smoke.set_physics_process(false)
	smoke.rng.seed=8412
	smoke.sample(actor); actor.position.x=20; smoke.sample(actor)
	# One step fires `cluster` puffs; the invariant is "a step emits, nothing else does".
	var step_emits:=smoke.cluster
	check(smoke.emitted==step_emits,"Ground travel emits one smoke step")
	# Per-puff scatter moves the puff on the floor plane, so this is a bound check:/n/t# the point must sit at the foot contact, not at the actor origin 13px higher.
	check(absf(smoke.sprites[0].global_position.z+13.0/32)<=0.25,"Footstep uses the same offset foot contact as the character bridge")
	var point: Vector3=smoke.sprites[0].global_position
	for i in 10: smoke.sample(actor)
	check(smoke.emitted==step_emits,"Standing creates no new smoke")
	actor.position.x+=1; smoke.sample(actor)
	check(smoke.sprites[0].global_position==point,"A foot puff remains behind instead of following its actor")
	actor.knockback_height=8; actor.position.x+=20; smoke.sample(actor)
	check(smoke.emitted==step_emits,"Airborne actor does not leave footsteps")
	actor.knockback_height=0; actor.dead=true; actor.position.x+=20; smoke.sample(actor)
	check(smoke.emitted==step_emits,"Corpse movement does not leave footsteps")
	actor.dead=false; actor.position.x+=100; smoke.sample(actor)
	check(smoke.emitted==step_emits,"Teleport does not emit a trail across the floor")
	for i in 100: smoke.emit_puff(Vector2(i,0),Vector2.LEFT)
	check(smoke.puffs.size()==SMOKE.LIMIT and smoke.sprites.size()==SMOKE.LIMIT,"Busy scene respects fixed carrier capacity")
	var sizes: Dictionary={}; var lives: Dictionary={}
	for puff in smoke.puffs:
		sizes[snappedf(float(puff.size),.01)]=true; lives[snappedf(float(puff.life),.01)]=true
	check(sizes.size()>8 and lives.size()>4,"Smoke varies its birth size and disappearance timing")
	var extremes:=smoke.puffs.map(func(puff:Dictionary)->float: return float(puff.size))
	check(extremes.min()<.4 and extremes.max()>.95,"Small and large puffs remain visibly distinct at gameplay zoom")
	seed(12345); var expected:=randf(); seed(12345)
	smoke.clear(); smoke.emit_puff(Vector2.ZERO,Vector2.LEFT)
	check(is_equal_approx(randf(),expected),"Smoke variation does not consume gameplay random numbers")
	smoke.clear(); actor.dead=false; smoke.sample(actor)
	var intervals: Dictionary={}
	for i in 15:
		intervals[snappedf(float(smoke.tracked[actor.get_instance_id()].next_distance),.1)]=true
		actor.position.x+=20; smoke.sample(actor)
	check(intervals.size()>5,"Constant-speed walking does not produce evenly spaced puffs")
	check(intervals.keys().any(func(gap:float)->bool: return gap<8) and intervals.keys().any(func(gap:float)->bool: return gap>20),"Short puff clusters alternate with clear gaps")
	smoke._physics_process(.5)
	check(smoke.puffs.is_empty(),"Expired smoke releases all visible slots")
	smoke.emit_puff(Vector2.ZERO,Vector2.ZERO); fixture.floor_transition_in_progress=true; smoke._physics_process(.01)
	check(smoke.puffs.is_empty() and smoke.tracked.is_empty(),"Floor transition clears smoke and distance history")
	fixture.floor_transition_in_progress=false
	smoke.emit_puff(Vector2.ZERO,Vector2.ZERO); fixture.token+=1; smoke._physics_process(.01)
	check(smoke.puffs.is_empty(),"New floor token discards old puffs")
	var muzzle:=preload("res://scenes/entities/weapon_muzzle_effect.tscn").instantiate(); root.add_child(muzzle)
	check(not muzzle.nyangeon_style,"Normal game keeps its approved muzzle until sample opt-in")
	muzzle.enable_nyangeon_style()
	muzzle._process(.1)
	check(is_equal_approx(muzzle.lifetime,.24),"A late-spawned muzzle presents its bright birth frame before aging")
	var copy:=preload("res://scenes/entities/weapon_muzzle_effect.tscn").instantiate(); root.add_child(copy); muzzle.copy_depth_visual_state_to(copy)
	check(copy.nyangeon_style and copy.lifetime==muzzle.lifetime,"Passive muzzle capture retains sample style and age")
	var hit:=preload("res://scenes/entities/combat_feedback_effect.tscn").instantiate(); root.add_child(hit)
	check(not hit.nyangeon_style,"Other damage types keep original feedback")
	hit.setup(Vector2.RIGHT,true,.18); hit.enable_nyangeon_style()
	var hit_copy:=preload("res://scenes/entities/combat_feedback_effect.tscn").instantiate(); root.add_child(hit_copy); hit.copy_depth_visual_state_to(hit_copy)
	check(hit_copy.nyangeon_style and hit_copy.is_kill,"Passive feedback capture retains lethal sample variant")
	muzzle.free(); copy.free(); hit.free(); hit_copy.free(); fixture.free()
	print("NYANGEON_VFX_SAMPLE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
