extends "res://tests/h06_hangar_crew_test.gd"

func camera_image() -> Image:
	await frames(4)
	await RenderingServer.frame_post_draw
	return display.world_viewport.get_texture().get_image()

func run() -> void:
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	await enter(CHAPTER.Save.RETURN_BAY)
	world._place_feet(Vector2(3.4,1.5))
	await frames(30)
	world.set_process(false)
	world.player.process_mode=Node.PROCESS_MODE_DISABLED
	var crew: Node3D=world.blockout.hangar_crew
	var baked: Image=await camera_image()
	baked.save_png(evidence.path_join("01-baked.png"))
	crew.blood_scenery.hide()
	world.set_meta(&"test_dynamic_hangar_crew_blood",true)
	crew.blood_created=false
	crew.activate()
	await frames(12)
	var original: Image=await camera_image()
	original.save_png(evidence.path_join("02-original-painter.png"))
	var relevant:=0
	var different:=0
	var maximum:=0.0
	for y in original.get_height():
		for x in original.get_width():
			var a:=original.get_pixel(x,y)
			var b:=baked.get_pixel(x,y)
			if maxf(a.r,b.r)<0.12 or maxf(a.g,b.g)<0.04 or not (a.r>a.g*1.4 and a.r>a.b*2 or b.r>b.g*1.4 and b.r>b.b*2):continue
			relevant+=1
			var error:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			maximum=maxf(maximum,error)
			if error>2.0/255.0:different+=1
	check(relevant>500,"actual camera contains the long blood trails")
	check(different==0,"static scenery matches the original blood painter at all blood-coloured camera pixels")
	FileAccess.open(evidence.path_join("parity.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"pixels":relevant,"different":different,"maximum_error":maximum},"\t"))
	await unload()
	quit(0 if different==0 and relevant>500 else 1)
