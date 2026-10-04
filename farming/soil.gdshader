shader_type spatial;
// A plot's top surface: grass sod giving way to furrowed soil as it's tilled; darker when wet.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float till : hint_range(0.0, 1.0) = 0.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 grass = texture(grass_tex, UV * 0.6 + seed * 0.1).rgb * vec3(0.82, 0.95, 0.62);
	vec3 soil = texture(soil_tex, UV * vec2(1.0, 1.0)).rgb * vec3(0.95, 0.85, 0.75);
	// Clods of sod come away in patches as the strikes add up.
	float n = hash(floor(UV * 7.0));
	float m = smoothstep(n - 0.12, n + 0.12, till * 1.15 - 0.05);
	vec3 c = mix(grass, soil, m);
	c *= mix(1.0, 0.58, wet * m);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.55, wet * m);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(soil_normal, UV).rgb, m);
}
