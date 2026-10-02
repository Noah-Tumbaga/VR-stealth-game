shader_type sky;

// Night sky: gradient, twinkling star field, milky band, moon disc with halo.

uniform vec3 top_color : source_color = vec3(0.008, 0.012, 0.035);
uniform vec3 horizon_color : source_color = vec3(0.045, 0.06, 0.11);
uniform vec3 ground_color : source_color = vec3(0.01, 0.012, 0.018);
uniform vec3 moon_color : source_color = vec3(0.92, 0.95, 1.0);
uniform float star_density = 0.004;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, h));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.15, h));
	}
	{
		// Milky band
		float band = exp(-pow(dot(d, normalize(vec3(0.3, 0.2, 0.93))) * 3.2, 2.0));
		float clouds = noise3(d * 6.0) * 0.6 + noise3(d * 14.0) * 0.4;
		col += vec3(0.05, 0.05, 0.08) * band * clouds * smoothstep(0.0, 0.3, h);
		// Stars
		vec3 sp = d * 260.0;
		vec3 cell = floor(sp);
		float r = hash(cell);
		if (r > 1.0 - star_density * (1.0 + band * 3.0) && h > 0.02) {
			vec3 f = fract(sp) - 0.5;
			float s = smoothstep(0.16, 0.0, length(f));
			float tw = 0.65 + 0.35 * sin(TIME * (1.5 + r * 7.0) + r * 120.0);
			vec3 tint = mix(vec3(0.8, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash(cell + 3.1));
			col += tint * s * tw * 1.6 * smoothstep(0.02, 0.25, h);
		}
	}
	if (LIGHT0_ENABLED) {
		vec3 md = normalize(LIGHT0_DIRECTION);
		float a = dot(md, d);
		float disc = smoothstep(0.99935, 0.99955, a);
		float crater = 0.78 + 0.22 * noise3(d * 900.0);
		float halo = pow(max(a, 0.0), 600.0) * 0.6 + pow(max(a, 0.0), 40.0) * 0.07;
		col += moon_color * (disc * 3.0 * crater + halo);
	}
	COLOR = col;
}
