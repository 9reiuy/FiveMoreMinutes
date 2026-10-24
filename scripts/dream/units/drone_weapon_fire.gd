extends Node3D
## Muzzle flash rig shared by the drone sample and formal game.
##
## Lives under Drone/Weapon/MuzzleBrake, builds its own additive flash quads and
## an OmniLight3D, then either self-runs on a timer or is stepped frame by frame
## by the capture script (set_flash_time); live_animation advances manual shots.

const FLASH_SHADER := preload("res://shaders/dream3d/drone_muzzle_flash.gdshader")
const STAR_SHADER := preload("res://shaders/dream3d/drone_muzzle_star.gdshader")
const FLASH_DURATION := 0.16
const FIRE_INTERVAL := 0.70
const LIGHT_PEAK := 12.0
const RECOIL := 0.035
const PUFF_COUNT := 12

var auto_fire := true
var flash_time := FLASH_DURATION
var cooldown := 0.25

var _weapon: Node3D
var _rotor: Node3D
var _flash_root: Node3D
var _flash_material: ShaderMaterial
var _light: OmniLight3D
var _weapon_rest_z := 0.0
var _recoil := 0.0
var recoil_strength:=RECOIL
var live_animation:=false
var _puffs: Array[Dictionary] = []
var _puff_texture: ImageTexture


func _ready() -> void:
	_weapon = get_parent().get_parent() as Node3D
	if _weapon == null or not is_instance_valid(_weapon):
		push_warning("DroneWeaponFire: expected parent chain MuzzleBrake -> Weapon")
		return
	_weapon_rest_z = _weapon.position.z
	# Rotor is a sibling of Weapon under the drone root.
	_rotor = _weapon.get_parent().get_node_or_null("Rotor") as Node3D
	_build_flash()
	_build_smoke()
	_apply_state()


func _build_flash() -> void:
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = FLASH_SHADER
	_flash_root = Node3D.new()
	_flash_root.name = "FlashRoot"
	# Runtime-only nodes: intentionally left without an owner so the packed
	# sample scene stores the rig, not a baked flash pose.
	add_child(_flash_root)

	# Camera-facing star + a short forward spike for volume.
	var star := Sprite3D.new()
	star.name = "FlashStar"
	star.texture = _make_star_texture()
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	star.pixel_size = 0.016
	star.position = Vector3(0.0, 0.0, -0.16)
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var star_material := ShaderMaterial.new()
	star_material.shader = STAR_SHADER
	star_material.set_shader_parameter("burst_texture", star.texture)
	star_material.set_shader_parameter("flash_color", Color(1.0, 0.66, 0.28))
	star.material_override = star_material
	_flash_root.add_child(star)

	var spike := MeshInstance3D.new()
	spike.name = "FlashSpike"
	var spike_mesh := BoxMesh.new()
	spike_mesh.size = Vector3(0.10, 0.10, 0.30)
	spike.mesh = spike_mesh
	spike.material_override = _flash_material
	spike.position = Vector3(0.0, 0.0, -0.13)
	spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_root.add_child(spike)

	_light = OmniLight3D.new()
	_light.name = "FlashLight"
	_light.light_color = Color("ffb066")
	_light.omni_range = 9.0
	_light.omni_attenuation = 1.4
	_light.light_specular = 0.6
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.0, -0.16)
	add_child(_light)


func _process(delta: float) -> void:
	if auto_fire:
		cooldown -= delta
		if cooldown <= 0.0:
			fire()
		flash_time += delta
	if live_animation:
		if not auto_fire: flash_time+=delta
		_recoil=recoil_strength*clampf(1.0-flash_time/.18,0.0,1.0)
	if _rotor != null and is_instance_valid(_rotor):
		_rotor.rotation.y += delta * 9.0
	_update_smoke(delta)
	_apply_state()


## Start one shot.  Recoil kicks the Weapon back along +Z, the muzzle's rear.
func fire() -> void:
	flash_time = 0.0
	cooldown = FIRE_INTERVAL
	_recoil = recoil_strength
	if _flash_root != null:
		_flash_root.rotation.z = randf_range(-0.6, 0.6)
	_spawn_smoke()
	_apply_state()


## Deterministic driving for captures: set the time since ignition directly.
func set_flash_time(time_since_fire: float) -> void:
	flash_time = time_since_fire
	_recoil = recoil_strength * clampf(1.0 - time_since_fire / 0.18, 0.0, 1.0)
	_apply_state()


func _apply_state() -> void:
	if _flash_root == null:
		return
	var open := flash_time < FLASH_DURATION
	_flash_root.visible = open and not bool(get_meta(&"particle_flame",false))
	if open:
		var k: float = clampf(flash_time / FLASH_DURATION, 0.0, 1.0)
		var falloff: float = pow(1.0 - k, 1.7)
		_flash_root.scale = Vector3.ONE * lerpf(0.55, 1.25, falloff)
		_flash_material.set_shader_parameter("intensity", 0.5 + 1.9 * falloff)
		var star := _flash_root.get_node_or_null("FlashStar") as Sprite3D
		if star != null:
			star.scale = Vector3.ONE * lerpf(0.9, 2.4, falloff)
			star.modulate.a = clampf(falloff * 1.4, 0.0, 1.0)
		_light.light_energy = LIGHT_PEAK * pow(1.0 - k, 2.1)
	else:
		_light.light_energy = 0.0
	if _weapon != null and is_instance_valid(_weapon):
		_weapon.position.z = _weapon_rest_z + _recoil


## Blocky muzzle smoke: a small pool of billboarded pixel puffs that expand,
## drift forward and fade.  Shared by the studio sample and the in-game shot.
func _build_smoke() -> void:
	_puff_texture = _make_puff_texture()
	for _index in PUFF_COUNT:
		var sprite := Sprite3D.new()
		sprite.texture = _puff_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = 0.01
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		sprite.visible = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sprite)
		_puffs.append({
			"node": sprite,
			"age": 99.0,
			"life": 1.0,
			"size": 1.0,
			"vel": Vector3.ZERO,
		})


func _make_puff_texture() -> ImageTexture:
	return preload("res://scripts/dream/nyangeon_vfx_shapes.gd").smoke_texture()


func _spawn_smoke() -> void:
	for _shot in 3:
		for puff in _puffs:
			if float(puff["age"]) < float(puff["life"]):
				continue
			var node: Sprite3D = puff["node"]
			node.visible = true
			node.position = Vector3(randf_range(-0.04, 0.04), randf_range(-0.03, 0.03), -0.22)
			node.scale = Vector3.ONE * 0.6
			node.modulate.a = 0.0
			puff["age"] = 0.0
			puff["life"] = randf_range(0.55, 0.95)
			puff["size"] = randf_range(0.8, 1.4)
			puff["vel"] = Vector3(
				randf_range(-0.30, 0.30),
				randf_range(0.05, 0.40),
				-randf_range(0.55, 1.10)
			)
			break


func _update_smoke(delta: float) -> void:
	for puff in _puffs:
		var node: Sprite3D = puff["node"]
		if not node.visible:
			continue
		var age := float(puff["age"]) + delta
		puff["age"] = age
		var life := float(puff["life"])
		var t := age / life
		if t >= 1.0:
			node.visible = false
			continue
		node.position += (puff["vel"] as Vector3) * delta
		node.scale = Vector3.ONE * lerpf(0.7, 2.8, t) * float(puff["size"])
		node.modulate.a = pow(1.0 - t, 1.3) * 0.78


## Hard-edged pixel star: bright core, four long arms, four short diagonals.
func _make_star_texture() -> ImageTexture:
	var size := 24
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := 11.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - centre, float(y) - centre)
			var glow := clampf(1.0 - d.length() / 5.0, 0.0, 1.0)
			var arms := 0.0
			if absf(d.x) <= 1.6:
				arms = maxf(arms, 1.0 - absf(d.y) / 10.5)
			if absf(d.y) <= 1.6:
				arms = maxf(arms, 1.0 - absf(d.x) / 10.5)
			if absf(absf(d.x) - absf(d.y)) <= 1.2:
				arms = maxf(arms, (1.0 - d.length() / 8.0) * 0.75)
			var alpha := maxf(glow, arms)
			if alpha < 0.22:
				alpha = 0.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
