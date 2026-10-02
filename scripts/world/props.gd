extends RefCounted
## Detailed prop builders. Each returns a Node3D placed under `parent`.

const Mats = preload("res://scripts/util/mats.gd")
const Geo = preload("res://scripts/util/geo.gd")
const LightSource = preload("res://scripts/world/light_source.gd")
const Humanoid = preload("res://scripts/npc/humanoid.gd")

static var rng := RandomNumberGenerator.new()


static func _root(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	return Geo.node(parent, pos, Vector3(0, rot_y, 0))


static func light(parent: Node3D, pos: Vector3, kind: String, energy: float, rng_m: float, strength := 1.0, shadows := false, flame_scale := 1.0) -> Node3D:
	var l := LightSource.new().configure(kind, energy, rng_m, strength, shadows, flame_scale)
	l.position = pos
	parent.add_child(l)
	return l


# ================================================================ containers

static func barrel(parent: Node, pos: Vector3, rot_y := 0.0, lid := true) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var w := Mats.planks()
	Geo.cyl(r, 0.3, 0.33, 0.33, Vector3(0, 0.165, 0), w)
	Geo.cyl(r, 0.33, 0.33, 0.3, Vector3(0, 0.48, 0), w)
	Geo.cyl(r, 0.33, 0.3, 0.33, Vector3(0, 0.795, 0), w)
	for y in [0.06, 0.3, 0.66, 0.9]:
		Geo.cyl(r, 0.335 if y in [0.3, 0.66] else 0.315, 0.335 if y in [0.3, 0.66] else 0.315, 0.035, Vector3(0, y, 0), Mats.iron())
	if lid:
		Geo.cyl(r, 0.28, 0.28, 0.02, Vector3(0, 0.955, 0), Mats.wood_dark())
	else:
		Geo.cyl(r, 0.28, 0.28, 0.02, Vector3(0, 0.88, 0), Mats.water())
	Geo.col_cyl(r, 0.34, 0.97, Vector3(0, 0.485, 0))
	return r


static func crate(parent: Node, pos: Vector3, rot_y := 0.0, s := 0.9) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var h := s * 0.5
	Geo.box(r, Vector3(s * 0.96, s * 0.96, s * 0.96), Vector3(0, h, 0), Mats.planks())
	var fr := Mats.wood()
	var t := s * 0.08
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Geo.box(r, Vector3(t, s, t), Vector3(x * (h - t * 0.4), h, z * (h - t * 0.4)), fr)
	for y in [t * 0.5, s - t * 0.5]:
		for z in [-1.0, 1.0]:
			Geo.box(r, Vector3(s, t, t), Vector3(0, y, z * (h - t * 0.4)), fr)
		for x in [-1.0, 1.0]:
			Geo.box(r, Vector3(t, t, s), Vector3(x * (h - t * 0.4), y, 0), fr)
	for z in [-1.0, 1.0]:
		Geo.box(r, Vector3(s * 1.25, t * 0.8, t * 0.6), Vector3(0, h, z * (h + 0.005)), fr, Vector3(0, 0, 45))
	Geo.col_box(r, Vector3(s, s, s), Vector3(0, h, 0))
	return r


static func crate_stack(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _root(parent, pos, rot_y)
	crate(r, Vector3(0, 0, 0), 4.0)
	crate(r, Vector3(0.95, 0, 0.1), -7.0)
	crate(r, Vector3(0.45, 0.9, 0.05), 12.0, 0.8)
	crate(r, Vector3(-0.1, 0, 0.98), 20.0, 0.75)
	sack(r, Vector3(1.2, 0, 1.0))
	return r


static func sack(parent: Node, pos: Vector3) -> Node3D:
	var r := _root(parent, pos, rng.randf() * 360.0)
	var burlap := Mats.cloth(Color(0.42, 0.33, 0.2))
	Geo.sphere(r, 0.26, Vector3(0, 0.22, 0), burlap, Vector3(1.0, 0.9, 0.8))
	Geo.sphere(r, 0.14, Vector3(0, 0.42, 0), burlap, Vector3(1.0, 0.8, 0.9))
	Geo.cyl(r, 0.05, 0.07, 0.08, Vector3(0, 0.52, 0), burlap)
	Geo.torus(r, 0.045, 0.06, Vector3(0, 0.5, 0), Mats.cloth(Color(0.3, 0.22, 0.12)))
	return r


static func chest(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _root(parent, pos, rot_y)
	Geo.box(r, Vector3(0.9, 0.45, 0.5), Vector3(0, 0.225, 0), Mats.wood_dark())
	Geo.cyl(r, 0.25, 0.25, 0.9, Vector3(0, 0.45, 0), Mats.wood_dark(), Vector3(0, 0, 90), Vector3(1.0, 1.0, 0.45), 16)
	for x in [-0.3, 0.3]:
		Geo.box(r, Vector3(0.05, 0.47, 0.52), Vector3(x, 0.23, 0), Mats.iron())
		Geo.torus(r, 0.24, 0.27, Vector3(x, 0.45, 0), Mats.iron(), Vector3(0, 0, 90), Vector3(1.0, 1.0, 0.47))
	Geo.box(r, Vector3(0.1, 0.12, 0.03), Vector3(0, 0.4, -0.26), Mats.brass())
	Geo.col_box(r, Vector3(0.9, 0.6, 0.5), Vector3(0, 0.3, 0))
	return r


# ================================================================ farm / courtyard

static func hay_bale(parent: Node, pos: Vector3, rot_y := 0.0, hide := true) -> Node3D:
	var r := _root(parent, pos, rot_y)
	Geo.box(r, Vector3(1.2, 0.55, 0.6), Vector3(0, 0.275, 0), Mats.hay())
	for x in [-0.3, 0.3]:
		Geo.box(r, Vector3(0.03, 0.57, 0.62), Vector3(x, 0.275, 0), Mats.cloth(Color(0.3, 0.22, 0.1)))
	Geo.col_box(r, Vector3(1.2, 0.55, 0.6), Vector3(0, 0.275, 0))
	if hide:
		pass
	return r


static func hay_pile(parent: Node, pos: Vector3, radius := 1.4) -> Node3D:
	## Loose hay - no collision, crouch inside to hide.
	var r := _root(parent, pos, rng.randf() * 360.0)
	var m := Mats.hay()
	for i in 7:
		var a := i * TAU / 7.0
		var d := radius * rng.randf_range(0.2, 0.6)
		Geo.sphere(r, radius * rng.randf_range(0.45, 0.6), Vector3(cos(a) * d, 0.1, sin(a) * d), m, Vector3(1.0, 0.65, 1.0), false, 12)
	Geo.sphere(r, radius * 0.7, Vector3(0, 0.15, 0), m, Vector3(1.0, 0.8, 1.0), false, 14)
	GameState.add_hiding_zone(r.global_position if r.is_inside_tree() else pos, radius, 1.2)
	return r


static func cart(parent: Node, pos: Vector3, rot_y := 0.0, hay_load := true) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var w := Mats.planks()
	var fr := Mats.wood()
	Geo.box(r, Vector3(1.4, 0.08, 2.4), Vector3(0, 0.75, 0), w)
	for x in [-0.68, 0.68]:
		Geo.box(r, Vector3(0.06, 0.45, 2.4), Vector3(x, 1.0, 0), w)
		for z in [-1.1, -0.4, 0.4, 1.1]:
			Geo.box(r, Vector3(0.08, 0.55, 0.08), Vector3(x, 0.98, z), fr)
	Geo.box(r, Vector3(1.4, 0.45, 0.06), Vector3(0, 1.0, 1.18), w)
	Geo.box(r, Vector3(0.12, 0.12, 2.6), Vector3(0, 0.62, 0), fr)
	for x in [-1.0, 1.0]:
		var wheel := Geo.node(r, Vector3(x * 0.8, 0.55, 0.3), Vector3(0, 0, 90))
		Geo.torus(wheel, 0.46, 0.55, Vector3.ZERO, fr, Vector3.ZERO, Vector3(1.0, 1.4, 1.0))
		Geo.torus(wheel, 0.53, 0.56, Vector3.ZERO, Mats.iron(), Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
		Geo.cyl(wheel, 0.09, 0.09, 0.18, Vector3.ZERO, fr)
		for k in 6:
			Geo.box(wheel, Vector3(0.05, 0.92, 0.04), Vector3.ZERO, fr, Vector3(0, k * 30.0, 0))
		# shafts
	for x in [-0.45, 0.45]:
		Geo.box(r, Vector3(0.07, 0.07, 2.0), Vector3(x, 0.65, -2.0), fr, Vector3(-8, 0, 0))
	if hay_load:
		Geo.sphere(r, 0.9, Vector3(0, 1.05, 0.1), Mats.hay(), Vector3(0.75, 0.55, 1.3))
	Geo.col_box(r, Vector3(1.5, 1.3, 2.5), Vector3(0, 0.65, 0))
	return r


static func well(parent: Node, pos: Vector3) -> Node3D:
	var r := _root(parent, pos)
	var st := Mats.stone()
	for i in 14:
		var a := i * TAU / 14.0
		Geo.box(r, Vector3(0.42, 0.85, 0.3), Vector3(cos(a) * 0.85, 0.425, sin(a) * 0.85), st, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	Geo.torus(r, 0.72, 1.05, Vector3(0, 0.88, 0), Mats.stone_trim(), Vector3.ZERO, Vector3(1.0, 1.6, 1.0))
	Geo.cyl(r, 0.72, 0.72, 0.02, Vector3(0, 0.3, 0), Mats.water())
	for x in [-0.95, 0.95]:
		Geo.box(r, Vector3(0.14, 2.3, 0.14), Vector3(x, 1.15, 0), Mats.wood())
	Geo.cyl(r, 0.06, 0.06, 1.9, Vector3(0, 1.55, 0), Mats.wood_dark(), Vector3(0, 0, 90))
	Geo.cyl(r, 0.12, 0.12, 0.4, Vector3(0, 1.55, 0), Mats.cloth(Color(0.4, 0.33, 0.2)), Vector3(0, 0, 90))  # rope coil
	Geo.cyl(r, 0.008, 0.008, 0.6, Vector3(0, 1.22, 0), Mats.cloth(Color(0.4, 0.33, 0.2)))
	Geo.cyl(r, 0.13, 0.11, 0.22, Vector3(0, 0.84, 0), Mats.planks())  # bucket
	Geo.torus(r, 0.12, 0.135, Vector3(0, 0.9, 0), Mats.iron())
	Geo.box(r, Vector3(0.05, 0.4, 0.05), Vector3(1.1, 1.55, -0.18), Mats.iron(), Vector3(0, 0, 0))  # crank
	# little roof
	for s in [-1.0, 1.0]:
		Geo.box(r, Vector3(2.4, 0.06, 1.0), Vector3(0, 2.55, s * 0.38), Mats.roof(), Vector3(s * 35.0, 0, 0))
	Geo.col_cyl(r, 1.05, 0.95, Vector3(0, 0.475, 0))
	return r


static func market_stall(parent: Node, pos: Vector3, rot_y: float, c1: Color, c2: Color) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var fr := Mats.wood()
	for x in [-1.3, 1.3]:
		for z in [-0.7, 0.7]:
			Geo.box(r, Vector3(0.1, 2.4 if z < 0 else 2.0, 0.1), Vector3(x, (2.4 if z < 0 else 2.0) * 0.5, z), fr)
	Geo.box(r, Vector3(2.8, 0.08, 1.2), Vector3(0, 0.9, -0.05), Mats.planks())
	Geo.box(r, Vector3(2.7, 0.8, 0.05), Vector3(0, 0.45, -0.62), Mats.planks())
	# striped canopy
	for i in 8:
		var m := Mats.cloth(c1 if i % 2 == 0 else c2)
		Geo.box(r, Vector3(0.36, 0.03, 1.75), Vector3(-1.26 + i * 0.36, 2.22, 0.0), m, Vector3(-13, 0, 0))
		Geo.box(r, Vector3(0.36, 0.25, 0.02), Vector3(-1.26 + i * 0.36, 1.92, -0.86), m, Vector3(0, 0, 0))
	# goods
	var apple := Mats.glossy(Color(0.5, 0.05, 0.04))
	var pear := Mats.glossy(Color(0.5, 0.48, 0.12))
	for i in 18:
		Geo.sphere(r, 0.045, Vector3(-1.1 + (i % 6) * 0.08, 0.98 + (i / 6) * 0.05, -0.3 + (i / 6) * 0.06), apple if i % 3 else pear, Vector3.ONE, false, 8)
	Geo.box(r, Vector3(0.6, 0.12, 0.4), Vector3(-0.9, 0.98, -0.2), Mats.planks())
	for i in 4:
		Geo.capsule(r, 0.06, 0.28, Vector3(0.2 + i * 0.14, 1.0, -0.2), Mats.flat(Color(0.55, 0.36, 0.16), 0.8), Vector3(0, 0, 90))  # loaves
	for i in 3:
		var pot := Geo.node(r, Vector3(0.9 + i * 0.18, 0.94, 0.1))
		Geo.sphere(pot, 0.08, Vector3(0, 0.08, 0), Mats.flat(Color(0.45, 0.22, 0.12), 0.7), Vector3(1.0, 1.1, 1.0), false, 12)
		Geo.cyl(pot, 0.04, 0.05, 0.05, Vector3(0, 0.18, 0), Mats.flat(Color(0.45, 0.22, 0.12), 0.7))
	Geo.col_box(r, Vector3(2.8, 1.0, 1.3), Vector3(0, 0.5, -0.05))
	return r


static func bench(parent: Node, pos: Vector3, rot_y := 0.0, l := 1.8) -> Node3D:
	var r := _root(parent, pos, rot_y)
	Geo.box(r, Vector3(l, 0.06, 0.38), Vector3(0, 0.45, 0), Mats.planks())
	for x in [-l * 0.4, l * 0.4]:
		Geo.box(r, Vector3(0.07, 0.43, 0.32), Vector3(x, 0.215, 0), Mats.wood())
	Geo.col_box(r, Vector3(l, 0.48, 0.38), Vector3(0, 0.24, 0))
	return r


static func table(parent: Node, pos: Vector3, rot_y: float, size: Vector2, cloth_c = null) -> Node3D:
	var r := _root(parent, pos, rot_y)
	Geo.box(r, Vector3(size.x, 0.07, size.y), Vector3(0, 0.78, 0), Mats.planks())
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Geo.box(r, Vector3(0.08, 0.75, 0.08), Vector3(x * (size.x * 0.5 - 0.1), 0.375, z * (size.y * 0.5 - 0.1)), Mats.wood_dark())
	Geo.box(r, Vector3(size.x - 0.2, 0.06, 0.06), Vector3(0, 0.2, 0), Mats.wood_dark())
	if cloth_c != null:
		Geo.box(r, Vector3(size.x * 0.8, 0.012, size.y + 0.1), Vector3(0, 0.82, 0), Mats.cloth(cloth_c))
	Geo.col_box(r, Vector3(size.x, 0.82, size.y), Vector3(0, 0.41, 0))
	return r


static func chair(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var w := Mats.wood_dark()
	Geo.box(r, Vector3(0.46, 0.05, 0.44), Vector3(0, 0.46, 0), w)
	for x in [-0.2, 0.2]:
		for z in [-0.19, 0.19]:
			Geo.box(r, Vector3(0.045, 0.46, 0.045), Vector3(x, 0.23, z), w)
		Geo.box(r, Vector3(0.045, 0.6, 0.045), Vector3(x, 0.77, 0.19), w)
	Geo.box(r, Vector3(0.42, 0.28, 0.03), Vector3(0, 0.88, 0.2), w)
	Geo.box(r, Vector3(0.4, 0.04, 0.38), Vector3(0, 0.5, 0), Mats.velvet(Color(0.4, 0.05, 0.05)))
	return r


static func tableware(parent: Node, pos: Vector3, count := 4) -> void:
	for i in count:
		var p := pos + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.3, 0.3))
		Geo.cyl(parent, 0.11, 0.09, 0.02, p + Vector3(0, 0.01, 0), Mats.flat(Color(0.6, 0.6, 0.62), 0.3, 0.8))  # plate
		Geo.cyl(parent, 0.035, 0.03, 0.12, p + Vector3(0.16, 0.06, 0), Mats.brass())  # cup
	Geo.cyl(parent, 0.09, 0.06, 0.28, pos + Vector3(0, 0.14, 0.05), Mats.flat(Color(0.3, 0.15, 0.08), 0.5))  # jug
	Geo.sphere(parent, 0.12, pos + Vector3(-0.3, 0.06, 0.1), Mats.flat(Color(0.5, 0.32, 0.12), 0.7), Vector3(1.4, 0.6, 1.0))  # roast


static func candle(parent: Node, pos: Vector3, with_light := false, h := 0.18) -> Node3D:
	var r := _root(parent, pos)
	Geo.cyl(r, 0.06, 0.07, 0.02, Vector3(0, 0.01, 0), Mats.brass())
	Geo.cyl(r, 0.022, 0.024, h, Vector3(0, h * 0.5 + 0.02, 0), Mats.wax())
	Geo.sphere(r, 0.026, Vector3(0, h * 0.75, 0.0), Mats.wax(), Vector3(1.0, 0.4, 1.0), false, 8)  # drip
	var fl := Geo.node(r, Vector3(0, h + 0.03, 0))
	if with_light:
		var l := LightSource.new().configure("candle", 0.6, 3.5, 0.45, false)
		fl.add_child(l)
	else:
		Geo.sphere(fl, 0.012, Vector3(0, 0.012, 0), Mats.emissive(Color(1.0, 0.75, 0.35), 6.0), Vector3(0.7, 1.8, 0.7), false, 8)
	return r


static func bed(parent: Node, pos: Vector3, rot_y := 0.0, blanket := Color(0.35, 0.1, 0.08)) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var w := Mats.wood_dark()
	Geo.box(r, Vector3(1.0, 0.3, 2.1), Vector3(0, 0.3, 0), w)
	Geo.box(r, Vector3(1.05, 0.9, 0.08), Vector3(0, 0.45, 1.06), w)
	Geo.box(r, Vector3(1.05, 0.55, 0.08), Vector3(0, 0.28, -1.06), w)
	Geo.box(r, Vector3(0.92, 0.16, 2.0), Vector3(0, 0.52, 0), Mats.cloth(Color(0.6, 0.55, 0.45)))
	Geo.box(r, Vector3(0.95, 0.06, 1.3), Vector3(0, 0.62, -0.32), Mats.cloth(blanket), Vector3(0, 0, 0))
	Geo.box(r, Vector3(0.02, 0.3, 1.3), Vector3(0.47, 0.48, -0.32), Mats.cloth(blanket))
	Geo.capsule(r, 0.1, 0.6, Vector3(0, 0.66, 0.8), Mats.cloth(Color(0.75, 0.72, 0.65)), Vector3(0, 0, 90), Vector3(1.0, 0.7, 1.0))
	Geo.col_box(r, Vector3(1.0, 0.65, 2.1), Vector3(0, 0.325, 0))
	return r


static func bookshelf(parent: Node, pos: Vector3, rot_y := 0.0, w := 1.6) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var wd := Mats.wood_dark()
	Geo.box(r, Vector3(w, 2.4, 0.04), Vector3(0, 1.2, 0.2), wd)
	for x in [-w * 0.5, w * 0.5]:
		Geo.box(r, Vector3(0.05, 2.4, 0.42), Vector3(x, 1.2, 0), wd)
	for i in 6:
		var y := 0.05 + i * 0.46
		Geo.box(r, Vector3(w, 0.04, 0.42), Vector3(0, y, 0), wd)
		if i == 5:
			continue
		var x := -w * 0.5 + 0.06
		while x < w * 0.5 - 0.08:
			var bw := rng.randf_range(0.035, 0.07)
			var bh := rng.randf_range(0.26, 0.38)
			var lean := 0.0 if rng.randf() > 0.12 else rng.randf_range(-14.0, 14.0)
			Geo.box(r, Vector3(bw, bh, rng.randf_range(0.22, 0.3)), Vector3(x + bw * 0.5, y + 0.02 + bh * 0.5, -0.02), Mats.book(rng.randi()), Vector3(0, 0, lean))
			x += bw + 0.004
			if rng.randf() < 0.05:
				x += 0.12
	Geo.box(r, Vector3(w + 0.1, 0.08, 0.48), Vector3(0, 2.44, 0), wd)
	Geo.col_box(r, Vector3(w, 2.45, 0.45), Vector3(0, 1.22, 0))
	return r


static func desk(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var wd := Mats.wood_dark()
	Geo.box(r, Vector3(1.8, 0.07, 0.9), Vector3(0, 0.8, 0), wd)
	for x in [-0.65, 0.65]:
		Geo.box(r, Vector3(0.45, 0.76, 0.85), Vector3(x, 0.38, 0), wd)
		for k in 3:
			Geo.box(r, Vector3(0.4, 0.2, 0.02), Vector3(x, 0.15 + k * 0.24, -0.43), Mats.wood())
			Geo.sphere(r, 0.015, Vector3(x, 0.15 + k * 0.24, -0.45), Mats.brass(), Vector3.ONE, false, 8)
	Geo.box(r, Vector3(0.6, 0.004, 0.42), Vector3(0.1, 0.837, 0.05), Mats.flat(Color(0.75, 0.68, 0.5), 0.9), Vector3(0, 8, 0))  # map
	Geo.box(r, Vector3(0.28, 0.06, 0.2), Vector3(-0.55, 0.865, 0.1), Mats.book(2), Vector3(0, -20, 0))
	Geo.box(r, Vector3(0.26, 0.05, 0.19), Vector3(-0.56, 0.92, 0.11), Mats.book(4), Vector3(0, -12, 0))
	Geo.cyl(r, 0.035, 0.03, 0.06, Vector3(0.55, 0.86, -0.15), Mats.glossy(Color(0.02, 0.02, 0.03)))  # inkwell
	Geo.capsule(r, 0.006, 0.22, Vector3(0.58, 0.95, -0.12), Mats.cloth(Color(0.9, 0.9, 0.85)), Vector3(20, 0, -25))  # quill
	Geo.col_box(r, Vector3(1.8, 0.85, 0.9), Vector3(0, 0.425, 0))
	return r


static func globe(parent: Node, pos: Vector3) -> Node3D:
	var r := _root(parent, pos)
	Geo.cyl(r, 0.05, 0.22, 0.05, Vector3(0, 0.025, 0), Mats.wood_dark())
	Geo.cyl(r, 0.03, 0.04, 0.75, Vector3(0, 0.4, 0), Mats.wood_dark())
	Geo.torus(r, 0.3, 0.32, Vector3(0, 1.05, 0), Mats.brass(), Vector3(90, 0, 23))
	var gm := Mats._cached("globe", func():
		var m := StandardMaterial3D.new()
		m.albedo_texture = Mats._tex(Mats._noise(0.01, 6, FastNoiseLite.TYPE_SIMPLEX, 777), [Color(0.1, 0.18, 0.28), Color(0.12, 0.2, 0.3), Color(0.5, 0.45, 0.3), Color(0.35, 0.4, 0.2)], 256)
		m.roughness = 0.4
		return m)
	Geo.sphere(r, 0.27, Vector3(0, 1.05, 0), gm)
	Geo.col_cyl(r, 0.25, 1.3, Vector3(0, 0.65, 0))
	return r


static func weapon_rack(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var w := Mats.wood()
	for x in [-0.8, 0.8]:
		Geo.box(r, Vector3(0.08, 1.6, 0.3), Vector3(x, 0.8, 0), w)
	Geo.box(r, Vector3(1.7, 0.08, 0.3), Vector3(0, 0.15, 0), w)
	Geo.box(r, Vector3(1.7, 0.08, 0.08), Vector3(0, 1.35, 0.05), w)
	for i in 5:
		var x := -0.6 + i * 0.3
		Geo.cyl(r, 0.018, 0.018, 1.9, Vector3(x, 1.05, 0.05), Mats.wood_dark(), Vector3(0, 0, 3))
		Geo.prism(r, Vector3(0.06, 0.2, 0.012), Vector3(x + 0.05, 2.08, 0.05), Mats.steel(), Vector3(0, 0, 3))
	Geo.cyl(r, 0.28, 0.28, 0.03, Vector3(0, 0.75, 0.2), Mats.wood(), Vector3(90, 0, 0))  # shield
	Geo.sphere(r, 0.06, Vector3(0, 0.75, 0.23), Mats.iron(), Vector3(1, 1, 0.5), false, 10)
	Geo.col_box(r, Vector3(1.7, 1.6, 0.35), Vector3(0, 0.8, 0))
	return r


static func banner(parent: Node, pos: Vector3, rot_y: float, c: Color, h := 2.6) -> Node3D:
	var r := _root(parent, pos, rot_y)
	Geo.cyl(r, 0.025, 0.025, 1.0, Vector3(0, 0, 0), Mats.wood_dark(), Vector3(0, 0, 90))
	for x in [-0.5, 0.5]:
		Geo.sphere(r, 0.04, Vector3(x, 0, 0), Mats.gold(), Vector3.ONE, false, 8)
	Geo.box(r, Vector3(0.85, h, 0.02), Vector3(0, -h * 0.5, 0.0), Mats.velvet(c))
	Geo.prism(r, Vector3(0.85, 0.35, 0.02), Vector3(0, -h - 0.175, 0), Mats.velvet(c), Vector3(0, 0, 180))
	Geo.box(r, Vector3(0.87, 0.05, 0.025), Vector3(0, -0.05, 0), Mats.gold())
	# heraldry: gold chevron + emblem
	Geo.prism(r, Vector3(0.6, 0.3, 0.025), Vector3(0, -h * 0.35, 0), Mats.gold())
	Geo.sphere(r, 0.12, Vector3(0, -h * 0.6, 0), Mats.gold(), Vector3(1, 1, 0.15), false, 12)
	Geo.sphere(r, 0.07, Vector3(0, -h * 0.6, -0.01), Mats.velvet(c.darkened(0.4)), Vector3(1, 1, 0.15), false, 12)
	return r


static func rug(parent: Node, pos: Vector3, rot_y: float, size: Vector2, c: Color) -> Node3D:
	var r := _root(parent, pos, rot_y)
	Geo.box(r, Vector3(size.x, 0.01, size.y), Vector3(0, 0.017, 0), Mats.carpet(c))
	Geo.box(r, Vector3(size.x - 0.4, 0.012, size.y - 0.4), Vector3(0, 0.018, 0), Mats.carpet(c.darkened(0.3)))
	Geo.box(r, Vector3(size.x - 0.6, 0.014, size.y - 0.6), Vector3(0, 0.019, 0), Mats.carpet(c))
	for z in [-size.y * 0.5, size.y * 0.5]:
		Geo.box(r, Vector3(size.x, 0.008, 0.06), Vector3(0, 0.016, z + signf(z) * 0.03), Mats.cloth(Color(0.8, 0.7, 0.45)))
	return r


static func pillar(parent: Node, pos: Vector3, h: float) -> Node3D:
	var r := _root(parent, pos)
	var m := Mats.stone_trim()
	Geo.box(r, Vector3(0.75, 0.25, 0.75), Vector3(0, 0.125, 0), m)
	Geo.cyl(r, 0.32, 0.34, 0.12, Vector3(0, 0.31, 0), m, Vector3.ZERO, Vector3.ONE, 20)
	Geo.cyl(r, 0.25, 0.28, h - 0.8, Vector3(0, h * 0.5, 0), m, Vector3.ZERO, Vector3.ONE, 20)
	for i in 10:
		var a := i * TAU / 10.0
		Geo.box(r, Vector3(0.04, h - 0.9, 0.04), Vector3(cos(a) * 0.255, h * 0.5, sin(a) * 0.255), Mats.stone(), Vector3(0, -rad_to_deg(a), 0))  # flutes
	Geo.cyl(r, 0.36, 0.27, 0.22, Vector3(0, h - 0.29, 0), m, Vector3.ZERO, Vector3.ONE, 20)
	Geo.box(r, Vector3(0.8, 0.18, 0.8), Vector3(0, h - 0.09, 0), m)
	Geo.col_cyl(r, 0.34, h, Vector3(0, h * 0.5, 0))
	return r


static func chandelier(parent: Node, pos: Vector3, shadows := true) -> Node3D:
	var r := _root(parent, pos)
	var iron := Mats.iron()
	for i in 3:
		var a := i * TAU / 3.0
		Geo.cyl(r, 0.008, 0.008, 1.6, Vector3(cos(a) * 0.35, 0.75, sin(a) * 0.35), iron, Vector3(rad_to_deg(sin(a)) * -0.2, 0, rad_to_deg(cos(a)) * 0.2))
	Geo.torus(r, 0.85, 0.92, Vector3.ZERO, iron)
	Geo.torus(r, 0.4, 0.45, Vector3(0, -0.15, 0), iron)
	Geo.cyl(r, 0.05, 0.02, 0.5, Vector3(0, -0.1, 0), iron)
	for i in 10:
		var a := i * TAU / 10.0
		candle(r, Vector3(cos(a) * 0.885, 0.0, sin(a) * 0.885), false, 0.14)
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		candle(r, Vector3(cos(a) * 0.425, -0.15, sin(a) * 0.425), false, 0.12)
	light(r, Vector3(0, 0.05, 0), "chandelier", 3.2, 11.0, 1.0, shadows)
	return r


static func fireplace(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var st := Mats.stone_trim()
	var sd := Mats.stone_dark()
	Geo.solid_box(r, Vector3(0.5, 1.6, 0.9), Vector3(-1.05, 0.8, 0), st)
	Geo.solid_box(r, Vector3(0.5, 1.6, 0.9), Vector3(1.05, 0.8, 0), st)
	Geo.box(r, Vector3(2.8, 0.25, 1.05), Vector3(0, 1.7, 0.05), st)  # mantel
	Geo.box(r, Vector3(2.2, 1.6, 0.8), Vector3(0, 2.6, 0.15), st)
	Geo.box(r, Vector3(1.7, 1.45, 0.05), Vector3(0, 0.75, 0.42), sd)  # back
	Geo.box(r, Vector3(2.6, 0.1, 1.3), Vector3(0, 0.05, -0.1), sd)  # hearth
	for i in 3:
		Geo.cyl(r, 0.07, 0.08, 0.9, Vector3(-0.1 + i * 0.1, 0.17 + (0.1 if i == 1 else 0.0), 0.05), Mats.bark(), Vector3(0, i * 40.0 - 40.0, 90))
	Geo.sphere(r, 0.35, Vector3(0, 0.1, 0.05), Mats.emissive(Color(1.0, 0.25, 0.05), 3.0), Vector3(1.6, 0.3, 0.8))  # embers
	light(r, Vector3(0, 0.3, -0.05), "fireplace", 3.0, 9.0, 1.1, true, 2.2)
	# candlesticks on mantel
	candle(r, Vector3(-0.9, 1.83, 0.0))
	candle(r, Vector3(0.9, 1.83, 0.0))
	Geo.col_box(r, Vector3(2.8, 0.2, 1.05), Vector3(0, 1.7, 0.05))
	return r


static func throne(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var wd := Mats.wood_dark()
	var gold := Mats.gold()
	var vel := Mats.velvet(Color(0.45, 0.04, 0.06))
	Geo.box(r, Vector3(1.0, 0.5, 0.8), Vector3(0, 0.25, 0), wd)
	Geo.box(r, Vector3(0.85, 0.1, 0.7), Vector3(0, 0.55, -0.02), vel)
	Geo.box(r, Vector3(1.0, 2.0, 0.15), Vector3(0, 1.0, 0.4), wd)
	Geo.box(r, Vector3(0.75, 1.3, 0.04), Vector3(0, 1.2, 0.31), vel)
	Geo.prism(r, Vector3(1.0, 0.4, 0.15), Vector3(0, 2.2, 0.4), wd)
	Geo.sphere(r, 0.08, Vector3(0, 2.45, 0.4), gold, Vector3.ONE, false, 12)
	for x in [-0.5, 0.5]:
		Geo.box(r, Vector3(0.1, 0.4, 0.75), Vector3(x, 0.8, 0.0), wd)
		Geo.sphere(r, 0.07, Vector3(x, 1.03, -0.36), gold, Vector3.ONE, false, 12)
		Geo.sphere(r, 0.07, Vector3(x, 2.02, 0.4), gold, Vector3.ONE, false, 12)
	Geo.col_box(r, Vector3(1.0, 1.0, 0.8), Vector3(0, 0.5, 0))
	return r


static func armor_stand(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var r := _root(parent, pos, rot_y)
	Geo.box(r, Vector3(0.8, 0.2, 0.8), Vector3(0, 0.1, 0), Mats.stone_trim())
	var h := Humanoid.new()
	h.build({"type": "guard", "tabard": Color(0.1, 0.1, 0.12), "helmet": "plumed", "plume": Color(0.1, 0.1, 0.1), "seed": 99})
	h.position = Vector3(0, 0.2, 0)
	r.add_child(h)
	h.frozen = true
	h.sh_r.rotation_degrees = Vector3(20, 0, 10)
	h.el_r.rotation_degrees = Vector3(70, 0, 0)
	for c in h.head.get_children():
		if c is MeshInstance3D and c.position.z < -0.05 and c.position.y < 0.2:
			c.visible = false  # empty helm: no face inside
	Geo.col_box(r, Vector3(0.7, 2.0, 0.7), Vector3(0, 1.0, 0))
	return r


static func candelabra(parent: Node, pos: Vector3) -> Node3D:
	var r := _root(parent, pos)
	var iron := Mats.iron()
	Geo.cyl(r, 0.06, 0.2, 0.08, Vector3(0, 0.04, 0), iron)
	Geo.cyl(r, 0.025, 0.03, 1.5, Vector3(0, 0.8, 0), iron)
	Geo.sphere(r, 0.05, Vector3(0, 0.6, 0), Mats.brass(), Vector3.ONE, false, 10)
	Geo.box(r, Vector3(0.6, 0.03, 0.03), Vector3(0, 1.5, 0), iron)
	for x in [-0.28, 0.0, 0.28]:
		candle(r, Vector3(x, 1.52 + (0.08 if x == 0.0 else 0.0), 0), false, 0.2)
	light(r, Vector3(0, 1.85, 0), "candle", 1.4, 6.0, 0.8, false)
	Geo.col_cyl(r, 0.2, 1.6, Vector3(0, 0.8, 0))
	return r


static func lamp_post(parent: Node, pos: Vector3, shadows := false) -> Node3D:
	var r := _root(parent, pos)
	var iron := Mats.iron()
	Geo.cyl(r, 0.14, 0.18, 0.3, Vector3(0, 0.15, 0), Mats.stone_trim())
	Geo.cyl(r, 0.05, 0.06, 2.8, Vector3(0, 1.6, 0), iron)
	Geo.box(r, Vector3(0.5, 0.05, 0.05), Vector3(0.2, 2.9, 0), iron)
	var lan := Geo.node(r, Vector3(0.42, 2.65, 0))
	Geo.cyl(lan, 0.0, 0.13, 0.12, Vector3(0, 0.2, 0), iron)
	Geo.cyl(lan, 0.1, 0.1, 0.03, Vector3(0, 0.13, 0), iron)
	Geo.cyl(lan, 0.09, 0.07, 0.24, Vector3(0, 0.0, 0), Mats.emissive(Color(1.0, 0.7, 0.35), 1.6), Vector3.ZERO, Vector3.ONE, 6)
	for i in 6:
		var a := i * TAU / 6.0
		Geo.box(lan, Vector3(0.012, 0.26, 0.012), Vector3(cos(a) * 0.09, 0.0, sin(a) * 0.09), iron)
	Geo.cyl(lan, 0.08, 0.08, 0.03, Vector3(0, -0.13, 0), iron)
	light(lan, Vector3(0, -0.05, 0), "lantern", 2.4, 9.0, 1.0, shadows)
	Geo.col_cyl(r, 0.15, 3.0, Vector3(0, 1.5, 0))
	return r


static func wall_torch(parent: Node, pos: Vector3, rot_y: float, shadows := false) -> Node3D:
	## Mounted on a wall; the torch leans out along local -Z.
	var r := _root(parent, pos, rot_y)
	var iron := Mats.iron()
	Geo.box(r, Vector3(0.12, 0.25, 0.03), Vector3(0, 0, 0), iron)
	Geo.box(r, Vector3(0.03, 0.03, 0.22), Vector3(0, -0.05, -0.11), iron)
	Geo.torus(r, 0.035, 0.05, Vector3(0, -0.02, -0.2), iron)
	Geo.cyl(r, 0.03, 0.022, 0.5, Vector3(0, 0.05, -0.24), Mats.wood_dark(), Vector3(-18, 0, 0))
	Geo.cyl(r, 0.045, 0.035, 0.12, Vector3(0, 0.28, -0.31), Mats.cloth(Color(0.15, 0.1, 0.05)), Vector3(-18, 0, 0))
	light(r, Vector3(0, 0.38, -0.34), "torch", 2.6, 8.0, 1.0, shadows)
	return r


static func brazier(parent: Node, pos: Vector3, shadows := false) -> Node3D:
	var r := _root(parent, pos)
	var iron := Mats.iron()
	for i in 3:
		var a := i * TAU / 3.0
		Geo.cyl(r, 0.025, 0.03, 1.1, Vector3(cos(a) * 0.2, 0.5, sin(a) * 0.2), iron, Vector3(rad_to_deg(sin(a)) * -0.25, 0, rad_to_deg(cos(a)) * 0.25))
	Geo.cyl(r, 0.4, 0.22, 0.25, Vector3(0, 1.05, 0), iron)
	Geo.torus(r, 0.38, 0.43, Vector3(0, 1.17, 0), iron)
	Geo.sphere(r, 0.32, Vector3(0, 1.12, 0), Mats.emissive(Color(1.0, 0.3, 0.06), 2.5), Vector3(1.0, 0.25, 1.0), false, 12)
	light(r, Vector3(0, 1.25, 0), "brazier", 3.4, 10.0, 1.15, shadows, 2.0)
	Geo.col_cyl(r, 0.4, 1.2, Vector3(0, 0.6, 0))
	return r


# ================================================================ nature

static func tree(parent: Node, pos: Vector3, s := 1.0, tint := Color(0.06, 0.12, 0.05)) -> Node3D:
	var r := _root(parent, pos, rng.randf() * 360.0)
	var b := Mats.bark()
	var h := 3.4 * s
	Geo.cyl(r, 0.16 * s, 0.3 * s, h, Vector3(0, h * 0.5, 0), b, Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), Vector3.ONE, 12)
	for i in 4:
		var a := i * TAU / 4.0 + rng.randf() * 0.5
		Geo.cyl(r, 0.04 * s, 0.14 * s, 0.7 * s, Vector3(cos(a) * 0.28 * s, 0.12 * s, sin(a) * 0.28 * s), b, Vector3(sin(a) * 60.0, 0, -cos(a) * 60.0), Vector3.ONE, 8)  # roots
	for i in 4:
		var a := i * TAU / 4.0 + rng.randf()
		var y := h * rng.randf_range(0.6, 0.85)
		Geo.cyl(r, 0.03 * s, 0.09 * s, 1.6 * s, Vector3(cos(a) * 0.5 * s, y + 0.4 * s, sin(a) * 0.5 * s), b, Vector3(sin(a) * 50.0, 0, -cos(a) * 50.0), Vector3.ONE, 8)
	var lv := Mats.leaves(tint)
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.3, 1.5) * s
		Geo.sphere(r, rng.randf_range(0.9, 1.4) * s, Vector3(cos(a) * d, h + rng.randf_range(-0.3, 1.2) * s, sin(a) * d), lv, Vector3(1.0, rng.randf_range(0.7, 0.95), 1.0), false, 10)
	Geo.col_cyl(r, 0.3 * s, h, Vector3(0, h * 0.5, 0))
	return r


static func pine(parent: Node, pos: Vector3, s := 1.0) -> Node3D:
	var r := _root(parent, pos, rng.randf() * 360.0)
	var h := 7.0 * s
	Geo.cyl(r, 0.08 * s, 0.32 * s, h, Vector3(0, h * 0.5, 0), Mats.bark(), Vector3.ZERO, Vector3.ONE, 10)
	var lv := Mats.leaves(Color(0.03, 0.08, 0.05))
	for i in 6:
		var t := float(i) / 6.0
		var rad := lerpf(2.0, 0.5, t) * s
		Geo.cyl(r, 0.0, rad, 2.0 * s, Vector3(0, h * 0.28 + t * h * 0.68 + 0.6 * s, 0), lv, Vector3(rng.randf_range(-3, 3), rng.randf() * 90.0, rng.randf_range(-3, 3)), Vector3.ONE, 9)
	Geo.col_cyl(r, 0.32 * s, h * 0.6, Vector3(0, h * 0.3, 0))
	return r


static func bush(parent: Node, pos: Vector3, s := 1.0, hide := true, flowers := false) -> Node3D:
	var r := _root(parent, pos, rng.randf() * 360.0)
	var lv := Mats.leaves(Color(0.05, 0.1, 0.04))
	for i in 6:
		var a := i * TAU / 6.0 + rng.randf() * 0.4
		var d := rng.randf_range(0.2, 0.55) * s
		Geo.sphere(r, rng.randf_range(0.45, 0.65) * s, Vector3(cos(a) * d, 0.45 * s, sin(a) * d), lv, Vector3(1.0, 0.85, 1.0), false, 10)
	Geo.sphere(r, 0.7 * s, Vector3(0, 0.6 * s, 0), lv, Vector3(1.0, 0.9, 1.0), false, 12)
	if flowers:
		var fc: Color = [Color(0.6, 0.05, 0.1), Color(0.7, 0.6, 0.75), Color(0.75, 0.7, 0.3)][rng.randi() % 3]
		var fm := Mats.flat(fc, 0.6)
		for i in 16:
			var a := rng.randf() * TAU
			var y := rng.randf_range(0.5, 1.15) * s
			Geo.sphere(r, 0.045, Vector3(cos(a) * 0.68 * s, y, sin(a) * 0.68 * s), fm, Vector3.ONE, false, 6)
	if hide:
		GameState.add_hiding_zone(r.global_position if r.is_inside_tree() else pos, 0.95 * s, 1.25 * s)
	return r


static func rock(parent: Node, pos: Vector3, s := 1.0) -> Node3D:
	var r := _root(parent, pos, rng.randf() * 360.0)
	var m := Mats.rock()
	Geo.sphere(r, 0.7 * s, Vector3(0, 0.25 * s, 0), m, Vector3(1.3, 0.75, 1.0), false, 7, Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)))
	Geo.sphere(r, 0.45 * s, Vector3(0.5 * s, 0.15 * s, 0.3 * s), m, Vector3(1.0, 0.8, 1.1), false, 6)
	Geo.col_box(r, Vector3(1.4 * s, 0.8 * s, 1.1 * s), Vector3(0, 0.3 * s, 0))
	return r


static func hedge(parent: Node, a: Vector2, b: Vector2, h := 2.1, thick := 0.9) -> Node3D:
	var center := (a + b) * 0.5
	var d := b - a
	var r := _root(parent, Vector3(center.x, 0, center.y), -rad_to_deg(atan2(d.y, d.x)))
	var lv := Mats.leaves(Color(0.04, 0.1, 0.035))
	var length := d.length()
	Geo.box(r, Vector3(length, h, thick), Vector3(0, h * 0.5, 0), lv)
	var n := int(length / 0.8)
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n
		Geo.sphere(r, thick * 0.6, Vector3(x, h - 0.05, 0), lv, Vector3(1.0, 0.5, 1.0), false, 8)
	Geo.col_box(r, Vector3(length, h, thick), Vector3(0, h * 0.5, 0))
	return r


static func flower_bed(parent: Node, pos: Vector3, size: Vector2) -> Node3D:
	var r := _root(parent, pos)
	Geo.box(r, Vector3(size.x, 0.2, size.y), Vector3(0, 0.1, 0), Mats.stone_trim())
	Geo.box(r, Vector3(size.x - 0.15, 0.06, size.y - 0.15), Vector3(0, 0.2, 0), Mats.dirt())
	var cols := [Color(0.7, 0.08, 0.12), Color(0.85, 0.75, 0.2), Color(0.6, 0.35, 0.8), Color(0.9, 0.9, 0.95)]
	for i in int(size.x * size.y * 10.0):
		var p := Vector3(rng.randf_range(-size.x * 0.45, size.x * 0.45), 0.25, rng.randf_range(-size.y * 0.45, size.y * 0.45))
		Geo.cyl(r, 0.006, 0.006, 0.18, p + Vector3(0, 0.05, 0), Mats.leaves(Color(0.08, 0.2, 0.06)), Vector3.ZERO, Vector3.ONE, 4)
		Geo.sphere(r, 0.04, p + Vector3(0, 0.15, 0), Mats.flat(cols[rng.randi() % cols.size()], 0.6), Vector3(1, 0.6, 1), false, 6)
	Geo.col_box(r, Vector3(size.x, 0.2, size.y), Vector3(0, 0.1, 0))
	return r


static func grass_field(parent: Node, center: Vector3, size: Vector2, count: int, exclude: Rect2 = Rect2()) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var blade := PrismMesh.new()
	blade.size = Vector3(0.06, 0.38, 0.01)
	mm.mesh = blade
	var xforms: Array = []
	for i in count:
		var p := Vector3(rng.randf_range(-size.x, size.x) * 0.5, 0, rng.randf_range(-size.y, size.y) * 0.5)
		var wp := Vector2(center.x + p.x, center.z + p.z)
		if exclude.size != Vector2.ZERO and exclude.has_point(wp):
			continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * rng.randf_range(0.6, 1.5)), center + p + Vector3(0, 0.15, 0))
		xforms.append(t)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, Color(0.06, 0.12, 0.04).lerp(Color(0.16, 0.18, 0.07), rng.randf()))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.backlight_enabled = true
	m.backlight = Color(0.05, 0.1, 0.03)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func rubble(parent: Node, pos: Vector3, spread: float, n: int) -> void:
	var st := Mats.stone()
	for i in n:
		var p := pos + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread * 0.6, spread * 0.6))
		var s := rng.randf_range(0.15, 0.45)
		Geo.box(parent, Vector3(s * 1.4, s, s), p + Vector3(0, s * 0.4, 0), st, Vector3(rng.randf_range(-25, 25), rng.randf() * 180.0, rng.randf_range(-25, 25)))


static func statue(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var r := _root(parent, pos, rot_y)
	var m := Mats.marble()
	Geo.box(r, Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0), Mats.stone_trim())
	Geo.box(r, Vector3(1.35, 0.12, 1.35), Vector3(0, 1.06, 0), Mats.stone_trim())
	var h := Humanoid.new()
	h.build({"type": "noble", "seed": 7})
	h.position = Vector3(0, 1.12, 0)
	h.scale = Vector3.ONE * 1.25
	r.add_child(h)
	h.frozen = true
	h.sh_r.rotation_degrees = Vector3(120, 0, 15)
	h.el_r.rotation_degrees = Vector3(20, 0, 0)
	for c in h.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = m
	Geo.col_box(r, Vector3(1.2, 3.4, 1.2), Vector3(0, 1.7, 0))
	return r
