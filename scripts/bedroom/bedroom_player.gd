extends CharacterBody2D

@export var speed := 125.0
var movement_enabled := true


func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right") if movement_enabled else 0.0
	velocity = Vector2(direction * speed, 0.0)
	move_and_slide()
	global_position.x = clampf(global_position.x, 34.0, 606.0)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, -27), 9.0, Color("98949a"))
	draw_rect(Rect2(-8, -18, 16, 27), Color("5f6270"))
	draw_line(Vector2(-5, 9), Vector2(-7, 22), Color("777985"), 4.0)
	draw_line(Vector2(5, 9), Vector2(7, 22), Color("777985"), 4.0)
