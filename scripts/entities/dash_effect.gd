extends Node2D

## 空格瞬移 / Dash 的序列帧特效：每次有效 Dash 生成一次本节点并完整播放
## Thunder.png 的 8 帧（从左到右、非循环、Nearest 过滤），
## 播完短暂淡出后回收。冷却中不会进入 dash 分支，因此不会播放假特效；
## 只负责视觉表现，不修改 Dash 距离/冷却/无敌逻辑。

const ATLAS: Texture2D = preload("res://art/Effects/Thunder.png")
const CONFIG := preload("res://resources/demo_config.tres")
# Thunder.png 为 512×256 横向序列帧：8 列 64×256，从左到右顺序播放，
# 闪电由完整逐渐消散（最后一列接近全透明，作为自然收尾帧）。
const FRAME_SIZE := Vector2(64, 256)
const FADE_OUT_SECONDS := 0.12
# 闪电内容纵向约 206px；光痕基准长度上限 120px，与玩家身体适配，不会遮满整个屏幕。
const MAX_FRAME_LENGTH := 206.0
const MAX_STREAK_WIDTH := 120.0
# 动画未正常结束时的防残留保险额外时长（正常路径由 animation_finished 回收）。
const FAILSAFE_EXTRA_SECONDS := 0.5

var sprite: AnimatedSprite2D


func setup(new_target: Node2D, direction: Vector2, duration: float, streak_length: float) -> void:
	# Thunder 闪电长轴为纵向，需再旋转 90° 使长轴贴合位移方向。
	rotation = (direction.normalized().angle() + PI * 0.5) if direction.length_squared() > 0.0001 else PI * 0.5
	# 光痕中心对齐本次位移过程中的玩家身体（路径中点），
	# 长度贴合实际位移距离（被边界截断时也随之缩短）。
	if is_instance_valid(new_target):
		global_position = new_target.global_position + direction * 0.5
	var frame_count: int = CONFIG.dash_thunder_frame_count
	var thunder_fps: float = CONFIG.dash_thunder_fps
	var frames := SpriteFrames.new()
	frames.add_animation(&"dash")
	frames.set_animation_loop(&"dash", false)
	frames.set_animation_speed(&"dash", thunder_fps)
	for index in frame_count:
		var tex := AtlasTexture.new()
		tex.atlas = ATLAS
		tex.region = Rect2(index * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(&"dash", tex)
	sprite = AnimatedSprite2D.new()
	# Stable child name lets a 3D Dream scene register this short-lived visual
	# with its existing depth bridge without introducing a second visual owner.
	sprite.name = "DashTrailSprite"
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.animation_finished.connect(_on_animation_finished)
	add_child(sprite)
	# 必须显式 play()：仅赋值 animation 不会启动播放，
	# 之前“只显示 1 帧”的根因就是缺少这一调用。
	sprite.play(&"dash")
	# 视觉尺寸贴合光痕长度；播放速度只由 dash_thunder_fps 决定，
	# 与 Dash 位移时长/冷却/无敌完全解耦（玩家位移结束不提前删除本节点）。
	sprite.scale = Vector2.ONE * (clampf(streak_length, 40.0, MAX_STREAK_WIDTH) / MAX_FRAME_LENGTH)
	# 防残留保险：即使 animation_finished 因故未触发，也会在整段动画时限后彻底删除。
	var failsafe := get_tree().create_timer(frame_count / maxf(thunder_fps, 1.0) + FADE_OUT_SECONDS + FAILSAFE_EXTRA_SECONDS)
	failsafe.timeout.connect(_failsafe_free)


func _failsafe_free() -> void:
	if is_inside_tree():
		queue_free()


func _on_animation_finished() -> void:
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, FADE_OUT_SECONDS)
	tween.tween_callback(queue_free)
