extends Node3D
## Builds "Vane Manor" - a walled noble estate at night - plus the forest
## approach, lighting, environment, characters and the navigation mesh.
##
## Layout (north = -Z):
##   South forest (start + river extraction) -> south wall with gatehouse and a
##   collapsed breach -> courtyard (well, market, carts, stable) -> barracks (W),
##   Vane Manor great hall + study (N), walled hedge garden with gazebo (E).

const Mats = preload("res://scripts/util/mats.gd")
const Geo = preload("res://scripts/util/geo.gd")
const Props = preload("res://scripts/world/props.gd")
const Guard = preload("res://scripts/npc/guard.gd")

const WALL_H := 5.5
const WALL_T := 1.2

var nav_region: NavigationRegion3D
var geo_root: Node3D  # everything static (parsed for navmesh)
var characters: Node3D
var player_start := Vector3(-21.0, 0.0, 47.5)
var extraction := Vector3(-14.0, 0.0, 53.6)
var vr := false


func build(p_vr: bool) -> void:
	vr = p_vr
	Props.rng.seed = 1984
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Level"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = 0.2
	nm.cell_height = 0.1
	nm.agent_height = 1.8
	nm.agent_radius = 0.4
	nm.agent_max_climb = 0.18
	nm.agent_max_slope = 40.0
	nm.filter_baking_aabb = AABB(Vector3(-31.0, -1.0, -31.0), Vector3(62.0, 7.0, 68.0))
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	geo_root = nav_region
	characters = Geo.node(self, Vector3.ZERO, Vector3.ZERO, "Characters")

	_environment()
	_ground()
	_outer_walls()
	_gatehouse()
	_forest()
	_courtyard()
	_barracks()
	_manor()
	_garden()
	_stable()
	_spawn_characters()


func bake_navigation() -> void:
	nav_region.bake_finished.connect(_on_baked)
	nav_region.bake_navigation_mesh(true)


func _on_baked() -> void:
	get_tree().create_timer(0.4).timeout.connect(func(): GameState.nav_ready = true)


# ================================================================ environment

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/night_sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.2, 0.34)
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.3
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.14)
	env.fog_density = 0.008
	env.fog_sky_affect = 0.25
	env.volumetric_fog_enabled = not vr
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.55, 0.6, 0.75)
	env.volumetric_fog_anisotropy = 0.4
	env.volumetric_fog_length = 60.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.08
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.56, 0.66, 0.98)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.directional_shadow_max_distance = 80.0
	moon.light_volumetric_fog_energy = 0.5
	add_child(moon)
	moon.look_at_from_position(Vector3.ZERO, -GameState.MOON_DIR.normalized(), Vector3.UP)


func _ground() -> void:
	var g := geo_root
	Geo.solid_box(g, Vector3(160, 1, 160), Vector3(0, -0.5, 0), Mats.grass())
	# Courtyard cobbles and interior paving (visual layers).
	Geo.box(g, Vector3(58.8, 0.02, 58.8), Vector3(0, 0.0, 0), Mats.cobble())
	Geo.box(g, Vector3(14.4, 0.024, 26.4), Vector3(22.2, 0.003, -16.2), Mats.grass())  # garden lawn
	Geo.box(g, Vector3(4.2, 0.02, 28.0), Vector3(0, 0.002, 44.0), Mats.dirt())  # road
	Geo.box(g, Vector3(6.0, 0.02, 2.4), Vector3(0, 0.004, 30.0), Mats.cobble())  # gate floor
	Geo.box(g, Vector3(4.0, 0.022, 3.0), Vector3(-21.0, 0.004, 30.0), Mats.dirt())  # breach
	# Invisible bounds: keep the player inside the compound + forest.
	for b in [[Vector3(1, 20, 64), Vector3(-31.6, 10, -0.5)], [Vector3(1, 20, 64), Vector3(31.6, 10, -0.5)], [Vector3(64, 20, 1), Vector3(0, 10, -31.6)]]:
		Geo.col_box(g, b[0], b[1])


# ================================================================ walls

func _wall(parent: Node3D, a: Vector2, b: Vector2, h: float, thick: float, mat: Material, openings := [], inner_sign := 0.0, inner := false, y0 := 0.0) -> void:
	## Straight wall from a to b (x,z) with openings [[dist_from_a, width, height], ...].
	## inner_sign: +1/-1 picks which side gets interior plaster + wainscot panels.
	var d := b - a
	var length := d.length()
	var dir := d / length
	var yaw := -rad_to_deg(atan2(d.y, d.x))
	var nrm := Vector2(-dir.y, dir.x) * inner_sign
	var segs: Array = []
	var cursor := 0.0
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return p[0] < q[0])
	for o in ops:
		var s0: float = o[0] - o[1] * 0.5
		var s1: float = o[0] + o[1] * 0.5
		if s0 > cursor:
			segs.append([cursor, s0, 0.0, h])
		if o[2] < h:
			segs.append([s0, s1, o[2], h])
		cursor = s1
		# door frame trim
		var fc: Vector2 = a + dir * o[0]
		for side in [-1.0, 1.0]:
			var jc: Vector2 = a + dir * (o[0] + side * (o[1] * 0.5 + 0.08))
			Geo.box(parent, Vector3(0.18, o[2] + 0.1, thick + 0.12), Vector3(jc.x, y0 + (o[2] + 0.1) * 0.5, jc.y), Mats.stone_trim(), Vector3(0, yaw, 0))
		Geo.box(parent, Vector3(o[1] + 0.5, 0.22, thick + 0.14), Vector3(fc.x, y0 + o[2] + 0.11, fc.y), Mats.stone_trim(), Vector3(0, yaw, 0))
	if cursor < length:
		segs.append([cursor, length, 0.0, h])
	for s in segs:
		var sl: float = s[1] - s[0]
		if sl < 0.01:
			continue
		var mid: float = (s[0] + s[1]) * 0.5
		var c2 := a + dir * mid
		var hh: float = s[3] - s[2]
		Geo.solid_box(parent, Vector3(sl, hh, thick), Vector3(c2.x, y0 + s[2] + hh * 0.5, c2.y), mat, Vector3(0, yaw, 0))
		if inner:
			var ic := c2 + nrm * (thick * 0.5 + 0.02)
			var wain_top := 1.25
			if s[2] < wain_top:
				var top := minf(s[3], wain_top)
				Geo.box(parent, Vector3(sl, top - s[2], 0.04), Vector3(ic.x, y0 + (s[2] + top) * 0.5, ic.y), Mats.wood_dark(), Vector3(0, yaw, 0))
				if s[3] > wain_top:
					var rc := c2 + nrm * (thick * 0.5 + 0.045)
					Geo.box(parent, Vector3(sl, 0.06, 0.05), Vector3(rc.x, y0 + wain_top, rc.y), Mats.wood(), Vector3(0, yaw, 0))
			var pb := maxf(s[2], wain_top)
			if s[3] > pb:
				Geo.box(parent, Vector3(sl, s[3] - pb, 0.03), Vector3(ic.x, y0 + (pb + s[3]) * 0.5, ic.y), Mats.plaster(), Vector3(0, yaw, 0))


func _battlements(parent: Node3D, a: Vector2, b: Vector2, h: float, thick: float) -> void:
	var d := b - a
	var length := d.length()
	var dir := d / length
	var yaw := -rad_to_deg(atan2(d.y, d.x))
	var n := int(length / 1.5)
	var st := Mats.stone()
	for i in n:
		var c := a + dir * ((i + 0.5) * length / n)
		Geo.box(parent, Vector3(0.75, 0.7, thick + 0.1), Vector3(c.x, h + 0.35, c.y), st, Vector3(0, yaw, 0))
	Geo.box(parent, Vector3(length, 0.18, thick + 0.25), Vector3((a.x + b.x) * 0.5, h - 0.09, (a.y + b.y) * 0.5), Mats.stone_trim(), Vector3(0, yaw, 0))
	Geo.box(parent, Vector3(length, 0.5, thick + 0.15), Vector3((a.x + b.x) * 0.5, 0.25, (a.y + b.y) * 0.5), Mats.stone_dark(), Vector3(0, yaw, 0))  # plinth


func _outer_walls() -> void:
	var g := geo_root
	var st := Mats.stone()
	var segs := [
		[Vector2(-30.6, -30), Vector2(30.6, -30)],
		[Vector2(30, -30), Vector2(30, 30)],
		[Vector2(-30, -30), Vector2(-30, 30)],
		[Vector2(-30.6, 30), Vector2(-23.2, 30)],
		[Vector2(-18.8, 30), Vector2(-3.0, 30)],
		[Vector2(3.0, 30), Vector2(30.6, 30)],
	]
	for s in segs:
		_wall(g, s[0], s[1], WALL_H, WALL_T, st)
		_battlements(g, s[0], s[1], WALL_H, WALL_T)
	# buttresses on the outer faces
	for i in 9:
		var t := -26.0 + i * 6.5
		for side in [-1.0, 1.0]:
			Geo.solid_box(g, Vector3(0.9, WALL_H - 1.0, 0.9), Vector3(side * 31.0, (WALL_H - 1.0) * 0.5, t), st)
		Geo.solid_box(g, Vector3(0.9, WALL_H - 1.0, 0.9), Vector3(t, (WALL_H - 1.0) * 0.5, -31.0), st)
	# Collapsed breach: jagged broken edges + rubble you can pick through.
	for side in [-1.0, 1.0]:
		var ex: float = -21.0 + side * 2.2
		for k in 3:
			var hgt := WALL_H - 1.2 - k * 1.4
			Geo.solid_box(g, Vector3(0.45, hgt, WALL_T * (1.0 - k * 0.12)), Vector3(ex - side * (0.225 + k * 0.45), hgt * 0.5, 30.0), st, Vector3(0, 0, side * k * 3.0))
	Props.rubble(g, Vector3(-21.0, 0, 30.0), 2.8, 26)
	Props.rubble(g, Vector3(-21.0, 0, 32.0), 3.5, 14)
	Props.rubble(g, Vector3(-21.0, 0, 28.0), 3.0, 12)
	# corner towers
	for c in [Vector2(-30, -30), Vector2(30, -30), Vector2(-30, 30), Vector2(30, 30)]:
		_tower(g, Vector3(c.x, 0, c.y), 2.6, 8.5)


func _tower(parent: Node3D, pos: Vector3, r: float, h: float) -> void:
	var st := Mats.stone()
	Geo.cyl(parent, r, r + 0.25, h, pos + Vector3(0, h * 0.5, 0), st, Vector3.ZERO, Vector3.ONE, 24)
	Geo.col_cyl(parent, r + 0.1, h, pos + Vector3(0, h * 0.5, 0))
	Geo.cyl(parent, r + 0.35, r + 0.35, 0.3, pos + Vector3(0, h - 0.1, 0), Mats.stone_trim(), Vector3.ZERO, Vector3.ONE, 24)
	for i in 10:
		var a := i * TAU / 10.0
		Geo.box(parent, Vector3(0.8, 0.8, 0.5), pos + Vector3(cos(a) * (r + 0.1), h + 0.4, sin(a) * (r + 0.1)), st, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	Geo.cyl(parent, 0.0, r + 0.7, 3.4, pos + Vector3(0, h + 2.4, 0), Mats.slate(), Vector3.ZERO, Vector3.ONE, 24)
	Geo.cyl(parent, 0.02, 0.06, 1.2, pos + Vector3(0, h + 4.5, 0), Mats.iron())
	# arrow slits
	for k in 3:
		var a2 := k * TAU / 3.0 + 0.5
		Geo.box(parent, Vector3(0.12, 1.0, 0.3), pos + Vector3(cos(a2) * (r + 0.06), h * 0.6, sin(a2) * (r + 0.06)), Mats.window_dark(), Vector3(0, -rad_to_deg(a2) + 90.0, 0))


func _gatehouse() -> void:
	var g := geo_root
	var st := Mats.stone()
	for side in [-1.0, 1.0]:
		var cx: float = side * 4.6
		Geo.solid_box(g, Vector3(3.2, 7.5, 3.4), Vector3(cx, 3.75, 30.0), st)
		_battlements(g, Vector2(cx - 1.6, 31.7), Vector2(cx + 1.6, 31.7), 7.5, 0.3)
		_battlements(g, Vector2(cx - 1.6, 28.3), Vector2(cx + 1.6, 28.3), 7.5, 0.3)
		Geo.box(g, Vector3(0.15, 1.2, 0.35), Vector3(cx, 4.8, 31.72), Mats.window_dark())  # arrow slit
		Props.banner(g, Vector3(cx, 6.6, 31.8), 0.0, Color(0.45, 0.05, 0.08), 2.6)
		Props.wall_torch(g, Vector3(side * 3.3, 3.0, 31.72), 180.0, true)
		Props.wall_torch(g, Vector3(side * 3.3, 3.0, 28.28), 0.0, false)
		# open gate leaves resting against the inner wall
		var leaf := Geo.node(g, Vector3(side * 2.95, 0, 28.8), Vector3(0, side * -80.0, 0))
		Geo.box(leaf, Vector3(2.9, 4.0, 0.14), Vector3(-side * 1.45, 2.0, 0), Mats.planks())
		for y in [0.6, 2.0, 3.4]:
			Geo.box(leaf, Vector3(2.9, 0.12, 0.18), Vector3(-side * 1.45, y, 0), Mats.iron())
		Geo.col_box(leaf, Vector3(2.9, 4.0, 0.2), Vector3(-side * 1.45, 2.0, 0))
	# arch lintel + raised portcullis
	Geo.solid_box(g, Vector3(6.2, 2.5, 3.4), Vector3(0, 5.25, 30.0), st)
	Geo.box(g, Vector3(6.4, 0.3, 3.5), Vector3(0, 4.05, 30.0), Mats.stone_trim())
	for i in 9:
		Geo.box(g, Vector3(0.08, 0.6, 0.08), Vector3(-2.6 + i * 0.65, 3.65, 30.6), Mats.iron())
		Geo.prism(g, Vector3(0.12, 0.2, 0.08), Vector3(-2.6 + i * 0.65, 3.25, 30.6), Mats.iron(), Vector3(0, 0, 180))
	Geo.box(g, Vector3(5.6, 0.1, 0.1), Vector3(0, 3.6, 30.6), Mats.iron())


# ================================================================ forest / approach

func _forest() -> void:
	var g := geo_root
	var rk := Mats.rock()
	# Cliffs enclosing the forest
	var cliffs := [
		[Vector3(2.0, 9.0, 30.0), Vector3(-42.0, 4.5, 44.0)],
		[Vector3(2.0, 9.0, 30.0), Vector3(42.0, 4.5, 44.0)],
		[Vector3(11.0, 9.0, 2.0), Vector3(-36.5, 4.5, 30.5)],
		[Vector3(11.0, 9.0, 2.0), Vector3(36.5, 4.5, 30.5)],
	]
	for c in cliffs:
		Geo.solid_box(g, c[0], c[1], rk)
		var size: Vector3 = c[0]
		var center: Vector3 = c[1]
		for i in int(maxf(size.x, size.z) / 2.5):
			var p := center + Vector3(Props.rng.randf_range(-size.x, size.x) * 0.5, Props.rng.randf_range(-3.0, 4.0), Props.rng.randf_range(-size.z, size.z) * 0.5)
			Geo.sphere(g, Props.rng.randf_range(1.8, 3.2), p, rk, Vector3(1.0, Props.rng.randf_range(0.6, 1.2), 1.0), false, 7, Vector3(Props.rng.randf() * 40.0, Props.rng.randf() * 180.0, 0))
	# River along the south edge
	Geo.box(g, Vector3(84.0, 0.05, 8.0), Vector3(0, 0.03, 59.5), Mats.water())
	Geo.box(g, Vector3(84.0, 0.2, 1.0), Vector3(0, 0.0, 55.4), Mats.dirt(), Vector3(-10, 0, 0))
	Geo.col_box(g, Vector3(84.0, 20.0, 1.0), Vector3(0, 10.0, 56.2))
	for i in 18:
		Props.rock(g, Vector3(Props.rng.randf_range(-40, 40), 0, Props.rng.randf_range(54.8, 55.6)), Props.rng.randf_range(0.4, 0.9))
	# Dock + rowboat (extraction)
	var dock := Geo.node(g, Vector3(-14.0, 0, 54.0))
	Geo.box(dock, Vector3(2.4, 0.08, 4.4), Vector3(0, 0.06, 1.0), Mats.planks())
	for x in [-1.1, 1.1]:
		for z in [-0.9, 1.0, 3.0]:
			Geo.cyl(dock, 0.09, 0.1, 1.2, Vector3(x, 0.0, z), Mats.wood_dark())
	var boat := Geo.node(g, Vector3(-11.8, 0.05, 57.0), Vector3(0, 8, 0))
	Geo.sphere(boat, 1.0, Vector3(0, 0.15, 0), Mats.planks(), Vector3(0.75, 0.45, 2.1), true, 16, Vector3(180, 0, 0))
	Geo.box(boat, Vector3(1.3, 0.05, 0.3), Vector3(0, 0.2, 0.4), Mats.wood())
	Geo.box(boat, Vector3(1.3, 0.05, 0.3), Vector3(0, 0.2, -0.6), Mats.wood())
	Geo.cyl(boat, 0.025, 0.025, 2.2, Vector3(0.5, 0.3, 0.2), Mats.wood(), Vector3(80, 20, 0))
	# Extraction marker: pale blue spirit-light
	var ex := Geo.node(self, extraction)
	Geo.torus(ex, 1.6, 1.75, Vector3(0, 0.15, 0), Mats.emissive(Color(0.3, 0.6, 1.0), 3.0))
	var beam := Mats.glow(Color(0.3, 0.55, 1.0, 0.12), 1.0)
	Geo.cyl(ex, 0.9, 1.4, 9.0, Vector3(0, 4.5, 0), beam, Vector3.ZERO, Vector3.ONE, 24)
	var exl := OmniLight3D.new()
	exl.light_color = Color(0.4, 0.6, 1.0)
	exl.light_energy = 1.2
	exl.omni_range = 6.0
	exl.position = Vector3(0, 1.5, 0)
	ex.add_child(exl)
	ex.name = "Extraction"
	# Camp at start
	var camp := Geo.node(g, player_start + Vector3(2.5, 0, 2.5))
	for i in 9:
		var a := i * TAU / 9.0
		Geo.sphere(camp, 0.18, Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6), rk, Vector3(1.0, 0.7, 1.0), false, 6)
	for i in 3:
		Geo.cyl(camp, 0.05, 0.06, 0.8, Vector3(0, 0.1, 0), Mats.bark(), Vector3(0, i * 60.0, 80))
	Geo.sphere(camp, 0.3, Vector3(0, 0.05, 0), Mats.emissive(Color(0.9, 0.2, 0.03), 1.2), Vector3(1.0, 0.25, 1.0))  # embers
	Props.chest(camp, Vector3(1.6, 0, -0.6), 30.0)
	# Trees, bushes, rocks
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 900:
		tries += 1
		var p := Vector3(Props.rng.randf_range(-40.0, 40.0), 0, Props.rng.randf_range(33.5, 54.0))
		if absf(p.x) < 3.5:
			continue  # road
		if p.distance_to(player_start) < 4.0 or p.distance_to(extraction) < 4.0:
			continue
		if absf(p.x + 21.0) < 2.5 and p.z < 38.0:
			continue  # path to breach
		if Props.rng.randf() < 0.75:
			Props.pine(g, p, Props.rng.randf_range(0.8, 1.35))
		else:
			Props.tree(g, p, Props.rng.randf_range(0.8, 1.2), Color(0.05, 0.1, 0.04))
		placed += 1
	for i in 26:
		var p2 := Vector3(Props.rng.randf_range(-38.0, 38.0), 0, Props.rng.randf_range(33.0, 53.0))
		if absf(p2.x) > 3.5:
			Props.bush(g, p2, Props.rng.randf_range(0.8, 1.3), true, Props.rng.randf() < 0.2)
	for i in 14:
		var p3 := Vector3(Props.rng.randf_range(-38.0, 38.0), 0, Props.rng.randf_range(34.0, 53.0))
		if absf(p3.x) > 3.5:
			Props.rock(g, p3, Props.rng.randf_range(0.5, 1.4))
	# Hedge of bushes near the breach to sneak up through.
	for p4 in [Vector3(-24.5, 0, 35.0), Vector3(-17.5, 0, 35.5), Vector3(-25.5, 0, 38.5), Vector3(-16.5, 0, 39.0)]:
		Props.bush(g, p4, 1.2)
	Props.grass_field(self, Vector3(0, 0, 43.0), Vector2(80.0, 22.0), 9000, Rect2(-2.5, 30.0, 5.0, 30.0))
	# Signpost + gate road lamps
	Props.lamp_post(g, Vector3(3.2, 0, 36.0))


# ================================================================ courtyard

func _courtyard() -> void:
	var g := geo_root
	Props.well(g, Vector3(-4.0, 0, 10.0))
	Props.market_stall(g, Vector3(8.0, 0, 15.5), 180.0, Color(0.55, 0.08, 0.06), Color(0.8, 0.75, 0.6))
	Props.market_stall(g, Vector3(12.8, 0, 15.5), 180.0, Color(0.1, 0.2, 0.45), Color(0.8, 0.75, 0.6))
	Props.cart(g, Vector3(-10.0, 0, 19.0), 25.0)
	Props.cart(g, Vector3(20.5, 0, 9.0), -70.0, false)
	Props.crate_stack(g, Vector3(16.0, 0, 2.0), 10.0)
	Props.crate_stack(g, Vector3(-14.5, 0, -11.5), -15.0)
	Props.crate_stack(g, Vector3(26.5, 0, -0.5), 80.0)
	for p in [Vector3(-15.8, 0, 7.5), Vector3(-15.1, 0, 8.3), Vector3(-15.9, 0, 9.1), Vector3(5.5, 0, 17.2), Vector3(14.9, 0, 17.1)]:
		Props.barrel(g, p, Props.rng.randf() * 360.0)
	Props.barrel(g, Vector3(-3.0, 0, 11.8), 0.0, false)
	for i in 3:
		Props.sack(g, Vector3(10.5 + i * 0.6, 0, 17.4))
	Props.hay_pile(g, Vector3(-14.8, 0, 12.5), 1.5)
	Props.hay_bale(g, Vector3(-13.0, 0, 14.6), 20.0)
	Props.hay_bale(g, Vector3(-12.6, 0, 15.4), 15.0)
	Props.tree(g, Vector3(-6.0, 0, 24.0), 1.15)
	Props.tree(g, Vector3(12.0, 0, 24.5), 1.0)
	Props.tree(g, Vector3(24.0, 0, 5.0), 1.2)
	Props.tree(g, Vector3(-24.5, 0, 16.0), 1.0)
	for p in [Vector3(-27.6, 0, 13.0), Vector3(-27.4, 0, 19.5), Vector3(-25.0, 0, 26.8), Vector3(-17.0, 0, 27.6), Vector3(27.3, 0, 11.5), Vector3(9.2, 0, -11.6), Vector3(-9.8, 0, -11.4), Vector3(4.0, 0, 27.6), Vector3(-27.4, 0, -12.0)]:
		Props.bush(g, p, 1.1, true, Props.rng.randf() < 0.3)
	Props.statue(g, Vector3(-3.5, 0, -6.0), 180.0)
	Props.bench(g, Vector3(-3.5, 0, -3.8), 0.0, 2.0)
	Props.weapon_rack(g, Vector3(-17.4, 0, 4.0), 90.0)
	# Lamp posts make pools of light - with dark gaps between.
	Props.lamp_post(g, Vector3(-6.5, 0, 16.0), true)
	Props.lamp_post(g, Vector3(6.0, 0, 4.0))
	Props.lamp_post(g, Vector3(-11.0, 0, -4.0))
	Props.lamp_post(g, Vector3(17.0, 0, 13.0))
	# Archery butts
	for i in 2:
		var ab := Geo.node(g, Vector3(-24.0 + i * 3.0, 0, 23.0), Vector3(0, 180, 0))
		Geo.cyl(ab, 0.6, 0.6, 0.35, Vector3(0, 1.1, 0), Mats.hay(), Vector3(90, 0, 0))
		for k in 3:
			Geo.torus(ab, 0.15 + k * 0.15, 0.2 + k * 0.15, Vector3(0, 1.1, -0.18), Mats.flat([Color(0.6, 0.05, 0.05), Color(0.9, 0.9, 0.85), Color(0.1, 0.1, 0.1)][k], 0.8), Vector3(90, 0, 0))
		Geo.box(ab, Vector3(0.08, 1.4, 0.08), Vector3(-0.45, 0.7, 0.3), Mats.wood(), Vector3(-15, 0, 0))
		Geo.box(ab, Vector3(0.08, 1.4, 0.08), Vector3(0.45, 0.7, 0.3), Mats.wood(), Vector3(-15, 0, 0))
	# Puddles reflecting the lights
	for p in [Vector3(2.0, 0.012, 20.0), Vector3(-8.0, 0.012, 2.0), Vector3(10.0, 0.012, -4.0)]:
		Geo.cyl(g, 1.2, 1.2, 0.004, p, Mats.water(), Vector3.ZERO, Vector3(1.0, 1.0, 0.6), 20)


# ================================================================ buildings

func _gable_roof(parent: Node3D, center: Vector3, length: float, width: float, rise: float, rot_y: float, overhang := 0.6, mat: Material = null) -> Node3D:
	var r := Geo.node(parent, center, Vector3(0, rot_y, 0))
	if mat == null:
		mat = Mats.roof()
	var hw := width * 0.5 + overhang
	var ang := atan2(rise, width * 0.5)
	var slope := sqrt(hw * hw + pow(hw * tan(ang), 2.0))
	var lx := length + overhang * 2.0
	for s in [-1.0, 1.0]:
		Geo.solid_box(r, Vector3(lx, 0.22, slope), Vector3(0, rise - hw * tan(ang) * 0.5, s * hw * 0.5), mat, Vector3(s * rad_to_deg(ang), 0, 0))
		Geo.box(r, Vector3(lx, 0.12, 0.2), Vector3(0, rise - hw * tan(ang) - 0.05, s * hw), Mats.wood_dark())  # fascia
	Geo.cyl(r, 0.16, 0.16, lx, Vector3(0, rise + 0.08, 0), Mats.slate(), Vector3(0, 0, 90))  # ridge cap
	for x in [-length * 0.5, length * 0.5]:
		Geo.prism(r, Vector3(width, rise, 0.4), Vector3(x, rise * 0.5, 0), Mats.plaster(), Vector3(0, 90, 0))
		for k in 3:
			Geo.box(r, Vector3(0.45, 0.14, width * (0.9 - k * 0.28)), Vector3(x, 0.4 + k * rise * 0.28, 0), Mats.wood_dark())  # timber framing
	return r


func _window(parent: Node3D, pos: Vector3, rot_y: float, w: float, h: float, lit: bool, shutters := false) -> void:
	## Local +Z points out of the wall.
	var r := Geo.node(parent, pos, Vector3(0, rot_y, 0))
	var glass := Mats.window_glass() if lit else Mats.window_dark()
	Geo.box(r, Vector3(w, h, 0.04), Vector3(0, 0, 0.0), glass)
	Geo.cyl(r, w * 0.5, w * 0.5, 0.04, Vector3(0, h * 0.5, 0.0), glass, Vector3(90, 0, 0), Vector3.ONE, 16)
	var trim := Mats.stone_trim()
	for x in [-w * 0.5 - 0.07, w * 0.5 + 0.07]:
		Geo.box(r, Vector3(0.14, h, 0.16), Vector3(x, 0, 0.05), trim)
	Geo.torus(r, w * 0.5, w * 0.5 + 0.14, Vector3(0, h * 0.5, 0.05), trim, Vector3(90, 0, 0), Vector3(1.0, 2.0, 1.0))
	Geo.box(r, Vector3(w + 0.4, 0.1, 0.25), Vector3(0, -h * 0.5 - 0.05, 0.1), trim)  # sill
	Geo.box(r, Vector3(0.04, h + w * 0.5, 0.05), Vector3(0, w * 0.25, 0.03), Mats.iron())  # mullion
	for k in 2:
		Geo.box(r, Vector3(w, 0.03, 0.05), Vector3(0, -h * 0.5 + (k + 1) * h / 3.0, 0.03), Mats.iron())
	if shutters:
		for s in [-1.0, 1.0]:
			Geo.box(r, Vector3(w * 0.5, h, 0.04), Vector3(s * (w * 0.75 + 0.18), 0, 0.12), Mats.planks(), Vector3(0, s * 20.0, 0))


func _barracks() -> void:
	var g := geo_root
	var x0 := -29.4
	var x1 := -18.0
	var z0 := -9.0
	var z1 := 5.0
	var h := 3.6
	var t := 0.5
	var st := Mats.stone()
	# east wall with the door at z=-2
	_wall(g, Vector2(x1, z0), Vector2(x1, z1), h, t, st, [[7.0, 1.6, 2.4]], 1.0, true)
	_wall(g, Vector2(x0 + 0.1, z0), Vector2(x1 + t * 0.5, z0), h, t, st, [], 1.0, true)
	_wall(g, Vector2(x0 + 0.1, z1), Vector2(x1 + t * 0.5, z1), h, t, st, [], -1.0, true)
	Geo.box(g, Vector3(11.0, 0.025, 13.6), Vector3(-23.7, 0.006, -2.0), Mats.planks())  # floor
	Geo.solid_box(g, Vector3(11.8, 0.25, 14.4), Vector3(-23.7, h + 0.12, -2.0), Mats.wood_dark())  # ceiling
	for k in 5:
		Geo.box(g, Vector3(11.4, 0.22, 0.22), Vector3(-23.7, h - 0.1, -7.6 + k * 2.8), Mats.wood())  # beams
	_gable_roof(g, Vector3(-23.7, h + 0.24, -2.0), 14.0, 11.4, 2.6, 90.0)
	for z in [-6.0, 2.0]:
		_window(g, Vector3(x1 + t * 0.5 + 0.02, 1.9, z), 90.0, 0.7, 1.0, true, true)
		_window(g, Vector3(x1 - t * 0.5 - 0.02, 1.9, z), -90.0, 0.7, 1.0, false)
	Props.wall_torch(g, Vector3(x1 + t * 0.5 + 0.02, 2.6, -3.4), -90.0, false)
	Props.banner(g, Vector3(x1 + t * 0.5 + 0.05, 3.3, 0.0), 90.0, Color(0.45, 0.05, 0.08), 1.6)
	# interior
	var beds := [-7.6, -5.0, 0.9, 3.5]
	for i in beds.size():
		Props.bed(g, Vector3(-27.6, 0, beds[i]), -90.0, [Color(0.35, 0.1, 0.08), Color(0.15, 0.2, 0.3), Color(0.3, 0.25, 0.15), Color(0.2, 0.25, 0.15)][i])
		Props.chest(g, Vector3(-25.9, 0, beds[i] + 0.0), 90.0)
	Props.table(g, Vector3(-22.6, 0, -1.6), 0.0, Vector2(1.1, 2.4))
	Props.bench(g, Vector3(-23.6, 0, -1.6), 90.0, 2.2)
	Props.bench(g, Vector3(-21.6, 0, -1.6), 90.0, 2.2)
	Props.tableware(g, Vector3(-22.6, 0.82, -1.6), 3)
	Props.candle(g, Vector3(-22.5, 0.82, -1.0), true)
	for i in 4:
		Geo.box(g, Vector3(0.05, 0.05, 0.05), Vector3(-22.4 + i * 0.07, 0.845, -2.4), Mats.flat(Color(0.9, 0.88, 0.8), 0.4), Vector3(Props.rng.randf() * 90.0, Props.rng.randf() * 90.0, 0))  # dice
	Props.weapon_rack(g, Vector3(-22.0, 0, -8.4), 0.0)
	for p in [Vector3(-19.0, 0, -8.2), Vector3(-19.7, 0, -8.3), Vector3(-19.0, 0, 4.3)]:
		Props.barrel(g, p)
	Props.crate(g, Vector3(-19.2, 0, 3.4), 15.0, 0.8)


func _manor() -> void:
	var g := geo_root
	var st := Mats.stone()
	var h := 6.0
	var t := 0.6
	var zf := -13.0  # front (south) face line
	var zb := -29.4  # back
	# exterior walls
	_wall(g, Vector2(-13.0, zf), Vector2(13.0, zf), h, t, st, [[9.5, 2.4, 3.2]], -1.0, true)
	_wall(g, Vector2(13.0, zb), Vector2(13.0, zf), h, t, st, [[12.4, 1.6, 2.6]], 1.0, true)
	_wall(g, Vector2(-13.0, zb), Vector2(-13.0, zf), h, t, st, [], -1.0, true)
	_wall(g, Vector2(-13.0, zb + 0.3), Vector2(13.0, zb + 0.3), h, t, st, [], 1.0, true)
	# hall / study partition with doorway at z=-21
	_wall(g, Vector2(6.0, zb), Vector2(6.0, zf), h, 0.4, Mats.plaster(), [[8.4, 1.6, 2.6]], 1.0, true)
	# floors & ceiling
	Geo.box(g, Vector3(18.8, 0.03, 15.6), Vector3(-3.5, 0.01, -21.2), Mats.marble())
	Geo.box(g, Vector3(6.6, 0.03, 15.6), Vector3(9.5, 0.01, -21.2), Mats.planks())
	Geo.solid_box(g, Vector3(26.4, 0.3, 17.0), Vector3(0, h + 0.15, -21.2), Mats.wood_dark())
	for k in 8:
		Geo.box(g, Vector3(0.3, 0.35, 15.8), Vector3(-11.5 + k * 3.3, h - 0.17, -21.2), Mats.wood())
	_gable_roof(g, Vector3(0, h + 0.3, -21.2), 26.4, 16.8, 4.0, 0.0, 0.7, Mats.slate())
	# chimney above the fireplace
	Geo.solid_box(g, Vector3(1.4, 6.5, 1.4), Vector3(-12.3, h + 3.0, -21.0), Mats.stone_dark())
	Geo.box(g, Vector3(1.7, 0.25, 1.7), Vector3(-12.3, h + 6.3, -21.0), Mats.stone_trim())
	# facade details
	Geo.box(g, Vector3(26.6, 0.5, 0.75), Vector3(0, 0.25, zf), Mats.stone_dark())
	Geo.box(g, Vector3(26.8, 0.3, 0.9), Vector3(0, h - 0.1, zf), Mats.stone_trim())
	Geo.box(g, Vector3(26.8, 0.2, 0.8), Vector3(0, 3.2, zf), Mats.stone_trim())
	for x in [-13.0, 13.0]:
		for k in 8:
			Geo.box(g, Vector3(0.7 if k % 2 == 0 else 0.5, 0.7, 0.7 if k % 2 == 0 else 0.5), Vector3(x, 0.4 + k * 0.72, zf), Mats.stone_trim())  # quoins
	for x in [-10.5, -7.2, 0.5, 3.4, 9.5]:
		var lit: bool = x != 3.4
		_window(g, Vector3(x, 1.95, zf + t * 0.5 + 0.02), 0.0, 1.0, 1.6, lit)
		_window(g, Vector3(x, 4.6, zf + t * 0.5 + 0.02), 0.0, 0.8, 1.2, x < 0.0)
		_window(g, Vector3(x, 1.95, zf - t * 0.5 - 0.02), 180.0, 1.0, 1.6, false)
	for z in [-26.0, -22.5, -14.5]:
		_window(g, Vector3(13.0 + t * 0.5 + 0.02, 1.95, z), 90.0, 0.9, 1.5, z != -22.5)
		_window(g, Vector3(13.0 - t * 0.5 - 0.02, 1.95, z), -90.0, 0.9, 1.5, false)
		_window(g, Vector3(13.0 + t * 0.5 + 0.02, 4.6, z), 90.0, 0.7, 1.1, true)
	for z in [-26.0, -16.0]:
		_window(g, Vector3(-13.0 - t * 0.5 - 0.02, 1.95, z), -90.0, 0.9, 1.5, true)
		_window(g, Vector3(-13.0 + t * 0.5 + 0.02, 1.95, z), 90.0, 0.9, 1.5, false)
	# portico
	for x in [-5.6, -1.4]:
		Props.pillar(g, Vector3(x, 0, -11.6), 4.2)
	Geo.box(g, Vector3(5.4, 0.35, 2.2), Vector3(-3.5, 4.35, -11.9), Mats.stone_trim())
	Geo.prism(g, Vector3(5.6, 1.3, 2.3), Vector3(-3.5, 5.15, -11.9), Mats.stone_trim())
	Geo.sphere(g, 0.3, Vector3(-3.5, 5.0, -10.76), Mats.gold(), Vector3(1.0, 1.0, 0.25), false, 16)  # crest
	for k in 3:
		Geo.box(g, Vector3(5.0 - k * 0.4, 0.05, 1.2 - k * 0.3), Vector3(-3.5, 0.025 + k * 0.005, -11.6 - k * 0.0), Mats.stone_trim())
	# main doors swung inward
	for s in [-1.0, 1.0]:
		var leaf := Geo.node(g, Vector3(-3.5 + s * 1.15, 0, zf - 0.25), Vector3(0, s * 75.0, 0))
		Geo.box(leaf, Vector3(1.15, 3.1, 0.1), Vector3(-s * 0.58, 1.55, -0.05), Mats.wood_dark())
		for y in [0.5, 1.6, 2.7]:
			Geo.box(leaf, Vector3(1.1, 0.08, 0.13), Vector3(-s * 0.58, y, -0.05), Mats.iron())
		Geo.torus(leaf, 0.07, 0.09, Vector3(-s * 0.95, 1.4, 0.0), Mats.brass(), Vector3(90, 0, 0))
	Props.brazier(g, Vector3(-7.0, 0, -11.2), true)
	Props.brazier(g, Vector3(0.0, 0, -11.2), true)
	Props.banner(g, Vector3(-9.0, 5.6, zf + 0.42), 0.0, Color(0.45, 0.05, 0.08), 2.6)
	Props.banner(g, Vector3(2.0, 5.6, zf + 0.42), 0.0, Color(0.45, 0.05, 0.08), 2.6)
	# side door (garden) leaf
	var sd := Geo.node(g, Vector3(13.0, 0, -17.0 - 0.8), Vector3(0, 100, 0))
	Geo.box(sd, Vector3(0.1, 2.5, 1.5), Vector3(0, 1.25, 0.0), Mats.wood_dark(), Vector3(0, 90, 0))
	Props.wall_torch(g, Vector3(13.32, 2.7, -18.6), -90.0, false)

	# ---- great hall interior
	Props.rug(g, Vector3(-3.5, 0, -19.5), 0.0, Vector2(2.4, 12.6), Color(0.45, 0.04, 0.05))
	Props.rug(g, Vector3(9.5, 0, -22.0), 0.0, Vector2(4.0, 5.0), Color(0.12, 0.15, 0.35))
	# dais (two shallow steps)
	Geo.solid_box(g, Vector3(6.6, 0.08, 3.2), Vector3(-3.5, 0.04, -27.25), Mats.marble())
	Geo.solid_box(g, Vector3(5.8, 0.16, 2.6), Vector3(-3.5, 0.08, -27.55), Mats.marble())
	Props.rug(g, Vector3(-3.5, 0.16, -27.6), 0.0, Vector2(5.0, 2.2), Color(0.35, 0.03, 0.06))
	Props.throne(g, Vector3(-3.5, 0.16, -28.2), 180.0)
	Props.candelabra(g, Vector3(-6.2, 0.16, -27.9))
	Props.candelabra(g, Vector3(-0.8, 0.16, -27.9))
	Props.banner(g, Vector3(-3.5, 5.5, -28.7), 0.0, Color(0.45, 0.05, 0.08), 3.2)
	Props.banner(g, Vector3(-8.5, 5.0, -28.7), 0.0, Color(0.1, 0.1, 0.25), 2.6)
	Props.banner(g, Vector3(1.5, 5.0, -28.7), 0.0, Color(0.1, 0.1, 0.25), 2.6)
	for x in [-10.0, 3.0]:
		for z in [-16.0, -20.0, -24.0]:
			Props.pillar(g, Vector3(x, 0, z), h)
	Props.table(g, Vector3(-7.0, 0, -20.0), 0.0, Vector2(1.1, 7.0), Color(0.75, 0.7, 0.6))
	for z in [-23.0, -21.0, -19.0, -17.0]:
		Props.chair(g, Vector3(-7.85, 0, z), 90.0)
		Props.chair(g, Vector3(-6.15, 0, z), -90.0)
	Props.tableware(g, Vector3(-7.0, 0.82, -22.0), 3)
	Props.tableware(g, Vector3(-7.0, 0.82, -18.0), 3)
	Props.candle(g, Vector3(-7.0, 0.82, -20.0), true, 0.25)
	Props.fireplace(g, Vector3(-12.2, 0, -21.0), -90.0)
	Props.chandelier(g, Vector3(-3.5, 4.4, -20.5), true)
	Props.armor_stand(g, Vector3(-12.1, 0, -16.0), -90.0)
	Props.armor_stand(g, Vector3(-12.1, 0, -26.0), -90.0)
	Props.wall_torch(g, Vector3(-6.0, 2.6, zf - 0.33), 0.0, false)
	Props.wall_torch(g, Vector3(5.77, 2.6, -15.5), 90.0, false)
	Props.chest(g, Vector3(4.8, 0, -28.2), 0.0)
	# ---- study
	Props.desk(g, Vector3(9.5, 0, -24.4), 0.0)
	Props.candle(g, Vector3(8.9, 0.84, -24.1), true)
	Props.candle(g, Vector3(10.2, 0.84, -24.6), false)
	Props.bookshelf(g, Vector3(8.0, 0, -28.55), 180.0)
	Props.bookshelf(g, Vector3(11.0, 0, -28.55), 180.0)
	Props.bookshelf(g, Vector3(12.45, 0, -24.0), 90.0, 1.8)
	Props.bookshelf(g, Vector3(12.45, 0, -21.6), 90.0, 1.8)
	Props.globe(g, Vector3(7.0, 0, -15.0))
	Props.candelabra(g, Vector3(12.2, 0, -27.8))
	Props.chest(g, Vector3(12.0, 0, -14.2), -90.0)
	Props.chair(g, Vector3(10.9, 0, -26.0), 160.0)


func _garden() -> void:
	var g := geo_root
	# boundary hedges
	Props.hedge(g, Vector2(15.0, -29.4), Vector2(15.0, -19.0))
	Props.hedge(g, Vector2(15.0, -15.4), Vector2(15.0, -3.0))
	Props.hedge(g, Vector2(15.0, -3.0), Vector2(20.5, -3.0))
	Props.hedge(g, Vector2(24.5, -3.0), Vector2(29.4, -3.0))
	# inner hedges
	Props.hedge(g, Vector2(18.2, -24.8), Vector2(22.0, -24.8), 1.7, 0.8)
	Props.hedge(g, Vector2(18.2, -10.2), Vector2(21.0, -10.2), 1.7, 0.8)
	Props.hedge(g, Vector2(24.5, -10.2), Vector2(26.8, -10.2), 1.7, 0.8)
	Props.hedge(g, Vector2(27.0, -22.0), Vector2(27.0, -12.6), 1.7, 0.8)
	# gazebo
	var gz := Geo.node(g, Vector3(22.5, 0, -17.5))
	Geo.solid_box(gz, Vector3(5.0, 0.06, 5.0), Vector3(0, 0.03, 0), Mats.marble())
	Geo.cyl(gz, 2.75, 2.75, 0.06, Vector3(0, 0.03, 0), Mats.marble(), Vector3.ZERO, Vector3.ONE, 8)
	for i in 8:
		var a := i * TAU / 8.0 + PI / 8.0
		var p := Vector3(cos(a) * 2.5, 0, sin(a) * 2.5)
		Geo.cyl(gz, 0.12, 0.14, 2.9, p + Vector3(0, 1.48, 0), Mats.marble(), Vector3.ZERO, Vector3.ONE, 12)
		Geo.col_cyl(gz, 0.15, 2.9, p + Vector3(0, 1.45, 0))
		if i != 1 and i != 3:  # open toward the fountain (south) and the manor (west)
			var a2 := a + PI / 8.0
			var rp := Vector3(cos(a2) * 2.35, 0.55, sin(a2) * 2.35)
			Geo.box(gz, Vector3(1.85, 0.08, 0.08), rp, Mats.marble(), Vector3(0, -rad_to_deg(a2) + 90.0, 0))
			for k in 4:
				var bp := Vector3(cos(a2) * 2.35, 0.28, sin(a2) * 2.35) + Vector3(-sin(a2), 0, cos(a2)) * (-0.6 + k * 0.4)
				Geo.cyl(gz, 0.03, 0.04, 0.5, bp, Mats.marble(), Vector3.ZERO, Vector3.ONE, 8)
	Geo.cyl(gz, 0.0, 3.4, 1.6, Vector3(0, 3.75, 0), Mats.slate(), Vector3.ZERO, Vector3.ONE, 8)
	Geo.cyl(gz, 2.9, 2.9, 0.2, Vector3(0, 2.95, 0), Mats.marble(), Vector3.ZERO, Vector3.ONE, 8)
	Geo.sphere(gz, 0.15, Vector3(0, 4.65, 0), Mats.gold(), Vector3.ONE, false, 12)
	var hang := Geo.node(gz, Vector3(0, 2.4, 0))
	Geo.cyl(hang, 0.008, 0.008, 0.5, Vector3(0, 0.3, 0), Mats.iron())
	Geo.cyl(hang, 0.08, 0.07, 0.2, Vector3(0, 0, 0), Mats.emissive(Color(1.0, 0.7, 0.35), 1.6), Vector3.ZERO, Vector3.ONE, 6)
	Props.light(hang, Vector3(0, -0.05, 0), "lantern", 1.6, 6.5, 0.9, false)
	Props.bench(gz, Vector3(0, 0.06, -1.6), 0.0, 1.6)
	# fountain
	var fn := Geo.node(g, Vector3(22.5, 0, -6.6))
	Geo.cyl(fn, 1.8, 1.9, 0.55, Vector3(0, 0.275, 0), Mats.stone_trim(), Vector3.ZERO, Vector3.ONE, 24)
	Geo.torus(fn, 1.7, 1.95, Vector3(0, 0.56, 0), Mats.marble(), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
	Geo.cyl(fn, 1.65, 1.65, 0.02, Vector3(0, 0.45, 0), Mats.water(), Vector3.ZERO, Vector3.ONE, 24)
	Geo.cyl(fn, 0.18, 0.28, 1.4, Vector3(0, 0.9, 0), Mats.marble(), Vector3.ZERO, Vector3.ONE, 12)
	Geo.cyl(fn, 0.7, 0.2, 0.25, Vector3(0, 1.6, 0), Mats.marble(), Vector3.ZERO, Vector3.ONE, 16)
	Geo.cyl(fn, 0.62, 0.62, 0.02, Vector3(0, 1.7, 0), Mats.water(), Vector3.ZERO, Vector3.ONE, 16)
	Geo.sphere(fn, 0.14, Vector3(0, 1.85, 0), Mats.marble(), Vector3.ONE, false, 10)
	Geo.col_cyl(fn, 1.9, 0.6, Vector3(0, 0.3, 0))
	_fountain_spray(fn, Vector3(0, 1.95, 0))
	# flower beds, rose bushes, statue, benches, lamps
	Props.flower_bed(g, Vector3(19.0, 0, -28.0), Vector2(4.0, 1.4))
	Props.flower_bed(g, Vector3(25.5, 0, -28.0), Vector2(4.0, 1.4))
	Props.flower_bed(g, Vector3(19.6, 0, -7.0), Vector2(1.4, 3.0))
	for p in [Vector3(17.2, 0, -21.5), Vector3(25.0, 0, -13.0), Vector3(28.4, 0, -24.0), Vector3(16.6, 0, -8.0), Vector3(25.8, 0, -4.5)]:
		Props.bush(g, p, 1.0, true, true)
	Props.bench(g, Vector3(22.5, 0, -4.0), 180.0, 1.8)
	Props.bench(g, Vector3(25.4, 0, -6.6), 90.0, 1.8)
	Props.lamp_post(g, Vector3(20.2, 0, -3.8))
	Props.lamp_post(g, Vector3(16.2, 0, -16.0))
	Props.tree(g, Vector3(27.8, 0, -27.6), 0.9, Color(0.07, 0.12, 0.05))
	Props.grass_field(self, Vector3(22.2, 0, -16.2), Vector2(14.0, 26.0), 2600, Rect2(19.6, -20.2, 5.8, 5.8))


func _fountain_spray(parent: Node3D, pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.1
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 22.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -6.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(0.7, 0.8, 1.0, 0.5)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.06)
	var m := preload("res://scripts/fx/fx.gd").particle_material(true)
	m.albedo_color = Color(0.6, 0.7, 0.9, 0.5)
	q.material = m
	p.draw_pass_1 = q
	parent.add_child(p)


func _stable() -> void:
	var g := geo_root
	var h := 3.4
	_wall(g, Vector2(18.0, 18.0), Vector2(29.4, 18.0), h, 0.4, Mats.planks(), [], 1.0, false)
	for z in [18.2, 21.8, 25.4, 29.2]:
		Geo.solid_box(g, Vector3(0.3, h, 0.3), Vector3(18.15, h * 0.5, z), Mats.wood_dark())
	Geo.solid_box(g, Vector3(11.8, 0.3, 11.8), Vector3(23.7, h + 0.15, 23.7), Mats.planks())
	Geo.box(g, Vector3(12.2, 0.18, 12.2), Vector3(23.7, h + 0.06, 23.7), Mats.wood_dark())
	# roof parapet
	Geo.solid_box(g, Vector3(0.25, 0.5, 11.8), Vector3(17.9, h + 0.55, 23.7), Mats.wood_dark())
	Geo.solid_box(g, Vector3(11.8, 0.5, 0.25), Vector3(23.7, h + 0.55, 17.9), Mats.wood_dark())
	# stalls
	for z in [21.8, 25.4]:
		Geo.solid_box(g, Vector3(4.0, 1.4, 0.12), Vector3(27.3, 0.7, z), Mats.planks())
	for z in [20.0, 23.6, 27.3]:
		Geo.solid_box(g, Vector3(0.5, 0.5, 2.6), Vector3(29.0, 0.25, z), Mats.planks())  # troughs
		Geo.box(g, Vector3(0.4, 0.05, 2.4), Vector3(29.0, 0.45, z), Mats.water())
	Props.hay_pile(g, Vector3(26.0, 0, 20.2), 1.3)
	Props.hay_pile(g, Vector3(26.0, 0, 27.4), 1.3)
	Props.hay_bale(g, Vector3(20.0, 0, 28.4), 0.0)
	Props.hay_bale(g, Vector3(20.2, 0.55, 28.4), 10.0)
	Props.hay_bale(g, Vector3(21.6, 0, 28.5), -5.0)
	Props.cart(g, Vector3(22.5, 0, 23.0), 95.0)
	Props.barrel(g, Vector3(19.0, 0, 19.0))
	Props.wall_torch(g, Vector3(23.0, 2.5, 18.22), 180.0, false)
	Props.crate(g, Vector3(17.2, 0, 21.0), 30.0, 0.9)
	Props.crate(g, Vector3(17.0, 0.9, 21.1), 10.0, 0.7)


# ================================================================ characters

func _guard_model(tabard: Color, helmet: String, seed_i: int, extra := {}) -> Dictionary:
	var skins := [Color(0.62, 0.45, 0.35), Color(0.48, 0.33, 0.24), Color(0.7, 0.52, 0.42), Color(0.36, 0.24, 0.17)]
	var hairs := [Color(0.12, 0.08, 0.05), Color(0.3, 0.18, 0.08), Color(0.05, 0.04, 0.03), Color(0.45, 0.35, 0.2)]
	var d := {"type": "guard", "tabard": tabard, "helmet": helmet, "seed": seed_i,
		"skin": skins[seed_i % skins.size()], "hair": hairs[(seed_i * 3) % hairs.size()],
		"beard": seed_i % 2 == 0, "cloak": Color(0.08, 0.08, 0.1)}
	d.merge(extra, true)
	return d


func _add_guard(cfg: Dictionary):
	var gd := Guard.new()
	gd.setup(cfg)
	var wps: Array = cfg.get("waypoints", [])
	gd.position = wps[0] if not wps.is_empty() else Vector3.ZERO
	gd.position += cfg.get("spawn_offset", Vector3.ZERO)
	var yaws: Array = cfg.get("yaws", [])
	if not yaws.is_empty() and yaws[0] != null:
		gd.rotation.y = deg_to_rad(yaws[0])
	characters.add_child(gd)
	return gd


func _spawn_characters() -> void:
	var red := Color(0.45, 0.06, 0.06)
	var blue := Color(0.08, 0.14, 0.38)
	var INF_WAIT := 1e9
	_add_guard({"name": "Bram", "model": _guard_model(red, "kettle", 1),
		"waypoints": [Vector3(-1.9, 0, 32.2)], "waits": [INF_WAIT], "yaws": [180.0]})
	_add_guard({"name": "Hollis", "model": _guard_model(red, "nasal", 2),
		"waypoints": [Vector3(1.9, 0, 32.2)], "waits": [INF_WAIT], "yaws": [180.0]})
	_add_guard({"name": "Osric", "model": _guard_model(red, "nasal", 3), "lantern": true,
		"waypoints": [Vector3(-12, 0, 22.5), Vector3(9.5, 0, 21.5), Vector3(13.5, 0, 8.0), Vector3(-1.0, 0, 4.0), Vector3(-12.0, 0, 9.0)],
		"waits": [3.0, 2.0, 3.0, 2.0, 2.0]})
	_add_guard({"name": "Wendel", "model": _guard_model(red, "kettle", 4),
		"waypoints": [Vector3(14.0, 0, 9.0), Vector3(14.0, 0, -6.0), Vector3(1.0, 0, -9.0), Vector3(-12.5, 0, -7.5), Vector3(-12.5, 0, 4.0), Vector3(2.0, 0, 7.5)],
		"waits": [2.0, 4.0, 2.0, 3.0, 2.0, 2.0], "yaws": [null, 90.0, null, null, null, null]})
	_add_guard({"name": "Fenwick", "model": _guard_model(red, "none", 5, {"cloak": null}),
		"waypoints": [Vector3(-26.75, 0.66, -5.0)], "waits": [INF_WAIT], "yaws": [0.0],
		"asleep": true, "deep_sleep": true})
	_add_guard({"name": "Garrick", "model": _guard_model(red, "nasal", 6),
		"waypoints": [Vector3(-22.6, 0, -4.0), Vector3(-16.4, 0, -2.0), Vector3(-20.0, 0, 3.6)],
		"waits": [9.0, 7.0, 6.0], "yaws": [180.0, -90.0, 90.0]})
	_add_guard({"name": "Aldous", "model": _guard_model(blue, "plumed", 7, {"plume": Color(0.1, 0.15, 0.5)}),
		"waypoints": [Vector3(-1.6, 0, -11.0)], "waits": [INF_WAIT], "yaws": [180.0]})
	_add_guard({"name": "Merrick", "model": _guard_model(blue, "nasal", 8),
		"waypoints": [Vector3(-11.6, 0, -14.8), Vector3(-11.6, 0, -25.6), Vector3(4.6, 0, -25.6), Vector3(4.6, 0, -14.8)],
		"waits": [2.0, 3.0, 2.0, 3.0]})
	_add_guard({"name": "Tamsin", "model": _guard_model(blue, "kettle", 9), "lantern": true,
		"waypoints": [Vector3(17.3, 0, -4.9), Vector3(28.3, 0, -4.9), Vector3(28.3, 0, -26.2), Vector3(17.3, 0, -26.2), Vector3(17.3, 0, -16.5)],
		"waits": [2.0, 3.0, 3.0, 2.0, 4.0]})
	var lord = _add_guard({"name": "Lord Aldric Vane", "target": true, "walk_speed": 1.15, "health": 50.0,
		"model": {"type": "noble", "seed": 11, "robe": Color(0.28, 0.04, 0.24), "hair": Color(0.6, 0.6, 0.62)},
		"safe_point": Vector3(7.2, 0, -27.4),
		"waypoints": [Vector3(-3.5, 0.16, -27.0), Vector3(-3.5, 0, -18.5), Vector3(9.5, 0, -25.6), Vector3(12.0, 0, -17.0),
			Vector3(22.5, 0.06, -17.0), Vector3(22.5, 0, -9.4), Vector3(17.0, 0, -17.0), Vector3(5.0, 0, -21.0)],
		"waits": [16.0, 4.0, 14.0, 0.5, 15.0, 8.0, 0.5, 0.5],
		"yaws": [180.0, null, 180.0, null, 0.0, 180.0, null, null],
		"poses": ["gesture", null, "read", null, "gesture", null, null, null]})
	GameState.target = lord
	var cap = _add_guard({"name": "Captain Roderick", "model": _guard_model(blue, "plumed", 10, {"plume": Color(0.7, 0.6, 0.2), "cloak": Color(0.25, 0.04, 0.05)}),
		"waypoints": [Vector3(-1.8, 0, -25.4)], "waits": [INF_WAIT], "yaws": [180.0], "walk_speed": 1.4})
	cap.follow = lord
	cap.run_speed = 4.4
	GameState.alarm_changed.connect(_on_alarm)


var _reinforced := false


func _on_alarm(active: bool) -> void:
	## First alarm of the night: the gate garrison turns out and hunts you.
	if not active or _reinforced:
		return
	_reinforced = true
	get_tree().create_timer(6.0).timeout.connect(_send_reinforcements)


func _send_reinforcements() -> void:
	if GameState.mission_over:
		return
	GameState.notify.emit("Reinforcements pour through the gate!", 3.0)
	Sfx.play_ui("alarm_bell", -2.0)
	for i in 3:
		var gd = _add_guard({"name": "Gate Sergeant %d" % (i + 1),
			"model": _guard_model(Color(0.3, 0.05, 0.05), "kettle", 20 + i, {"cloak": Color(0.05, 0.05, 0.05)}),
			"waypoints": [Vector3(-1.5 + i * 1.5, 0, 26.0)], "waits": [8.0], "walk_speed": 1.8})
		gd.run_speed = 5.2
		var p = GameState.player
		if p:
			gd.call_deferred("investigate", p.global_position, true)
