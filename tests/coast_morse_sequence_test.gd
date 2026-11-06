extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sequence:=preload("res://scripts/preview/coast_morse_sequence.gd").new()
	sequence.configure("S")
	var runs: Array[float]=[]; var count:=0
	for i in 2000:
		var on: bool=sequence.power_at(float(i)*.001)>.5
		if on: count+=1
		elif count>0: runs.append(float(count)*.001); count=0
	check(runs.size()==3,"S produces three separate flashes")
	for duration in runs: check(absf(duration-.215)<.012,"dot duration retains short pulse including eased edges")
	check(sequence.power_at(.36)==0. and sequence.power_at(.84)==0.,"gaps remain visibly dark")
	check(sequence.power_at(-.1)==0.,"negative/unstarted time has no phantom flash")
	check(sequence.power_at(1.7)==0.,"word pause follows S")
	sequence.configure("O")
	check(sequence.pulses.size()==3 and is_equal_approx(sequence.pulses[0].y-sequence.pulses[0].x,.72),"O uses three long flashes")
	sequence.configure("SOS")
	check(sequence.pulses.size()==9,"preview SOS retains all nine symbols")
	check(is_equal_approx(sequence.power_at(.12),sequence.power_at(sequence.cycle_duration+.12)),"replay preserves timing")
	print("COAST_MORSE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
