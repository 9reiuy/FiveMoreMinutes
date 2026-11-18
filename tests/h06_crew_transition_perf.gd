extends "res://tests/h06_hangar_crew_test.gd"

func run() -> void:
	evidence=OS.get_environment("FORKLIFT_EVIDENCE")
	preload("res://tests/support/background_gpu.gd").start(self)
	var results: Array=[]
	for enhanced: bool in [false,true,false]:
		test_activities=enhanced
		await enter(CHAPTER.Save.PUMP)
		world.prepared=world._plan_region(PLAN.Visit.EMPTY_HANGAR)
		while not world.prepared.build_steps.is_empty():world.prepared.prepare_step()
		await frames(20)
		world._set_lower(true)
		world._place_feet(Vector2(-8.8,7.5))
		var started:=Time.get_ticks_usec()
		world._enter_prepared()
		var total: float=(Time.get_ticks_usec()-started)*0.001
		results.append({"enhanced":enhanced,"enter_ms":total,"blood_ms":world.blockout.hangar_crew.blood_preparation_ms,"segments":world.blockout.hangar_crew.blood_segments})
		await frames(45)
		await unload()
	print("CREW_TRANSITIONS ",JSON.stringify(results))
	FileAccess.open(evidence.path_join("transitions.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	quit()
