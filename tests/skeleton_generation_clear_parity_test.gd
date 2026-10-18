extends SceneTree
const GENERATOR=preload("res://scripts/dream/office_skeleton_generator.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var baseline: bool="--save-baseline" in OS.get_cmdline_user_args()
	var filename:="res://.runtime/skeleton_clear_baseline.json"
	var expected: Dictionary={} if baseline else JSON.parse_string(FileAccess.get_file_as_string(filename))
	var output: Dictionary={}
	var times: Array=[]
	for kind in GENERATOR.TYPES:
		for seed_value in [120,41001,73021]:
			var key:="%s:%d" % [kind,seed_value]
			var rng:=RandomNumberGenerator.new(); rng.seed=seed_value
			var started:=Time.get_ticks_usec()
			var data: Dictionary=GENERATOR.generate(rng,{"seed":seed_value,"type":kind,"compact":true,"enhanced_dressing":true})
			var elapsed:=(Time.get_ticks_usec()-started)/1000.0
			times.append(elapsed)
			var signature:=(var_to_bytes(data)).hex_encode().sha256_text()
			output[key]={"signature":signature,"rng":str(rng.state)}
			if data.is_empty() or (not baseline and output[key]!=expected.get(key,{})): failures+=1; push_error("Layout/RNG parity: "+key)
			print("SKELETON_CLEAR_CASE ",key," cpu_ms=",elapsed)
			await process_frame
	if baseline:
		var file:=FileAccess.open(filename,FileAccess.WRITE); file.store_string(JSON.stringify(output)); file.close()
	times.sort()
	print("SKELETON_CLEAR_RESULT cases=",times.size()," failures=",failures," median_ms=",times[times.size()/2]," max_ms=",times.back())
	quit(1 if failures else 0)
