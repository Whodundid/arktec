shader_type canvas_item;

uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_strength = 8.0;
uniform float wind_factor = 1.0;
uniform float wind_time = 0.0;
uniform float wind_phase = 0.0;
uniform float shadow_alpha = 0.30;
uniform float top_blur_radius_pixels : hint_range(0.0, 6.0) = 4.0;

void vertex() {
	float canopy_weight = pow(1.0 - UV.y, 2.0);
	float sway = sin(wind_time * 1.7 + wind_phase + UV.y * 2.2) * 0.65;
	sway += sin(wind_time * 0.83 + wind_phase * 1.7) * 0.35;
	VERTEX += wind_direction * sway * wind_strength * wind_factor * canopy_weight * 0.75;
}

void fragment() {
	// UV.y is 1.0 at the trunk base and 0.0 at the canopy tip. Keep the base
	// crisp, then increase a nine-tap texture-space blur toward the far end.
	float height_from_base = smoothstep(0.04, 0.90, pow(1.0 - UV.y, 0.85));
	vec2 texel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec2 blur_step = texel_size * top_blur_radius_pixels * height_from_base;
	float blurred_alpha = texture(TEXTURE, UV).a * 0.25;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2( blur_step.x, 0.0), vec2(0.0), vec2(1.0))).a * 0.125;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2(-blur_step.x, 0.0), vec2(0.0), vec2(1.0))).a * 0.125;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2(0.0,  blur_step.y), vec2(0.0), vec2(1.0))).a * 0.125;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2(0.0, -blur_step.y), vec2(0.0), vec2(1.0))).a * 0.125;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2( blur_step.x,  blur_step.y), vec2(0.0), vec2(1.0))).a * 0.0625;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2(-blur_step.x,  blur_step.y), vec2(0.0), vec2(1.0))).a * 0.0625;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2( blur_step.x, -blur_step.y), vec2(0.0), vec2(1.0))).a * 0.0625;
	blurred_alpha += texture(TEXTURE, clamp(UV + vec2(-blur_step.x, -blur_step.y), vec2(0.0), vec2(1.0))).a * 0.0625;
	float alpha = blurred_alpha * shadow_alpha;
	COLOR = vec4(0.03, 0.045, 0.035, alpha);
}
