class_name RollSpeedTrail
extends Node2D

## Katana ZERO (武士 零) 风格高能霓虹残影与剑气疾速流光特效。
## 包含：
## 1. 标志性双色交替霓虹残影（Cyber Cyan <-> Hot Magenta <-> Electric Violet）
## 2. 沿位移方向的微 RGB 色散分色（Chromatic Aberration）
## 3. 经典复古 1px CRT/VHS 扫描线与随机微位移切片（Micro Glitch Slice）
## 4. 疾速剑风切线（Blade Wind Streaks）跟随残影斩裂空气
## 5. 纯表现层特效，完全不影响实际 Dash 距离、碰撞、冷却或无敌判定。

const KATANA_TRAIL_SHADER: Shader = preload("res://shaders/katana_zero_trail.gdshader")

const MIN_LIFETIME := 0.04
const MAX_LIFETIME := 0.6
const MAX_STRETCH := 1.0
const STRETCH_OFFSET_PIXELS := 4.0

## 武士 零经典双色交替霓虹调色板
const PALETTES: Array[Dictionary] = [
	{
		# 0: 赛博青蓝主色 + 霓虹品红边缘拖尾色散
		"primary": Color(0.0, 0.95, 1.0, 0.95),
		"secondary": Color(1.0, 0.08, 0.62, 0.85),
	},
	{
		# 1: 烈焰品红主色 + 赛博青蓝边缘拖尾色散
		"primary": Color(1.0, 0.08, 0.62, 0.95),
		"secondary": Color(0.0, 0.95, 1.0, 0.85),
	},
	{
		# 2: 幻紫主色 + 赛博青蓝边缘拖尾色散
		"primary": Color(0.68, 0.12, 1.0, 0.92),
		"secondary": Color(0.0, 0.95, 1.0, 0.80),
	},
	{
		# 3: 明亮青翠主色 + 幻紫边缘拖尾色散
		"primary": Color(0.05, 0.98, 0.95, 0.95),
		"secondary": Color(0.72, 0.15, 1.0, 0.85),
	},
]

static var _next_ghost_index: int = 0


static func reset_counter() -> void:
	_next_ghost_index = 0


func setup(
	source_visual: Node2D,
	sample_position: Vector2,
	motion_direction: Vector2,
	stretch_amount: float = 0.12,
	start_alpha: float = 0.85,
	lifetime: float = 0.26,
	forced_index: int = -1
) -> void:
	if source_visual == null or not is_instance_valid(source_visual):
		queue_free()
		return

	var ghost_index: int = forced_index if forced_index >= 0 else _next_ghost_index
	_next_ghost_index += 1

	global_position = sample_position
	visible = true
	modulate = Color(1.0, 1.0, 1.0, clampf(start_alpha, 0.0, 1.0))
	z_index = source_visual.z_index - 1

	var direction: Vector2 = motion_direction.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	var direction_angle: float = direction.angle()

	# 选择该残影对应的霓虹配色
	var palette: Dictionary = PALETTES[ghost_index % PALETTES.size()]
	var primary_col: Color = palette["primary"]
	var secondary_col: Color = palette["secondary"]

	# 部分残影附加微 VHS 故障切片
	var glitch_amount: float = 2.2 if (ghost_index % 3 == 1) else 0.0

	# 运动拉伸轴节点
	var motion_axis := Node2D.new()
	motion_axis.name = "MotionStretch"
	motion_axis.rotation = direction_angle
	var effective_stretch: float = clampf(stretch_amount, 0.0, MAX_STRETCH)
	motion_axis.scale = Vector2(1.0 + effective_stretch, 1.0)
	motion_axis.position = -Vector2(effective_stretch * STRETCH_OFFSET_PIXELS, 0.0)
	add_child(motion_axis)

	# 保持姿态的姿态镜像节点
	var snapshot := Node2D.new()
	snapshot.name = "Snapshot"
	snapshot.rotation = source_visual.global_rotation - direction_angle
	snapshot.scale = source_visual.global_scale
	snapshot.modulate = Color.WHITE
	snapshot.self_modulate = Color.WHITE
	snapshot.visible = source_visual.visible
	motion_axis.add_child(snapshot)

	_copy_visual_tree(source_visual, snapshot, direction, primary_col, secondary_col, glitch_amount)

	# 附带剑风疾速切线
	_spawn_speed_streaks(direction, primary_col, ghost_index)

	var fade_seconds: float = clampf(lifetime, MIN_LIFETIME, MAX_LIFETIME)
	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_QUAD)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	fade_tween.tween_callback(Callable(self, "queue_free"))

	var failsafe := get_tree().create_timer(fade_seconds + 0.5)
	failsafe.timeout.connect(_failsafe_free)


func _failsafe_free() -> void:
	if is_inside_tree():
		queue_free()


func _spawn_speed_streaks(direction: Vector2, neon_color: Color, ghost_idx: int) -> void:
	var perp := Vector2(-direction.y, direction.x)
	# 身体不同高度（头部 -22px, 躯干 -14px, 脚步 -6px）
	var heights := [-22.0, -14.0, -6.0]
	for i in heights.size():
		if (ghost_idx + i) % 2 == 0:
			continue
		var h: float = heights[i]
		var offset_origin := Vector2(0.0, h) + perp * randf_range(-2.0, 2.0)
		var streak_len := randf_range(28.0, 52.0)
		var streak := _create_speed_streak(offset_origin, direction, streak_len, neon_color)
		add_child(streak)


static var _shared_streak_curve: Curve

func _create_speed_streak(local_origin: Vector2, direction: Vector2, length: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.name = "BladeStreak"
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.width = 1.6
	line.z_index = -1

	if _shared_streak_curve == null:
		_shared_streak_curve = Curve.new()
		_shared_streak_curve.add_point(Vector2(0.0, 1.0))
		_shared_streak_curve.add_point(Vector2(0.25, 0.85))
		_shared_streak_curve.add_point(Vector2(1.0, 0.0))
	line.width_curve = _shared_streak_curve

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, color.a))
	grad.add_point(0.2, color)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	line.gradient = grad

	var p0 := local_origin
	var p1 := local_origin - direction * length
	line.points = PackedVector2Array([p0, p1])
	return line


func _copy_visual_tree(
	source: Node,
	target: Node2D,
	motion_dir: Vector2,
	primary_color: Color,
	secondary_color: Color,
	glitch_amount: float
) -> void:
	for child_variant in source.get_children():
		var child: Node = child_variant as Node
		if child == null or not child is Node2D:
			continue
		if child is Sprite2D:
			var source_sprite: Sprite2D = child as Sprite2D
			var sprite := Sprite2D.new()
			sprite.name = source_sprite.name
			sprite.texture = source_sprite.texture
			sprite.texture_filter = source_sprite.texture_filter
			sprite.region_enabled = source_sprite.region_enabled
			sprite.region_rect = source_sprite.region_rect
			sprite.hframes = source_sprite.hframes
			sprite.vframes = source_sprite.vframes
			sprite.frame = source_sprite.frame
			sprite.flip_h = source_sprite.flip_h
			sprite.flip_v = source_sprite.flip_v
			sprite.offset = source_sprite.offset
			sprite.centered = source_sprite.centered
			sprite.position = source_sprite.position
			sprite.rotation = source_sprite.rotation
			sprite.scale = source_sprite.scale
			sprite.skew = source_sprite.skew
			var source_alpha := clampf(source_sprite.modulate.a * source_sprite.self_modulate.a, 0.0, 1.0)
			sprite.modulate = Color(1.0, 1.0, 1.0, source_alpha)
			sprite.self_modulate = Color.WHITE
			sprite.visible = source_sprite.visible
			sprite.z_index = source_sprite.z_index
			sprite.z_as_relative = source_sprite.z_as_relative

			# 计算在纹理空间中沿着世界位移方向的 UV 投影向量
			var uv_dir: Vector2 = motion_dir.rotated(-source_sprite.global_rotation)
			if source_sprite.global_scale.x < 0.0 or source_sprite.flip_h:
				uv_dir.x = -uv_dir.x
			if source_sprite.global_scale.y < 0.0 or source_sprite.flip_v:
				uv_dir.y = -uv_dir.y
			if uv_dir.length_squared() > 0.0001:
				uv_dir = uv_dir.normalized()
			else:
				uv_dir = Vector2.RIGHT

			var mat := ShaderMaterial.new()
			mat.shader = KATANA_TRAIL_SHADER
			mat.set_shader_parameter("primary_color", primary_color)
			mat.set_shader_parameter("secondary_color", secondary_color)
			mat.set_shader_parameter("motion_uv_dir", uv_dir)
			mat.set_shader_parameter("split_pixels", 2.4)
			mat.set_shader_parameter("scanline_strength", 0.28)
			mat.set_shader_parameter("glitch_slice_amount", glitch_amount)
			mat.set_shader_parameter("core_brightness", 1.35)

			# 设置 Region UV 约束防止图集相邻像素渗漏
			if source_sprite.texture is AtlasTexture:
				var atlas_tex := source_sprite.texture as AtlasTexture
				if atlas_tex.atlas != null:
					var aw: float = maxf(float(atlas_tex.atlas.get_width()), 1.0)
					var ah: float = maxf(float(atlas_tex.atlas.get_height()), 1.0)
					var r: Rect2 = atlas_tex.region
					mat.set_shader_parameter("region_uv", Vector4(
						r.position.x / aw,
						r.position.y / ah,
						(r.position.x + r.size.x) / aw,
						(r.position.y + r.size.y) / ah
					))
			elif source_sprite.region_enabled and source_sprite.texture != null:
				var tw: float = maxf(float(source_sprite.texture.get_width()), 1.0)
				var th: float = maxf(float(source_sprite.texture.get_height()), 1.0)
				var r: Rect2 = source_sprite.region_rect
				mat.set_shader_parameter("region_uv", Vector4(
					r.position.x / tw,
					r.position.y / th,
					(r.position.x + r.size.x) / tw,
					(r.position.y + r.size.y) / th
				))
			else:
				mat.set_shader_parameter("region_uv", Vector4(0.0, 0.0, 1.0, 1.0))

			sprite.material = mat
			target.add_child(sprite)
			continue

		var source_node: Node2D = child as Node2D
		var node_copy := Node2D.new()
		node_copy.name = source_node.name
		node_copy.position = source_node.position
		node_copy.rotation = source_node.rotation
		node_copy.scale = source_node.scale
		node_copy.skew = source_node.skew
		var node_alpha := clampf(source_node.modulate.a * source_node.self_modulate.a, 0.0, 1.0)
		node_copy.modulate = Color(1.0, 1.0, 1.0, node_alpha)
		node_copy.self_modulate = Color.WHITE
		node_copy.visible = source_node.visible
		node_copy.z_index = source_node.z_index
		node_copy.z_as_relative = source_node.z_as_relative
		target.add_child(node_copy)
		_copy_visual_tree(source_node, node_copy, motion_dir, primary_color, secondary_color, glitch_amount)
