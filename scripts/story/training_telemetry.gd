extends Control
## Small world-anchored armour/ammunition diagram. No permanent corner HUD.
var ratio:=1.0
var rounds:=2
var armour:=true
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(100,10)
func _draw() -> void:
	draw_rect(Rect2(0,0,100,9),Color("101722"))
	if armour:
		draw_rect(Rect2(1,1,98*clampf(ratio,0,1),7),Color("739d9c"))
	else:
		for i in 12:
			draw_rect(Rect2(2+i*8,2,5,5),Color("d0cba9") if i<rounds else Color("344653"))
