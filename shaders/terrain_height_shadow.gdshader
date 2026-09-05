shader_type canvas_item;

uniform vec2 shadow_direction = vec2(0.0, -1.0);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float tile_size = 64.0;
uniform float shadow_alpha : hint_range(0.0, 0.5) = 0.22;
uniform float midday_length_blocks : hint_range(0.0, 2.0) = 0.40;
uniform float low_sun_length_blocks : hint_range(0.0, 3.0) = 0.75;
uniform float max_shadow_length = 70.4;

varying float caster_strength;
varying float edge_contribution;

void vertex() {
	vec2 direction = normalize(shadow_direction);
	float exposed_height = INSTANCE_CUSTOM.r;
	vec2 edge_normal = normalize(INSTANCE_CUSTOM.gb);
	float facing = max(dot(edge_normal, direction), 0.0);
	caster_strength = smoothstep(0.02, 0.18, facing);
	// North- and side-facing strips meet at outcrop corners. Split their opacity
	// between the two orientations so the overlap approximates one shadow. Keep
	// at least forty percent on the side edge while the sun is diagonal; without
	// it, stepped ledges lose the connector that closes their triangular gap.
	float direction_sum = max(abs(direction.x) + abs(direction.y), 0.001);
	float side_share = abs(direction.x) / direction_sum;
	if (abs(direction.x) > 0.02 && abs(direction.y) > 0.02) {
		side_share = clamp(side_share, 0.40, 0.60);
	}
	edge_contribution = abs(edge_normal.x) > 0.5 ? side_share : 1.0 - side_share;
	float elevation = 0.22 + daylight * 0.78;
	float length_blocks = mix(low_sun_length_blocks, midday_length_blocks, elevation);
	float projection_length = min(exposed_height * tile_size * length_blocks, max_shadow_length);
	projection_length *= mix(0.65, 1.0, caster_strength);
	vec2 edge_tangent = vec2(-edge_normal.y, edge_normal.x);

	// Each instance is one exposed tile edge. A half-pixel overlap avoids sampling
	// cracks, while beginning two pixels under the ledge survives fractional zoom
	// and guarantees firm contact without lengthening the visible cast.
	float across = (UV.x - 0.5) * (tile_size + 0.50) * caster_strength;
	float contact_tuck = 2.0 * caster_strength;
	float along = -contact_tuck + UV.y * (projection_length + contact_tuck);
	VERTEX = edge_tangent * across + direction * along;
}

void fragment() {
	// Do not fade segment sides or the wall contact: neighboring strips must meet
	// cleanly and the shadow must begin directly beneath the raised surface.
	float far_fade = smoothstep(0.0, 0.24, 1.0 - UV.y);
	float alpha = shadow_alpha * daylight * caster_strength * edge_contribution * far_fade;
	COLOR = vec4(0.025, 0.035, 0.030, alpha);
}
