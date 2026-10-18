class_name PlayerCombatInfoPanel
extends Control

## Compact, event-driven battle HUD view.  This node owns no gameplay state:
## callers only publish the authoritative Player values through the setters
## below.  It deliberately draws the six slot rings in one place so the
## layout stays pixel-stable at every canvas scale.

const WEAPON_ATLAS: Script = preload("res://scripts/data/dream_gun_atlas.gd")
const PORTRAIT: Texture2D = preload("res://art/Dream/chr_page.png")
const FIST_ICON: Texture2D = preload("res://art/icon/Sprites_Cropped/RPG_Stat_Strength_Fist_Melee_Attack.png")
const DASH_ICON: Texture2D = preload("res://art/icon/dash.png")
const FLASHLIGHT_ICON: Texture2D = preload("res://art/icon/Sprites_Cropped/Software_Flashlight_Torch_Illumination_Lighting.png")
const FOOD_ICON: Texture2D = preload("res://art/icon/Sprites_Cropped/Food_Bread_Loaf.png")

## A near-square status cluster: the portrait is the visual centre and the
## six slots orbit it in a shallow hexagonal arc.  Coordinates are authored
## once in the panel's local space so viewport resizing cannot stretch them.
const PORTRAIT_RECT := Rect2(83.0, 55.0, 74.0, 86.0)
const LEFT_SLOT_POSITIONS := [Vector2(55.0, 43.0), Vector2(31.0, 102.0), Vector2(55.0, 161.0)]
const RIGHT_SLOT_POSITIONS := [Vector2(185.0, 43.0), Vector2(209.0, 102.0), Vector2(185.0, 161.0)]
const SLOT_RADIUS := 18.0
const SELECTED_RADIUS := 22.0
const HEALTH_RECT := Rect2(16.0, 207.0, 208.0, 15.0)

const SLOT_FILL_COLOR := Color("f4f1eadb")
const SLOT_RING_COLOR := Color("777084dc")
const SLOT_EMPTY_COLOR := Color("fffdf5ff")
const SLOT_SELECTED_COLOR := Color("423d50ff")
const ICON_DISABLED_COLOR := Color("77727b99")
const HEALTH_BACK_COLOR := Color("241b23ff")
const HEALTH_FILL_COLOR := Color("bd4c55ff")
const HEALTH_EDGE_COLOR := Color("17151cff")

var ranged_weapon_id := ""
var melee_weapon_id := ""
var selected_weapon_id := ""
var active_weapon_category: StringName = &""
var ranged_icon: Texture2D
var melee_icon: Texture2D
var health := 0.0
var maximum_health := 1.0
var dash_remaining := 0.0
var dash_total := 1.0
var dash_active := false
var dash_charges := 0
var dash_max_charges := 0
var dash_hunger_disabled := false
var flashlight_available := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func set_weapon_state(
	next_ranged_weapon_id: String,
	next_melee_weapon_id: String,
	next_selected_weapon_id: String,
	next_active_weapon_category: StringName = &""
) -> void:
	ranged_weapon_id = next_ranged_weapon_id
	melee_weapon_id = next_melee_weapon_id
	selected_weapon_id = next_selected_weapon_id
	active_weapon_category = next_active_weapon_category
	ranged_icon = WEAPON_ATLAS.get_icon(ranged_weapon_id) if not ranged_weapon_id.is_empty() else null
	melee_icon = WEAPON_ATLAS.get_icon(melee_weapon_id) if not melee_weapon_id.is_empty() else null
	queue_redraw()


func set_health(current: float, maximum: float) -> void:
	health = maxf(current, 0.0)
	maximum_health = maxf(maximum, 1.0)
	queue_redraw()


func set_dash_state(remaining: float, total: float, active: bool, charges: int, maximum_charges: int) -> void:
	dash_remaining = maxf(remaining, 0.0)
	dash_total = maxf(total, 0.001)
	dash_active = active
	dash_charges = maxi(charges, 0)
	dash_max_charges = maxi(maximum_charges, 0)
	queue_redraw()


func set_hungry_run(disabled: bool) -> void:
	dash_hunger_disabled = disabled
	queue_redraw()


func set_flashlight_available(available: bool) -> void:
	flashlight_available = available
	queue_redraw()


func _draw() -> void:
	# The status cluster deliberately has no card/panel backdrop.  Only the
	# portrait, circular slots, and the single HP bar are drawn over the game.
	_draw_portrait()
	_draw_weapon_slots()
	_draw_function_slots()
	_draw_health_bar()


func _draw_portrait() -> void:
	_draw_texture_fitted(PORTRAIT, PORTRAIT_RECT, Color.WHITE)


func _draw_weapon_slots() -> void:
	var ranged_selected := selected_weapon_id == ranged_weapon_id and not ranged_weapon_id.is_empty()
	var melee_selected := selected_weapon_id == melee_weapon_id and not melee_weapon_id.is_empty()
	if not active_weapon_category.is_empty():
		ranged_selected = ranged_selected and active_weapon_category == WEAPON_ATLAS.CATEGORY_RANGED
		melee_selected = melee_selected and active_weapon_category == WEAPON_ATLAS.CATEGORY_MELEE
	_draw_slot(LEFT_SLOT_POSITIONS[0], ranged_icon, ranged_weapon_id.is_empty(), ranged_selected)
	_draw_slot(LEFT_SLOT_POSITIONS[1], melee_icon, melee_weapon_id.is_empty(), melee_selected)
	_draw_slot(LEFT_SLOT_POSITIONS[2], FIST_ICON, false, selected_weapon_id.is_empty())


func _draw_function_slots() -> void:
	var dash_disabled := dash_hunger_disabled or dash_active or dash_charges <= 0
	var dash_color := ICON_DISABLED_COLOR if dash_disabled else Color.WHITE
	_draw_slot(RIGHT_SLOT_POSITIONS[0], DASH_ICON, false, false, dash_color)
	_draw_slot(RIGHT_SLOT_POSITIONS[1], FLASHLIGHT_ICON, false, false, Color.WHITE if flashlight_available else ICON_DISABLED_COLOR)
	# Food is intentionally a visual placeholder only; there is no food state
	# or input behind this slot.
	_draw_slot(RIGHT_SLOT_POSITIONS[2], FOOD_ICON, false, false, ICON_DISABLED_COLOR)


func _draw_slot(center: Vector2, icon: Texture2D, empty: bool, selected: bool, icon_color: Color = Color.WHITE) -> void:
	draw_circle(center, SLOT_RADIUS, SLOT_FILL_COLOR)
	draw_arc(center, SLOT_RADIUS, 0.0, TAU, 24, SLOT_RING_COLOR, 2.0, false)
	if selected:
		# The selected state is a separate outer ring, not an icon recolour.
		draw_arc(center, SELECTED_RADIUS, 0.0, TAU, 24, SLOT_SELECTED_COLOR, 3.0, false)
	if empty or icon == null:
		# Keep an explicit white empty state instead of hiding the category slot.
		draw_circle(center, 3.0, SLOT_EMPTY_COLOR)
		return
	_draw_texture_fitted(icon, Rect2(center - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), icon_color)


func _draw_health_bar() -> void:
	draw_rect(HEALTH_RECT, HEALTH_EDGE_COLOR, true)
	var inner := HEALTH_RECT.grow(-2.0)
	draw_rect(inner, HEALTH_BACK_COLOR, true)
	var ratio := clampf(health / maximum_health, 0.0, 1.0)
	if ratio > 0.0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), HEALTH_FILL_COLOR, true)
		# One-pixel highlight makes the bar readable in the pale Interiors A rooms.
		draw_line(inner.position + Vector2(1.0, 1.0), Vector2(inner.position.x + inner.size.x * ratio - 1.0, inner.position.y + 1.0), Color("f08a80b0"), 1.0)


func _draw_texture_fitted(texture: Texture2D, target: Rect2, color: Color) -> void:
	if texture == null:
		return
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale := minf(target.size.x / source_size.x, target.size.y / source_size.y)
	var size := source_size * scale
	var rect := Rect2(target.position + (target.size - size) * 0.5, size)
	draw_texture_rect(texture, rect, false, color)
