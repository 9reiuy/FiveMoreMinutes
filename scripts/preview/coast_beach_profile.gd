extends RefCounted
## Shared profile for the authored low beach and its sampled swash boundary.

static func distance(x: float, z: float, headland_distance: float) -> float:
	var waterline := 2.9 + sin(x * .27) * .38 + sin(x * .54 + .9) * .18
	var side := absf(x + 3.0) - (18.4 + sin(z * .23) * .55)
	var beach_distance := maxf(waterline - z, side)
	return lerpf(beach_distance, headland_distance, smoothstep(13.0, 22.0, z))

static func height(x: float, z: float, headland_height: float, headland_distance: float) -> float:
	var shore := distance(x, z, headland_distance)
	var sand := clampf(-shore * .063, -1.3, .56)
	sand += sin(x * .31 + z * .22) * sin(z * .49) * .042 * smoothstep(.8, 3.1, -shore)
	return lerpf(sand, headland_height, smoothstep(14.0, 22.0, z))
