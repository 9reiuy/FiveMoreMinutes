extends RefCounted
## One run owns the choice, independently of streamed rooms and presentation nodes.
var scientist_killed := false
var introduction_seen := false
var monitoring_shutter_open := false
var crew_escaped := false

func restore(data:Dictionary)->void:
	scientist_killed=bool(data.get("scientist_killed",false))
	introduction_seen=bool(data.get("introduction_seen",false))
	monitoring_shutter_open=bool(data.get("monitoring_shutter_open",introduction_seen))
	crew_escaped=bool(data.get("crew_escaped",false)) and not scientist_killed

func snapshot()->Dictionary:
	return {"scientist_killed":scientist_killed,"introduction_seen":introduction_seen,
		"monitoring_shutter_open":monitoring_shutter_open,"crew_escaped":crew_escaped}
