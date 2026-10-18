extends SceneTree
## Frozen outputs include the approved 2026-10-14 V3 corridor opening policy.
## Future generation optimization must preserve these maps and caller RNG.
const GENERATOR = preload("res://scripts/dream/office_skeleton_generator.gd")
const FIXTURE = "res://tests/fixtures/native_generator_parity_20261013.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)

func check_rectangle_queries() -> void:
	var random := RandomNumberGenerator.new(); random.seed=63191
	for repetition in 12:
		var bounds:=Rect2i(-5,-7,20,22)
		var available: Dictionary={}
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				if random.randf()>.12: available[Vector2i(x,y)]=true
		var index: Dictionary=GENERATOR._rectangle_floor_index(available,bounds)
		for trial in 64:
			var a:=Rect2i(random.randi_range(-8,20),random.randi_range(-10,22),random.randi_range(1,8),random.randi_range(1,8))
			var original:=true
			for point in GENERATOR._cells(a):
				if not available.has(point): original=false
			check(GENERATOR._indexed_rectangle_available(a,index)==original,"Summed-area membership including holes/negative/outside cells")
			var b:=Rect2i(random.randi_range(-8,20),random.randi_range(-10,22),random.randi_range(1,8),random.randi_range(1,8))
			if a.intersects(b): continue
			var shared:=0
			for point in GENERATOR._cells(a):
				for direction in GENERATOR.DIRS:
					if b.has_point(point+direction): shared+=1
			check(GENERATOR._rectangle_contact_count(a,b)==shared,"Rectangle contact matches original four-neighbor scan")

func run() -> void:
	check_rectangle_queries()
	var recording: bool = "--record-baseline" in OS.get_cmdline_user_args()
	var reference: GDScript
	if recording:
		reference = GDScript.new()
		reference.source_code = FileAccess.get_file_as_string("res://.runtime/perf_delivery_20261013/baseline_sources/scripts/dream/office_skeleton_generator.gd")
		if reference.reload() != OK:
			push_error("Frozen native generator failed to compile")
			quit(1); return
	var expected: Dictionary = {}
	if not recording:
		expected = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var records: Dictionary = {}
	var old_usec := 0
	var new_usec := 0
	for skeleton in ["A1", "B2", "C3", "V3"]:
		for map_seed in [1001, 41001, 73013, 98271]:
			var key: String = "%s/%d" % [skeleton, map_seed]
			var options: Dictionary = {"seed":map_seed, "type":skeleton, "compact":true, "enhanced_dressing":true}
			var random := RandomNumberGenerator.new(); random.seed=map_seed
			if recording:
				var started := Time.get_ticks_usec()
				var original: Dictionary = reference.generate(random,options)
				old_usec += Time.get_ticks_usec()-started
				expected[key] = {"sha256":JSON.stringify(original).sha256_text(), "rng_state":str(random.state)}
				random.seed=map_seed
			var started := Time.get_ticks_usec()
			var current: Dictionary = GENERATOR.generate(random,options)
			new_usec += Time.get_ticks_usec()-started
			var actual: Dictionary = {"sha256":JSON.stringify(current).sha256_text(), "rng_state":str(random.state)}
			records[key]=actual
			checks+=1
			if current.is_empty() or actual!=expected.get(key,{}):
				failures+=1; push_error("Native map/RNG parity failed: "+key)
			random.seed=map_seed
			var compiled: Dictionary=GENERATOR.generate_compiled(random,options)
			check(not compiled.is_empty() and JSON.stringify(compiled.source)==JSON.stringify(current) and str(random.state)==actual.rng_state,"Compiled generation preserves source and RNG: "+key)
			check(JSON.stringify(compiled.layout)==JSON.stringify(GENERATOR.ADAPTER.compile(compiled.source)),"Validated layout equals a fresh adapter compilation: "+key)
	if recording and failures==0:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/fixtures"))
		var file:=FileAccess.open(FIXTURE,FileAccess.WRITE)
		file.store_string(JSON.stringify(expected,"\t"))
	print("NATIVE_GENERATOR_PARITY ",JSON.stringify({"checks":checks,"failures":failures,"original_ms":old_usec/1000.0,"candidate_ms":new_usec/1000.0,"scope":"16 deterministic generation calls; not live FPS"}))
	quit(1 if failures else 0)
