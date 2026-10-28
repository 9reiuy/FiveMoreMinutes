extends Control
## Comic status lettering: capture the world anchor once, project it every frame.
const COMIC = preload("res://scripts/ui/comic_pixel_text.gd")
var text := ""
var world: Node3D
var anchor := Vector3.ZERO
var age := 0.0
var shadow: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow = Control.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	var material := ShaderMaterial.new()
	material.shader = COMIC.HALFTONE
	shadow.material = material
	add_child(shadow)
	shadow.draw.connect(_draw_shadow)

func present(owner_world: Node3D, value: String) -> void:
	world = owner_world
	text = value
	anchor = world.get_gameplay_world_position(world._player_ground_anchor_position(), 1.15)
	age = 0.0
	modulate = Color.WHITE
	show()
	advance(0.0)

func advance(delta: float) -> void:
	if not visible or not is_instance_valid(world) or not is_instance_valid(world.camera_3d): return
	age += maxf(delta, 0.0)
	position = (world.player.get_presentation_hud_position(world.camera_3d.unproject_position(anchor)) + world.WEAPON_NAME_POPUP_OFFSET + world.WEAPON_NAME_POPUP_SIZE * .5).round()
	queue_redraw()
	shadow.queue_redraw()

func _draw() -> void:
	# The owner's lifetime controls fade/end; no repeating bounce during reload.
	COMIC.draw(self, text, Vector2.ZERO, minf(age, .3 + text.length() * .028), false, 1.0, COMIC.INK, 1000000.0)

func _draw_shadow() -> void:
	COMIC.draw(shadow, text, Vector2.ZERO, minf(age, .3 + text.length() * .028), true, 1.0, COMIC.INK, 1000000.0)
