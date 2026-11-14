uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;

float tutorial_hint_reveal(float panel_x) {
	float edge = mix(-24.0, 252.0, reveal_progress);
	return 1.0 - smoothstep(edge - 24.0, edge + 24.0, panel_x);
}
