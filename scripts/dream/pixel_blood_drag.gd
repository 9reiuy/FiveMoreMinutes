extends RefCounted
## Independent art pass over the original smear. Carves tapered fragments;
## never expands its bounds, fills its grooves or changes the drag trajectory.

static func apply(effect: BlackBloodEffect, start: Vector2, finish: Vector2, width: float, intensity: float) -> Dictionary:
	var original: Array[Vector2] = effect.ground_pixels.duplicate()
	var direction := (finish-start).normalized()
	var side := direction.orthogonal()
	var half_width := clampf(width*.5,.5,12.0)*clampf(sqrt(maxf(intensity,0.0)),.72,1.0)
	var rows: Dictionary = {}; var protected: Dictionary = {}
	var extremes: Array[Vector2] = []; var minima := [INF,INF,INF,INF]; var maxima := [-INF,-INF,-INF,-INF]
	for i in 8: extremes.append(Vector2.ZERO)
	for p in original:
		var world := effect.to_global(p)
		var delta := world-start
		var along := delta.dot(direction); var across := delta.dot(side)
		var row := roundi(along)
		var envelope: Vector2 = rows.get(row,Vector2(INF,-INF))
		rows[row] = Vector2(minf(envelope.x,across),maxf(envelope.y,across))
		# Keep both existing longitudinal groove bands, including their closures.
		if half_width>=3.5 and (absf(across-half_width*.28)<2.25 or absf(across+half_width*.58)<2.25): protected[p] = true
		var values := [world.x,world.y,along,across]
		for axis in 4:
			if values[axis]<minima[axis]: minima[axis]=values[axis]; extremes[axis*2]=p
			if values[axis]>maxima[axis]: maxima[axis]=values[axis]; extremes[axis*2+1]=p
	for p in extremes: protected[p] = true
	var kept: Array[Vector2] = []
	var open_gap_cells := 0
	for p in original:
		if protected.has(p): kept.append(p); continue
		var world := effect.to_global(p); var delta := world-start
		var across := delta.dot(side)
		var envelope: Vector2 = rows[roundi(delta.dot(direction))]
		var lower := envelope.x; var upper := envelope.y
		var band := 0
		if across < -half_width*.58:
			upper = minf(upper,-half_width*.58-1.1)
		elif across > half_width*.28:
			lower = maxf(lower,half_width*.28+1.1); band = 2
		else:
			lower = maxf(lower,-half_width*.58+1.1)
			upper = minf(upper,half_width*.28-1.1); band = 1
		# A world-path phase survives short independently emitted segments.
		# Unequal lengths/offsets break up the old filled band without noise.
		var period: float = [23.0,31.0,19.0][band]
		var phase: float = [3.0,14.0,8.0][band]
		var t := fposmod(world.dot(direction)+phase,period)/period
		if t>.80:
			open_gap_cells += 1
			continue
		var progress := t/.80
		var centre := lerpf(lower,upper,[.55,.45,.48][band])
		var half_span := maxf((upper-lower)*.5,.5)
		var tapered_width := maxf(.30,half_span*(1.0-pow(progress,.85)))
		if absf(across-centre)<=tapered_width: kept.append(p)
	effect.ground_pixels = kept
	effect.ground_pixel_types.resize(kept.size()); effect.ground_pixel_types.fill(BlackBloodEffect.StampType.PIXEL_CELL)
	effect.queue_redraw()
	var stats := {"before":original.size(),"after":kept.size(),"removed":original.size()-kept.size(),"added":0,"open_gap_cells":open_gap_cells,"width_argument":width,"groove_band_cells":protected.size(),"before_bounds":_bounds(effect,original,direction,side),"after_bounds":_bounds(effect,kept,direction,side)}
	effect.set_meta(&"pixel_drag_art",stats)
	return stats

static func _bounds(effect: Node2D, pixels: Array[Vector2], direction: Vector2, side: Vector2) -> Array:
	var values := [INF,-INF,INF,-INF,INF,-INF,INF,-INF]
	for p in pixels:
		var world := effect.to_global(p)
		var axes := [world.x,world.y,world.dot(direction),world.dot(side)]
		for axis in 4:
			values[axis*2] = minf(values[axis*2],axes[axis]); values[axis*2+1] = maxf(values[axis*2+1],axes[axis])
	return values
