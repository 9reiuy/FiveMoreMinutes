extends RefCounted
## Offline height profile for the editable city/cliff sample. No central dome.
const LEFT: Array[Vector2]=[Vector2(-6.6,4.9),Vector2(-7.4,8.8),Vector2(-7.0,11.7),Vector2(-8.15,14.0),Vector2(-7.7,17.5),Vector2(-8.4,20.2),Vector2(-8.0,24),Vector2(-8.9,28.2),Vector2(-8.1,32)]
const RIGHT: Array[Vector2]=[Vector2(-.6,5.7),Vector2(1.05,8.0),Vector2(.7,10.7),Vector2(1.8,13.1),Vector2(2.15,16.1),Vector2(.85,20.0),Vector2(2.0,23.3),Vector2(1.25,27.1),Vector2(2.4,32)]
static func edge_x(chain: Array[Vector2],z: float) -> float:
	for i in range(1,chain.size()):
		if z<=chain[i].y:
			return lerpf(chain[i-1].x,chain[i].x,clampf((z-chain[i-1].y)/(chain[i].y-chain[i-1].y),0.,1.))
	return chain[-1].x
static func platform_width(z: float) -> float:
	return minf(-3.-edge_x(LEFT,z),edge_x(RIGHT,z)+3.)
static func height(x: float, z: float, coast: float) -> float:
	var beach := minf(.44, -coast * .065) if coast < 0. else maxf(-2.8, -coast * .14)
	beach += .035 * sin(x*.81+z*.22) * sin(z*.63) * smoothstep(.4,2.,absf(coast))
	var side := maxf(edge_x(LEFT,z)-x,x-edge_x(RIGHT,z))
	# An irregular but mostly straight bluff, rather than a narrowing nose.
	var front := 4.9 + .65*smoothstep(-4.3,.2,x) + .20*sin(x*.72)
	var edge := maxf(side, maxf(front-z,z-32.))
	var platform := 1.-smoothstep(-.20,.45,edge)
	var elevation := 2.55 + .025*clampf(25.-z,0.,22.)
	var weathering := .025*sin(x*.72)*sin(z*.36)
	# Keep a steep upper rock face, then let an actual sloped foot run out
	# onto the lower beach. The shoreline mask prevents a raised underwater rim.
	var land := smoothstep(.05,.85,-coast)
	var talus := (1.-smoothstep(.25,2.15,edge))*1.05*land
	return beach+talus+maxf(elevation+weathering-beach-talus,0.)*platform
