extends Node2D
# 弹丸本体统一使用 SP402 序列首帧（SP402_01）静态保持，飞行全程常驻直到命中或销毁；
# 后续序列帧由枪口序列帧子特效完整播放，不阻塞弹丸本体与射速。
const BULLET_TEXTURE: Texture2D = preload("res://art/Effects/SP402_nyknck/SP402_01.png")
# SP402_01 帧内弹丸内容中心约在 (39.5, 16)，绘制时将其对准弹体坐标。
const BULLET_CONTENT_CENTER := Vector2(39.5, 16.0)
# 三倍扩图后的梦境地图边界（与 dream_world.WORLD_SIZE 一致并略外扩）。
# 旧小地图硬编码边界 (30..610, 54..312) 会让飞入新区域的弹丸凭空消失，已废弃。
const ARENA_BOUNDS := Rect2(-16.0, -16.0, 1072.0, 512.0)
var direction:=Vector2.RIGHT; var damage:=10.0; var speed:=170.0; var max_distance:=300.0; var radius:=5.0; var traveled:=0.0; var target:Node2D
func setup(dir:Vector2,dmg:float,spd:float,distance:float,hit_radius:float,new_target:Node2D)->void: direction=dir.normalized(); damage=dmg; speed=spd; max_distance=distance; radius=hit_radius; target=new_target; rotation=direction.angle()+PI; queue_redraw() # SP402 前进轴为局部 -x，朝向 +PI 单独处理，帧不倒放
func _process(delta:float)->void:
	var step:=speed*delta; position+=direction*step; traveled+=step
	if is_instance_valid(target) and global_position.distance_to(target.global_position)<=radius+10: target.receive_damage(damage); queue_free(); return
	# 弹丸只允许因命中目标、超出最大飞行距离、离开地图边界而销毁；
	# 每发弹丸都是独立实例，新一发生成不会触碰仍在飞行中的旧弹丸。
	if traveled>=max_distance or not ARENA_BOUNDS.has_point(global_position): queue_free()
func _draw()->void: draw_texture_rect(BULLET_TEXTURE, Rect2(-BULLET_CONTENT_CENTER, BULLET_TEXTURE.get_size()), false)
