extends RefCounted
## One consumable equipment piece, shared by the Engineer and Player.
const ART := preload("res://art/Dream/enemy/Engineer.png")
const REGION := Rect2(96, 0, 32, 32)
const HEAD_OFFSET := Vector2(-1, -12)
const DROP_CHANCE := 0.02
static var _texture: AtlasTexture
var actor: Node2D
var sprite: Sprite2D


static func texture() -> AtlasTexture:
	if _texture == null:
		_texture = AtlasTexture.new()
		_texture.atlas = ART
		_texture.region = REGION
	return _texture


func attach(owner_actor: Node2D, head: Sprite2D) -> void:
	actor = owner_actor
	sprite = Sprite2D.new()
	sprite.name = "SafetyHelmet"
	sprite.texture = texture()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = HEAD_OFFSET
	sprite.z_index = 3
	head.add_child(sprite)
	refresh()


func refresh() -> void:
	if is_instance_valid(sprite):
		sprite.visible = bool(actor.get("helmet_equipped"))


func equip() -> bool:
	if bool(actor.get("helmet_equipped")):
		return false
	actor.set("helmet_equipped", true)
	return true


func protect(next_health: float) -> float:
	if next_health <= 0.0 and bool(actor.get("helmet_equipped")):
		# Commit consumption before callbacks or another pellet can enter damage again.
		actor.set("helmet_equipped", false)
		return 1.0
	return next_health
