extends Node3D
## Presentation only. No sight queries, AI events, gameplay or camera writes.
@export var flashlight_range := 18.0
## SpotLight3D uses the full cone angle.  The wider cone keeps the floor lit
## when the perspective mouse ray intersects the ground several cells away,
## while the finite range still prevents the light from washing the map out.
@export_range(8.0, 89.0, 1.0) var flashlight_angle := 60.0
@export var flashlight_energy := 1.1
@export var flashlight_attenuation := 0.80
## A small filter radius hides the remaining one-pixel quantization of the
## Compatibility renderer's positional shadow map without washing out the
## flashlight cone.  This is presentation-only; it does not alter LOS or
## projectile collision.
@export_range(0.0, 3.0, 0.05) var flashlight_shadow_blur := 1.80
@export var body_height := 0.85
## A perspective ground ray can be almost horizontal when the cursor is far
## from the Player.  Keep its horizontal aim direction, but give the real
## SpotLight3D a minimum downward pitch so its cone actually intersects the
## ground near the Player instead of travelling above it.
@export_range(0.0, 60.0, 1.0) var flashlight_min_downward_pitch_degrees := 24.0
## The Player carrier is a camera-facing plane.  The light anchor is derived
## from that plane instead of being tied to a world-axis offset.  A small
## signed offset puts the emitter on the side from which the current ray
## leaves the plane; the sign changes continuously as aim crosses parallel.
## Values are world units (one floor cell is one world unit).
@export_range(0.0, 0.5, 0.005) var emitter_plane_margin := 0.04
@export_range(0.0, 0.5, 0.005) var emitter_side_scale := 0.14
@export_range(0.01, 0.5, 0.01) var emitter_transition_dot := 0.12
## The emitter orbit clears the full camera-facing Player footprint.  The
## default side radius matches the current 1.5x, 32px Player art (including a
## small margin); the measured carrier width can increase it for a wide weapon.
@export_category("Flashlight emitter orbit")
@export_range(0.25, 1.5, 0.01) var emitter_orbit_radius_side := 0.90
@export_range(0.10, 0.8, 0.01) var emitter_orbit_radius_forward := 0.36
@export_range(0.0, 0.25, 0.005) var emitter_orbit_margin := 0.06
@export var emitter_orbit_use_carrier_footprint := true
@export var muzzle_duration := 0.080
const MUZZLE_POOL_SIZE := 6
const MUZZLE_ENERGY := {&"pistol": 2.6, &"rifle": 3.0, &"assault_rifle": 3.0, &"shotgun": 4.0}
const PIXELS_PER_WORLD_UNIT := 32.0
const EMITTER_COLLISION_MARGIN_PIXELS := 1.5
## The Player visible carrier receives light on layer 2.  Its separate
## SHADOWS_ONLY proxy uses layer 4 so the flashlight can exclude the proxy
## without excluding the visible Player from the cone.
const PLAYER_VISUAL_LAYER := 2
const PLAYER_SHADOW_LAYER := 4
const CUTOUT_OCCLUDER_LAYER := 8
## World lights illuminate: environment(1) + player visual(2) + player shadow proxy(4) + furniture cutout occluders(8).
const WORLD_LIGHT_CULL_MASK := 1 | PLAYER_VISUAL_LAYER | PLAYER_SHADOW_LAYER | CUTOUT_OCCLUDER_LAYER
var world: Node3D
var flashlight: SpotLight3D
## Player flashlight state is owned here so both 3D Dream scenes use the same
## single SpotLight3D.  It starts disabled so the first L press is an
## unambiguous "turn on" action; death only hides the light temporarily and
## does not erase the player's preference for the next live frame.
var flashlight_enabled := false
var muzzle_lights: Array[OmniLight3D] = []
var remaining: Array[float] = []
var _pulse_deadlines_usec: Array[int] = []
var next_flash := 0
var emitter_position := Vector3.ZERO
var managed_shadows := false
var shadow_transition_paused := false
var _muzzle_shadow_slot := -1
var _muzzle_shadow_frame := -1
var _muzzle_shadow_score := 0.0


func set_managed_shadows(enabled: bool) -> void:
	managed_shadows = enabled
	# Floor lamps own the player's single body shadow. Gun flashes continue
	# to shadow furniture/enemies without adding another player silhouette.
	for light in muzzle_lights:
		light.shadow_caster_mask = light.shadow_caster_mask & ~PLAYER_SHADOW_LAYER if enabled else light.shadow_caster_mask | PLAYER_SHADOW_LAYER
	_clear_muzzle_shadows()


func set_shadow_transition_paused(paused: bool) -> void:
	shadow_transition_paused = paused
	if paused:
		_clear_muzzle_shadows()
		for index in muzzle_lights.size():
			remaining[index] = 0.0
			muzzle_lights[index].visible = false
		if flashlight != null:
			flashlight.visible = false


func _clear_muzzle_shadows() -> void:
	for light in muzzle_lights:
		light.shadow_enabled = false
		if managed_shadows: light.shadow_caster_mask &= ~PLAYER_SHADOW_LAYER
	_muzzle_shadow_slot = -1
	_muzzle_shadow_frame = -1
	_muzzle_shadow_score = 0.0

func configure(owner_world: Node3D) -> void:
	world = owner_world
	# Lighting remains responsive while a dialogue/gameplay parent is paused;
	# this is a presentation node and has no gameplay authority.
	process_mode = Node.PROCESS_MODE_ALWAYS
	flashlight = SpotLight3D.new()
	flashlight.name = "PlayerFlashlight"
	flashlight.spot_range = flashlight_range
	flashlight.spot_angle = flashlight_angle
	flashlight.spot_attenuation = flashlight_attenuation
	flashlight.spot_angle_attenuation = 0.6
	flashlight.light_energy = flashlight_energy
	flashlight.light_color = Color(1.0, 0.97, 0.88)
	flashlight.light_specular = 0.0
	flashlight.shadow_enabled = true
	# 引擎默认 bias�?.1/2.0）。旧�?0.04/0.3 在掠射角下造成大面积自阴影
	# 条纹（摩尔纹主源之一）；如出现薄墙漏�?阴影漂浮再下调并�?A/B�?	flashlight.shadow_bias = 0.1
	flashlight.shadow_normal_bias = 2.0
	flashlight.shadow_blur = flashlight_shadow_blur
	# Illuminate the world and the visible Player (PLAYER_VISUAL stays lit),
	# but do not let the Player's shadow-only proxy occlude the light it
	# originates from (PLAYER_SHADOW_LAYER stays excluded).
	flashlight.light_cull_mask = WORLD_LIGHT_CULL_MASK & ~PLAYER_SHADOW_LAYER
	flashlight.visible = flashlight_enabled
	add_child(flashlight)
	for index in MUZZLE_POOL_SIZE:
		var light := OmniLight3D.new()
		light.name = "MuzzlePulse%d" % index
		light.omni_range = 4.0
		light.omni_attenuation = 1.0
		light.light_color = Color(1, 0.70, 0.34)
		light.light_specular = 0.0
		light.light_cull_mask = WORLD_LIGHT_CULL_MASK
		# The office selects at most one slot; legacy callers remain unshadowed.
		light.shadow_enabled = false
		if managed_shadows: light.shadow_caster_mask &= ~PLAYER_SHADOW_LAYER
		light.shadow_bias = 0.04
		light.shadow_normal_bias = 0.6
		light.visible = false
		add_child(light)
		muzzle_lights.append(light)
		remaining.append(0.0)
		_pulse_deadlines_usec.append(0)

func _process(delta: float) -> void:
	# Flash pulses must expire even while the player is absent during a floor
	# transition; the pool is visual and has no actor/gameplay ownership.
	for index in muzzle_lights.size():
		if remaining[index] <= 0.0 and not muzzle_lights[index].visible:
			continue
		remaining[index] = maxf(remaining[index] - delta, 0.0)
		if managed_shadows and Time.get_ticks_usec() >= _pulse_deadlines_usec[index]:
			remaining[index] = 0.0
		var active_pulse := remaining[index] > 0.0
		if muzzle_lights[index].visible != active_pulse:
			muzzle_lights[index].visible = active_pulse
		if not active_pulse:
			if muzzle_lights[index].shadow_enabled:
				muzzle_lights[index].shadow_enabled = false
			if index == _muzzle_shadow_slot:
				_muzzle_shadow_slot = -1
	if shadow_transition_paused:
		return
	if not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	if Input.is_action_just_pressed("toggle_flashlight"):
		toggle_player_flashlight()
	if flashlight == null:
		return
	var should_show := flashlight_enabled and not bool(world.player.get("dead"))
	if flashlight_enabled:
		var ground: Vector2 = world.player.global_position
		var aim: Vector2 = world.get_gameplay_aim_position()
		aim_flashlight(ground, aim)
	if flashlight.visible != should_show:
		flashlight.visible = should_show


func set_flashlight_enabled(enabled: bool) -> void:
	flashlight_enabled = enabled
	if flashlight != null:
		var player_dead := is_instance_valid(world) and is_instance_valid(world.player) and bool(world.player.get("dead"))
		if flashlight_enabled and is_instance_valid(world) and is_instance_valid(world.player):
			aim_flashlight(world.player.global_position, world.get_gameplay_aim_position())
		flashlight.visible = flashlight_enabled and not player_dead


func toggle_player_flashlight() -> bool:
	set_flashlight_enabled(not flashlight_enabled)
	return flashlight_enabled


## Backwards-compatible shorthand for callers that do not need the Player
## qualifier.  Both names operate on the same single SpotLight3D state.
func toggle_flashlight() -> bool:
	return toggle_player_flashlight()


func is_flashlight_enabled() -> bool:
	return flashlight_enabled



func aim_flashlight(ground: Vector2, aim: Vector2) -> void:
	if flashlight == null:
		return
	var horizontal := Vector2(
		(aim.x - ground.x) / PIXELS_PER_WORLD_UNIT,
		(aim.y - ground.y) / PIXELS_PER_WORLD_UNIT
	)
	# Preserve the mouse's X/Z direction while preventing a far perspective
	# ground point from producing an almost-horizontal spotlight that misses the
	# floor.  The resulting ray is continuous for every mouse position.
	var minimum_drop := horizontal.length() * tan(deg_to_rad(flashlight_min_downward_pitch_degrees))
	var vertical_drop := maxf(body_height, minimum_drop)
	var map_direction := Vector3(horizontal.x, -vertical_drop, horizontal.y)
	var direction := get_parent_node_3d().global_basis * map_direction
	var direction_normalized := direction.normalized() if direction.length_squared() > 0.000001 else Vector3(0.0, -1.0, 0.0)
	var target_emitter := _compute_safe_emitter_position(ground, direction_normalized)
	# The signed plane offset is already a continuous function of aim direction,
	# so assigning the target directly avoids stale positions after room changes
	# or respawn teleports.  There are no discrete Up/Left/Right branches to
	# snap between.
	emitter_position = target_emitter
	flashlight.global_position = emitter_position
	# Only the light rotates. Physics, camera and character are untouched.
	flashlight.global_basis = Basis.looking_at(direction_normalized, Vector3.FORWARD if absf(direction_normalized.y) > 0.999 else Vector3.UP)


func _compute_safe_emitter_position(ground: Vector2, aim_direction: Vector3) -> Vector3:
	# Use the actual Player carrier plane whenever it is available.  This keeps
	# the anchor correct during fake-height/knockdown and avoids duplicating the
	# bridge's camera-facing transform constants here.
	var plane_origin := get_parent_node_3d().to_global(Vector3(ground.x / PIXELS_PER_WORLD_UNIT, body_height, ground.y / PIXELS_PER_WORLD_UNIT))
	var plane_normal := Vector3.ZERO
	var plane_right := Vector3.ZERO
	var bridge: Node3D = null
	if world != null:
		bridge = world.get("player_depth_bridge") as Node3D
	if bridge != null:
		var carrier := bridge.get("actor_sprite") as Sprite3D
		if carrier != null and is_instance_valid(carrier):
			plane_origin = carrier.global_position
			plane_normal = carrier.global_basis.z.normalized()
			plane_right = carrier.global_basis.x.normalized()
	if plane_normal.length_squared() < 0.5:
		var camera: Camera3D = null
		if world != null:
			camera = world.get("camera_3d") as Camera3D
		plane_normal = camera.global_basis.z.normalized() if camera != null else Vector3(0.0, 0.70710678, 0.70710678)
		plane_right = camera.global_basis.x.normalized() if camera != null else Vector3.RIGHT
	var right_flat := Vector3(plane_right.x, 0.0, plane_right.z)
	if right_flat.length_squared() < 0.5:
		right_flat = Vector3.RIGHT
	else:
		right_flat = right_flat.normalized()
	var forward_flat := Vector3(plane_normal.x, 0.0, plane_normal.z)
	if forward_flat.length_squared() < 0.5:
		forward_flat = Vector3.FORWARD
	else:
		forward_flat = forward_flat.normalized()
	# Keep both orbit axes tangent to the actual carrier plane.  The horizontal
	# projection of the second tangent follows the camera-forward floor axis,
	# while its vertical component compensates for the plane's tilt.  This lets
	# the emitter orbit in front/behind without changing which side of the
	# Player visual plane the aim ray leaves.
	var forward_tangent := right_flat.cross(plane_normal)
	if forward_tangent.length_squared() < 0.5:
		forward_tangent = Vector3.FORWARD
	else:
		forward_tangent = forward_tangent.normalized()
	if forward_tangent.dot(forward_flat) < 0.0:
		forward_tangent = -forward_tangent
	var aim_flat := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if aim_flat.length_squared() < 0.000001:
		aim_flat = forward_flat
	else:
		aim_flat = aim_flat.normalized()
	# Project the horizontal aim onto the camera-facing basis.  Scaling the
	# two components independently creates a small ellipse: the side radius
	# clears the wider Player/weapon silhouette, while the forward radius stays
	# close to the body.  All components vary continuously with aim direction.
	var side_component := aim_flat.dot(right_flat)
	var forward_component := aim_flat.dot(forward_flat)
	var side_radius := _orbit_side_radius(bridge)
	var orbit_offset := right_flat * side_component * side_radius
	orbit_offset += forward_tangent * forward_component * emitter_orbit_radius_forward
	# If the aim ray points into the carrier plane, its signed emitter offset is
	# negative; if it points away, the offset is positive.  This is a continuous
	# function of the dot product, not an Up/Left/Right branch.  The small
	# clamped bias supplies a margin once the angle is meaningful while still
	# converging to zero smoothly for a ray parallel to the plane.
	var plane_dot := aim_direction.dot(plane_normal)
	var margin_weight := clampf(plane_dot / maxf(emitter_transition_dot, 0.001), -1.0, 1.0)
	var signed_offset := plane_dot * emitter_side_scale + margin_weight * emitter_plane_margin
	var proposed := plane_origin + orbit_offset + plane_normal * signed_offset
	return _keep_emitter_on_player_side(ground, proposed)


func _orbit_side_radius(bridge: Node3D) -> float:
	var radius := emitter_orbit_radius_side
	if not emitter_orbit_use_carrier_footprint or bridge == null:
		return radius
	var source_actor := bridge.get("source_actor") as Node2D
	if source_actor == null or not is_instance_valid(source_actor):
		return radius
	var bounds := [INF, -INF]
	var source_paths: Array = bridge.get("source_paths")
	for path_variant in source_paths:
		var path := NodePath(path_variant)
		# HP labels are UI, not part of the camera-facing gameplay silhouette.
		if String(path).begins_with("PlayerHPBar"):
			continue
		var visual_root := source_actor.get_node_or_null(path) as Node
		if visual_root != null:
			_accumulate_visual_width(visual_root, source_actor, bounds)
	if bounds[0] == INF or bounds[1] == -INF:
		return radius
	var measured_half_width := maxf(absf(float(bounds[0])), absf(float(bounds[1]))) / PIXELS_PER_WORLD_UNIT
	return maxf(radius, measured_half_width + emitter_orbit_margin)


func _accumulate_visual_width(node: Node, source_actor: Node2D, bounds: Array) -> void:
	if not node is CanvasItem or not (node as CanvasItem).visible:
		return
	var rect := Rect2()
	var has_rect := false
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			rect = sprite.get_rect()
			has_rect = true
	elif node is AnimatedSprite2D:
		var animated := node as AnimatedSprite2D
		# AnimatedSprite2D does not expose Sprite2D's `get_rect()`.  Build the
		# current-frame rectangle from the active SpriteFrames texture so the
		# cached carrier footprint remains valid on every renderer/version.
		if animated.sprite_frames != null:
			var frame_count: int = animated.sprite_frames.get_frame_count(animated.animation)
			if frame_count > 0:
				var frame_index: int = clampi(animated.frame, 0, frame_count - 1)
				var frame_texture: Texture2D = animated.sprite_frames.get_frame_texture(animated.animation, frame_index)
				if frame_texture != null:
					var frame_size := frame_texture.get_size()
					rect = Rect2(animated.offset - (frame_size * 0.5 if animated.centered else Vector2.ZERO), frame_size)
					has_rect = true
	if has_rect:
		var node_2d := node as Node2D
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var point: Vector2 = node_2d.global_transform * corner
			var relative_x: float = point.x - source_actor.global_position.x
			bounds[0] = minf(float(bounds[0]), relative_x)
			bounds[1] = maxf(float(bounds[1]), relative_x)
	for child in node.get_children():
		_accumulate_visual_width(child, source_actor, bounds)


func _keep_emitter_on_player_side(ground: Vector2, proposed: Vector3) -> Vector3:
	## The offset is intentionally tiny, but a Player can stand flush with a
	## wall/door/furniture collider.  In that case the offset must not put the
	## light origin on the obstacle's far side.  This is a 2D gameplay ray used
	## only as a safety clamp; it does not alter LOS, actor movement or collision.
	if world == null or not is_instance_valid(world.player) or not world.player.is_inside_tree():
		return proposed
	var proposed_local := get_parent_node_3d().to_local(proposed)
	var emitter_ground := Vector2(proposed_local.x, proposed_local.z) * PIXELS_PER_WORLD_UNIT
	var travel := emitter_ground - ground
	if travel.length_squared() < 0.000001:
		return proposed
	var collision_mask := 4 | 8 # generated Wall/Door layer + formal Furniture layer
	if world.has_method("get_vision_occluder_collision_mask"):
		collision_mask = int(world.call("get_vision_occluder_collision_mask")) | 8
	var query := PhysicsRayQueryParameters2D.create(ground, emitter_ground, collision_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [world.player.get_rid()]
	var space_state: PhysicsDirectSpaceState2D = world.player.get_world_2d().direct_space_state
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return proposed
	var hit_position: Vector2 = hit.get("position", ground)
	var available := maxf(ground.distance_to(hit_position) - EMITTER_COLLISION_MARGIN_PIXELS, 0.0)
	var safe_ground := ground + travel.normalized() * minf(travel.length(), available)
	proposed_local.x = safe_ground.x / PIXELS_PER_WORLD_UNIT
	proposed_local.z = safe_ground.y / PIXELS_PER_WORLD_UNIT
	return get_parent_node_3d().to_global(proposed_local)

func flash_muzzle(muzzle_position: Vector2, kind: StringName) -> void:
	# Compatibility entry point: callers with gameplay-plane coordinates retain
	# their previous position mapping. The 3D office passes a captured world-space
	# muzzle directly to flash_muzzle_world instead.
	var world_muzzle := get_parent_node_3d().to_global(Vector3(muzzle_position.x / PIXELS_PER_WORLD_UNIT, 0.70, muzzle_position.y / PIXELS_PER_WORLD_UNIT))
	flash_muzzle_world(world_muzzle, kind)


func flash_muzzle_world(muzzle_world_position: Vector3, kind: StringName) -> void:
	if muzzle_lights.is_empty() or shadow_transition_paused:
		return
	var slot := next_flash
	if managed_shadows:
		# Keep the selected pulse's formal muzzle snapshot fixed even when the
		# six-slot pool wraps under simultaneous automatic fire.
		var shortest := INF
		for offset in muzzle_lights.size():
			var candidate := (next_flash + offset) % muzzle_lights.size()
			if candidate == _muzzle_shadow_slot and remaining[candidate] > 0.0:
				continue
			if remaining[candidate] < shortest:
				shortest = remaining[candidate]
				slot = candidate
	var light := muzzle_lights[slot]
	light.shadow_enabled = false
	light.global_position = muzzle_world_position
	light.light_energy = float(MUZZLE_ENERGY.get(kind, 2.6))
	remaining[slot] = minf(muzzle_duration, 0.080) if managed_shadows else muzzle_duration
	_pulse_deadlines_usec[slot] = Time.get_ticks_usec() + int(remaining[slot] * 1000000.0)
	light.visible = true
	if managed_shadows:
		var frame := Engine.get_process_frames()
		var score := _muzzle_screen_contribution(light)
		if score > 0.0 and (_muzzle_shadow_slot < 0 or (frame == _muzzle_shadow_frame and score > _muzzle_shadow_score)):
			if _muzzle_shadow_slot >= 0:
				muzzle_lights[_muzzle_shadow_slot].shadow_enabled = false
			_muzzle_shadow_slot = slot
			_muzzle_shadow_frame = frame
			_muzzle_shadow_score = score
			light.shadow_enabled = true
	next_flash = (slot + 1) % MUZZLE_POOL_SIZE


func _muzzle_screen_contribution(light: OmniLight3D) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return light.light_energy
	if camera.is_position_behind(light.global_position):
		return 0.0
	var screen := camera.unproject_position(light.global_position)
	var bounds := get_viewport().get_visible_rect()
	var distance_squared := maxf(1.0, camera.global_position.distance_squared_to(light.global_position))
	var area := light.omni_range * light.omni_range / distance_squared
	# Nearby off-screen flashes may cast into frame, but visible flashes win.
	return light.light_energy * area * (1.0 if bounds.has_point(screen) else 0.15)
