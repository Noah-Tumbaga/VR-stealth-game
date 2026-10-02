extends RefCounted
## Small geometry helpers for assembling detailed models out of primitive meshes.
## All rotations are in degrees.

const WORLD_LAYER := 1


static func mesh(parent: Node, m: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh(parent, b, mat, pos, rot, scl)


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE, sides := 18) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return mesh(parent, c, mat, pos, rot, scl)


static func sphere(parent: Node, r: float, pos: Vector3, mat: Material, scl := Vector3.ONE, hemi := false, segs := 20, rot := Vector3.ZERO) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = segs
	s.rings = maxi(segs / 2, 4)
	return mesh(parent, s, mat, pos, rot, scl)


static func capsule(parent: Node, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.001)
	c.radial_segments = 16
	c.rings = 6
	return mesh(parent, c, mat, pos, rot, scl)


static func prism(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, apex := 0.5) -> MeshInstance3D:
	var p := PrismMesh.new()
	p.size = size
	p.left_to_right = apex
	return mesh(parent, p, mat, pos, rot)


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return mesh(parent, t, mat, pos, rot, scl)


# ---------------------------------------------------------------- collision

static func col_box(parent: Node, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = WORLD_LAYER
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation_degrees = rot
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


static func col_cyl(parent: Node, r: float, h: float, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = WORLD_LAYER
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


static func solid_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	col_box(parent, size, pos, rot)
	return box(parent, size, pos, mat, rot)


static func node(parent: Node, pos := Vector3.ZERO, rot := Vector3.ZERO, node_name := "") -> Node3D:
	var n := Node3D.new()
	if node_name != "":
		n.name = node_name
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	return n


static func seg_point_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).distance_to(p)
