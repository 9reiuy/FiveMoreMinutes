extends Node2D

## 梦境地图运行时填充：Cracks 基础地面、零星 Tiles 残片、外墙环与 Crawling Depths 装饰。
## 素材：Crawling Depths，作者 pingupollas（署名见 docs/THIRD_PARTY_ASSETS.md）。
## 地图固定种子生成，墙环带物理碰撞（碰撞层 8），装饰纯视觉不参与战斗。
## 地表构成：可走区域约 90% 为 Cracks，Tiles 类人工地面残片不超过 10% 且只以小片零星分布。
## Tentacle 地图装饰占比 = 0：触手素材只允许由 TentacleSpawner 以正式敌人形式生成。

const ASSET_DIR := "res://assets/art/dream/crawling_depths/"
const GRID := Vector2i(65, 30)
const SPAWN_CENTER := Vector2(520, 240)
const SPAWN_CLEAR_RADIUS := 140.0
const WAKE_POINT := Vector2(120, 394)
const WAKE_CLEAR_RADIUS := 64.0
const TILE_BUDGET_RATIO := 0.10
const TILE_PATCH_MAX_ATTEMPTS := 400
const DECORATION_MARGIN := 48.0
const MAP_SEED := 20260807

const FLOOR_SOURCE := 0
const WALL_SOURCE := 1
const CRACK_SOURCE := 2

const WALL_CELLS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(1, 1), Vector2i(1, 2),
	Vector2i(3, 2), Vector2i(4, 2), Vector2i(1, 4), Vector2i(1, 5),
]

var rng := RandomNumberGenerator.new()

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var tile_patch_layer: TileMapLayer = $TilePatchLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var decoration_container: Node2D = $Decorations


func _ready() -> void:
	rng.seed = MAP_SEED
	_fill_ground()
	_fill_walls()
	_place_static_decorations()
	_place_animated_decorations()


func _fill_ground() -> void:
	var crack_cells: Array[Vector2i] = []
	for y in range(4):
		for x in range(2):
			crack_cells.append(Vector2i(x, y))
	for y in range(1, GRID.y - 1):
		for x in range(1, GRID.x - 1):
			var atlas_cell: Vector2i = crack_cells[rng.randi_range(0, crack_cells.size() - 1)]
			ground_layer.set_cell(Vector2i(x, y), CRACK_SOURCE, atlas_cell)
	_place_tile_patches()


## Tiles 只作为被裂纹吞噬后残存的人工地面碎片：小片、零星、总量不超过可走地面的 10%。
func _place_tile_patches() -> void:
	var floor_cells: Array[Vector2i] = []
	for y in range(4):
		for x in range(5):
			floor_cells.append(Vector2i(x, y))
	var inner_cell_count := (GRID.x - 2) * (GRID.y - 2)
	var tile_budget := int(floor(float(inner_cell_count) * TILE_BUDGET_RATIO))
	var placed := 0
	var tile_cells: Dictionary = {}
	for _attempt in range(TILE_PATCH_MAX_ATTEMPTS):
		if placed >= tile_budget:
			break
		var center := Vector2i(rng.randi_range(3, GRID.x - 4), rng.randi_range(3, GRID.y - 4))
		var patch_cells: Array[Vector2i] = _build_patch_cells(center)
		var valid := patch_cells.size() > 0
		for cell in patch_cells:
			if not _is_tile_cell_isolated(cell, tile_cells):
				valid = false
				break
		if not valid:
			continue
		for cell in patch_cells:
			if placed >= tile_budget:
				break
			tile_patch_layer.set_cell(cell, FLOOR_SOURCE, floor_cells[rng.randi_range(0, floor_cells.size() - 1)])
			tile_cells[cell] = true
			placed += 1


func _build_patch_cells(center: Vector2i) -> Array[Vector2i]:
	var roll := rng.randf()
	var cells: Array[Vector2i] = []
	if roll < 0.35:
		for dy in range(2):
			for dx in range(2):
				cells.append(center + Vector2i(dx, dy))
	elif roll < 0.60:
		for dy in range(2):
			for dx in range(3):
				cells.append(center + Vector2i(dx, dy))
	elif roll < 0.80:
		cells.append(center)
	else:
		cells.append(center)
		cells.append(center + Vector2i(1, 0))
		cells.append(center + Vector2i(rng.randi_range(0, 1), 1))
	return cells


## Tiles 残片之间保持明显间隔，避免连成大块或棋盘式分布。
func _is_tile_cell_isolated(cell: Vector2i, tile_cells: Dictionary) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if tile_cells.has(cell + Vector2i(dx, dy)):
				return false
	return true


func _fill_walls() -> void:
	for x in range(GRID.x):
		_set_wall_cell(Vector2i(x, 0))
		_set_wall_cell(Vector2i(x, GRID.y - 1))
	for y in range(GRID.y):
		_set_wall_cell(Vector2i(0, y))
		_set_wall_cell(Vector2i(GRID.x - 1, y))


func _set_wall_cell(cell: Vector2i) -> void:
	wall_layer.set_cell(cell, WALL_SOURCE, WALL_CELLS[rng.randi_range(0, WALL_CELLS.size() - 1)])


func _place_static_decorations() -> void:
	var specs: Array[Array] = [
		[ASSET_DIR + "statue_a.png", 2],
		[ASSET_DIR + "statue_b.png", 2],
		[ASSET_DIR + "statue_c.png", 2],
		[ASSET_DIR + "vein_column_short.png", 3],
		[ASSET_DIR + "vein_column_tall.png", 3],
		[ASSET_DIR + "urn_1.png", 4],
		[ASSET_DIR + "urn_2.png", 4],
		[ASSET_DIR + "book_altar.png", 2],
	]
	for spec in specs:
		var texture := load(String(spec[0])) as Texture2D
		if texture == null:
			continue
		for _index in range(int(spec[1])):
			var spot := _find_decoration_position()
			if spot == Vector2.INF:
				continue
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.position = spot
			decoration_container.add_child(sprite)


func _place_animated_decorations() -> void:
	# 帧布局来自素材表实测：eye 32x32x28、mouth 56宽x64高x18、
	# vein 29宽x16高x12、floating_rock 32x32x6、little_eyes 16x16x36。
	# 规则：地图本身不出现任何 Tentacle 装饰（tentacle_sheet.png 仅限触手怪敌人使用）。
	var eye_frames := _grid_frames(28, Vector2(32, 32), Vector2.ZERO)
	var mouth_frames: Array[Rect2] = []
	for index in range(18):
		mouth_frames.append(Rect2(6 + 64 * index, 0, 56, 64))
	var vein_frames: Array[Rect2] = []
	for index in range(12):
		vein_frames.append(Rect2(3 + 32 * index, 0, 29, 16))
	var rock_frames := _grid_frames(6, Vector2(32, 32), Vector2.ZERO)
	var little_eye_frames := _grid_frames(36, Vector2(16, 16), Vector2.ZERO)
	var specs: Array[Array] = [
		[ASSET_DIR + "eye_sheet.png", eye_frames, 2.0, 5],
		[ASSET_DIR + "mouth_sheet.png", mouth_frames, 2.0, 3],
		[ASSET_DIR + "vein_sheet.png", vein_frames, 2.0, 8],
		[ASSET_DIR + "floating_rock_sheet.png", rock_frames, 2.0, 4],
		[ASSET_DIR + "little_eyes_sheet.png", little_eye_frames, 4.0, 6],
	]
	for spec in specs:
		var texture := load(String(spec[0])) as Texture2D
		var frames: Array[Rect2] = spec[1]
		if texture == null or frames.is_empty():
			continue
		var sprite_frames := SpriteFrames.new()
		sprite_frames.set_animation_speed(&"default", float(spec[2]))
		sprite_frames.set_animation_loop(&"default", true)
		for region in frames:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			sprite_frames.add_frame(&"default", atlas)
		for _index in range(int(spec[3])):
			var spot := _find_decoration_position()
			if spot == Vector2.INF:
				continue
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = sprite_frames
			sprite.position = spot
			sprite.frame = rng.randi_range(0, frames.size() - 1)
			sprite.play(&"default")
			decoration_container.add_child(sprite)


func _grid_frames(count: int, size: Vector2, origin: Vector2) -> Array[Rect2]:
	var frames: Array[Rect2] = []
	for index in range(count):
		frames.append(Rect2(origin + Vector2(size.x * index, 0), size))
	return frames


## 找一个避开出生安全区、唤醒点与墙环的装饰位置；找不到返回 INF。
func _find_decoration_position() -> Vector2:
	for _attempt in range(40):
		var candidate := Vector2(
			rng.randf_range(DECORATION_MARGIN, GRID.x * 16.0 - DECORATION_MARGIN),
			rng.randf_range(DECORATION_MARGIN, GRID.y * 16.0 - DECORATION_MARGIN)
		)
		if candidate.distance_to(SPAWN_CENTER) < SPAWN_CLEAR_RADIUS:
			continue
		if candidate.distance_to(WAKE_POINT) < WAKE_CLEAR_RADIUS:
			continue
		return candidate
	return Vector2.INF
