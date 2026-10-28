extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,360)
	var camera:=Camera3D.new(); root.add_child(camera)
	camera.position=Vector3(0,8,12); camera.look_at(Vector3.ZERO)
	var worst:=0.
	for i in 80:
		camera.position.x=float(i)*.0017
		worst=maxf(worst,preload("res://scripts/dream/preview/pixel_camera_stability.gd").apply(camera,Vector3.ZERO))
	print("CAMERA_STABILITY max_pixel_error=",worst)
	camera.free(); quit(0 if worst<.01 else 1)
