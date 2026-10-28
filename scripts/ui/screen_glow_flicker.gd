extends RefCounted
## Shared bedroom/held-phone video brightness: discrete changes, no random fade.
static func pick(low: float, high: float, rng: RandomNumberGenerator = null) -> float:
	return lerpf(minf(low,high), maxf(low,high), rng.randf() if rng != null else randf())

static func next_alpha(config: Resource, current: float, rng: RandomNumberGenerator = null) -> float:
	var low: float = minf(config.bedroom_chr_glow_alpha_normal_min,config.bedroom_chr_glow_alpha_normal_max)
	var high: float = maxf(config.bedroom_chr_glow_alpha_normal_min,config.bedroom_chr_glow_alpha_normal_max)
	var chance: float = clampf(config.bedroom_chr_glow_big_change_chance,0,1)
	if (rng.randf() if rng != null else randf()) < chance:
		if current >= (low+high)*.5:
			return pick(config.bedroom_chr_glow_alpha_dark_min,config.bedroom_chr_glow_alpha_dark_max,rng)
		return pick(config.bedroom_chr_glow_alpha_bright_min,config.bedroom_chr_glow_alpha_bright_max,rng)
	if current < low or current > high: return pick(low,high,rng)
	var change := pick(.03,.10,rng)
	if current <= low+.03: return minf(current+change,high)
	if current >= high-.03: return maxf(current-change,low)
	return clampf(current+change*(-1.0 if (rng.randf() if rng != null else randf())<.5 else 1.0),low,high)
