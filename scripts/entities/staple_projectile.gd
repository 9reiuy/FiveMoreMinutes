extends Node2D
var direction:=Vector2.RIGHT; var damage:=10.0; var speed:=170.0; var max_distance:=300.0; var radius:=5.0; var traveled:=0.0; var target:Node2D
func setup(dir:Vector2,dmg:float,spd:float,distance:float,hit_radius:float,new_target:Node2D)->void: direction=dir.normalized(); damage=dmg; speed=spd; max_distance=distance; radius=hit_radius; target=new_target
func _process(delta:float)->void:
	var step:=speed*delta; position+=direction*step; traveled+=step
	if is_instance_valid(target) and global_position.distance_to(target.global_position)<=radius+10: target.receive_damage(damage); queue_free(); return
	if traveled>=max_distance or global_position.x<30 or global_position.x>610 or global_position.y<54 or global_position.y>312: queue_free()
func _draw()->void: draw_line(Vector2(-7,0),Vector2(7,0),Color("d5d2c8"),3)
