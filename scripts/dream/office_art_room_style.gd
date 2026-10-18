extends RefCounted
## Rendering classification only: never changes authored_sample or room identity.
static func key(room: Dictionary) -> String:
	if bool(room.get("authored_sample",false)): return String(room.get("sample_key","corridor"))
	if String(room.get("room_type",""))=="corridor": return "corridor"
	if bool(room.get("elevator_reception",false)): return "reception"
	var archetype := String(room.get("archetype",""))
	if archetype in ["open_office","small_office","office"]: return "office"
	if archetype.begins_with("conference"): return "conference"
	if archetype in ["manager","executive"]: return "manager"
	if archetype in ["archive","storage","printing"]: return "archive"
	if archetype in ["server","server_room"]: return "server"
	if archetype in ["pantry","restroom","lounge","reception","corridor"]: return archetype
	return "office"
