class_name DreamGunAtlas
extends RefCounted

## Dream武器的唯一视觉映射。Player、Employee、WorldWeapon、Projectile与Shell
## 都从这里取资源，避免同一weapon_id在不同脚本中错配。
const BASIC_TEXTURE := preload("res://art/Dream/weapons/Guns/Luger.png")
const SHOTGUN_TEXTURE := preload("res://art/Dream/weapons/Guns/SawedOffShotgun.png")
const ASSAULT_RIFLE_TEXTURE := preload("res://art/Dream/weapons/Guns/M15.png")
const MP5_TEXTURE := preload("res://art/Dream/weapons/Guns/MP5.png")
const LUCILLE_TEXTURE := preload("res://art/Dream/weapons/Weapons/3.png")
const BOOKS_TEXTURE := preload("res://art/Dream/weapons/Weapons/books.png")
## Separate inventory identities, sharing Lucille's current combat/motion family.
const LUCILLE_VARIANT_IDS: Array[String] = ["melee_plank", "melee_pipe", "melee_pipe_wrench", "melee_wrench", "melee_crowbar", "melee_machete"]
const MELEE_RANGE_MULTIPLIERS := {
	"melee_pipe": 0.7,
	"melee_pipe_wrench": 0.7,
	"melee_wrench": 0.7,
	"melee_crowbar": 0.7,
	"books": 0.5,
}
## Absolute source pixels on each real handle; same two-hand stack as Lucille.
const MELEE_GRIP_PIXELS := {
	"melee_plank": Vector2(14,16),
	"melee_pipe": Vector2(21,16),
	"melee_pipe_wrench": Vector2(18,15),
	"melee_wrench": Vector2(24,16),
	"melee_crowbar": Vector2(23,15),
	"melee_machete": Vector2(15,16),
}

const PISTOL_PROJECTILE := preload("res://art/Dream/weapons/Bullets/PistolAmmoSmall.png")
const SHOTGUN_PROJECTILE := preload("res://art/Dream/weapons/Bullets/RifleAmmoSmall.png")
const ASSAULT_RIFLE_PROJECTILE := preload("res://art/Dream/weapons/Bullets/RifleAmmoBig.png")
const PISTOL_SHELL := preload("res://art/Dream/weapons/Bullets/PistolAmmoSmall.png")
const SHOTGUN_SHELL := preload("res://art/Dream/weapons/Bullets/ShotgunShellSmall.png")
const ASSAULT_RIFLE_SHELL := preload("res://art/Dream/weapons/Bullets/RifleAmmoSmall.png")

const WEAPON_TEXTURES := {
	"basic": BASIC_TEXTURE,
	"shotgun": SHOTGUN_TEXTURE,
	"assault_rifle": ASSAULT_RIFLE_TEXTURE,
	"mp5": MP5_TEXTURE,
	"lucille": LUCILLE_TEXTURE,
	"books": BOOKS_TEXTURE,
	"melee_plank": preload("res://art/Dream/weapons/Weapons/6.png"),
	"melee_pipe": preload("res://art/Dream/weapons/Weapons/11.png"),
	"melee_pipe_wrench": preload("res://art/Dream/weapons/Weapons/21.png"),
	"melee_wrench": preload("res://art/Dream/weapons/Weapons/22.png"),
	"melee_crowbar": preload("res://art/Dream/weapons/Weapons/23.png"),
	"melee_machete": preload("res://art/Dream/weapons/Weapons/43.png"),
}

const PROJECTILE_TEXTURES := {
	"basic": PISTOL_PROJECTILE,
	"shotgun": SHOTGUN_PROJECTILE,
	"assault_rifle": ASSAULT_RIFLE_PROJECTILE,
	"mp5": ASSAULT_RIFLE_PROJECTILE,
}

const SHELL_TEXTURES := {
	"basic": PISTOL_SHELL,
	"shotgun": SHOTGUN_SHELL,
	"assault_rifle": ASSAULT_RIFLE_SHELL,
	"mp5": ASSAULT_RIFLE_SHELL,
}

# TrashCan01未覆盖RigidBody2D.mass，Godot默认值为1.0；以下全部明确低于它。
const WORLD_MASSES := {
	"basic": 0.45,
	"assault_rifle": 0.62,
	"mp5": 0.62,
	"shotgun": 0.68,
	"lucille": 0.78,
	"books": 0.58,
}

const CATEGORY_RANGED: StringName = &"ranged"
const CATEGORY_MELEE: StringName = &"melee"
## Fist is an input/category state rather than a registered weapon resource.
const CATEGORY_FIST: StringName = &"fist"
const WEAPON_CATEGORIES := {
	"basic": CATEGORY_RANGED,
	"shotgun": CATEGORY_RANGED,
	"assault_rifle": CATEGORY_RANGED,
	"mp5": CATEGORY_RANGED,
	"lucille": CATEGORY_MELEE,
	"books": CATEGORY_MELEE,
}

## Stable gameplay-facing names.  UI and world pickups must resolve names from
## the same registry as textures/categories so an ID can never silently show a
## stale, weapon-specific label.
const WEAPON_DISPLAY_NAMES := {
	"basic": "小手枪",
	"shotgun": "霰弹枪",
	"assault_rifle": "突击枪",
	"mp5": "MP5冲锋枪",
	"lucille": "露西尔",
	"books": "Books",
	"melee_plank": "铁棍",
	"melee_pipe": "弯管",
	"melee_pipe_wrench": "管钳",
	"melee_wrench": "扳手",
	"melee_crowbar": "撬棍",
	"melee_machete": "铁棒",
}

const BOOKS_SKIN_COUNT := 4
const BOOKS_SKIN_CELL_SIZE := Vector2(32.0, 26.0)
static var _books_skin_cache: Dictionary = {}


static func has_weapon(weapon_id: String) -> bool:
	return WEAPON_TEXTURES.has(weapon_id)


static func get_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for weapon_id in WEAPON_TEXTURES.keys():
		ids.append(str(weapon_id))
	ids.sort()
	return ids


static func sanitize_weapon_id(weapon_id: String) -> String:
	# Deleted/unknown IDs intentionally become empty-handed rather than silently
	# granting a different weapon to an old save.
	return weapon_id if WEAPON_TEXTURES.has(weapon_id) else ""


static func get_display_name(weapon_id: String) -> String:
	if weapon_id.is_empty():
		return "空手"
	return str(WEAPON_DISPLAY_NAMES.get(weapon_id, weapon_id))


static func has_firearm(weapon_id: String) -> bool:
	return PROJECTILE_TEXTURES.has(weapon_id)


static func uses_lucille_motion(weapon_id: String) -> bool:
	return weapon_id == "lucille" or weapon_id in LUCILLE_VARIANT_IDS


static func get_behavior_id(weapon_id: String) -> String:
	return "lucille" if uses_lucille_motion(weapon_id) else weapon_id


static func get_melee_range_multiplier(weapon_id: String) -> float:
	return float(MELEE_RANGE_MULTIPLIERS.get(weapon_id, 1.0))


static func get_melee_grip_pixels(texture: Texture2D, fallback: Vector2) -> Vector2:
	for weapon_id in LUCILLE_VARIANT_IDS:
		if WEAPON_TEXTURES[weapon_id] == texture:
			return MELEE_GRIP_PIXELS[weapon_id]
	return fallback


static func is_ranged_weapon(weapon_id: String) -> bool:
	return has_firearm(weapon_id)


static func is_automatic_weapon(weapon_id: String) -> bool:
	return weapon_id in ["assault_rifle", "mp5"]


static func get_category(weapon_id: String) -> StringName:
	if weapon_id.is_empty():
		return CATEGORY_FIST
	if uses_lucille_motion(weapon_id):
		return CATEGORY_MELEE
	return WEAPON_CATEGORIES.get(weapon_id, CATEGORY_RANGED) as StringName


static func get_icon(weapon_id: String, skin_index: int = 0) -> Texture2D:
	if weapon_id.is_empty():
		return null
	if weapon_id == "books":
		return _get_books_skin_texture(skin_index)
	return WEAPON_TEXTURES.get(weapon_id, BASIC_TEXTURE) as Texture2D


static func get_held(weapon_id: String, skin_index: int = 0) -> Texture2D:
	return get_icon(weapon_id, skin_index)


static func get_skin_count(weapon_id: String) -> int:
	return BOOKS_SKIN_COUNT if weapon_id == "books" else 1


static func normalize_skin_index(weapon_id: String, skin_index: int) -> int:
	var count := get_skin_count(weapon_id)
	return posmod(skin_index, count) if count > 1 else 0


static func _get_books_skin_texture(skin_index: int) -> Texture2D:
	var normalized := normalize_skin_index("books", skin_index)
	if _books_skin_cache.has(normalized):
		return _books_skin_cache[normalized] as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = BOOKS_TEXTURE
	atlas.region = Rect2(
		BOOKS_SKIN_CELL_SIZE.x * normalized,
		0.0,
		BOOKS_SKIN_CELL_SIZE.x,
		BOOKS_SKIN_CELL_SIZE.y
	)
	atlas.filter_clip = true
	_books_skin_cache[normalized] = atlas
	return atlas


static func get_projectile(weapon_id: String) -> Texture2D:
	return PROJECTILE_TEXTURES.get(weapon_id, PISTOL_PROJECTILE) as Texture2D


static func ejects_shell(weapon_id: String) -> bool:
	return SHELL_TEXTURES.has(weapon_id)


static func get_shell(weapon_id: String) -> Texture2D:
	return SHELL_TEXTURES.get(weapon_id, PISTOL_SHELL) as Texture2D


static func get_world_mass(weapon_id: String) -> float:
	return float(WORLD_MASSES.get(get_behavior_id(weapon_id), WORLD_MASSES["basic"]))
