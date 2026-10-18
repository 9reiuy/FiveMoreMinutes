extends SceneTree

const BRIDGE := preload("res://scripts/dream/dream_3d_actor_depth_bridge.gd")
class Actor extends Node2D:
	var knockback_height := 0.0
	var dead := false
	var last_aim_direction := Vector2.RIGHT
	var selected_weapon_id := "pistol"

class EnemyActor extends Node2D:
	var knockdown_height := 12.0
	var dead := false
	var last_facing_direction := Vector2.UP
	var held_weapon_id := ""

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func make_bridge(stage: Node3D, camera: Camera3D, actor: Node2D, enabled: bool, paths: Array) -> Node3D:
	var bridge := BRIDGE.new()
	stage.add_child(bridge)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	bridge.add_child(viewport)
	var capture := Node2D.new()
	viewport.add_child(capture)
	bridge.volume_shadow_enabled = enabled
	bridge.set_world_camera(camera)
	bridge.configure(actor, viewport, capture, null, paths)
	return bridge

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	stage.rotation.y = -PI / 4
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 8, 8)
	camera.look_at(Vector3.ZERO)
	var actor := Actor.new()
	actor.add_to_group(&"dream_player")
	root.add_child(actor)
	var body := Node2D.new()
	body.name = "CharacterVisual"
	actor.add_child(body)
	for label in ["LeftFoot", "RightFoot"]:
		var foot := Node2D.new()
		foot.name = label
		body.add_child(foot)
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	actor.add_child(shadow)
	var grip := Node2D.new()
	grip.name = "WeaponRoot"
	grip.position = Vector2(0, -18)
	actor.add_child(grip)
	var muzzle := Marker2D.new()
	muzzle.name = "ProjectileOrigin"
	muzzle.position = Vector2(20, 0)
	grip.add_child(muzzle)
	var bridge := make_bridge(stage, camera, actor, true, [^"CharacterVisual", ^"WeaponRoot"])
	var caster: Node3D = bridge.volume_shadow
	check(caster != null, "Office character gets a volume caster")
	check(not bridge.shadow_proxy.visible, "No simultaneous upright sprite caster")
	check(caster.weapon == null and caster.get_node_or_null("WeaponVolume") == null, "Player has no coarse held-gun caster; visible weapon stays independent")
	for part: MeshInstance3D in caster.parts.values():
		check(part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "Body part only renders into shadow maps")
		check(part.layers == 4, "Player caster remains excluded by flashlight mask")
	var original_position := actor.position
	var original_shadow_alpha := shadow.modulate.a
	var ground_bridge := make_bridge(stage, camera, actor, true, [^"Shadow"])
	check(is_equal_approx(ground_bridge.actor_sprite.modulate.a, 0.28), "Office contact capture has reduced opacity")
	check(shadow.modulate.a == original_shadow_alpha, "Shared 2D shadow unchanged")
	for height in [0.0, 16.0, 32.0]:
		actor.knockback_height = height
		for roll in [0.0, PI / 4, PI / 2, PI, 1.5 * PI]:
			body.rotation = roll
			bridge._process(0.0)
			check(is_equal_approx(caster.global_position.y, height / 32), "Caster follows formal Fake Height")
			var lowest := INF
			for part: MeshInstance3D in caster.parts.values():
				for corner in 8:
					lowest = minf(lowest, (part.global_transform * part.mesh.get_aabb().get_endpoint(corner)).y)
			check(absf(lowest - height / 32) < 0.001, "Roll and prone volume stays grounded without owner displacement")
			check(actor.position == original_position, "Shadow pose never changes gameplay owner")
	body.rotation = 0
	for index in 8:
		actor.last_aim_direction = Vector2.RIGHT.rotated(index * PI / 4)
		grip.rotation = index * PI / 4
		bridge._process(0)
		var mapped_muzzle: Dictionary = bridge.get_weapon_visual_snapshot(muzzle.global_position)
		check(mapped_muzzle.world_origin is Vector3 and caster.weapon == null, "Visible weapon mapping survives without rebuilding a coarse caster")
	# A mirrored or scaled sprite must not repeatedly multiply the volume scale.
	body.scale = Vector2(-0.7, 0.7)
	for _frame in 120:
		bridge._process(0)
	check(caster.body.basis.get_scale().is_equal_approx(Vector3.ONE * 0.7), "Repeated synchronization does not accumulate scale")
	var old_leg: Transform3D = caster.parts.LeftLeg.transform
	body.get_node("LeftFoot").position += Vector2(4, -2)
	bridge._process(0)
	check(not caster.parts.LeftLeg.transform.is_equal_approx(old_leg), "Foot animation changes the limb volume")
	actor.position = Vector2(400, -300)
	bridge._process(0)
	var expected_ground := stage.to_global(Vector3(400.0 / 32, 0, -300.0 / 32))
	check(Vector2(caster.global_position.x, caster.global_position.z).distance_to(Vector2(expected_ground.x, expected_ground.z)) < 0.001, "Moving volume respects rotated map position")
	check(caster.visible, "Offscreen owner still has a caster for shadows entering the view")
	var enemy := EnemyActor.new()
	enemy.add_to_group(&"dream_enemies")
	root.add_child(enemy)
	var enemy_body := Node2D.new()
	enemy_body.name = "CharacterVisual"
	enemy.add_child(enemy_body)
	var enemy_bridge := make_bridge(stage, camera, enemy, true, [^"CharacterVisual"])
	enemy_bridge._process(0)
	var enemy_caster: Node3D = enemy_bridge.volume_shadow
	check(is_equal_approx(enemy_caster.global_position.y, 12.0 / 32), "Enemy uses its own knockdown height authority")
	check(enemy_caster.parts.Head.layers == 2, "Enemy remains visible to the player flashlight shadow pass")
	check(enemy_caster.parts.Head.mesh == caster.parts.Head.mesh, "Characters share head mesh resources")
	check(enemy_caster.parts.Torso.mesh == caster.parts.Torso.mesh, "Characters share body mesh resources")
	check(not enemy_caster.weapon.visible, "Unarmed enemy has no phantom weapon shadow")
	var enemy_forward: Vector3 = -enemy_caster.body.global_basis.z.normalized()
	check(enemy_forward.is_equal_approx((stage.global_basis * Vector3(0, 0, -1)).normalized()), "Enemy orientation follows official last facing direction")
	enemy.free()
	check(not enemy_caster.visible, "Enemy disposal immediately hides all caster parts")
	actor.dead = true
	body.rotation = PI / 2
	bridge._process(0)
	check(caster.visible and caster.weapon == null, "Dead body retains shadow without a coarse held-gun caster")
	actor.visible = false
	bridge._process(0)
	check(not caster.visible, "Hidden owner cannot leave ghost caster")
	actor.visible = true
	var legacy := make_bridge(stage, camera, actor, false, [^"CharacterVisual", ^"WeaponRoot"])
	check(legacy.volume_shadow == null, "Other worlds do not opt in implicitly")
	actor.free()
	check(not caster.visible, "Source disposal immediately hides volume before deferred cleanup")
	stage.queue_free()
	await process_frame
	check(not is_instance_valid(caster) and not is_instance_valid(enemy_caster), "Volume components are freed with their bridges")
	print("Actor volume shadow: ", checks, " checks, ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)
