extends RefCounted
## The near walking shore and the long visual coast use the same water edge.

static func edge(z: float) -> float:
	return 6.0 + maxf(-z,0.0)*.28 - 14.0*smoothstep(-2.0,8.0,z)

static func distance(x: float, z: float) -> float:
	return edge(z)-x

static func height(x: float, z: float, approach_height: float) -> float:
	var inland := x-edge(z)
	var shelf := clampf(inland*.055,-1.3,.62)
	shelf += smoothstep(5.0,6.5,inland)*1.4
	shelf += smoothstep(10.0,12.0,inland)*2.0
	shelf += smoothstep(16.0,18.0,inland)*1.8
	shelf += sin(x*.23+z*.17)*sin(z*.13)*.055*smoothstep(2.0,12.0,inland)
	return lerpf(shelf,approach_height,smoothstep(16.0,24.0,z))
