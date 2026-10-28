extends SceneTree

var checks: int = 0
var failures: Array[String] = []

class MockWorld extends Node3D:
	var floor_root: Node3D = Node3D.new()
	var camera_3d: Camera3D = Camera3D.new()

	func _ready() -> void:
		add_child(floor_root)
		add_child(camera_3d)

	func _muzzle_smoke() -> Node3D:
		var existing: Node = floor_root.get_node_or_null("MuzzleSmoke")
		if existing != null:
			return existing as Node3D
		var smoke: Node3D = (preload("res://scripts/dream/muzzle_smoke.gd").new()) as Node3D
		smoke.name = "MuzzleSmoke"
		floor_root.add_child(smoke)
		smoke.call("configure", self)
		return smoke

	func _clear_muzzle_and_burning_vfx() -> void:
		var host: Node = floor_root if floor_root != null else self
		if is_instance_valid(host):
			var burning_node: Node = host.get_node_or_null("BurningEffects")
			if is_instance_valid(burning_node) and burning_node.has_method("clear"):
				burning_node.clear()
			var smoke_node: Node = host.get_node_or_null("MuzzleSmoke")
			if is_instance_valid(smoke_node) and smoke_node.has_method("clear"):
				smoke_node.clear()
		if host != self and is_instance_valid(self):
			var self_burning: Node = get_node_or_null("BurningEffects")
			if is_instance_valid(self_burning) and self_burning.has_method("clear"):
				self_burning.clear()
			var self_smoke: Node = get_node_or_null("MuzzleSmoke")
			if is_instance_valid(self_smoke) and self_smoke.has_method("clear"):
				self_smoke.clear()

	func _set_muzzle_smoke_visible(visible_state: bool) -> void:
		var host: Node = floor_root if floor_root != null else self
		var smoke: Node = host.get_node_or_null("MuzzleSmoke") if is_instance_valid(host) else null
		if smoke == null and host != self and is_instance_valid(self):
			smoke = get_node_or_null("MuzzleSmoke")
		if is_instance_valid(smoke) and smoke.has_method("set_overlay_visible"):
			smoke.set_overlay_visible(visible_state)


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
		print("FAIL: ", label)
	else:
		print("PASS: ", label)


func run() -> void:
	print("--- Starting Muzzle VFX & Elevator Transition Lifecycle Test ---")
	var root_node: Window = root
	var world: MockWorld = MockWorld.new()
	root_node.add_child(world)

	# =========================================================================
	# Test 1: MuzzleSmoke lifecycle, clear, overlay toggle, and burst suppression
	# =========================================================================
	print("\n[Test 1] MuzzleSmoke lifecycle")
	var smoke: Node3D = world._muzzle_smoke()
	check(smoke != null, "MuzzleSmoke instantiated")
	check(smoke.has_method("clear"), "MuzzleSmoke has clear()")
	check(smoke.has_method("set_overlay_visible"), "MuzzleSmoke has set_overlay_visible()")
	check(smoke.has_method("is_overlay_visible"), "MuzzleSmoke has is_overlay_visible()")
	check(smoke.call("is_overlay_visible") == true, "MuzzleSmoke overlay initially visible")

	# Burst smoke
	smoke.call("burst", Vector3.ZERO, Vector3.RIGHT, 6)
	var puffs_arr: Array = smoke.get("puffs") as Array
	check(puffs_arr.size() > 0, "MuzzleSmoke has puffs after burst: " + str(puffs_arr.size()))

	# Clear smoke
	smoke.call("clear")
	puffs_arr = smoke.get("puffs") as Array
	check(puffs_arr.is_empty(), "MuzzleSmoke puffs empty after clear()")
	check(smoke.get("_pool_drawn") == false, "MuzzleSmoke _pool_drawn reset to false")
	var fills: Array = smoke.get("fills") as Array
	var all_fills_hidden: bool = true
	for s in fills:
		var sprite: Sprite2D = s as Sprite2D
		if sprite.visible:
			all_fills_hidden = false
			break
	check(all_fills_hidden, "All fill sprites hidden after clear()")

	# Burst again to confirm recovery
	smoke.call("burst", Vector3.ZERO, Vector3.RIGHT, 4)
	puffs_arr = smoke.get("puffs") as Array
	check(puffs_arr.size() > 0, "MuzzleSmoke can burst again after clear()")

	# Hide overlay (simulating elevator entry / cab ride)
	smoke.call("set_overlay_visible", false)
	check(smoke.call("is_overlay_visible") == false, "MuzzleSmoke is_overlay_visible() false")
	var overlay_canvas: CanvasLayer = smoke.get("overlay") as CanvasLayer
	check(overlay_canvas != null and overlay_canvas.visible == false, "CanvasLayer visible is false")
	puffs_arr = smoke.get("puffs") as Array
	check(puffs_arr.is_empty(), "Puffs cleared when overlay hidden")

	# Burst during hidden overlay must be completely suppressed
	smoke.call("burst", Vector3.ZERO, Vector3.RIGHT, 5)
	puffs_arr = smoke.get("puffs") as Array
	check(puffs_arr.is_empty(), "Burst while overlay hidden is completely suppressed (0 puffs)")

	# Restore overlay
	smoke.call("set_overlay_visible", true)
	check(smoke.call("is_overlay_visible") == true, "MuzzleSmoke is_overlay_visible() true after restore")
	check(overlay_canvas.visible == true, "CanvasLayer visible restored to true")

	# Burst works again
	smoke.call("burst", Vector3.ZERO, Vector3.RIGHT, 5)
	puffs_arr = smoke.get("puffs") as Array
	check(puffs_arr.size() > 0, "Burst works again after overlay restored")
	smoke.call("clear")

	# =========================================================================
	# Test 2: BurningEffects lifecycle and ElementalParticles3D clear()
	# =========================================================================
	print("\n[Test 2] BurningEffects & ElementalParticles3D lifecycle")
	var burning_script: Script = preload("res://scripts/dream/burning_effects.gd")
	var burning: Node = (burning_script.new()) as Node
	burning.name = "BurningEffects"
	world.floor_root.add_child(burning)
	burning.call("configure", world)
	check(burning.has_method("clear"), "BurningEffects has clear()")

	# Spawn muzzle flame particles
	burning.call("muzzle", Vector3(1.0, 0.5, 2.0), Vector3.FORWARD)
	var effects_node: Node3D = burning.get("effects") as Node3D
	check(effects_node != null, "ElementalParticles3D child effects present")
	check(effects_node.has_method("clear"), "ElementalParticles3D has clear()")
	var particles_arr: Array = effects_node.get("particles") as Array
	check(particles_arr.size() > 0, "Particles spawned for muzzle flame: " + str(particles_arr.size()))

	# Clear BurningEffects
	burning.call("clear")
	particles_arr = effects_node.get("particles") as Array
	check(particles_arr.is_empty(), "ElementalParticles3D particles cleared")
	var shockwaves_arr: Array = effects_node.get("shockwaves") as Array
	check(shockwaves_arr.is_empty(), "ElementalParticles3D shockwaves cleared")
	var fires_dict: Dictionary = effects_node.get("fires") as Dictionary
	check(fires_dict.is_empty(), "ElementalParticles3D fires cleared")

	# =========================================================================
	# Test 3: firearm_render_preparation cleanup helper
	# =========================================================================
	print("\n[Test 3] firearm_render_preparation cleanup helper")
	# Emit both flame and smoke
	burning.call("muzzle", Vector3.ZERO, Vector3.FORWARD)
	smoke.call("burst", Vector3.ZERO, Vector3.RIGHT, 6)
	check((effects_node.get("particles") as Array).size() > 0, "Particles present before cleanup helper")
	check((smoke.get("puffs") as Array).size() > 0, "Puffs present before cleanup helper")

	var prep_script: Script = preload("res://scripts/dream/firearm_render_preparation.gd")
	check(prep_script.has_method("_clear_firearm_render_vfx"), "firearm_render_preparation has _clear_firearm_render_vfx()")
	prep_script.call("_clear_firearm_render_vfx", world)

	check((effects_node.get("particles") as Array).is_empty(), "Particles cleared by firearm_render_preparation cleanup")
	check((smoke.get("puffs") as Array).is_empty(), "Smoke puffs cleared by firearm_render_preparation cleanup")

	# =========================================================================
	# Test 4: Dream3D world transition helpers
	# =========================================================================
	print("\n[Test 4] Dream3D transition helpers")
	burning.call("muzzle", Vector3.ZERO, Vector3.FORWARD)
	smoke.call("burst", Vector3.ZERO, Vector3.RIGHT, 6)
	check((effects_node.get("particles") as Array).size() > 0, "Particles present before transition")
	check((smoke.get("puffs") as Array).size() > 0, "Puffs present before transition")

	# Entering elevator
	world._clear_muzzle_and_burning_vfx()
	world._set_muzzle_smoke_visible(false)
	check((effects_node.get("particles") as Array).is_empty(), "Particles cleared on elevator entry")
	check((smoke.get("puffs") as Array).is_empty(), "Puffs cleared on elevator entry")
	check(smoke.call("is_overlay_visible") == false, "Smoke overlay hidden on elevator entry")

	# Cab ride: attempts to burst are dropped
	smoke.call("burst", Vector3.ZERO, Vector3.RIGHT, 6)
	check((smoke.get("puffs") as Array).is_empty(), "Cab ride: no puffs spawned")

	# Exiting elevator / Floor idle
	world._clear_muzzle_and_burning_vfx()
	world._set_muzzle_smoke_visible(true)
	check(smoke.call("is_overlay_visible") == true, "Smoke overlay restored on floor exit")
	check((smoke.get("puffs") as Array).is_empty(), "Puffs stay empty on floor exit until fired")

	print("\n==========================================")
	print("MUZZLE_VFX_TRANSITION_LIFECYCLE checks=", checks, " failures=", failures.size())
	print("==========================================")

	world.queue_free()
	quit(0 if failures.is_empty() else 1)
