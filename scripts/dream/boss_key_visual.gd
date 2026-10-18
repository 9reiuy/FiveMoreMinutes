extends Node2D

## Small pixel-style key drawn from rectangles so the prototype has no
## placeholder 3D mesh or second art pipeline.

var bob_time := 0.0


## The key is drawn with CanvasItem primitives rather than a Sprite2D.  The
## depth bridge hides the original CanvasLayer source, so expose the same
## passive state-copy contract used by the other custom-drawn world visuals.
## This creates no second pickup or gameplay owner; it only lets the 3D capture
## viewport redraw the existing key silhouette at its current animation time.
func copy_depth_visual_state_to(target: Node2D) -> void:
	if target == null:
		return
	target.set("bob_time", bob_time)
	target.modulate = modulate
	target.self_modulate = self_modulate
	target.scale = scale
	target.queue_redraw()


func _process(delta: float) -> void:
	bob_time += delta
	position.y = roundf(sin(bob_time * 2.2) * 1.0)
	queue_redraw()


func _draw() -> void:
	# The legacy scene is now the Employee Badge carrier.  Keep the silhouette
	# intentionally small and pixel-aligned so it reads as an office ID card,
	# not as the old gold key, while preserving the existing pickup/bridge path.
	var border := Color("263444")
	var card := Color("d9e6ef")
	var stripe := Color("72a8c8")
	var ink := Color("52687c")
	draw_rect(Rect2(-10, -7, 20, 14), border)
	draw_rect(Rect2(-8, -5, 16, 10), card)
	draw_rect(Rect2(-8, -5, 16, 3), stripe)
	draw_rect(Rect2(-5, 0, 4, 3), ink)
	draw_rect(Rect2(1, 0, 6, 1), ink)
	draw_rect(Rect2(1, 2, 4, 1), ink)
