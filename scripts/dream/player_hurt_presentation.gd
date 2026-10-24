extends Node
## Effective player damage only. No combat timers, motion or damage ownership.
const WORDS: Array[String]=["好痛！","我丢！","哎哟！","疼啊！"]
const INK:=Color("edf2ff")
const DARK:=Color("121525")
const FONT=preload("res://scripts/ui/crisp_interaction_font.gd")
const COMIC=preload("res://scripts/ui/comic_pixel_text.gd")
const LIFETIME:=.85
const SHOCK_SECONDS:=.30
var world: Node3D
var player: Node2D
var age:=1.0
var phrase:=""
var last_word:=-1
var emitted:=0
var rng:=RandomNumberGenerator.new()
var stars: Array[Dictionary]=[]
var bursts: Array[Dictionary]=[]
var hit_world:=Vector3.ZERO
var layer: CanvasLayer
var surface: Control
var word_shadow: Control
var post_layer: CanvasLayer
var post_rect: ColorRect
var shock: ShaderMaterial
var post_copy: BackBufferCopy

func configure(owner_world: Node3D) -> void:
	world=owner_world; player=world.player
	process_mode=Node.PROCESS_MODE_ALWAYS; process_priority=50
	rng.randomize(); _claim()
	layer=CanvasLayer.new(); layer.name="PlayerHurtFeedbackHUD"; layer.layer=38; add_child(layer)
	surface=Control.new(); surface.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(surface)
	surface.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	word_shadow=Control.new(); word_shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	word_shadow.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(word_shadow); layer.move_child(word_shadow,0)
	var halftone:=ShaderMaterial.new()
	halftone.shader=preload("res://shaders/player_hurt_word_halftone.gdshader")
	word_shadow.material=halftone; word_shadow.draw.connect(_draw_word_shadows)
	surface.draw.connect(_draw_feedback)
	# Palette is layer 18. Re-copy its finished result before this later pass:
	# two screen-reading shaders must not silently reuse the pre-palette buffer.
	post_layer=CanvasLayer.new(); post_layer.name="PlayerHurtWorldShock"; post_layer.layer=19
	post_layer.set_meta(&"world_post_effect",true); add_child(post_layer)
	post_copy=BackBufferCopy.new(); post_copy.copy_mode=BackBufferCopy.COPY_MODE_DISABLED; post_layer.add_child(post_copy)
	post_rect=ColorRect.new(); post_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	post_layer.add_child(post_rect); post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shock=ShaderMaterial.new(); shock.shader=preload("res://shaders/player_hurt_shock.gdshader"); post_rect.material=shock
	post_rect.hide(); layer.hide()
	player.effective_damage_taken.connect(_on_damage)
	player.died.connect(clear)

func _claim() -> void:
	if is_instance_valid(player): player.set_meta(&"stylized_player_hurt",weakref(self))
func _owns_player() -> bool:
	if not is_instance_valid(player): return false
	var reference: Variant=player.get_meta(&"stylized_player_hurt",null)
	return reference is WeakRef and reference.get_ref()==self
func _active() -> bool:
	return is_instance_valid(world) and is_instance_valid(player) and is_inside_tree() and world.get("floor_root")==get_parent() and not get_tree().paused and world.get("floor_transition_in_progress")!=true and world.get("elevator_transition_in_progress")!=true
func _on_damage(amount: float) -> void:
	if amount<=0 or not _active() or player.dead: return
	_claim(); age=0; emitted+=1
	last_word=(last_word+rng.randi_range(1,WORDS.size()-1))%WORDS.size()
	phrase=WORDS[last_word]; stars=[]
	hit_world=_hit_world()
	var camera: Camera3D=world.camera_3d
	var depth:=maxf(.1,-(camera.global_transform.affine_inverse()*hit_world).z)
	var projected:=camera.unproject_position(hit_world)
	var viewport_size:=camera.get_viewport().get_visible_rect().size
	var hud_width: float=player.get_presentation_hud_position(viewport_size).x-player.get_presentation_hud_position(Vector2.ZERO).x
	var pixel_world:=camera.project_position(projected+Vector2(viewport_size.x/maxf(1,hud_width),0),depth).distance_to(hit_world)
	for i in 6:
		var angle:=TAU*float(i)/6.0+rng.randf_range(-.2,.2)
		stars.append({"direction":Vector2.from_angle(angle),"speed":rng.randf_range(22,38),"radius":rng.randf_range(2,4),"spin":rng.randf_range(-3,3)})
	bursts.append({"origin":hit_world,"right":camera.global_basis.x.normalized(),"up":camera.global_basis.y.normalized(),"units":pixel_world,"age":0.0,"phrase":phrase,"stars":stars})
	if bursts.size()>4: bursts.pop_front()
	if is_instance_valid(player.visual): player.visual.visible=true
	_update_pose(); layer.show(); surface.queue_redraw(); word_shadow.queue_redraw()
func _process(delta: float) -> void:
	if not _active() or player.dead: clear(); return
	if age>=LIFETIME and bursts.is_empty(): return
	age+=delta
	for burst in bursts: burst.age+=delta
	bursts=bursts.filter(func(burst: Dictionary) -> bool: return burst.age<LIFETIME)
	_update_pose()
	if age>=LIFETIME: clear()
	surface.queue_redraw()
	word_shadow.queue_redraw()
func _update_pose() -> void:
	if not _owns_player() or not is_instance_valid(world) or not is_instance_valid(player.visual): return
	var scale_offset:=0.0
	if age<.09: scale_offset=.2*(1.0-age/.09)
	elif age<.28: scale_offset=-.09*sin((age-.09)/.19*PI)
	player.visual.scale=Vector2(1.0+scale_offset,1.0-scale_offset)*player.character_visual_scale
	var bridge: Variant=world.get("player_depth_bridge")
	if is_instance_valid(bridge):
		for material in [bridge.get("lit_material"),bridge.get("attachment_sprite").material_override if is_instance_valid(bridge.get("attachment_sprite")) else null]:
			if material is ShaderMaterial: material.set_shader_parameter("hurt_flash_amount",1.0 if age<.07 else 0.0)
	post_rect.visible=age<SHOCK_SECONDS
	post_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT if age<SHOCK_SECONDS else BackBufferCopy.COPY_MODE_DISABLED
	shock.set_shader_parameter("strength",pow(maxf(0,1.0-age/SHOCK_SECONDS),1.4))
	shock.set_shader_parameter("phase",age/SHOCK_SECONDS)
	var settings:=get_node_or_null("/root/SettingsManager")
	shock.set_shader_parameter("distort_strength",1.0 if settings==null or settings.get_setting(&"screen_shake_enabled",true) else 0.0)
	if age>=SHOCK_SECONDS: return
	var camera: Camera3D=world.camera_3d
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return
	shock.set_shader_parameter("hit_center",camera.unproject_position(hit_world)/camera.get_viewport().get_visible_rect().size)
func _hit_world() -> Vector3:
	var bridge: Variant=world.get("player_depth_bridge")
	if is_instance_valid(bridge) and bridge.has_method("get_hit_feedback_world_position"):
		return bridge.get_hit_feedback_world_position()
	return world.get_gameplay_world_position(player.global_position,.8)
func clear() -> void:
	age=1; stars.clear(); bursts.clear()
	if is_instance_valid(layer): layer.hide()
	if is_instance_valid(post_rect): post_rect.hide()
	if is_instance_valid(post_copy): post_copy.copy_mode=BackBufferCopy.COPY_MODE_DISABLED
	if _owns_player(): _update_pose()
func _draw_feedback() -> void:
	if bursts.is_empty() or not _active(): return
	for burst in bursts: _draw_burst(burst)
func project_feedback(point: Vector3) -> Vector2:
	return player.get_presentation_hud_position(world.camera_3d.unproject_position(point))
func star_world_position(burst: Dictionary,star: Dictionary) -> Vector3:
	var t: float=burst.age
	var offset: Vector2=star.direction*(10+star.speed*t)+Vector2(0,t*t*35)
	return burst.origin+(burst.right*offset.x-burst.up*offset.y)*burst.units
func word_world_position(burst: Dictionary) -> Vector3:
	var t: float=burst.age
	return burst.origin+burst.up*burst.units*(22+t*20+4*sin(minf(t/.15,1)*PI))
func _draw_burst(burst: Dictionary) -> void:
	var point: Vector3=burst.origin
	if world.camera_3d.is_position_behind(point): return
	var at:=project_feedback(point)
	var t: float=burst.age
	var fade:=clampf((LIFETIME-t)/.25,0,1)
	if t<.16:
		var flare:=PackedVector2Array()
		for i in 16:
			var radius: float=(19 if i%2==0 else 8)*(1.0-t/.2)
			flare.append((at+Vector2.from_angle(TAU*i/16.0)*radius).round())
		surface.draw_colored_polygon(flare,Color(INK,1.0-t/.16))
	for star in burst.stars:
		var star_world:=star_world_position(burst,star)
		if world.camera_3d.is_position_behind(star_world): continue
		var center:=project_feedback(star_world).round()
		var pixel_scale:=project_feedback(star_world+burst.right*burst.units).distance_to(project_feedback(star_world))
		var shape:=PackedVector2Array()
		for i in 8:
			var radius: float=star.radius*(1 if i%2==0 else .3)*pixel_scale
			# The centre is pixel-snapped; preserve tip geometry so small rotating
			# stars never collapse into duplicate vertices during triangulation.
			shape.append(center+Vector2.from_angle(TAU*i/8.0+t*star.spin)*radius)
		surface.draw_colored_polygon(shape,Color(INK,fade))
		surface.draw_polyline(shape+PackedVector2Array([shape[0]]),Color(DARK,fade),1,false)
	_draw_words(surface,burst,false)

func _draw_word_shadows() -> void:
	if bursts.is_empty() or not _active(): return
	for burst in bursts: _draw_words(word_shadow,burst,true)

## Deterministic per-character poses; no gameplay RNG or moving-player anchor.
func word_glyph_pose(t: float,index: int) -> Dictionary:
	return COMIC.glyph_pose(t,index)

func _draw_words(target: Control,burst: Dictionary,shadow_pass: bool) -> void:
	if world.camera_3d.is_position_behind(burst.origin): return
	COMIC.draw(target,burst.phrase,project_feedback(word_world_position(burst)).round(),burst.age,shadow_pass)
func _enter_tree() -> void: _claim()
func _exit_tree() -> void:
	clear()
	if _owns_player(): player.remove_meta(&"stylized_player_hurt")
func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and is_instance_valid(layer): layer.queue_free()
