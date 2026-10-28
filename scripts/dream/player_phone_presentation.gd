extends RefCounted
## Presentation only, advanced by GamePhone's unpaused real-time driver.
const ART = preload("res://art/Dream/dream_chr_32x32.png")
const FLICKER = preload("res://scripts/ui/screen_glow_flicker.gd")
const CONFIG = preload("res://resources/demo_config.tres")
const FRAME_SECONDS := .08
const LOOP_SECONDS := .25
var world: Node3D
var actor: Node2D
var pose: Sprite2D
var frames: Array[AtlasTexture] = []
var mask: Texture2D
var snapshots: Array[Dictionary] = []
var elapsed := 0.0
var close_elapsed := 0.0
var closing := false
var close_start_frame := 3
var frame_index := 0
var glow_alpha := .75
var next_flicker := 0.0
var rng := RandomNumberGenerator.new()
var emission_material: ShaderMaterial

func bind(owner_world: Node3D) -> void:
	world = owner_world
	actor = world.player
	rng.randomize()
	for child in actor.visual.get_children():
		if child is CanvasItem:
			snapshots.append({"node":weakref(child),"visible":child.visible})
			child.hide()
	for node in [actor.weapon_root,actor.heal_overlay]:
		snapshots.append({"node":weakref(node),"visible":node.visible})
		node.hide()
	snapshots.append({"node":weakref(actor.visual),"visible":actor.visual.visible})
	actor.visual.show()
	for i in 6:
		var texture := AtlasTexture.new()
		texture.atlas = ART
		texture.region = Rect2(i*32,192,32,32)
		frames.append(texture)
	var atlas_mask := AtlasTexture.new()
	atlas_mask.atlas = ART; atlas_mask.region = Rect2(192,192,32,32)
	mask = ImageTexture.create_from_image(atlas_mask.get_image())
	pose = Sprite2D.new()
	pose.name = "PhonePose"
	pose.centered = false
	pose.position = Vector2(-16,-32)
	pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.visual.add_child(pose)
	pose.texture = frames[0]
	glow_alpha = FLICKER.pick(CONFIG.bedroom_chr_glow_alpha_normal_min,CONFIG.bedroom_chr_glow_alpha_normal_max,rng)
	_schedule_flicker()
	_sync_capture()

func _schedule_flicker() -> void:
	next_flicker = FLICKER.pick(maxf(CONFIG.bedroom_chr_glow_interval_min,.05),maxf(CONFIG.bedroom_chr_glow_interval_max,.05),rng)

func begin_close() -> void:
	closing = true
	close_elapsed = 0.0
	close_start_frame = mini(frame_index,3)

func advance(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(pose): return
	elapsed += delta
	if closing:
		close_elapsed += delta
		frame_index = maxi(0,close_start_frame-int(close_elapsed/FRAME_SECONDS))
	elif elapsed < FRAME_SECONDS*4:
		frame_index = mini(3,int(elapsed/FRAME_SECONDS))
	else:
		frame_index = 4 + int((elapsed-FRAME_SECONDS*4)/LOOP_SECONDS)%2
	pose.texture = frames[frame_index]
	next_flicker -= delta
	if next_flicker <= 0:
		glow_alpha = FLICKER.next_alpha(CONFIG,glow_alpha,rng)
		_schedule_flicker()
	_sync_capture()

func _sync_capture() -> void:
	var bridge: Node = world.player_depth_bridge if is_instance_valid(world) else null
	if not is_instance_valid(bridge): return
	bridge._process(0.0)
	var copies: Array[Node] = bridge.render_root.find_children("PhonePose","Sprite2D",true,false)
	if copies.is_empty(): return
	var copy: Sprite2D = copies[0]
	var inverse: Transform2D = copy.global_transform.affine_inverse()
	emission_material = bridge.lit_material
	if not is_instance_valid(emission_material): return
	emission_material.set_shader_parameter("phone_glow_mask",mask)
	emission_material.set_shader_parameter("phone_glow_origin",copy.global_transform.origin)
	emission_material.set_shader_parameter("phone_glow_inverse",Vector4(inverse.x.x,inverse.x.y,inverse.y.x,inverse.y.y))
	emission_material.set_shader_parameter("phone_glow_strength",glow_alpha if frame_index>=2 else 0.0)
	emission_material.set_shader_parameter("phone_glow_enabled",frame_index>=2)

func release() -> void:
	if is_instance_valid(emission_material):
		emission_material.set_shader_parameter("phone_glow_enabled",false)
		emission_material.set_shader_parameter("phone_glow_strength",0.0)
	for record in snapshots:
		var node: CanvasItem = record.node.get_ref()
		if is_instance_valid(node): node.visible = record.visible
	snapshots.clear()
	if is_instance_valid(pose): pose.free()
	if is_instance_valid(world) and world.is_inside_tree() and is_instance_valid(world.player_depth_bridge) and world.player_depth_bridge.is_inside_tree(): world.player_depth_bridge._process(0.0)
