extends Node3D
## One live 2D gameplay owner, passive visual copies, one depth-tested carrier.
## No duplicated movement, timers, damage, groups, signals, or collision.
const PIXELS_PER_WORLD_CELL := 32.0
const CHARACTER_PROJECTION := preload("res://scripts/dream/character_visual_projection.gd")
const ACTOR_VOLUME_SHADOW := preload("res://scripts/dream/actor_volume_shadow.gd")
static var _character_no_shadow_shader: Shader
## Formal Player/Enemy visual carriers share one receiver layer.  The Player's
## shadow-only carrier stays separate because a Light3D cull mask applies to
## both receivers and shadow casters; this lets the flashlight illuminate the
## Player while excluding only the Player shadow from that light.
const CHARACTER_VISUAL_LAYER := 2
const PLAYER_SHADOW_LAYER := 4
const VISUAL_CONFIG: Resource = preload("res://resources/demo_config.tres")
const CHARACTER_EMISSION_FALLBACK := 0.045
const DEFAULT_SOURCE_PATHS: Array[NodePath] = [^"CharacterVisual", ^"HealOverlay", ^"WeaponRoot", ^"PlayerHPBar"]
var source_actor: Node2D
var render_viewport: SubViewport
var render_root: Node2D
var _snapshot_capture_refresh_pending := false
var actor_sprite: Sprite3D
## 正式 World Camera 的显式引用。bridge 的 2D capture 走 SubViewport，
## 其所在 Viewport 不一定持有当前 3D 相机，因此显式持有引用，
## 未设置时才回退 get_viewport().get_camera_3d()。
var world_camera: Camera3D
var source_roots: Array[Node2D] = []
var clone_roots: Array[Node2D] = []
var source_paths: Array[NodePath] = DEFAULT_SOURCE_PATHS.duplicate()
var configured := false
var actor_center_height := 0.70710678
var actor_center_depth_offset := -0.70710678
var viewport_offset := Vector2(64, 96)
var billboard_mode: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_ENABLED
var plane_rotation := Vector3.ZERO
var disable_clone_processing := true
var ground_only := false
var outline_material: ShaderMaterial
var floor_contact_lift := 0.0
var lowest_visible_pixel := 0.0
var lit_material: ShaderMaterial
var blood_material: ShaderMaterial
var projectile_material: ShaderMaterial
var feedback_material: ShaderMaterial
## Presentation-only charge effects use the same semantic carrier as Blood, but
## with their own reserved red marker.  The marker deliberately uses only
## 0/1 channels: Compatibility can convert non-extreme colours while sampling
## the final screen, but pure red remains an identity value in either space.
const CHARGE_SEMANTIC_MARKER := Vector3(1.0, 0.0, 0.0) # #FF0000
## Camera-facing presentation is explicit for muzzle/projectile carriers.  The
## built-in Sprite3D billboard can choose a slightly different basis for two
## carriers created in different frames, which is enough to make a projectile
## look detached from its muzzle in the perspective view.
var camera_plane_visual := false
var shadow_proxy: Sprite3D
## A tiny real Light3D is presentation-only. It is created only for the
## formal Player/Enemy carriers, never for furniture, blood, or UI.
var character_local_light: OmniLight3D
var character_local_light_enabled := false
var character_local_light_height := 0.22
const CHARACTER_LOCAL_LIGHT_RECEIVER_MASK := 1 | CHARACTER_VISUAL_LAYER
## Actors that already expose the formal 2D `Shadow` sprite have a dedicated
## ground-contact shadow bridge.  Keep the legacy ShadowProxy node for the
## lighting/test contract, but do not also cast the entire upright actor
## capture onto the floor; that produces the oversized, displaced silhouette
## visible beside the intended ground ellipse.
var shadow_proxy_enabled := true
## Explicit office-only opt-in, assigned by the owning world before configure.
var volume_shadow_enabled := false
var volume_shadow: Node3D
## 血迹等永久静态视觉的生命周期：settle 后停止完整 _process，仅保留必要同步。
## STATIC_FROZEN = Floor/静态 Wall 血（捕获与 transform 均冻结）；
## TRANSFORM_ONLY = Door 血（capture 冻结，transform 轻量跟随门叶）。
var static_visual_frozen := false
var transform_only := false
var freeze_pending := false
var wake_frames := 0
var follow_source_rotation := false
var last_static_signature := 0
var capture_initialized := false
var room_presentation_active := true
var furniture_capture_pending := false
var furniture_capture_epoch := 0
var furniture_capture_callback: Callable
static var opaque_rect_cache: Dictionary = {}
var character_projection := false
var weapon_sprite: Sprite3D
var weapon_material: ShaderMaterial
var attachment_sprite: Sprite3D
var layer_viewports: Array[SubViewport] = []
var weapon_capture_root: Node2D
var attachment_capture_root: Node2D
var body_contact_local := Vector2.ZERO
var contact_scale := Vector2.ZERO
var grip_local := Vector2.ZERO
var weapon_reference_height := 0.0
var weapon_capture_rotation_delta := 0.0
var body_reference_origin := Vector3.ZERO
var body_reference_normal := Vector3.FORWARD
var projectile_pool_release: Callable
var shared_capture_managed := false
var capture_atlas_release: Callable
var _cached_character_visual: Node2D
var _cached_weapon_root: Node2D
var _cached_projectile_origin: Node2D
var _cached_projectile_origin_resolved := false
var _cached_collision_shape: Node2D
var _cached_collision_shape_resolved := false
var _cached_shadow_node: Node2D
var _cached_shadow_node_resolved := false
var _cached_bullet_sprite: Node2D
var _cached_bullet_sprite_resolved := false
var _cached_height_prop: StringName = &""
var _cached_height_prop_resolved := false
var _cached_is_enemy := false
var _cached_static_capture_source := false
var _cached_room_gated_prop := false
var _cached_is_player := false
var _last_source_actor_child_count: int = -1
var _last_corpse_body_transform := Transform2D()
var _last_corpse_copy_transform := Transform2D()
var _corpse_contact_cached := false
var _cached_lowest_visible_pixel := 0.0
var _last_body_plane_origin := Vector3(INF, INF, INF)
var _last_body_plane_normal := Vector3(INF, INF, INF)
var _last_weapon_plane_height: float = INF
var _last_shot_plane_origin := Vector3(INF, INF, INF)
var _last_shot_plane_normal := Vector3(INF, INF, INF)
var _cached_unversioned_draw_roots: Dictionary = {}


func _refresh_static_source_flags() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		_cached_static_capture_source = ground_only
		_cached_room_gated_prop = false
		return
	_cached_static_capture_source = (
		ground_only
		or source_actor.is_in_group(&"environment_debris")
		or source_actor.is_in_group(&"damageable_props")
		or source_actor.is_in_group(&"black_blood_stains")
	)
	_cached_room_gated_prop = (
		source_actor.is_in_group(&"damageable_props")
		and source_actor.has_method("set_room_runtime_active")
	)


func _reset_actor_node_caches() -> void:
	_cached_character_visual = null
	_cached_weapon_root = null
	_cached_projectile_origin = null
	_cached_projectile_origin_resolved = false
	_cached_collision_shape = null
	_cached_collision_shape_resolved = false
	_cached_shadow_node = null
	_cached_shadow_node_resolved = false
	_cached_bullet_sprite = null
	_cached_bullet_sprite_resolved = false
	_cached_height_prop = &""
	_cached_height_prop_resolved = false
	_cached_is_enemy = source_actor != null and is_instance_valid(source_actor) and source_actor.is_in_group(&"dream_enemies")
	_cached_is_player = source_actor != null and is_instance_valid(source_actor) and source_actor.is_in_group(&"dream_player")
	_last_source_actor_child_count = -1
	_corpse_contact_cached = false
	_cached_lowest_visible_pixel = 0.0
	_last_body_plane_origin = Vector3(INF, INF, INF)
	_last_body_plane_normal = Vector3(INF, INF, INF)
	_last_weapon_plane_height = INF
	_last_shot_plane_origin = Vector3(INF, INF, INF)
	_last_shot_plane_normal = Vector3(INF, INF, INF)
	_cached_unversioned_draw_roots.clear()
	if source_actor != null and is_instance_valid(source_actor):
		_cached_character_visual = source_actor.get_node_or_null(^"CharacterVisual") as Node2D
		_cached_weapon_root = source_actor.get_node_or_null(^"WeaponRoot") as Node2D
		_cached_collision_shape = source_actor.get_node_or_null(^"CollisionShape2D") as Node2D
		_cached_collision_shape_resolved = true
		_cached_shadow_node = source_actor.get_node_or_null(^"Shadow") as Node2D
		_cached_shadow_node_resolved = true

func _notification(what: int) -> void:
	# Reparenting during floor stash also emits tree_exiting; only actual
	# deletion releases an atlas cell. The floor atlas may already be gone.
	if what==NOTIFICATION_PREDELETE and capture_atlas_release.is_valid():
		capture_atlas_release.call()

## Reuse only an already-configured projectile carrier. Character/blood
## captures never enter this pool; their state and ownership stay unchanged.
func rebind_projectile(source: Node2D, camera: Camera3D, height: float, depth: float) -> void:
	_rebind_capture(source, camera, height, depth, [source.get_node(^"BulletSprite")])

func rebind_muzzle(source: Node2D, camera: Camera3D, height: float, depth: float) -> void:
	_rebind_capture(source, camera, height, depth, [source])

func rebind_feedback(source: Node2D, camera: Camera3D) -> void:
	# Pool slots were created with a legacy dummy. Rebinding must update their
	# depth/material policy too, not just the source position and captured pixels.
	var projected_hit:=source.has_meta(&"hit_reference_plane_origin")
	if projected_hit:
		prepare_feedback_material()
		projectile_material=feedback_material
		actor_sprite.material_override=feedback_material
	else:
		projectile_material=null
		actor_sprite.material_override=null
	camera_plane_visual=bool(source.get_meta(&"depth_visual_camera_plane",false))
	actor_sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED if camera_plane_visual else billboard_mode
	_rebind_capture(source, camera, float(source.get_meta(&"feedback_height",0.14)), 0.0, [source])

func prepare_feedback_material() -> void:
	if feedback_material!=null: return
	feedback_material=ShaderMaterial.new()
	feedback_material.shader=preload("res://shaders/dream3d/hit_feedback_carrier.gdshader")
	feedback_material.set_shader_parameter("capture_texture",render_viewport.get_texture())

func rebind_floor_object(source: Node2D, camera: Camera3D, path: NodePath) -> void:
	# A prior settled object may have frozen its target. Reset its signature so
	# the next owner gets a first capture even when both sprites share a frame.
	request_capture_refresh()
	_rebind_capture(source,camera,actor_center_height,actor_center_depth_offset,[source.get_node(path)])

func rebind_blood_ground(source: Node2D, camera: Camera3D, height: float) -> void:
	# Unlike transient feedback, blood may have frozen its capture or enlarged
	# it after consolidation. New ownership must force a fresh static capture.
	plane_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	follow_source_rotation = false
	if actor_sprite != null:
		actor_sprite.rotation = plane_rotation
	request_capture_refresh()
	_rebind_capture(source,camera,height,0.0,[source])

func rebind_blood_surface(source: Node2D, camera: Camera3D, height: float, requested_plane_rotation: Vector3, requested_follow_source_rotation: bool = false) -> void:
	plane_rotation = requested_plane_rotation
	follow_source_rotation = requested_follow_source_rotation
	if actor_sprite != null:
		actor_sprite.rotation = plane_rotation
	request_capture_refresh()
	_rebind_capture(source, camera, height, 0.0, [source])
	if source.has_method("is_visual_settled") and source.is_visual_settled():
		freeze_pending = true
		if follow_source_rotation:
			transform_only = true

func rebind_shell(source: Node2D, camera: Camera3D) -> void:
	_rebind_capture(source, camera, 0.1, 0.0, [source.get_node(^"ShellSprite")])

func _rebind_capture(source: Node2D, camera: Camera3D, height: float, depth: float, roots: Array) -> void:
	source_actor = source
	_reset_actor_node_caches()
	world_camera = camera
	actor_center_height = height
	actor_center_depth_offset = depth
	source_roots.clear()
	source_roots.assign(roots)
	_last_source_actor_child_count = source_actor.get_child_count() if is_instance_valid(source_actor) else -1
	configured = true
	room_presentation_active = true
	static_visual_frozen = false
	transform_only = false
	freeze_pending = false
	_refresh_static_source_flags()
	set_meta(&"source_actor", source)
	source.tree_exiting.connect(_on_source_tree_exiting, CONNECT_ONE_SHOT)
	set_process(true)
	_process(0.0)

func suspend_projectile() -> void:
	configured = false
	set_process(false)
	actor_sprite.hide()
	if shadow_proxy != null: shadow_proxy.hide()
	render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for copy in clone_roots: copy.hide()
	source_roots.clear()
	source_actor = null
	_reset_actor_node_caches()
	remove_meta(&"source_actor")

func configure(source: Node2D, viewport: SubViewport, root: Node2D,
		hide_source_canvas: CanvasLayer = null, requested_source_paths: Array = [],
		requested_center_height: float = 0.70710678, requested_depth_offset: float = -0.70710678,
		requested_viewport_offset: Vector2 = Vector2(64, 96),
		requested_billboard_mode: BaseMaterial3D.BillboardMode = BaseMaterial3D.BILLBOARD_ENABLED,
		requested_plane_rotation: Vector3 = Vector3.ZERO, _requested_disable_clone_processing: bool = false,
		requested_force_lit: bool = false, requested_follow_source_rotation: bool = false) -> void:
	source_actor = source
	_reset_actor_node_caches()
	render_viewport = viewport
	render_root = root
	if not requested_source_paths.is_empty():
		source_paths.clear()
		for path in requested_source_paths:
			if path is NodePath or path is String:
				source_paths.append(NodePath(path))
	if source_paths.has(^"CharacterVisual"):
		for extra in [^"EnemyHPBar", ^"EmojiAnchor"]:
			if source.has_node(extra) and not source_paths.has(extra):
				source_paths.append(extra)
	actor_center_height = requested_center_height
	actor_center_depth_offset = requested_depth_offset
	viewport_offset = requested_viewport_offset
	billboard_mode = requested_billboard_mode
	plane_rotation = requested_plane_rotation
	follow_source_rotation = requested_follow_source_rotation
	ground_only = source_paths.size() == 1 and String(source_paths[0]) == "Shadow"
	_refresh_static_source_flags()
	if source_actor == null or render_viewport == null or render_root == null:
		return
	character_projection = source_paths.has(^"CharacterVisual") and (
		_cached_is_player or _cached_is_enemy)
	if character_projection:
		var weapon_root := _cached_weapon_root
		grip_local = weapon_root.position if weapon_root != null else Vector2(0, -18)
	shadow_proxy_enabled = _cached_shadow_node == null
	if volume_shadow_enabled and character_projection:
		shadow_proxy_enabled = false
	source_actor.tree_exiting.connect(_on_source_tree_exiting, CONNECT_ONE_SHOT)
	actor_sprite = Sprite3D.new()
	actor_sprite.name = "DepthVisual"
	actor_sprite.texture = render_viewport.get_texture()
	actor_sprite.pixel_size = 1.0 / PIXELS_PER_WORLD_CELL
	actor_sprite.billboard = billboard_mode
	actor_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	actor_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	actor_sprite.alpha_scissor_threshold = 0.05
	# Player and Enemy body/held-weapon pixels share one formal receiver layer.
	# Environment geometry remains on layer 1; directional room/window lights can
	# therefore target characters without producing the old floor cone artifact.
	if source_paths.has(^"CharacterVisual") and (
		source_actor.is_in_group(&"dream_player")
		or source_actor.is_in_group(&"dream_enemies")
	):
		actor_sprite.layers = CHARACTER_VISUAL_LAYER
	var blood_visual := _is_blood_source()
	var charge_semantic_visual := _is_charge_semantic_source()
	# Effects/ground overlays stay emissive; real pixel objects receive lighting
	# and use alpha-cut silhouettes in the light's shadow pass, not quad shadows.
	var solid_visual := not ground_only and (source_paths.has(^"CharacterVisual") or source_paths.has(^"Sprite2D") or source_paths.has(^"WeaponSprite"))
	# Non-character effects such as spent casings still use the optional lit
	# carrier. Blood is the exception: it stays in the same world/depth buffer,
	# but uses its own unshaded semantic material below so lighting cannot alter
	# its identity marker.
	# Blood is intentionally not sent through the shared lit carrier.  It keeps
	# the main-world Sprite3D/depth path, but writes a reserved semantic marker
	# for the final palette pass instead of a light-dependent RGB colour.
	# Projectile tracer carriers are intentionally unshaded.  The projectile's
	# gameplay Node2D marks this presentation-only path before registration, so
	# a moving bullet never creates a dynamic Light3D-like lighting dependency or
	# gets dimmed by a room light.  All other visual carriers retain their normal
	# lighting policy.
	var unshaded_visual := bool(source_actor.get_meta(&"depth_visual_unshaded", false))
	var projectile_self_emission := bool(source_actor.get_meta(&"projectile_self_emission", false))
	camera_plane_visual = projectile_self_emission or bool(source_actor.get_meta(&"depth_visual_camera_plane", false))
	var lit_visual := not blood_visual and not charge_semantic_visual and not unshaded_visual and (solid_visual or requested_force_lit)
	actor_sprite.shaded = lit_visual
	# 可见精灵只受光、永不进 shadow pass：掠射手电下的像素 alpha 自阴影条纹
	# （摩尔纹）由这一刀切断。投影改由下方 SHADOWS_ONLY 孪生代理负责。
	actor_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if projectile_self_emission or source_actor.has_meta(&"shot_visual_origin"):
		# Projectile heads/tracers stay presentation-only and unshaded, but use a
		# dedicated spatial carrier so their captured pixels remain visibly bright
		# in a dark room.  This is still fed by the same 2D BulletSprite capture;
		# no gameplay origin or per-weapon visual offset is introduced here.
		projectile_material = ShaderMaterial.new()
		projectile_material.shader = preload("res://shaders/dream3d/projectile_emissive_carrier.gdshader")
		projectile_material.set_shader_parameter("capture_texture", render_viewport.get_texture())
		var projectile_emission_variant: Variant = VISUAL_CONFIG.get(&"projectile_self_emission_strength")
		var projectile_emission_strength: float = 0.85
		if projectile_emission_variant != null:
			projectile_emission_strength = clampf(float(projectile_emission_variant), 0.0, 2.0)
		projectile_material.set_shader_parameter(
			"projectile_emission_strength",
			projectile_emission_strength
		)
		actor_sprite.material_override = projectile_material
		actor_sprite.shaded = false
		# Keep the projectile on the same camera-facing plane as the formal muzzle
		# effect. The height/depth anchor is supplied by add_projectile; the
		# upright Player/Enemy baseline is intentionally not inferred here because
		# it would lift the bullet away from the muzzle in perspective projection.
		actor_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	elif camera_plane_visual:
		# Muzzle flashes use the same explicit camera plane as projectiles.  Keep
		# this local to these visual carriers; ordinary actor/furniture bridges
		# retain their existing billboard policy.
		actor_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	elif blood_visual or charge_semantic_visual:
		blood_material = ShaderMaterial.new()
		blood_material.shader = preload("res://shaders/dream3d/blood_semantic_carrier.gdshader")
		blood_material.set_shader_parameter("capture_texture", render_viewport.get_texture())
		blood_material.set_shader_parameter(
			"semantic_marker",
			Vector3(0.8509804, 0.4196078, 0.0941176) if blood_visual else CHARGE_SEMANTIC_MARKER
		)
		actor_sprite.material_override = blood_material
		actor_sprite.shaded = false
	elif lit_visual:
		lit_material = ShaderMaterial.new()
		var is_character := source_actor.is_in_group(&"dream_player") or source_actor.is_in_group(&"dream_enemies")
		var carrier_shader: Shader = preload("res://shaders/dream3d/lit_pixel_carrier.gdshader")
		if volume_shadow_enabled and is_character:
			if _character_no_shadow_shader == null:
				_character_no_shadow_shader = Shader.new()
				_character_no_shadow_shader.code = carrier_shader.code.replace(
					"render_mode cull_disabled,", "render_mode shadows_disabled, cull_disabled,")
			lit_material.shader = _character_no_shadow_shader
		else:
			lit_material.shader = carrier_shader
		lit_material.set_shader_parameter("capture_texture", render_viewport.get_texture())
		# Keep the visibility floor scoped to the formal Player/Enemy gameplay
		# groups. Furniture, weapons, and non-Blood pickups remain ordinary lit
		# objects and never become accidental environment lights.
		var emission_variant: Variant = VISUAL_CONFIG.get(&"character_self_emission_strength")
		var emission_strength := CHARACTER_EMISSION_FALLBACK
		if emission_variant != null:
			emission_strength = clampf(float(emission_variant), 0.0, 1.0)
		lit_material.set_shader_parameter(
			"character_emission_strength",
			emission_strength if is_character else 0.0
		)
		var scale_variant: Variant = VISUAL_CONFIG.get(&"character_light_scale")
		var light_scale := 0.50
		if scale_variant != null:
			light_scale = clampf(float(scale_variant), 0.0, 2.0)
		lit_material.set_shader_parameter(
			"character_light_scale",
			light_scale if is_character else 1.0
		)
		# Furniture is a real visual occluder, while Player/Enemy/weapon/effect
		# carriers are not.  The shared screen-space cutout stays disabled unless
		# the gameplay owner explicitly belongs to the formal prop group.
		lit_material.set_shader_parameter(
			"occlusion_cutout_enabled",
			_should_receive_occlusion_cutout()
		)
		actor_sprite.material_override = lit_material
		# Use the SAME actual plane in camera and shadow passes. Shader billboards
		# can otherwise face the light in a shadow pass and cast a different shape.
		actor_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	actor_sprite.no_depth_test = false
	actor_sprite.rotation = plane_rotation
	add_child(actor_sprite)
	if volume_shadow_enabled and ground_only:
		# Weaken only this passive capture, never the shared 2D Shadow sprite.
		actor_sprite.modulate.a = 0.28
	if volume_shadow_enabled and character_projection:
		volume_shadow = ACTOR_VOLUME_SHADOW.new()
		volume_shadow.name = "ActorVolumeShadow"
		add_child(volume_shadow)
		var player_caster := source_actor.is_in_group(&"dream_player")
		# Keep the player's existing body shadow, without the coarse gun box
		# that projects a detached rod behind the head. Visible gun art is separate.
		volume_shadow.configure(source_actor, PLAYER_SHADOW_LAYER if player_caster else CHARACTER_VISUAL_LAYER, not player_caster)
	if solid_visual:
		# 投影代理：与可见精灵同一 capture、同一 transform 的 SHADOWS_ONLY 孪生。
		# 阴影仍是真实像素剪影（不是整块矩形），与 Actor 对齐、不参与碰撞；
		# HP 条/表情等半透明捕获像素也因此不再向墙面投出噪声影。
		shadow_proxy = Sprite3D.new()
		shadow_proxy.name = "ShadowProxy"
		shadow_proxy.texture = actor_sprite.texture
		shadow_proxy.pixel_size = actor_sprite.pixel_size
		shadow_proxy.billboard = actor_sprite.billboard
		shadow_proxy.texture_filter = actor_sprite.texture_filter
		shadow_proxy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		shadow_proxy.alpha_scissor_threshold = actor_sprite.alpha_scissor_threshold
		shadow_proxy.shaded = false
		shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow_proxy.layers = (
			PLAYER_SHADOW_LAYER
			if source_actor.is_in_group(&"dream_player")
			else actor_sprite.layers
		)
		shadow_proxy.rotation = actor_sprite.rotation
		add_child(shadow_proxy)
		shadow_proxy.visible = shadow_proxy_enabled
	_create_character_local_light()
	if character_projection:
		_create_character_layers()
	if hide_source_canvas != null:
		hide_source_canvas.visible = false
	configured = true
	_sync_roots()
	_process(0.0)
	if source_actor.has_method("is_visual_settled") and source_actor.is_visual_settled():
		# 创建时即已 settled 的血迹（如 death pool）：首次捕获完成后冻结。
		freeze_pending = true
		if follow_source_rotation:
			transform_only = true

func enable_furniture_capture_outline() -> void:
	if actor_sprite == null or render_viewport == null:
		return
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://shaders/dream3d/furniture_sprite_outline.gdshader")
	outline.set_shader_parameter("capture_texture", render_viewport.get_texture())
	actor_sprite.material_overlay = outline


func _should_receive_occlusion_cutout() -> bool:
	if source_actor == null or not is_instance_valid(source_actor):
		return false
	# All generated Furniture uses this group.  The metadata escape hatch lets
	# a future authored high visual opt in without changing the bridge contract.
	return source_actor.is_in_group(&"damageable_props") or bool(
		source_actor.get_meta(&"occlusion_cutout_occluder", false)
	)


func _create_character_local_light() -> void:
	# The local light belongs to the formal CharacterVisual carrier, not to every
	# auxiliary bridge that happens to reference a Player/Enemy source.  This
	# excludes the dedicated ground-only Shadow bridge as well as transient
	# single-effect carriers created during combat or presentation rebuilds.
	if ground_only or not source_paths.has(^"CharacterVisual"):
		return
	if source_actor == null or not is_instance_valid(source_actor):
		return
	if not source_actor.is_in_group(&"dream_player") and not source_actor.is_in_group(&"dream_enemies"):
		return
	var enabled_variant: Variant = VISUAL_CONFIG.get(&"character_local_light_enabled")
	character_local_light_enabled = true if enabled_variant == null else bool(enabled_variant)
	if not character_local_light_enabled:
		return
	var energy_variant: Variant = VISUAL_CONFIG.get(&"character_local_light_energy")
	var range_variant: Variant = VISUAL_CONFIG.get(&"character_local_light_range")
	var attenuation_variant: Variant = VISUAL_CONFIG.get(&"character_local_light_attenuation")
	var color_variant: Variant = VISUAL_CONFIG.get(&"character_local_light_color")
	var energy := 0.18 if energy_variant == null else clampf(float(energy_variant), 0.0, 1.0)
	var light_range := 1.25 if range_variant == null else clampf(float(range_variant), 0.10, 3.0)
	var attenuation := 1.0 if attenuation_variant == null else clampf(float(attenuation_variant), 0.0, 2.0)
	var light_color := Color("dceeff")
	if color_variant is Color:
		light_color = color_variant
	character_local_light = OmniLight3D.new()
	character_local_light.name = "CharacterLocalLight"
	character_local_light.omni_range = light_range
	character_local_light.omni_attenuation = attenuation
	character_local_light.light_energy = energy
	character_local_light.light_color = light_color
	character_local_light.light_specular = 0.0
	character_local_light.light_cull_mask = CHARACTER_LOCAL_LIGHT_RECEIVER_MASK
	character_local_light.shadow_enabled = false
	character_local_light.visible = false
	add_child(character_local_light)


func _character_local_light_is_active() -> bool:
	if source_actor == null or not is_instance_valid(source_actor) or source_actor.is_queued_for_deletion():
		return false
	if not source_actor.visible or bool(source_actor.get("dead")):
		return false
	if source_actor.is_in_group(&"dream_enemies"):
		var runtime_active: Variant = source_actor.get("room_runtime_active")
		if runtime_active is bool and not bool(runtime_active):
			return false
	return true


func _update_character_local_light(position_2d: Vector2) -> void:
	if not character_local_light_enabled or character_local_light == null or not is_instance_valid(character_local_light):
		return
	character_local_light.global_position = get_parent_node_3d().to_global(Vector3(
		position_2d.x / PIXELS_PER_WORLD_CELL,
		character_local_light_height,
		position_2d.y / PIXELS_PER_WORLD_CELL
	))
	character_local_light.visible = character_local_light_enabled and _character_local_light_is_active()

func _is_blood_source() -> bool:
	return source_actor != null and is_instance_valid(source_actor) and source_actor.is_in_group(&"black_blood_stains")


func _is_charge_semantic_source() -> bool:
	if source_actor == null or not is_instance_valid(source_actor):
		return false
	# The marker belongs to the explicit visual child, not the Enemy root.  This
	# prevents the normal Enemy body bridge from being treated as a charge
	# carrier when the two bridges coexist.
	for path in source_paths:
		var visual := source_actor.get_node_or_null(path) as Node2D
		if visual != null and bool(visual.get_meta(&"depth_visual_charge_semantic", false)):
			return true
	return false

func set_world_camera(camera: Camera3D) -> void:
	world_camera = camera
	if configured and character_projection:
		_process(0.0)


func _create_character_layers() -> void:
	# Passive captures only: no duplicate Actor, Weapon, AI, timers or inventory.
	for layer_name in ["Weapon", "Attachments"]:
		var viewport := SubViewport.new()
		viewport.name = layer_name + "Capture"
		viewport.size = render_viewport.size
		if layer_name == "Weapon":
			viewport.size = render_viewport.size * 2
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.handle_input_locally = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		layer_viewports.append(viewport)
		var capture := Node2D.new()
		# Extra room for long guns in every direction, without moving the grip.
		capture.position = Vector2(viewport.size - render_viewport.size) * 0.5
		viewport.add_child(capture)
		var sprite := Sprite3D.new()
		sprite.name = layer_name + "Visual"
		sprite.texture = viewport.get_texture()
		sprite.pixel_size = actor_sprite.pixel_size
		sprite.texture_filter = actor_sprite.texture_filter
		sprite.no_depth_test = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.layers = actor_sprite.layers
		add_child(sprite)
		if layer_name == "Weapon":
			weapon_capture_root = capture
			weapon_sprite = sprite
			weapon_material = lit_material.duplicate() as ShaderMaterial
			weapon_material.set_shader_parameter("capture_texture", viewport.get_texture())
			sprite.material_override = weapon_material
		else:
			attachment_capture_root = capture
			attachment_sprite = sprite
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/dream3d/projectile_emissive_carrier.gdshader")
			material.set_shader_parameter("capture_texture", viewport.get_texture())
			material.set_shader_parameter("projectile_emission_strength", 0.0)
			sprite.material_override = material


func _capture_root_for_path(path: NodePath) -> Node2D:
	if not character_projection:
		return render_root
	if path == ^"WeaponRoot":
		return weapon_capture_root
	if path in [^"CharacterVisual", ^"HealOverlay"]:
		return render_root
	return attachment_capture_root


func _character_ground() -> Vector3:
	if not _cached_collision_shape_resolved and source_actor != null and is_instance_valid(source_actor):
		_cached_collision_shape = source_actor.get_node_or_null(^"CollisionShape2D") as Node2D
		_cached_collision_shape_resolved = true
	var collider := _cached_collision_shape if is_instance_valid(_cached_collision_shape) else null
	var point := collider.global_position if collider != null else source_actor.global_position
	return get_parent_node_3d().to_global(Vector3(point.x / PIXELS_PER_WORLD_CELL, 0.0, point.y / PIXELS_PER_WORLD_CELL))


func _refresh_body_contact() -> void:
	if not is_instance_valid(_cached_character_visual) and source_actor != null and is_instance_valid(source_actor):
		_cached_character_visual = source_actor.get_node_or_null(^"CharacterVisual") as Node2D
	var body := _cached_character_visual
	if body == null or contact_scale.is_equal_approx(body.scale.abs()):
		return
	# Bind feet, not the current weapon silhouette. Facing changes do not move Y.
	var bottom := -INF
	for foot_name in [^"LeftFoot", ^"RightFoot"]:
		var foot := body.get_node_or_null(foot_name) as Node2D
		if foot != null:
			bottom = maxf(bottom, _lowest_pixel(foot) - source_actor.global_position.y + _source_fake_height_pixels())
	if is_finite(bottom):
		body_contact_local = Vector2(0.0, bottom)
	contact_scale = body.scale.abs()


func _character_colour_origin(camera: Camera3D, height: float) -> Vector3:
	var contact_in_capture: Vector2
	var is_dead_enemy := _cached_is_enemy and bool(source_actor.get("dead"))
	if is_dead_enemy and lowest_visible_pixel > 0.0:
		# A corpse's feet are no longer its lowest visible point once its body and
		# limbs rotate. Anchor the current opaque silhouette to the floor rather
		# than reusing the standing foot contact cached before death.
		# lowest_visible_pixel is source-local: the capture root adds viewport_offset
		# before the texture is projected on the camera-facing plane.
		contact_in_capture = viewport_offset + Vector2(0.0, lowest_visible_pixel) - Vector2(render_viewport.size) * 0.5
	else:
		_refresh_body_contact()
		contact_in_capture = body_contact_local + viewport_offset - Vector2(render_viewport.size) * 0.5
	var offset := camera.global_basis.orthonormalized() * Vector3(contact_in_capture.x, -contact_in_capture.y, 0.0) / PIXELS_PER_WORLD_CELL
	var contact_clearance := 0.012 if is_dead_enemy else floor_contact_lift
	return _character_ground() + Vector3.UP * (height / PIXELS_PER_WORLD_CELL + contact_clearance) - offset


func _sync_character_planes(camera: Camera3D, height: float) -> void:
	body_reference_origin = _character_ground()
	body_reference_normal = Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
	var body_plane_changed := body_reference_origin != _last_body_plane_origin or body_reference_normal != _last_body_plane_normal
	if body_plane_changed:
		_last_body_plane_origin = body_reference_origin
		_last_body_plane_normal = body_reference_normal
		CHARACTER_PROJECTION.set_material_plane(lit_material, body_reference_origin, body_reference_normal)
		CHARACTER_PROJECTION.set_material_plane(outline_material, body_reference_origin, body_reference_normal)
	# Read the authored grip authority, not the enemy's animated orbit position.
	var enemy_grip: Variant = source_actor.get("weapon_root_base_position")
	var config: Variant = source_actor.get("runtime_config")
	if enemy_grip is Vector2:
		grip_local = enemy_grip
	elif config is Resource:
		var configured_grip: Variant = config.get("player_weapon_root_offset")
		if configured_grip is Vector2:
			grip_local = configured_grip
	# Pixels below the feet represent forward reach in X/Z, not negative height.
	var grip_capture := grip_local + viewport_offset - Vector2(render_viewport.size) * 0.5
	var grip_world := actor_sprite.global_transform * (Vector3(grip_capture.x, -grip_capture.y, 0.0) / PIXELS_PER_WORLD_CELL)
	weapon_reference_height = maxf(grip_world.y, height / PIXELS_PER_WORLD_CELL + 0.05)
	weapon_sprite.global_transform = actor_sprite.global_transform
	attachment_sprite.global_transform = actor_sprite.global_transform
	if weapon_reference_height != _last_weapon_plane_height:
		_last_weapon_plane_height = weapon_reference_height
		CHARACTER_PROJECTION.set_material_plane(weapon_material, Vector3(0, weapon_reference_height, 0), Vector3.UP)
		CHARACTER_PROJECTION.set_material_plane(weapon_sprite.material_overlay as ShaderMaterial, Vector3(0, weapon_reference_height, 0), Vector3.UP)
	if body_plane_changed:
		CHARACTER_PROJECTION.set_material_plane(attachment_sprite.material_override as ShaderMaterial, body_reference_origin, body_reference_normal)


## Camera-facing hit point on the visible torso, with a small depth clearance.
func get_hit_feedback_world_position() -> Vector3:
	var camera:=_active_world_camera()
	if camera==null or source_actor==null: return actor_sprite.global_position
	var torso:=source_actor.get_node_or_null(^"CharacterVisual/BodyPivot/Body") as Sprite2D
	if torso==null: return actor_sprite.global_position
	var point:=source_actor.to_local(torso.to_global(_opaque_rect(torso).get_center()))
	var capture:=point+viewport_offset-Vector2(render_viewport.size)*.5
	var basis:=camera.global_basis.orthonormalized()
	return _character_colour_origin(camera,_source_fake_height_pixels())+basis*Vector3(capture.x,-capture.y,0)/PIXELS_PER_WORLD_CELL+basis.z*.035

func get_hit_feedback_depth_plane() -> Dictionary:
	var camera:=_active_world_camera()
	if camera==null: return {}
	var normal:=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
	return {"origin":_character_ground()+normal*.04,"normal":normal}

## Floor point directly under the visible prone torso. Collision and fake
## height stay authoritative; only the floor stain attachment uses this point.
func get_corpse_blood_ground_position() -> Vector2:
	var fallback := source_actor.global_position if is_instance_valid(source_actor) else Vector2.ZERO
	var camera := _active_world_camera()
	var map_parent := get_parent_node_3d()
	if not configured or not character_projection or camera == null or map_parent == null:
		return fallback
	var torso := source_actor.get_node_or_null(^"CharacterVisual/BodyPivot/Body") as Sprite2D
	if torso == null or torso.texture == null or not bool(source_actor.get("death_landed")):
		return fallback
	var point := source_actor.to_local(torso.to_global(_opaque_rect(torso).get_center()))
	var capture_point := point + viewport_offset - Vector2(render_viewport.size) * 0.5
	var colour_point := _character_colour_origin(camera, 0.0) + camera.global_basis.orthonormalized() * Vector3(capture_point.x, -capture_point.y, 0.0) / PIXELS_PER_WORLD_CELL
	var screen := camera.unproject_position(colour_point)
	var origin := map_parent.to_local(camera.project_ray_origin(screen))
	var direction := map_parent.global_basis.inverse() * camera.project_ray_normal(screen)
	if absf(direction.y) < 0.00001:
		return fallback
	var floor_point := origin + direction * (-origin.y / direction.y)
	return Vector2(floor_point.x, floor_point.z) * PIXELS_PER_WORLD_CELL


func get_weapon_visual_snapshot(gameplay_point: Vector2) -> Dictionary:
	var camera := _active_world_camera()
	if not character_projection or camera == null or not configured:
		return {}
	if not is_instance_valid(_cached_character_visual) and source_actor != null and is_instance_valid(source_actor):
		_cached_character_visual = source_actor.get_node_or_null(^"CharacterVisual") as Node2D
	var body := _cached_character_visual
	var needs_full_contact := (body != null and absf(body.rotation) >= 0.1) \
		or (_cached_is_enemy and bool(source_actor.get("dead")))
	if needs_full_contact or not source_actor.visible or not room_presentation_active \
		or bool(get_meta(&"test_legacy_snapshot_sync", false)):
		_process(0.0)
	else:
		# Aim iteration needs fresh geometry, not another recursive sprite copy,
		# layer signature, light update and humanoid shadow synchronization.
		# Keep the exact old ordering: heading uses the previous reference height.
		var height := _source_fake_height_pixels()
		weapon_capture_rotation_delta = _weapon_capture_delta(camera)
		floor_contact_lift = 0.0
		lowest_visible_pixel = 0.0
		actor_sprite.global_basis = camera.global_basis.orthonormalized()
		actor_sprite.global_position = _character_colour_origin(camera, height)
		_sync_character_planes(camera, height)
		# A late shot may follow the regular process callback. Refresh passive
		# captures before drawing, once for all snapshots in this message batch.
		var will_process_this_frame := Engine.is_in_physics_frame() and is_inside_tree() and not get_tree().paused and is_processing() and not bool(get_meta(&"test_legacy_pending_refresh", false)) and not has_meta(&"test_snapshot_flush_count")
		if not will_process_this_frame and not _snapshot_capture_refresh_pending:
			_snapshot_capture_refresh_pending = true
			call_deferred("_flush_snapshot_capture_refresh")
	return _weapon_visual_snapshot_synced(gameplay_point, camera)

func _flush_snapshot_capture_refresh() -> void:
	if not _snapshot_capture_refresh_pending: return
	_snapshot_capture_refresh_pending = false
	if not configured or not is_instance_valid(source_actor) or source_actor.is_queued_for_deletion(): return
	if has_meta(&"test_snapshot_flush_count"):
		set_meta(&"test_snapshot_flush_count", int(get_meta(&"test_snapshot_flush_count")) + 1)
	_process(0.0)


func _weapon_visual_snapshot_synced(gameplay_point: Vector2, camera: Camera3D) -> Dictionary:
	var height := _source_fake_height_pixels()
	var height_offset := source_actor.global_transform.basis_xform(Vector2(0, height))
	var half_vp := Vector2(render_viewport.size) * 0.5
	var capture_point := gameplay_point - source_actor.global_position + viewport_offset - half_vp + height_offset
	if not is_instance_valid(_cached_weapon_root) and source_actor != null and is_instance_valid(source_actor):
		_cached_weapon_root = source_actor.get_node_or_null(^"WeaponRoot") as Node2D
	var weapon_root := _cached_weapon_root
	if weapon_root != null:
		var grip_point := weapon_root.global_position - source_actor.global_position + viewport_offset - half_vp + height_offset
		capture_point = grip_point + (capture_point - grip_point).rotated(weapon_capture_rotation_delta)
	var colour_world := actor_sprite.global_transform * (Vector3(capture_point.x, -capture_point.y, 0) / PIXELS_PER_WORLD_CELL)
	var world_point := CHARACTER_PROJECTION.intersect_reference_plane(camera, colour_world, Vector3(0, weapon_reference_height, 0), Vector3.UP)
	return {"world_origin": world_point, "gameplay_origin": gameplay_point, "height": weapon_reference_height}


func _set_character_layer_activity(active: bool) -> void:
	if not character_projection:
		return
	weapon_sprite.visible = active
	attachment_sprite.visible = active
	for viewport in layer_viewports:
		if not active:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			viewport.remove_meta(&"capture_content_signature")
			continue
		if bool(get_meta(&"disable_character_capture_cache", false)):
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			viewport.remove_meta(&"capture_content_signature")
			continue
		var capture := viewport.get_child(0) as Node2D
		# Keep unknown custom drawing live: properties alone cannot describe its
		# pixels. Static sprites/labels need a new capture only when they change.
		if _has_unversioned_capture_draw(capture):
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			continue
		var signature := _character_layer_signature(capture)
		if not viewport.has_meta(&"capture_content_signature") or int(viewport.get_meta(&"capture_content_signature")) != signature:
			viewport.set_meta(&"capture_content_signature", signature)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		# Do not disable a pending UPDATE_ONCE: a shot may synchronize the same
		# bridge several times before frame_post_draw. The renderer consumes it.

func _has_unversioned_capture_draw(node: Node) -> bool:
	if node is CanvasItem and not node.visible:
		return false
	# A canvas shader can animate via TIME or mutate uniforms without changing
	# the sprite's properties. Do not cache that unsupported drawing contract.
	if node is CanvasItem and node.material is ShaderMaterial:
		return true
	if node.has_method("copy_depth_visual_state_to") and not node.has_method("get_capture_content_version"):
		return true
	for child in node.get_children():
		if _has_unversioned_capture_draw(child): return true
	return false


func _character_layer_signature(node: Node) -> int:
	var values: Array = []
	if node is Node2D:
		values.append_array([node.transform, node.visible, node.modulate, node.self_modulate, node.z_index, node.z_as_relative, node.texture_filter, node.material])
		if node.has_method("get_capture_content_version"):
			values.append(node.call("get_capture_content_version"))
	if node is Sprite2D:
		values.append_array([node.texture, node.frame, node.region_rect, node.flip_h, node.flip_v, node.offset, node.region_enabled, node.hframes, node.vframes, node.centered])
	elif node is AnimatedSprite2D:
		values.append_array([node.sprite_frames, node.animation, node.frame, node.flip_h, node.flip_v])
	elif node is Line2D:
		values.append_array([node.points, node.width, node.default_color, node.gradient])
	elif node is Polygon2D:
		values.append_array([node.polygon, node.color])
	elif node is Label:
		values.append_array([node.position, node.size, node.text, node.visible, node.modulate, node.self_modulate, node.theme])
	for child in node.get_children():
		values.append(_character_layer_signature(child))
	return hash(values)


func _active_world_camera() -> Camera3D:
	if world_camera != null and is_instance_valid(world_camera):
		return world_camera
	var vp := get_viewport()
	return vp.get_camera_3d() if vp != null else null


func _make_visual_copy(source: Node2D) -> Node2D:
	var copy: Node2D
	if source.has_method("copy_depth_visual_state_to"):
		# The small custom-draw effect exposes an explicit passive replication API.
		# Construct only its Node2D script, never its gameplay children.
		copy = Node2D.new()
		copy.set_script(source.get_script())
	elif source is Sprite2D or source is AnimatedSprite2D or source is Line2D or source is Polygon2D:
		copy = source.duplicate(0) as Node2D
		for child in copy.get_children():
			copy.remove_child(child)
			child.free()
	else:
		copy = Node2D.new()
	copy.name = source.name
	copy.process_mode = Node.PROCESS_MODE_DISABLED
	if copy.has_method("set_depth_replica"):
		copy.call("set_depth_replica", true)
	# Blood gets a separate dynamic 3D carrier for airborne droplets.  The
	# passive SubViewport copy is therefore explicitly ground/wall-only so it
	# cannot leave a moving ground-plane ghost behind each airborne droplet.
	if _is_blood_source() and source.has_method("copy_depth_visual_state_to"):
		copy.set_meta(&"blood_ground_only_capture", true)
	return copy

func _sync_roots() -> void:
	# Visual branches may change when equipping/dropping; ownership never changes.
	var any_removed := false
	for index in range(source_roots.size() - 1, -1, -1):
		if not is_instance_valid(source_roots[index]) or source_roots[index].is_queued_for_deletion():
			clone_roots[index].free()
			source_roots.remove_at(index)
			clone_roots.remove_at(index)
			any_removed = true
	var current_actor_children := source_actor.get_child_count()
	if not any_removed and not source_roots.is_empty() and current_actor_children == _last_source_actor_child_count:
		return
	_last_source_actor_child_count = current_actor_children
	for path in source_paths:
		var source := source_actor.get_node_or_null(path) as Node2D
		if source == null or source_roots.has(source) or source.is_queued_for_deletion():
			continue
		var copy := _make_visual_copy(source)
		_capture_root_for_path(path).add_child(copy)
		source_roots.append(source)
		clone_roots.append(copy)


func _shot_capture_heading(camera: Camera3D) -> float:
	# Both the tracer and muzzle burst live on camera-facing capture planes.
	# Their 2D gameplay direction must be projected through the current map and
	# camera before the passive capture rotates; otherwise a rotated building
	# makes the flash point away from the bullet. The 2D source is unchanged.
	var shot_origin_variant: Variant = source_actor.get_meta(&"shot_visual_origin") if source_actor.has_meta(&"shot_visual_origin") else null
	var shot_gameplay_variant: Variant = source_actor.get_meta(&"shot_gameplay_origin") if source_actor.has_meta(&"shot_gameplay_origin") else null
	var direction_variant: Variant = source_actor.get_meta(&"shot_gameplay_direction") if source_actor.has_meta(&"shot_gameplay_direction") else null
	if not direction_variant is Vector2 and source_actor.has_meta(&"projectile_self_emission") and bool(source_actor.get_meta(&"projectile_self_emission")):
		direction_variant = source_actor.get("direction")
	if camera == null or not shot_origin_variant is Vector3 or not shot_gameplay_variant is Vector2 or not direction_variant is Vector2:
		return NAN
	var direction: Vector2 = direction_variant
	if direction.length_squared() <= 0.0001:
		return NAN
	var map_parent := get_parent_node_3d()
	if map_parent == null:
		return NAN
	var world_direction := map_parent.global_basis * Vector3(direction.x, 0.0, direction.y)
	var shot_origin: Vector3 = shot_origin_variant
	var shot_gameplay: Vector2 = shot_gameplay_variant
	var travel := source_actor.global_position - shot_gameplay
	var current_world := shot_origin + map_parent.global_basis * Vector3(travel.x, 0.0, travel.y) / PIXELS_PER_WORLD_CELL
	var screen_direction := camera.unproject_position(current_world + world_direction / PIXELS_PER_WORLD_CELL) - camera.unproject_position(current_world)
	return screen_direction.angle() if screen_direction.length_squared() > 0.0001 else NAN


func _weapon_capture_delta(camera: Camera3D) -> float:
	if not character_projection or camera == null:
		return 0.0
	if not is_instance_valid(_cached_weapon_root) and source_actor != null and is_instance_valid(source_actor):
		_cached_weapon_root = source_actor.get_node_or_null(^"WeaponRoot") as Node2D
	var root := _cached_weapon_root
	var map_parent := get_parent_node_3d()
	if root == null or map_parent == null:
		return 0.0
	var gameplay_heading := root.global_rotation
	var direction := Vector2.RIGHT.rotated(gameplay_heading)
	var grip_world := map_parent.to_global(Vector3(root.global_position.x / PIXELS_PER_WORLD_CELL,
		weapon_reference_height, root.global_position.y / PIXELS_PER_WORLD_CELL))
	var world_direction := map_parent.global_basis * Vector3(direction.x, 0.0, direction.y)
	var projected := camera.unproject_position(grip_world + world_direction) - camera.unproject_position(grip_world)
	if projected.length_squared() < 0.0001:
		return weapon_capture_rotation_delta
	return wrapf(projected.angle() - gameplay_heading, -PI, PI)

func _process(_delta: float) -> void:
	# A regular full sync after a snapshot already satisfies its deferred work.
	# A later snapshot schedules fresh work again, so late poses never lag.
	if not bool(get_meta(&"test_legacy_pending_refresh", false)):
		_snapshot_capture_refresh_pending = false
	if not configured:
		return
	if not is_instance_valid(source_actor) or source_actor.is_queued_for_deletion():
		_on_source_tree_exiting()
		return
	if is_inside_tree() and not source_actor.is_inside_tree():
		_on_source_tree_exiting()
		return
	if not room_presentation_active:
		return
	if transform_only:
		# STATIC_CAPTURE_FOLLOW_TRANSFORM：capture 内容已冻结（不再 sync/签名/
		# viewport 更新），仅保留载体 transform 跟随门叶，血迹不悬空。
		if follow_source_rotation and not ground_only:
			actor_sprite.global_basis = get_parent_node_3d().global_basis * Basis(Vector3.UP, PI * 0.5 - source_actor.global_rotation)
		actor_sprite.global_position = get_parent_node_3d().to_global(Vector3(source_actor.global_position.x / PIXELS_PER_WORLD_CELL,
			actor_center_height + floor_contact_lift,
			source_actor.global_position.y / PIXELS_PER_WORLD_CELL + actor_center_depth_offset))
		actor_sprite.visible = source_actor.visible
		if shadow_proxy != null:
			shadow_proxy.global_transform = actor_sprite.global_transform
			shadow_proxy.visible = actor_sprite.visible and shadow_proxy_enabled
		return
	var static_capture := _cached_static_capture_source
	# Furniture is room-gated gameplay content.  While a dormant room is hidden,
	# its static bridge must remain dormant rather than accepting a transparent
	# first capture and freezing it forever.  Room activation explicitly wakes
	# this bridge through request_capture_refresh().
	if _cached_room_gated_prop:
		var runtime_active_variant: Variant = source_actor.get("room_runtime_active")
		var runtime_active := runtime_active_variant == null or bool(runtime_active_variant)
		if not runtime_active or not source_actor.visible:
			if actor_sprite != null:
				actor_sprite.visible = source_actor.visible
			if shadow_proxy != null:
				shadow_proxy.visible = source_actor.visible
			if render_viewport != null:
				render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			static_visual_frozen = false
			set_process(true)
			return
	if not source_actor.visible and not static_capture and not freeze_pending:
		if volume_shadow != null:
			volume_shadow.hide()
		_set_character_layer_activity(false)
		if actor_sprite != null:
			actor_sprite.visible = false
		if shadow_proxy != null:
			shadow_proxy.visible = false
		if character_local_light != null:
			character_local_light.visible = false
		if render_viewport != null:
			render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_sync_roots()
	if projectile_material != null and source_actor.has_method(&"flush_office_tracer_update"):
		source_actor.flush_office_tracer_update()
	var height := 0.0 if ground_only else _source_fake_height_pixels()
	var camera := _active_world_camera()
	if character_projection and not is_instance_valid(_cached_character_visual):
		_cached_character_visual = source_actor.get_node_or_null(^"CharacterVisual") as Node2D
	var character_body := _cached_character_visual if character_projection else null
	var is_dead_enemy := _cached_is_enemy and bool(source_actor.get("dead"))
	var upright_contact := character_projection and camera != null \
		and not is_dead_enemy \
		and (character_body == null or absf(character_body.rotation) < 0.1)
	var skip_capture_sync := false
	if upright_contact and not bool(get_meta(&"test_legacy_offscreen_capture_sync", false)):
		# The existing rendering gate already disables these captures. Use the
		# current formal colour origin (not last frame's Sprite3D position) before
		# traversing their passive copies. Shadow and gameplay still update below.
		floor_contact_lift = 0.0
		var origin := _character_colour_origin(camera, height)
		var viewport := camera.get_viewport()
		if viewport != null and not camera.is_position_behind(origin):
			skip_capture_sync = not viewport.get_visible_rect().grow(160).has_point(camera.unproject_position(origin))
	if has_meta(&"test_capture_sync_skipped"):
		set_meta(&"test_capture_sync_skipped", skip_capture_sync)
	var has_shot_origin := source_actor.has_meta(&"shot_visual_origin")
	# Crowd CPU: upright enemy capture trees rarely need 60 Hz property copies.
	# Alternate frames by instance id so a packed room does not sync every enemy
	# every tick. Player stays every frame. World Sprite3D pose / lights below
	# still update. Legacy meta restores unconditional sync for A/B fixtures.
	var skip_staggered_enemy_sync := false
	if (
		character_projection
		and upright_contact
		and not skip_capture_sync
		and _cached_is_enemy
		and not bool(get_meta(&"test_legacy_character_sync_every_frame", false))
	):
		skip_staggered_enemy_sync = ((Engine.get_process_frames() + get_instance_id()) & 1) == 1
	if not skip_capture_sync and not skip_staggered_enemy_sync:
		weapon_capture_rotation_delta = _weapon_capture_delta(camera)
		var shot_heading := _shot_capture_heading(camera) if has_shot_origin else NAN
		if not is_nan(shot_heading) and not _cached_bullet_sprite_resolved:
			_cached_bullet_sprite = source_actor.get_node_or_null(^"BulletSprite") as Node2D
			_cached_bullet_sprite_resolved = true
		var optimize_capture_transform := bool(get_meta(&"test_capture_transform_optimization", true))
		for index in source_roots.size():
			var source := source_roots[index]
			var copy := clone_roots[index]
			_sync_node(source, copy, optimize_capture_transform, optimize_capture_transform)
			# Preserve root rotation/scale (bullets, thrown weapons, body parts), but
			# never copy world translation into the offscreen capture.
			var capture := source.global_transform
			capture.origin -= source_actor.global_position
			if source != source_actor and not ground_only:
				capture.origin += source_actor.global_transform.basis_xform(Vector2(0, height))
			if not is_nan(shot_heading) and (source == _cached_bullet_sprite or source == source_actor):
				# Rotate the tracer about its head, or the muzzle effect about its
				# origin. Both are the captured shot point in the viewport centre.
				var delta_angle := shot_heading - capture.get_rotation()
				capture.origin = capture.origin.rotated(delta_angle)
				capture.x = capture.x.rotated(delta_angle)
				capture.y = capture.y.rotated(delta_angle)
			if character_projection and source == _cached_weapon_root:
				# Rotate around the authored grip. Gameplay Aim/attack remains unchanged;
				# only the captured weapon pixels follow the formal camera projection.
				capture.x = capture.x.rotated(weapon_capture_rotation_delta)
				capture.y = capture.y.rotated(weapon_capture_rotation_delta)
			capture.origin += viewport_offset
			if not optimize_capture_transform or copy.transform != capture:
				copy.transform = capture
			var target_vis := source_actor.visible and source.visible
			if not optimize_capture_transform or copy.visible != target_vis:
				copy.visible = target_vis
			if source != source_actor:
				var target_mod := source.modulate * source_actor.modulate
				if not optimize_capture_transform or copy.modulate != target_mod:
					copy.modulate = target_mod
	var position_2d := source_actor.global_position
	if not skip_staggered_enemy_sync:
		_update_character_local_light(position_2d)
	floor_contact_lift = 0.0
	lowest_visible_pixel = 0.0
	if camera != null and (camera_plane_visual or ((lit_material != null or projectile_material != null) and billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED)):
		actor_sprite.global_basis = camera.global_basis.orthonormalized()
	if follow_source_rotation and not ground_only:
		# A stain parented to a swinging door leaf keeps its plane on the
		# leaf's current face: the wall-stain texture frame maps world normal
		# axis to texture X, so the vertical plane yaw is 90° - source yaw.
		actor_sprite.global_basis = get_parent_node_3d().global_basis * Basis(Vector3.UP, PI * 0.5 - source_actor.global_rotation)
	# Upright living characters discard this scan below and use their cached
	# foot contact. Keep it for every corpse/rotated pose and non-character carrier.
	if not ground_only and viewport_offset.y > render_viewport.size.y * 0.5 \
		and (not upright_contact or bool(get_meta(&"test_legacy_contact_scan", false))):
		# A standing pivot is not a landing pivot after a 90-degree death rotation.
		# Derive the contact from the actual opaque sprite bounds in the capture.
		# This adjusts presentation Y only, never gameplay position or fake height.
		var can_cache_corpse := character_projection and character_body != null and not bool(get_meta(&"test_legacy_contact_scan", false)) and not has_meta(&"test_contact_scan_count")
		if can_cache_corpse and _corpse_contact_cached and character_body.transform == _last_corpse_body_transform and not clone_roots.is_empty() and clone_roots[0].transform == _last_corpse_copy_transform:
			lowest_visible_pixel = _cached_lowest_visible_pixel
		else:
			for copy in clone_roots:
				if character_projection and copy.name != &"CharacterVisual":
					continue
				lowest_visible_pixel = maxf(lowest_visible_pixel, _lowest_pixel(copy) - viewport_offset.y)
			if can_cache_corpse and not clone_roots.is_empty():
				_corpse_contact_cached = true
				_last_corpse_body_transform = character_body.transform
				_last_corpse_copy_transform = clone_roots[0].transform
				_cached_lowest_visible_pixel = lowest_visible_pixel
		var up_y := camera.global_basis.y.y if camera != null else 0.70710678
		floor_contact_lift = lowest_visible_pixel * maxf(up_y, 0.0) / PIXELS_PER_WORLD_CELL
	var target_pos := get_parent_node_3d().to_global(Vector3(position_2d.x / PIXELS_PER_WORLD_CELL,
		actor_center_height + height / PIXELS_PER_WORLD_CELL + floor_contact_lift,
		position_2d.y / PIXELS_PER_WORLD_CELL + actor_center_depth_offset))
	if character_projection and camera != null:
		if character_body == null or absf(character_body.rotation) < 0.1:
			floor_contact_lift = 0.0
		target_pos = _character_colour_origin(camera, height)
	elif has_shot_origin:
		var shot_origin: Vector3 = source_actor.get_meta(&"shot_visual_origin")
		var shot_gameplay: Vector2 = source_actor.get_meta(&"shot_gameplay_origin")
		var travel := position_2d - shot_gameplay
		target_pos = shot_origin + get_parent_node_3d().global_basis * Vector3(travel.x, 0, travel.y) / PIXELS_PER_WORLD_CELL
		var plane_origin: Vector3=source_actor.get_meta(&"hit_reference_plane_origin",shot_origin)
		var plane_normal: Vector3=source_actor.get_meta(&"hit_reference_plane_normal",Vector3.UP)
		if plane_origin != _last_shot_plane_origin or plane_normal != _last_shot_plane_normal:
			_last_shot_plane_origin = plane_origin
			_last_shot_plane_normal = plane_normal
			CHARACTER_PROJECTION.set_material_plane(projectile_material, plane_origin, plane_normal)
	elif ground_only and (_cached_is_player or _cached_is_enemy):
		# Keep the existing ground shadow under the same collision-foot anchor.
		if not _cached_shadow_node_resolved:
			_cached_shadow_node = source_actor.get_node_or_null(^"Shadow") as Node2D
			_cached_shadow_node_resolved = true
		var shadow_source := _cached_shadow_node
		if shadow_source != null and is_instance_valid(shadow_source):
			var shadow_pixel := shadow_source.global_position - source_actor.global_position + viewport_offset - Vector2(render_viewport.size) * 0.5
			target_pos = _character_ground() + Vector3.UP * actor_center_height - actor_sprite.global_basis * Vector3(shadow_pixel.x, -shadow_pixel.y, 0) / PIXELS_PER_WORLD_CELL
	if actor_sprite.is_inside_tree():
		actor_sprite.global_position = target_pos
	else:
		actor_sprite.position = target_pos
	actor_sprite.visible = source_actor.visible
	if character_projection and camera != null:
		if skip_staggered_enemy_sync:
			# Pose uniforms stay from the last synced frame; only follow the
			# already-updated world sprite transform so the billboard keeps pace.
			weapon_sprite.global_transform = actor_sprite.global_transform
			attachment_sprite.global_transform = actor_sprite.global_transform
		else:
			_sync_character_planes(camera, height)
			_sync_volume_shadow(camera, height)
	if shadow_proxy != null:
		# 代理与可见精灵逐帧同 transform：阴影剪影始终贴合真实像素。
		if shadow_proxy.is_inside_tree() and actor_sprite.is_inside_tree():
			shadow_proxy.global_transform = actor_sprite.global_transform
		else:
			shadow_proxy.transform = actor_sprite.transform
		shadow_proxy.visible = actor_sprite.visible and shadow_proxy_enabled
	# Never render distant or hidden captures continuously. Gameplay still runs.
	if shared_capture_managed:
		# The floor pool owns the shared target. An individual casing must never
		# disable another casing's capture, including after release or culling.
		return
	# on-screen 判断跟随正式 World Camera 所在 viewport 的尺寸（unproject 返回的
	# 是该 viewport 的像素坐标，所以用它自己的 visible_rect 做判据）。
	var vp := get_viewport()
	var camera_viewport_rect: Rect2 = (
		camera.get_viewport().get_visible_rect() if camera != null and camera.get_viewport() != null else (vp.get_visible_rect() if vp != null else Rect2())
	)
	var on_screen := camera == null or (not camera.is_position_behind(actor_sprite.global_position)
		and camera_viewport_rect.grow(160).has_point(camera.unproject_position(actor_sprite.global_position)))
	# 血迹（永久保留）纳入静态捕获：settle 后 SubViewport 不再每帧重绘，
	# 仅当载荷版本变化（新血滴落地 / append_wall_impact）时刷新一次。
	if _cached_room_gated_prop:
		# configure() and _process() can both run before the first rendered frame.
		# Do not cancel UPDATE_ONCE or accept a static capture until the renderer
		# has actually completed it with this room's drawable source.
		freeze_pending = false
		var signature := _capture_signature(render_root)
		if not capture_initialized or signature != last_static_signature:
			if not furniture_capture_pending:
				last_static_signature = signature
				furniture_capture_pending = true
				render_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
				furniture_capture_callback = _on_furniture_capture_drawn.bind(furniture_capture_epoch)
				RenderingServer.frame_post_draw.connect(furniture_capture_callback, CONNECT_ONE_SHOT)
		elif not furniture_capture_pending:
			render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			static_visual_frozen = true
			set_process(false)
	elif freeze_pending:
		# 静态血迹冻结：UPDATE_ONCE 与可见性无关（离屏同样完成单次捕获），
		# 冻结后该 bridge 的 per-frame 成本归零（Door 血转 transform-only）。
		render_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		freeze_pending = false
		if follow_source_rotation:
			transform_only = true
		else:
			static_visual_frozen = true
			set_process(false)
	elif static_capture:
		if not capture_initialized:
			render_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			last_static_signature = _capture_signature(render_root)
			capture_initialized = true
		else:
			var signature := _capture_signature(render_root)
			if signature != last_static_signature:
				last_static_signature = signature
				render_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			else:
				render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
				if not _cached_is_enemy and not _cached_is_player and not source_actor.is_in_group(&"physical_doors"):
					static_visual_frozen = true
					set_process(false)
	elif on_screen and source_actor.visible:
		render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_set_character_layer_activity(on_screen and source_actor.visible and room_presentation_active)


func _sync_volume_shadow(camera: Camera3D, height: float) -> void:
	if volume_shadow == null:
		return
	var grip: Variant = null
	var muzzle: Variant = null
	if not is_instance_valid(_cached_weapon_root) and source_actor != null and is_instance_valid(source_actor):
		_cached_weapon_root = source_actor.get_node_or_null(^"WeaponRoot") as Node2D
	var root := _cached_weapon_root
	if not _cached_projectile_origin_resolved and source_actor != null and is_instance_valid(source_actor):
		_cached_projectile_origin = source_actor.get_node_or_null(^"WeaponRoot/ProjectileOrigin") as Node2D
		if _cached_projectile_origin == null:
			_cached_projectile_origin = source_actor.get_node_or_null(^"WeaponRoot/WeaponMotion/ProjectileOrigin") as Node2D
		_cached_projectile_origin_resolved = true
	var marker := _cached_projectile_origin if is_instance_valid(_cached_projectile_origin) else null
	var selected: Variant = source_actor.get("selected_weapon_id")
	if selected == null:
		selected = source_actor.get("held_weapon_id")
	if volume_shadow.weapon != null and root != null and root.visible and marker != null and selected != null and not str(selected).is_empty():
		grip = _weapon_visual_snapshot_synced(root.global_position, camera).get("world_origin")
		muzzle = _weapon_visual_snapshot_synced(marker.global_position, camera).get("world_origin")
	volume_shadow.sync_pose(_character_ground(), get_parent_node_3d().global_basis, height / PIXELS_PER_WORLD_CELL, grip, muzzle)

func _on_furniture_capture_drawn(epoch: int) -> void:
	if epoch != furniture_capture_epoch:
		return
	furniture_capture_pending = false
	if not is_instance_valid(source_actor) or not room_presentation_active:
		return
	if not source_actor.is_inside_tree() or not source_actor.visible or source_roots.is_empty():
		return
	if source_actor.get("room_runtime_active") == false:
		return
	capture_initialized = true


func _capture_signature(node: Node2D) -> int:
	var values: Array = [node.transform, node.visible, node.modulate, node.self_modulate]
	# 血迹等自定义绘制节点：签名纳入其载荷版本号（普通属性无法反映像素变化）。
	if node.has_method("get_capture_content_version"):
		values.append(int(node.call("get_capture_content_version")))
	if node is Sprite2D:
		values.append_array([node.texture, node.frame, node.region_rect, node.flip_h, node.flip_v, node.offset])
	for child in node.get_children():
		if child is Node2D: values.append(_capture_signature(child))
	return hash(values)

func _lowest_pixel(node: Node2D) -> float:
	if has_meta(&"test_contact_scan_count"):
		set_meta(&"test_contact_scan_count", int(get_meta(&"test_contact_scan_count")) + 1)
	if not node.visible:
		return -INF
	var bottom := -INF
	if node is Sprite2D and node.texture != null:
		var rect := _opaque_rect(node)
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			bottom = maxf(bottom, (node.global_transform * corner).y)
	for child in node.get_children():
		if child is Node2D:
			bottom = maxf(bottom, _lowest_pixel(child))
	return bottom

func _opaque_rect(sprite: Sprite2D) -> Rect2:
	var region := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	var cell_size := region.size / Vector2(sprite.hframes, sprite.vframes)
	region = Rect2(region.position + Vector2(sprite.frame_coords) * cell_size, cell_size)
	var key := "%d:%s" % [sprite.texture.get_instance_id(), region]
	if not opaque_rect_cache.has(key):
		var image := _read_texture_image(sprite.texture)
		if image != null and not image.is_empty():
			opaque_rect_cache[key] = Rect2(image.get_region(Rect2i(region)).get_used_rect())
		else:
			opaque_rect_cache[key] = Rect2(Vector2.ZERO, cell_size)
	var used: Rect2 = opaque_rect_cache[key]
	if sprite.flip_h:
		used.position.x = cell_size.x - used.end.x
	if sprite.flip_v:
		used.position.y = cell_size.y - used.end.y
	used.position += sprite.offset - (cell_size * 0.5 if sprite.centered else Vector2.ZERO)
	return used

func _read_texture_image(texture: Texture2D) -> Image:
	# AtlasTexture.get_image crops before decompression in the engine. Resolve
	# its source first so GPU-compressed furniture atlases can be sampled safely.
	if texture is AtlasTexture:
		var atlas_image := _read_texture_image(texture.atlas)
		return atlas_image.get_region(Rect2i(texture.region)) if texture.region.has_area() else atlas_image
	var result := texture.get_image()
	if result != null and result.is_compressed():
		result.decompress()
	return result

## 血迹视觉 settled 后调用：再做一次完整同步与单次捕获，然后停止完整处理。
func freeze_static_visual() -> void:
	if transform_only or static_visual_frozen:
		return
	freeze_pending = true


## 冻结后有新载荷（append_wall_impact）时调用：临时唤醒一次同步与捕获，
## 完成后自动重新冻结。源节点保持停帧不受影响。
func mark_visual_dirty() -> void:
	if transform_only or not static_visual_frozen:
		return
	static_visual_frozen = false
	freeze_pending = true
	set_process(true)
	wake_frames = 2


## The world may configure a blood source after the bridge has been created so
## its 2D wall raycasts have a live physics space.  Force one fresh capture
## after setup without making the static SubViewport update every frame.
func resize_blood_ground_capture(half_extent: float) -> void:
	if not _is_blood_source() or render_viewport == null:
		return
	var extent := clampi(ceili(half_extent), 64, 112)
	if is_instance_valid(source_actor): source_actor.set_meta(&"blood_ground_capture_extent",extent)
	var requested_size := Vector2i(extent * 2, extent * 2)
	if render_viewport.size == requested_size:
		return
	render_viewport.size = requested_size
	viewport_offset = Vector2(extent, extent)
	request_capture_refresh()


func request_capture_refresh() -> void:
	if transform_only:
		return
	if furniture_capture_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(furniture_capture_callback):
		RenderingServer.frame_post_draw.disconnect(furniture_capture_callback)
	furniture_capture_epoch += 1
	furniture_capture_pending = false
	static_visual_frozen = false
	capture_initialized = false
	last_static_signature = 0
	set_process(true)


## Room visibility owns the gameplay source, while a frozen static bridge no
## longer receives _process() ticks to observe source.visible changes.  Keep a
## small presentation-only gate so dormant furniture cannot remain on screen,
## and wake exactly one capture when its room becomes active again.
func set_room_presentation_active(active: bool) -> void:
	_set_character_layer_activity(active and is_instance_valid(source_actor) and source_actor.visible)
	if not configured:
		return
	room_presentation_active = active
	if not active:
		if furniture_capture_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(furniture_capture_callback):
			RenderingServer.frame_post_draw.disconnect(furniture_capture_callback)
		furniture_capture_epoch += 1
		furniture_capture_pending = false
		render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)
		var is_visible: bool = (source_actor != null and is_instance_valid(source_actor) and source_actor.visible)
		if actor_sprite != null and is_instance_valid(actor_sprite):
			actor_sprite.visible = is_visible
		if shadow_proxy != null and is_instance_valid(shadow_proxy):
			shadow_proxy.visible = is_visible and shadow_proxy_enabled
		if character_local_light != null and is_instance_valid(character_local_light):
			character_local_light.visible = is_visible
		return
	if source_actor == null or not is_instance_valid(source_actor):
		return
	if transform_only:
		set_process(true)
		return
	request_capture_refresh()


func _on_source_tree_exiting() -> void:
	if projectile_pool_release.is_valid():
		suspend_projectile()
		projectile_pool_release.call(self)
		return
	if is_instance_valid(volume_shadow):
		volume_shadow.hide()
	if is_instance_valid(actor_sprite):
		actor_sprite.hide()
	if is_instance_valid(shadow_proxy):
		shadow_proxy.hide()
	if is_instance_valid(character_local_light):
		character_local_light.hide()
	if is_inside_tree() and not is_queued_for_deletion():
		queue_free()

func _source_fake_height_pixels() -> float:
	if _cached_height_prop_resolved:
		if _cached_height_prop == &"":
			return 0.0
		var v: Variant = source_actor.get(_cached_height_prop)
		if v is float or v is int:
			return maxf(float(v), 0.0)
		return 0.0
	_cached_height_prop_resolved = true
	for property_name in [&"knockback_height", &"knockdown_height", &"fake_height", &"height"]:
		var value: Variant = source_actor.get(property_name)
		if value is float or value is int:
			_cached_height_prop = property_name
			return maxf(float(value), 0.0)
	return 0.0

func _sync_node(source: Node2D, copy: Node2D, skip_transform: bool = false, optimize_transform: bool = false) -> void:
	# Node2D::set_transform in the installed engine always notifies the render
	# server, even for equal transforms. Never use approximate equality here.
	if not skip_transform and (not optimize_transform or copy.transform != source.transform):
		copy.transform = source.transform
	if not optimize_transform:
		copy.visible = source.visible
		copy.modulate = source.modulate
		copy.self_modulate = source.self_modulate
		copy.z_index = source.z_index
		copy.z_as_relative = source.z_as_relative
		copy.texture_filter = source.texture_filter
		copy.material = source.material
		if source is Sprite2D and copy is Sprite2D:
			copy.texture = source.texture
			copy.region_enabled = source.region_enabled
			copy.region_rect = source.region_rect
			copy.hframes = source.hframes
			copy.vframes = source.vframes
			copy.frame = source.frame
			copy.flip_h = source.flip_h
			copy.flip_v = source.flip_v
			copy.offset = source.offset
			copy.centered = source.centered
		elif source is Line2D and copy is Line2D:
			copy.points = source.points
			copy.width = source.width
			copy.default_color = source.default_color
			copy.gradient = source.gradient
		elif source is AnimatedSprite2D and copy is AnimatedSprite2D:
			copy.sprite_frames = source.sprite_frames
			copy.animation = source.animation
			copy.set_frame_and_progress(source.frame, source.frame_progress)
			copy.flip_h = source.flip_h
			copy.flip_v = source.flip_v
		elif source is Polygon2D and copy is Polygon2D:
			copy.polygon = source.polygon
			copy.color = source.color
	else:
		if copy.visible != source.visible: copy.visible = source.visible
		if copy.modulate != source.modulate: copy.modulate = source.modulate
		if copy.self_modulate != source.self_modulate: copy.self_modulate = source.self_modulate
		if copy.z_index != source.z_index: copy.z_index = source.z_index
		if copy.z_as_relative != source.z_as_relative: copy.z_as_relative = source.z_as_relative
		if copy.texture_filter != source.texture_filter: copy.texture_filter = source.texture_filter
		if copy.material != source.material: copy.material = source.material
		if source is Sprite2D and copy is Sprite2D:
			if copy.texture != source.texture: copy.texture = source.texture
			if copy.region_enabled != source.region_enabled: copy.region_enabled = source.region_enabled
			if copy.region_rect != source.region_rect: copy.region_rect = source.region_rect
			if copy.hframes != source.hframes: copy.hframes = source.hframes
			if copy.vframes != source.vframes: copy.vframes = source.vframes
			if copy.frame != source.frame: copy.frame = source.frame
			if copy.flip_h != source.flip_h: copy.flip_h = source.flip_h
			if copy.flip_v != source.flip_v: copy.flip_v = source.flip_v
			if copy.offset != source.offset: copy.offset = source.offset
			if copy.centered != source.centered: copy.centered = source.centered
		elif source is Line2D and copy is Line2D:
			copy.points = source.points
			if copy.width != source.width: copy.width = source.width
			if copy.default_color != source.default_color: copy.default_color = source.default_color
			if copy.gradient != source.gradient: copy.gradient = source.gradient
		elif source is AnimatedSprite2D and copy is AnimatedSprite2D:
			if copy.sprite_frames != source.sprite_frames: copy.sprite_frames = source.sprite_frames
			if copy.animation != source.animation: copy.animation = source.animation
			if copy.frame != source.frame or copy.frame_progress != source.frame_progress:
				copy.set_frame_and_progress(source.frame, source.frame_progress)
			if copy.flip_h != source.flip_h: copy.flip_h = source.flip_h
			if copy.flip_v != source.flip_v: copy.flip_v = source.flip_v
		elif source is Polygon2D and copy is Polygon2D:
			copy.polygon = source.polygon
			if copy.color != source.color: copy.color = source.color
	if source.has_method("copy_depth_visual_state_to"):
		source.call("copy_depth_visual_state_to", copy)
	var src_child_count := source.get_child_count()
	var copy_child_count := copy.get_child_count()
	if src_child_count == 0 and copy_child_count == 0:
		return
	var matched_in_order := true
	var replica_idx := 0
	var names: Array[StringName] = []
	for i in src_child_count:
		var child := source.get_child(i)
		# Charge VFX are already represented by a local unlit bridge.  Do not
		# duplicate them into the actor's lit capture as well, otherwise the same
		# sprite is rendered twice and the lit copy becomes environment-dependent.
		if bool(child.get_meta(&"depth_visual_unlit", false)):
			continue
		if child is Label:
			var c_name := child.name
			var label: Label = null
			if matched_in_order and replica_idx < copy_child_count:
				var candidate := copy.get_child(replica_idx)
				if candidate is Label and candidate.name == c_name:
					label = candidate as Label
					replica_idx += 1
				else:
					matched_in_order = false
			if label == null:
				label = copy.get_node_or_null(NodePath(c_name)) as Label
			if label == null:
				matched_in_order = false
				label = child.duplicate(0) as Label
				label.set_script(null)
				label.process_mode = Node.PROCESS_MODE_DISABLED
				copy.add_child(label)
			names.append(c_name)
			if label.position != child.position: label.position = child.position
			if label.size != child.size: label.size = child.size
			if label.text != child.text: label.text = child.text
			if label.visible != child.visible: label.visible = child.visible
			if label.modulate != child.modulate: label.modulate = child.modulate
			continue
		if not child is Node2D or child is CollisionObject2D or child is CollisionShape2D or child is CollisionPolygon2D:
			continue
		var c_name := child.name
		var replica: Node2D = null
		if matched_in_order and replica_idx < copy_child_count:
			var candidate := copy.get_child(replica_idx)
			if candidate is Node2D and candidate.name == c_name:
				replica = candidate as Node2D
				replica_idx += 1
			else:
				matched_in_order = false
		if replica == null:
			replica = copy.get_node_or_null(NodePath(c_name)) as Node2D
		if replica == null:
			matched_in_order = false
			replica = _make_visual_copy(child)
			copy.add_child(replica)
		names.append(c_name)
		_sync_node(child, replica, false, optimize_transform)
	if not matched_in_order or replica_idx != copy_child_count:
		for child in copy.get_children():
			if not names.has(child.name):
				child.free()

func set_target_highlight(enabled: bool) -> void:
	set_target_highlight_state(1 if enabled else 0)


func set_target_highlight_state(state: int) -> void:
	if actor_sprite == null:
		return
	if state != 0 and outline_material == null:
		outline_material = ShaderMaterial.new()
		outline_material.shader = load("res://shaders/dream3d/pixel_target_outline.gdshader")
		outline_material.set_shader_parameter("capture_texture", render_viewport.get_texture())
		outline_material.set_shader_parameter("billboard_enabled", actor_sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED)
	var outline_color := Color.WHITE
	if state == 2:
		outline_color = Color(0.55, 0.58, 0.62, 1.0)
	if outline_material != null:
		outline_material.set_shader_parameter("outline_color", outline_color)
	actor_sprite.material_overlay = outline_material if state != 0 else null
	if character_projection:
		if state == 0:
			weapon_sprite.material_overlay = null
		else:
			var weapon_outline := weapon_sprite.material_overlay as ShaderMaterial
			if weapon_outline == null:
				weapon_outline = outline_material.duplicate() as ShaderMaterial
				weapon_outline.set_shader_parameter("capture_texture", weapon_sprite.texture)
				weapon_sprite.material_overlay = weapon_outline
			weapon_outline.set_shader_parameter("outline_color", outline_color)
			CHARACTER_PROJECTION.set_material_plane(weapon_outline, Vector3(0, weapon_reference_height, 0), Vector3.UP)
