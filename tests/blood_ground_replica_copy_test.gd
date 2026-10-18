extends SceneTree

const BLOOD = preload("res://scripts/entities/black_blood_effect.gd")

func _initialize() -> void:
	var source = BLOOD.new()
	var ground = BLOOD.new()
	var full = BLOOD.new()
	source.ground_pixels.assign([Vector2(2, 3)])
	source.ground_pixel_types.assign([BLOOD.StampType.PIXEL_CELL])
	source.airborne_pixels.assign([{"position": Vector2(8, 9), "payload": [1, 2]}])
	source.ground_visual_scale = 1.37
	ground.set_meta(&"blood_ground_only_capture", true)
	ground.airborne_pixels.assign([{"stale": true}])
	source.copy_depth_visual_state_to(ground)
	source.copy_depth_visual_state_to(full)
	var checks: Array[bool] = [ground.airborne_pixels.is_empty(), ground.ground_pixels == source.ground_pixels, ground.ground_pixel_types == source.ground_pixel_types, ground.ground_visual_scale == source.ground_visual_scale, full.airborne_pixels == source.airborne_pixels]
	full.airborne_pixels[0].payload.append(3)
	checks.append(source.airborne_pixels[0].payload == [1, 2])
	var failures := checks.count(false)
	print("BLOOD GROUND COPY checks=%d failures=%d" % [checks.size(), failures])
	source.free(); ground.free(); full.free()
	quit(0 if failures == 0 else 1)
