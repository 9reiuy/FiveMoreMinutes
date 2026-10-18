shader_type canvas_item;
render_mode unshaded;

uniform bool shine_enabled = false;
uniform float shine_strength = 0.55;
uniform float shine_width = 0.10;
uniform float shine_period = 3.2;
uniform float shine_phase_offset = 0.0;
uniform float shine_diagonal = 0.35;
uniform vec4 shine_color : source_color = vec4(1.0);
const vec3 SHINE_DIRECT_OUTPUT = vec3(1.0);
const float SHINE_CORE_THRESHOLD = 0.72;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (shine_enabled && base.a > 0.001) {
		// The travel span is deliberately wider than the sprite.  The portions
		// outside [0, 1] create a short quiet pause between sweeps.
		float period = max(shine_period, 0.1);
		float phase = fract((TIME + shine_phase_offset) / period);
		float sweep_position = phase * 1.9 - 0.45;
		float projection = UV.x + UV.y * shine_diagonal;
		float width = max(shine_width, 0.005);
		float distance_to_band = abs(projection - sweep_position);
		float band = 1.0 - smoothstep(0.0, width, distance_to_band);
		float highlight = band * clamp(shine_strength, 0.0, 1.0);
		vec3 result_rgb = clamp(base.rgb + shine_color.rgb * highlight, 0.0, 1.0);
		// Keep the feathered band edges ordinary highlights so the whole weapon
		// does not become white while the sweep passes over it.
		if (band >= SHINE_CORE_THRESHOLD) {
			// The sweep is a normal white presentation highlight.  It must never
			// emit the internal magenta palette marker, which can leak in direct
			// 3D launches or when the final overlay is not yet attached.
			result_rgb = SHINE_DIRECT_OUTPUT;
		}
		base = vec4(result_rgb, base.a);
	}
	COLOR = base;
}
