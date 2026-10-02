extends RefCounted
## One-shot visual effects: blood, smoke, magic bursts, flashes.

const Mats = preload("res://scripts/util/mats.gd")

static var _soft_tex: GradientTexture2D


static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


static func particle_material(additive: bool, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func color_ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func scale_curve(a: float, b: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func burst(parent: Node, pos: Vector3, colors: Array, amount: int, lifetime: float, speed: Vector2, size: float, gravity: Vector3, additive: bool, spread := 180.0, dir := Vector3.UP, size_end := 0.2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = scale_curve(1.0, size_end)
	pm.color_ramp = color_ramp(colors)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_material(additive)
	p.draw_pass_1 = q
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	var tree := parent.get_tree()
	if tree:
		tree.create_timer(lifetime + 0.6).timeout.connect(p.queue_free)
	return p


static func blood(parent: Node, pos: Vector3, dir: Vector3) -> void:
	burst(parent, pos, [Color(0.45, 0.0, 0.0, 1.0), Color(0.25, 0.0, 0.0, 0.9), Color(0.1, 0.0, 0.0, 0.0)], 40, 0.9, Vector2(1.0, 3.5), 0.05, Vector3(0, -9.8, 0), false, 35.0, dir.normalized(), 0.6)
	burst(parent, pos, [Color(0.35, 0.0, 0.0, 0.6), Color(0.15, 0.0, 0.0, 0.0)], 10, 0.6, Vector2(0.2, 0.6), 0.16, Vector3(0, -1.0, 0), false, 60.0, dir.normalized(), 1.5)


static func smoke(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, [Color(0.3, 0.3, 0.3, 0.0), Color(0.25, 0.25, 0.25, 0.55), Color(0.2, 0.2, 0.2, 0.0)], 20, 2.2, Vector2(0.2, 0.6), 0.35, Vector3(0, 0.6, 0), false, 25.0, Vector3.UP, 2.5)


static func magic_burst(parent: Node, pos: Vector3, c: Color, radius := 1.0) -> void:
	var c0 := Color(c.r * 2.0, c.g * 2.0, c.b * 2.0, 1.0)
	burst(parent, pos, [c0, Color(c.r, c.g, c.b, 0.6), Color(c.r, c.g, c.b, 0.0)], 60, 0.9, Vector2(1.5 * radius, 4.0 * radius), 0.12, Vector3.ZERO, true, 180.0, Vector3.UP, 0.1)
	burst(parent, pos, [Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 0.35), Color(c.r, c.g, c.b, 0.0)], 14, 1.6, Vector2(0.1, 0.6), 0.7 * radius, Vector3(0, 0.3, 0), true, 180.0, Vector3.UP, 1.8)
	flash(parent, pos, c, 6.0 * radius, 4.0, 0.35)


static func flash(parent: Node, pos: Vector3, c: Color, rng: float, energy: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.omni_range = rng
	l.light_energy = energy
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


static func sleep_mist(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, [Color(0.5, 0.7, 1.0, 0.0), Color(0.5, 0.7, 1.0, 0.45), Color(0.4, 0.5, 0.9, 0.0)], 30, 2.0, Vector2(0.2, 0.9), 0.4, Vector3(0, -0.3, 0), true, 180.0, Vector3.UP, 2.0)


static func shadow_puff(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, [Color(0.05, 0.0, 0.1, 0.0), Color(0.08, 0.02, 0.15, 0.8), Color(0.0, 0.0, 0.0, 0.0)], 40, 1.0, Vector2(0.5, 2.0), 0.5, Vector3(0, 0.5, 0), false, 180.0, Vector3.UP, 1.6)
	burst(parent, pos, [Color(0.7, 0.4, 1.0, 1.0), Color(0.4, 0.1, 0.8, 0.0)], 30, 0.6, Vector2(1.0, 3.0), 0.05, Vector3.ZERO, true, 180.0)
