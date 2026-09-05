shader_type canvas_item;

uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_strength = 8.0;
uniform float wind_factor = 1.0;
uniform float wind_time = 0.0;
uniform float wind_phase = 0.0;

void vertex() {
	float canopy_weight = pow(1.0 - UV.y, 2.0);
	float sway = sin(wind_time * 1.7 + wind_phase + UV.y * 2.2) * 0.65;
	sway += sin(wind_time * 0.83 + wind_phase * 1.7) * 0.35;
	VERTEX += wind_direction * sway * wind_strength * wind_factor * canopy_weight;
}
