extends SceneTree
const GENERATOR=preload("res://scripts/dream/office_skeleton_generator.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var builder:=GENERATOR.new()
	var cells: Dictionary={}
	for y in 13:
		for x in 21: cells[Vector2i(x,y)]=true; builder.owners[Vector2i(x,y)]="room"
	var room:={"id":"room","cells":cells}
	builder.doors=[{"a":"room","b":"outside","glass":false,"vertical":true,"line":0,"start":5,"width":1},{"a":"room","b":"outside","glass":false,"vertical":true,"line":21,"start":5,"width":1}]
	var rng:=RandomNumberGenerator.new(); rng.seed=21984
	var failures:=0
	for case_index in 300:
		builder.occupied.clear()
		for item in 10: builder.occupied[Vector2i(rng.randi_range(0,20),rng.randi_range(0,12))]=true
		var extra: Dictionary={}
		for item in 5: extra[Vector2i(rng.randi_range(-1,21),rng.randi_range(-1,13))]=true
		var base: Dictionary=builder._clear(room,{})
		var legacy: bool=builder._room_clear(room,extra)
		var cached: bool=builder._room_clear(room,extra,base)
		if legacy!=cached: failures+=1; push_error("Candidate clearance parity %d" % case_index)
		if base!=builder._clear(room,{}): failures+=1; push_error("Local base mutated")
	print("SKELETON_CLEARANCE_RESULT checks=600 failures=",failures)
	quit(1 if failures else 0)
