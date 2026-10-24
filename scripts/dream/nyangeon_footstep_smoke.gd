extends Node3D
## Floor-owned, depth-tested native sprites; no capture viewports.
const SHAPES=preload("res://scripts/dream/nyangeon_vfx_shapes.gd")
const LIMIT:=72
## Merged cloud shapes: three unpacked dust circles fused, then one 1px ring drawn
## around the union (#131333). Baked because the source build outlines a whole layer
## once, which is what makes separate circles read as a single cloud.
const CLUSTER_TEXTURES: Array= [
	preload("res://assets/art/vfx/smoke_cluster/cluster_0.png"),
	preload("res://assets/art/vfx/smoke_cluster/cluster_1.png"),
	preload("res://assets/art/vfx/smoke_cluster/cluster_2.png"),
	preload("res://assets/art/vfx/smoke_cluster/cluster_3.png"),
	preload("res://assets/art/vfx/smoke_cluster/cluster_4.png"),
	preload("res://assets/art/vfx/smoke_cluster/cluster_5.png"),
]
var rng:=RandomNumberGenerator.new()
var world: Node3D
var tracked: Dictionary={}
var puffs: Array[Dictionary]=[]
var sprites: Array[Sprite3D]=[]
var cursor:=0
var emitted:=0
var peak_active:=0
var update_usec:=0
var updates:=0
var enabled:=true
var floor_token:=-1
## Puffs fired per footstep. Each baked cloud already contains three circles.
var cluster:=2
## Seconds a puff spends growing into its full size. 0 keeps the older curve,
## which only shrank after 25% of its life.
var grow_time:=0.12
## Pre-baked cloud shapes: several circles merged, one outline around the union.
var variants: Array[Texture2D]=[]
var variant_pixel_size:=1.0/28.0
## Life fraction at which the alpha starts dropping to zero. 0.75 matched the older
## curve; 0.45 keeps the fade visible across most of a short-lived puff.
var fade_start:=0.45

func configure(owner_world: Node3D)->void:
	world=owner_world
	# Presentation randomness must never advance gameplay/weapon RNG.
	rng.randomize()
	if variants.is_empty():
		variants.assign(CLUSTER_TEXTURES)
	var texture:=SHAPES.active_smoke_texture()
	var filter:=BaseMaterial3D.TEXTURE_FILTER_LINEAR if SHAPES.smoke_style=="soft" else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for i in LIMIT:
		var sprite:=Sprite3D.new()
		sprite.texture=texture; sprite.pixel_size=1.0/32.0
		sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter=filter
		sprite.no_depth_test=false; sprite.shaded=false; sprite.visible=false
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		add_child(sprite); sprites.append(sprite)
	process_physics_priority=20

func clear()->void:
	tracked.clear(); puffs.clear()
	for sprite in sprites: sprite.visible=false

func eligible(actor: Node2D)->bool:
	# Formal gameplay canvas is hidden by the 3D bridge. The actor's own
	# visibility and room flags, not its hidden 2D ancestors, govern emission.
	if not actor.visible or actor.get("dead")==true: return false
	if actor.get("sky_drop_active")==true or actor.get("knockdown_airborne")==true: return false
	if actor.get("dashing")==true or actor.get("is_tactical_dash_executing")==true: return false
	if actor.get("room_runtime_active")==false or actor.get("player_vision_visible")==false: return false
	for key in ["knockback_height","knockdown_height","vault_height"]:
		var height: Variant=actor.get(key)
		if height!=null and float(height)>0.5: return false
	for key in ["external_knockback_left","knockback_left","knockback_recovery_left"]:
		var remaining: Variant=actor.get(key)
		if remaining!=null and float(remaining)>0: return false
	return true

func sample(actor: Node2D)->void:
	var id:=actor.get_instance_id()
	var at:=actor.global_position
	if not tracked.has(id): tracked[id]={"at":at,"distance":0.0,"cluster_left":rng.randi_range(0,2),"next_distance":rng.randf_range(9,18)}; return
	var state: Dictionary=tracked[id]
	var move: Vector2=at-Vector2(state.at)
	state.at=at
	if not eligible(actor) or move.length()>32.0:
		state.distance=0.0; return
	state.distance+=move.length()
	if move.length()<0.01 or float(state.distance)<float(state.next_distance): return
	state.distance=0.0
	if int(state.cluster_left)>0:
		state.cluster_left-=1
		state.next_distance=rng.randf_range(4,8)
	else:
		state.cluster_left=rng.randi_range(1,2)
		state.next_distance=rng.randf_range(20,28)
	var camera: Camera3D=world.get("camera_3d")
	var position_3d: Vector3=world.get_gameplay_world_position(at,.06)
	if camera!=null and (camera.is_position_behind(position_3d) or not camera.get_viewport().get_visible_rect().grow(30).has_point(camera.unproject_position(position_3d))): return
	# The character bridge anchors visible feet to the body's collider, whose
	# local offset differs between player and enemies. Use that same contact.
	var collider:=actor.get_node_or_null("CollisionShape2D") as Node2D
	var ground: Vector2=collider.global_position if collider!=null else at
	for i in maxi(1,cluster):
		var offset:=Vector2.ZERO
		if cluster>1:
			var angle:=rng.randf()*TAU
			offset=Vector2(cos(angle),sin(angle))*rng.randf_range(2.0,7.0)
		emit_puff(ground-move.normalized()*4.0+offset,-move.normalized())

func emit_puff(at: Vector2,drift: Vector2)->void:
	# Stop allocating work when full; near actors are sampled first.
	if puffs.size()>=LIMIT: return
	var slot:=cursor
	for i in LIMIT:
		slot=(cursor+i)%LIMIT
		if not sprites[slot].visible: break
	cursor=(slot+1)%LIMIT
	var sprite:=sprites[slot]
	sprite.visible=true
	if not variants.is_empty():
		sprite.texture=variants[rng.randi_range(0,variants.size()-1)]
		sprite.pixel_size=variant_pixel_size
	var point: Vector3=world.get_gameplay_world_position(at,.09)
	# Distinct small/medium/large silhouettes, with a short group followed by
	# a real gap, read as irregular footsteps at the actual gameplay zoom.
	var bucket:=rng.randf()
	var size:=rng.randf_range(.30,.44) if bucket<.4 else (rng.randf_range(.55,.72) if bucket<.8 else rng.randf_range(.90,1.08))
	var life:=rng.randf_range(.24,.44)
	var varied_drift:=drift.rotated(rng.randf_range(-.35,.35))*rng.randf_range(.08,.16)
	puffs.append({"slot":slot,"age":0.0,"size":size,"life":life,"origin":point,"drift":world.global_basis*Vector3(varied_drift.x,0,varied_drift.y)})
	sprite.global_position=point; sprite.scale=Vector3.ONE*size; sprite.modulate=Color.WHITE
	sprite.flip_h=rng.randf()<.5
	emitted+=1; peak_active=maxi(peak_active,puffs.size())

func _physics_process(delta: float)->void:
	var started:=Time.get_ticks_usec()
	if not is_instance_valid(world): queue_free(); return
	var token: int=world.get_current_floor_token() if world.has_method("get_current_floor_token") else 0
	if floor_token!=token: clear(); floor_token=token
	if not enabled or not is_visible_in_tree() or world.get("floor_transition_in_progress")==true:
		clear(); return
	for i in range(puffs.size()-1,-1,-1):
		var puff: Dictionary=puffs[i]
		puff.age+=delta
		var sprite:=sprites[int(puff.slot)]
		var t: float=float(puff.age)/float(puff.life)
		if t>=1:
			sprite.visible=false; puffs.remove_at(i); continue
		sprite.global_position=Vector3(puff.origin)+Vector3(puff.drift)*t+Vector3.UP*.08*t
		var size:=float(puff.size)*(1.0-.7*maxf(0,(t-.25)/.75))
		if grow_time>0.0: size*=.55+.45*clampf(float(puff.age)/grow_time,0.0,1.0)
		sprite.scale=Vector3.ONE*size
		sprite.modulate.a=1.0 if t<fade_start else clampf((1.0-t)/maxf(0.01,1.0-fade_start),0.0,1.0)
	var actors: Array[Node2D]=[]
	var player: Node2D=world.get("player")
	if is_instance_valid(player): actors.append(player)
	var enemies: Node=world.get("enemy_root")
	if is_instance_valid(enemies):
		for actor in enemies.get_children():
			if actor is CharacterBody2D: actors.append(actor)
	if is_instance_valid(player): actors.sort_custom(func(a:Node2D,b:Node2D)->bool: return a.global_position.distance_squared_to(player.global_position)<b.global_position.distance_squared_to(player.global_position))
	var live: Dictionary={}
	for actor in actors:
		live[actor.get_instance_id()]=true; sample(actor)
	for id in tracked.keys():
		if not live.has(id): tracked.erase(id)
	updates+=1; update_usec+=Time.get_ticks_usec()-started
