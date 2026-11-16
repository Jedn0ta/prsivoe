shader_type canvas_item;
// Rounded corners for card photos.
uniform float radius = 0.055;
uniform float ratio = 1.52;
void fragment() {
	vec2 p = vec2(UV.x, UV.y * ratio);
	vec2 hs = vec2(0.5, 0.5 * ratio);
	vec2 q = abs(p - hs) - (hs - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	COLOR.a *= 1.0 - smoothstep(-0.006, 0.0, d);
}
