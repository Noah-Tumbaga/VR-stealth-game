extends RefCounted
## Procedural PBR material library.
## Every surface is built from FastNoiseLite-driven textures (albedo + normal maps)
## so the game ships with zero imported assets but still renders detailed surfaces.

static var _cache: Dictionary = {}


static func _noise(freq: float, octaves := 5, ntype := FastNoiseLite.TYPE_SIMPLEX_SMOOTH, seed_v := 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = ntype
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_v
	return n


static func _cellular(freq: float, ret := FastNoiseLite.RETURN_DISTANCE2_SUB, seed_v := 3, jitter := 0.9) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.cellular_return_type = ret
	n.cellular_jitter = jitter
	n.seed = seed_v
	return n


static func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / float(maxi(colors.size() - 1, 1)))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	return g


static func _tex(noise: Noise, colors: Array, size := 512) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = noise
	t.color_ramp = _ramp(colors)
	return t


static func _ntex(noise: Noise, bump := 6.0, size := 512) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = noise
	t.as_normal_map = true
	t.bump_strength = bump
	return t


static func _rtex(noise: Noise, lo: float, hi: float, size := 256) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = noise
	t.color_ramp = _ramp([Color(lo, lo, lo), Color(hi, hi, hi)])
	return t


static func _base(albedo_tex: Texture2D, normal_tex: Texture2D, normal_scale: float, rough: float, metal: float, uv: float, triplanar := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo_tex
	if normal_tex:
		m.normal_enabled = true
		m.normal_texture = normal_tex
		m.normal_scale = normal_scale
	m.roughness = rough
	m.metallic = metal
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3(uv, uv, uv)
	else:
		m.uv1_scale = Vector3(uv, uv, uv)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _cached(key: String, maker: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


# ---------------------------------------------------------------- architecture

static func stone() -> Material:
	return _cached("stone", func():
		var albedo := _tex(_noise(0.012, 6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 11), [Color(0.24, 0.23, 0.22), Color(0.36, 0.34, 0.31), Color(0.45, 0.43, 0.39)])
		var nrm := _ntex(_cellular(0.018, FastNoiseLite.RETURN_DISTANCE2_SUB, 7), 10.0)
		var m := _base(albedo, nrm, 1.4, 0.93, 0.0, 0.32)
		m.roughness_texture = _rtex(_noise(0.03, 3, FastNoiseLite.TYPE_SIMPLEX, 4), 0.75, 1.0)
		return m)


static func stone_dark() -> Material:
	return _cached("stone_dark", func():
		var albedo := _tex(_noise(0.015, 6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 21), [Color(0.13, 0.13, 0.14), Color(0.22, 0.21, 0.21), Color(0.28, 0.27, 0.26)])
		var nrm := _ntex(_cellular(0.014, FastNoiseLite.RETURN_DISTANCE2_SUB, 9), 12.0)
		return _base(albedo, nrm, 1.5, 0.95, 0.0, 0.3))


static func stone_trim() -> Material:
	return _cached("stone_trim", func():
		var albedo := _tex(_noise(0.02, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 31), [Color(0.42, 0.40, 0.36), Color(0.55, 0.52, 0.47)])
		var nrm := _ntex(_noise(0.04, 5, FastNoiseLite.TYPE_SIMPLEX, 32), 3.0)
		return _base(albedo, nrm, 0.8, 0.85, 0.0, 0.6))


static func cobble() -> Material:
	return _cached("cobble", func():
		var cell := _cellular(0.034, FastNoiseLite.RETURN_DISTANCE2_SUB, 5, 0.85)
		var albedo := _tex(cell, [Color(0.07, 0.07, 0.07), Color(0.20, 0.19, 0.18), Color(0.30, 0.29, 0.27), Color(0.34, 0.33, 0.31)])
		var nrm := _ntex(cell, 14.0)
		var m := _base(albedo, nrm, 1.6, 0.88, 0.0, 0.42)
		m.roughness_texture = _rtex(_noise(0.02, 3, FastNoiseLite.TYPE_SIMPLEX, 6), 0.55, 0.95)
		return m)


static func plaster() -> Material:
	return _cached("plaster", func():
		var albedo := _tex(_noise(0.01, 6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 41), [Color(0.52, 0.47, 0.40), Color(0.66, 0.61, 0.53), Color(0.70, 0.66, 0.58)])
		var nrm := _ntex(_noise(0.05, 6, FastNoiseLite.TYPE_SIMPLEX, 42), 2.0)
		return _base(albedo, nrm, 0.6, 0.95, 0.0, 0.4))


static func wood() -> Material:
	return _cached("wood", func():
		var n := _noise(0.006, 4, FastNoiseLite.TYPE_SIMPLEX, 51)
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		var albedo := _tex(n, [Color(0.17, 0.10, 0.05), Color(0.30, 0.19, 0.10), Color(0.38, 0.25, 0.14)])
		var nrm := _ntex(n, 4.0)
		var m := _base(albedo, nrm, 0.9, 0.78, 0.0, 0.5)
		m.uv1_scale = Vector3(0.25, 2.5, 0.25)
		return m)


static func wood_dark() -> Material:
	return _cached("wood_dark", func():
		var n := _noise(0.008, 4, FastNoiseLite.TYPE_SIMPLEX, 61)
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		var albedo := _tex(n, [Color(0.06, 0.035, 0.02), Color(0.13, 0.08, 0.045), Color(0.19, 0.12, 0.07)])
		var nrm := _ntex(n, 3.0)
		var m := _base(albedo, nrm, 0.8, 0.55, 0.0, 0.5)
		m.uv1_scale = Vector3(0.3, 2.0, 0.3)
		return m)


static func planks() -> Material:
	return _cached("planks", func():
		var cell := _cellular(0.02, FastNoiseLite.RETURN_DISTANCE2_SUB, 71, 0.2)
		var albedo := _tex(_noise(0.01, 5, FastNoiseLite.TYPE_SIMPLEX, 72), [Color(0.16, 0.10, 0.06), Color(0.27, 0.17, 0.09), Color(0.33, 0.22, 0.12)])
		var nrm := _ntex(cell, 5.0)
		var m := _base(albedo, nrm, 0.8, 0.7, 0.0, 0.6)
		m.uv1_scale = Vector3(1.6, 1.6, 0.25)
		return m)


static func roof() -> Material:
	return _cached("roof", func():
		var cell := _cellular(0.05, FastNoiseLite.RETURN_DISTANCE2_SUB, 81, 0.35)
		var albedo := _tex(_noise(0.02, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 82), [Color(0.17, 0.08, 0.06), Color(0.30, 0.13, 0.09), Color(0.36, 0.18, 0.12)])
		var nrm := _ntex(cell, 12.0)
		return _base(albedo, nrm, 1.5, 0.85, 0.0, 0.5))


static func slate() -> Material:
	return _cached("slate", func():
		var cell := _cellular(0.05, FastNoiseLite.RETURN_DISTANCE2_SUB, 91, 0.3)
		var albedo := _tex(_noise(0.02, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 92), [Color(0.08, 0.09, 0.11), Color(0.15, 0.16, 0.19), Color(0.2, 0.21, 0.24)])
		var nrm := _ntex(cell, 12.0)
		return _base(albedo, nrm, 1.5, 0.6, 0.1, 0.5))


static func marble() -> Material:
	return _cached("marble", func():
		var n := _noise(0.004, 7, FastNoiseLite.TYPE_SIMPLEX, 101)
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		var albedo := _tex(n, [Color(0.36, 0.34, 0.33), Color(0.62, 0.60, 0.57), Color(0.78, 0.76, 0.72)])
		var nrm := _ntex(_cellular(0.012, FastNoiseLite.RETURN_DISTANCE2_SUB, 102, 0.05), 3.0)
		var m := _base(albedo, nrm, 0.6, 0.18, 0.0, 0.35)
		return m)


static func carpet(c: Color) -> Material:
	return _cached("carpet_%s" % c.to_html(), func():
		var n := _cellular(0.06, FastNoiseLite.RETURN_CELL_VALUE, 111, 0.0)
		var albedo := _tex(n, [c.darkened(0.35), c, c.lightened(0.08)])
		var nrm := _ntex(_noise(0.4, 2, FastNoiseLite.TYPE_VALUE, 112), 1.5)
		return _base(albedo, nrm, 0.5, 1.0, 0.0, 0.8))


# ---------------------------------------------------------------- nature

static func grass() -> Material:
	return _cached("grass", func():
		var albedo := _tex(_noise(0.01, 7, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 121), [Color(0.07, 0.1, 0.05), Color(0.12, 0.18, 0.08), Color(0.17, 0.22, 0.1), Color(0.2, 0.19, 0.12)])
		var nrm := _ntex(_noise(0.12, 4, FastNoiseLite.TYPE_SIMPLEX, 122), 3.0)
		return _base(albedo, nrm, 0.7, 0.96, 0.0, 0.15))


static func dirt() -> Material:
	return _cached("dirt", func():
		var albedo := _tex(_noise(0.015, 6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 131), [Color(0.10, 0.07, 0.05), Color(0.19, 0.14, 0.09), Color(0.24, 0.19, 0.13)])
		var nrm := _ntex(_cellular(0.09, FastNoiseLite.RETURN_DISTANCE, 132), 4.0)
		return _base(albedo, nrm, 0.8, 0.97, 0.0, 0.3))


static func bark() -> Material:
	return _cached("bark", func():
		var n := _noise(0.02, 5, FastNoiseLite.TYPE_SIMPLEX, 141)
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		var albedo := _tex(n, [Color(0.06, 0.045, 0.035), Color(0.15, 0.11, 0.08), Color(0.2, 0.16, 0.12)])
		var nrm := _ntex(n, 12.0)
		var m := _base(albedo, nrm, 1.5, 0.95, 0.0, 1.0)
		m.uv1_scale = Vector3(1.5, 0.35, 1.5)
		return m)


static func leaves(tint := Color(0.06, 0.12, 0.05)) -> Material:
	return _cached("leaves_%s" % tint.to_html(), func():
		var cell := _cellular(0.09, FastNoiseLite.RETURN_DISTANCE2_SUB, 151, 1.0)
		var albedo := _tex(_noise(0.05, 4, FastNoiseLite.TYPE_SIMPLEX, 152), [tint.darkened(0.55), tint, tint.lightened(0.25)])
		var nrm := _ntex(cell, 14.0)
		var m := _base(albedo, nrm, 1.6, 0.9, 0.0, 1.2)
		m.backlight_enabled = true
		m.backlight = tint.darkened(0.2)
		return m)


static func rock() -> Material:
	return _cached("rock", func():
		var albedo := _tex(_noise(0.02, 7, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 161), [Color(0.12, 0.12, 0.13), Color(0.25, 0.25, 0.25), Color(0.33, 0.32, 0.30)])
		var nrm := _ntex(_noise(0.03, 7, FastNoiseLite.TYPE_SIMPLEX, 162), 12.0)
		return _base(albedo, nrm, 1.5, 0.92, 0.0, 0.4))


static func hay() -> Material:
	return _cached("hay", func():
		var n := _noise(0.05, 3, FastNoiseLite.TYPE_SIMPLEX, 171)
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		var albedo := _tex(n, [Color(0.25, 0.18, 0.06), Color(0.45, 0.35, 0.14), Color(0.55, 0.45, 0.2)])
		var nrm := _ntex(n, 8.0)
		var m := _base(albedo, nrm, 1.2, 1.0, 0.0, 1.0)
		m.uv1_scale = Vector3(3.0, 0.6, 3.0)
		return m)


static func water() -> Material:
	return _cached("water", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.03, 0.06, 0.08, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.04
		m.metallic = 0.3
		m.normal_enabled = true
		m.normal_texture = _ntex(_noise(0.04, 4, FastNoiseLite.TYPE_SIMPLEX, 181), 3.0)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.8, 0.8, 0.8)
		return m)


# ---------------------------------------------------------------- metals & fabrics

static func steel() -> Material:
	return _cached("steel", func():
		var albedo := _tex(_noise(0.03, 5, FastNoiseLite.TYPE_SIMPLEX, 191), [Color(0.42, 0.43, 0.45), Color(0.58, 0.59, 0.62)])
		var nrm := _ntex(_noise(0.08, 4, FastNoiseLite.TYPE_SIMPLEX, 192), 1.2)
		var m := _base(albedo, nrm, 0.4, 0.32, 0.92, 1.5)
		m.roughness_texture = _rtex(_noise(0.05, 4, FastNoiseLite.TYPE_SIMPLEX, 193), 0.18, 0.5)
		return m)


static func iron() -> Material:
	return _cached("iron", func():
		var albedo := _tex(_noise(0.04, 5, FastNoiseLite.TYPE_SIMPLEX, 201), [Color(0.08, 0.08, 0.08), Color(0.18, 0.17, 0.16), Color(0.22, 0.15, 0.10)])
		var nrm := _ntex(_noise(0.1, 4, FastNoiseLite.TYPE_SIMPLEX, 202), 3.0)
		return _base(albedo, nrm, 0.8, 0.6, 0.8, 1.5))


static func gold() -> Material:
	return _cached("gold", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.62, 0.25)
		m.metallic = 1.0
		m.roughness = 0.28
		return m)


static func brass() -> Material:
	return _cached("brass", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.45, 0.22)
		m.metallic = 0.95
		m.roughness = 0.42
		return m)


static func blade() -> Material:
	return _cached("blade", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.74, 0.78)
		m.metallic = 1.0
		m.roughness = 0.12
		m.normal_enabled = true
		m.normal_texture = _ntex(_noise(0.2, 2, FastNoiseLite.TYPE_SIMPLEX, 211), 0.6)
		return m)


static func blackened_steel() -> Material:
	return _cached("blk_steel", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.06, 0.07)
		m.metallic = 0.9
		m.roughness = 0.35
		return m)


static func chainmail() -> Material:
	return _cached("chain", func():
		var cell := _cellular(0.22, FastNoiseLite.RETURN_DISTANCE, 221, 0.0)
		var albedo := _tex(cell, [Color(0.5, 0.5, 0.52), Color(0.32, 0.32, 0.34), Color(0.08, 0.08, 0.08)], 256)
		var nrm := _ntex(cell, 8.0, 256)
		var m := _base(albedo, nrm, 1.2, 0.45, 0.85, 3.0)
		return m)


static func leather() -> Material:
	return _cached("leather", func():
		var albedo := _tex(_noise(0.03, 5, FastNoiseLite.TYPE_SIMPLEX, 231), [Color(0.12, 0.07, 0.04), Color(0.22, 0.13, 0.07), Color(0.28, 0.17, 0.09)])
		var nrm := _ntex(_cellular(0.12, FastNoiseLite.RETURN_DISTANCE, 232), 2.0)
		return _base(albedo, nrm, 0.6, 0.62, 0.0, 2.0))


static func leather_dark() -> Material:
	return _cached("leather_dark", func():
		var albedo := _tex(_noise(0.03, 5, FastNoiseLite.TYPE_SIMPLEX, 241), [Color(0.03, 0.025, 0.02), Color(0.07, 0.05, 0.035), Color(0.1, 0.07, 0.05)])
		var nrm := _ntex(_cellular(0.12, FastNoiseLite.RETURN_DISTANCE, 242), 2.0)
		return _base(albedo, nrm, 0.6, 0.5, 0.0, 2.0))


static func cloth(c: Color) -> Material:
	return _cached("cloth_%s" % c.to_html(), func():
		var weave := _noise(0.5, 2, FastNoiseLite.TYPE_VALUE, 251)
		var albedo := _tex(_noise(0.02, 4, FastNoiseLite.TYPE_SIMPLEX, 252), [c.darkened(0.25), c, c.lightened(0.05)], 256)
		var nrm := _ntex(weave, 1.5, 256)
		var m := _base(albedo, nrm, 0.6, 0.95, 0.0, 1.5)
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.6
		return m)


static func velvet(c: Color) -> Material:
	return _cached("velvet_%s" % c.to_html(), func():
		var albedo := _tex(_noise(0.02, 4, FastNoiseLite.TYPE_SIMPLEX, 261), [c.darkened(0.4), c, c.lightened(0.1)], 256)
		var m := _base(albedo, null, 0.0, 0.85, 0.0, 1.0)
		m.rim_enabled = true
		m.rim = 0.7
		m.rim_tint = 0.2
		return m)


static func fur() -> Material:
	return _cached("fur", func():
		var n := _noise(0.15, 3, FastNoiseLite.TYPE_SIMPLEX, 271)
		var albedo := _tex(n, [Color(0.18, 0.15, 0.12), Color(0.42, 0.38, 0.32), Color(0.6, 0.56, 0.5)], 256)
		var nrm := _ntex(n, 10.0, 256)
		var m := _base(albedo, nrm, 1.5, 1.0, 0.0, 2.0)
		m.rim_enabled = true
		m.rim = 0.8
		return m)


static func skin(c: Color) -> Material:
	return _cached("skin_%s" % c.to_html(), func():
		var albedo := _tex(_noise(0.06, 4, FastNoiseLite.TYPE_SIMPLEX, 281), [c.darkened(0.12), c, c.lightened(0.04)], 256)
		var nrm := _ntex(_noise(0.3, 2, FastNoiseLite.TYPE_SIMPLEX, 282), 0.6, 256)
		var m := _base(albedo, nrm, 0.3, 0.55, 0.0, 2.0)
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.35
		m.rim_enabled = true
		m.rim = 0.2
		return m)


static func hair(c: Color) -> Material:
	return _cached("hair_%s" % c.to_html(), func():
		var n := _noise(0.4, 2, FastNoiseLite.TYPE_SIMPLEX, 291)
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		var albedo := _tex(n, [c.darkened(0.4), c, c.lightened(0.15)], 256)
		var nrm := _ntex(n, 6.0, 256)
		var m := _base(albedo, nrm, 1.0, 0.7, 0.0, 2.0)
		m.uv1_scale = Vector3(4.0, 0.5, 4.0)
		return m)


static func flat(c: Color, rough := 0.6, metal := 0.0) -> Material:
	return _cached("flat_%s_%.2f_%.2f" % [c.to_html(), rough, metal], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		return m)


static func glossy(c: Color) -> Material:
	return flat(c, 0.08, 0.0)


static func emissive(c: Color, energy := 2.0) -> Material:
	return _cached("emis_%s_%.2f" % [c.to_html(), energy], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		m.roughness = 0.5
		return m)


static func glow(c: Color, energy := 3.0) -> Material:
	## Unshaded additive glow - flames, magic orbs.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * energy
	m.albedo_color.a = c.a
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


static func window_glass() -> Material:
	return _cached("window_lit", func():
		var m := StandardMaterial3D.new()
		var cell := _cellular(0.03, FastNoiseLite.RETURN_DISTANCE2_SUB, 301, 0.0)
		m.albedo_texture = _tex(cell, [Color(0.25, 0.1, 0.02), Color(1.0, 0.62, 0.25), Color(1.0, 0.75, 0.4)], 256)
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = 0.75
		m.roughness = 0.2
		return m)


static func window_dark() -> Material:
	return _cached("window_dark", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.02, 0.03, 0.05)
		m.roughness = 0.08
		m.metallic = 0.4
		return m)


static func book(seed_i: int) -> Material:
	var palette := [Color(0.35, 0.06, 0.05), Color(0.08, 0.16, 0.3), Color(0.1, 0.22, 0.1), Color(0.35, 0.25, 0.1), Color(0.18, 0.08, 0.2), Color(0.25, 0.15, 0.08)]
	return cloth(palette[seed_i % palette.size()])


static func wax() -> Material:
	return _cached("wax", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.88, 0.75)
		m.roughness = 0.5
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.6
		return m)


static func blood() -> Material:
	return _cached("blood", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.0, 0.0)
		m.roughness = 0.15
		m.metallic = 0.1
		return m)
