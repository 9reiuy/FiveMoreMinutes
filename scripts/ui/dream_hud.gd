extends Control

@export var config: DemoConfig

@onready var dash_icon: TextureRect = $DashIndicator/DashIcon
@onready var endless_day_area: Control = $EndlessDayArea
@onready var endless_day_label: Label = $EndlessDayArea/DayLabel
@onready var endless_day_progress: ProgressBar = $EndlessDayArea/DayProgress
var dungeon_minimap: Control = null

var time_text := "04:00"
var health := 100.0
var maximum_health := 100.0
var kills := 0
var dash_remaining := 0.0
var dash_total := 2.0
var dash_active := false
var dash_charges := 1
var dash_max_charges := 1
var dash_hunger_disabled := false
var shielded := false
var dissociation_ready := false
var endless_mode := false
var endless_day_duration := 120.0
var displayed_time_scale := 1.0
var vhs_preview_rect: ColorRect = null


func _ready() -> void:
	_update_dash_indicator()
	endless_day_area.visible = endless_mode
	dash_icon.visible = false
	_init_vhs_preview()


func _init_vhs_preview() -> void:
	var shader = load("res://shaders/dream3d/vhs_tactical_preview.gdshader") as Shader
	if shader != null:
		vhs_preview_rect = ColorRect.new()
		vhs_preview_rect.name = "VHSTacticalPreview"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		vhs_preview_rect.material = mat
		vhs_preview_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vhs_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vhs_preview_rect.visible = false
		add_child(vhs_preview_rect)


func _process(_delta: float) -> void:
	var time_controller := get_node_or_null("/root/DreamTimeController")
	if time_controller == null:
		time_controller = get_tree().get_first_node_in_group(&"dream_time_controller")
	if time_controller != null and time_controller.has_method("get_resolved_time_scale"):
		displayed_time_scale = maxf(float(time_controller.call("get_resolved_time_scale")), 0.0)
	else:
		displayed_time_scale = maxf(Engine.time_scale, 0.0)

	if time_controller != null and time_controller.has_method("is_tactical_planning_active"):
		var is_planning: bool = bool(time_controller.call("is_tactical_planning_active"))
		if vhs_preview_rect != null and vhs_preview_rect.visible != is_planning:
			vhs_preview_rect.visible = is_planning

	queue_redraw()


func set_clock(value: String) -> void:
	time_text = value
	queue_redraw()


func configure_endless_mode(enabled: bool, day_duration: float) -> void:
	endless_mode = enabled
	endless_day_duration = maxf(day_duration, 0.001)
	if is_node_ready():
		endless_day_area.visible = enabled


func set_endless_day_progress(day: int, progress: float) -> void:
	if not is_node_ready():
		return
	endless_day_label.text = "第%d天" % maxi(day, 1)
	endless_day_progress.value = clampf(progress, 0.0, 1.0) * 100.0


func set_health(current: float, maximum: float) -> void:
	health = current
	maximum_health = maximum
	queue_redraw()


func set_weapon_state(
	ranged_weapon_id: String,
	melee_weapon_id: String,
	selected_weapon_id: String,
	active_weapon_category: StringName = &""
) -> void:
	# Kept as a compatibility endpoint for DreamPlayer; the removed combat panel
	# no longer owns an update chain or a second inventory presentation.
	pass


func set_flashlight_available(available: bool) -> void:
	# Compatibility endpoint retained for older Player callers.
	pass


## The Random Dream world supplies the already-authored macro topology.  HUD
## only forwards it to the minimap renderer; it never discovers rooms itself.
func set_dungeon_minimap_data(
	rooms: Array,
	connections: Array,
	corridors: Array,
	cell_pixels: float = 32.0
) -> void:
	if dungeon_minimap != null and dungeon_minimap.has_method("configure"):
		dungeon_minimap.call("configure", rooms, connections, corridors, cell_pixels)


func set_dungeon_minimap_room_state(room_id: int, state: StringName) -> void:
	if dungeon_minimap != null and dungeon_minimap.has_method("set_room_state"):
		dungeon_minimap.call("set_room_state", room_id, state)


func set_dungeon_minimap_corridor_state(corridor_id: int, state: StringName) -> void:
	if dungeon_minimap != null and dungeon_minimap.has_method("set_corridor_state"):
		dungeon_minimap.call("set_corridor_state", corridor_id, state)


func set_dungeon_minimap_player(position: Vector2, room_id: int) -> void:
	if dungeon_minimap != null and dungeon_minimap.has_method("set_player_state"):
		dungeon_minimap.call("set_player_state", position, room_id)


func set_dash_state(remaining: float, total: float, active: bool, charges: int = 1, maximum_charges: int = 1) -> void:
	dash_remaining = remaining
	dash_total = maxf(total, 0.001)
	dash_active = active
	dash_charges = charges
	dash_max_charges = maximum_charges
	_update_dash_indicator()
	queue_redraw()


func set_hungry_run(enabled: bool) -> void:
	dash_hunger_disabled = enabled
	_update_dash_indicator()
	queue_redraw()


func _update_dash_indicator() -> void:
	if not is_instance_valid(dash_icon):
		return
	var material := dash_icon.material as ShaderMaterial
	if material == null:
		return
	# 仍有可用次数时保持完整图标；次数耗尽后，按剩余冷却比例让灰色遮罩
	# 从底部逐步退去。空腹禁用和冲刺动作本身显示为完全灰色。
	var cooldown_ratio := 0.0
	if dash_hunger_disabled or dash_active:
		cooldown_ratio = 1.0
	elif dash_charges <= 0:
		cooldown_ratio = clampf(dash_remaining / maxf(dash_total, 0.001), 0.0, 1.0)
	material.set_shader_parameter("cooldown_ratio", cooldown_ratio)


func set_skill_state(has_shield: bool, revive_ready: bool) -> void:
	shielded = has_shield
	dissociation_ready = revive_ready
	queue_redraw()


func _draw() -> void:
	var font := PixelFont.get_font()
	# The HUD draws the clock, shared time multiplier, and non-progression status.
	if not endless_mode:
		draw_string(font, Vector2(0, 66), time_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 19, Color("d2ced6"))
	if shielded:
		draw_string(font, Vector2(510, 80), "护盾 ◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8ebad0"))
	if dissociation_ready:
		draw_string(font, Vector2(510, 97), "意识解离 ◈", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d7b45f"))
	# Keep the time multiplier in the Dream HUD itself so both legacy 2D and 3D
	# gameplay presentations consume the same DreamTimeController authority.
	var viewport_size := get_viewport_rect().size
	var indicator_y := viewport_size.y - 14.0
	var triangle := PackedVector2Array([
		Vector2(14.0, indicator_y - 7.0),
		Vector2(14.0, indicator_y + 5.0),
		Vector2(20.0, indicator_y - 1.0),
	])
	draw_colored_polygon(triangle, Color("d2ced6"))
	draw_string(font, Vector2(27.0, indicator_y + 3.0), "x %.2f" % displayed_time_scale, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d2ced6"))
