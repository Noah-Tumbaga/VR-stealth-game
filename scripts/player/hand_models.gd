extends RefCounted
## Builds the player's gloved hands: a curved assassin's dagger in the right,
## a rune-etched casting gauntlet with spell orb, wrist display and light gem
## in the left. Built around the OpenXR grip pose (-Z forward through the fist).

const Mats = preload("res://scripts/util/mats.gd")
const Geo = preload("res://scripts/util/geo.gd")


static func _glove(root: Node3D, side: float, mat: Material, open_hand: bool) -> void:
	var stitch := Mats.leather()
	# palm / back of hand
	Geo.box(root, Vector3(0.085, 0.032, 0.095), Vector3(side * 0.012, 0.0, 0.005), mat, Vector3(0, 0, side * 70.0))
	Geo.box(root, Vector3(0.05, 0.02, 0.06), Vector3(side * 0.035, 0.018, 0.02), stitch, Vector3(0, 0, side * 70.0))  # back plate
	# fingers
	for i in 4:
		var z := -0.035 + i * 0.022
		var flen: float = [0.07, 0.078, 0.074, 0.06][i]
		if open_hand:
			Geo.capsule(root, 0.0095, flen, Vector3(side * -0.005, 0.03, z - 0.0), mat, Vector3(0, 0, side * 20.0))
		else:
			# wrapped around the grip: proximal + distal segments
			Geo.capsule(root, 0.01, 0.045, Vector3(side * -0.02, 0.018, z), mat, Vector3(0, 0, side * 70.0))
			Geo.capsule(root, 0.0095, 0.04, Vector3(side * -0.03, -0.012, z), mat, Vector3(0, 0, side * -10.0))
			Geo.sphere(root, 0.011, Vector3(side * -0.008, 0.03, z), stitch, Vector3.ONE, false, 8)  # knuckle
	# thumb
	Geo.capsule(root, 0.012, 0.06, Vector3(side * -0.018, 0.0, -0.045), mat, Vector3(-60, side * 30.0, side * 40.0))
	# bracer
	Geo.cyl(root, 0.038, 0.034, 0.14, Vector3(side * 0.01, 0.0, 0.11), mat, Vector3(90, 0, 0))
	for k in 3:
		Geo.cyl(root, 0.04, 0.04, 0.012, Vector3(side * 0.01, 0.0, 0.07 + k * 0.035), stitch, Vector3(90, 0, 0))
	Geo.sphere(root, 0.006, Vector3(side * 0.01, 0.04, 0.09), Mats.brass(), Vector3.ONE, false, 8)


static func build_right_hand() -> Node3D:
	var root := Node3D.new()
	root.name = "RightHandRig"
	var glove := Mats.leather_dark()
	var visual := Geo.node(root, Vector3.ZERO, Vector3.ZERO, "Visual")
	_glove(visual, 1.0, glove, false)
	# Dagger: grip through the fist along Z, blade forward (-Z).
	var d := Geo.node(visual, Vector3(-0.012, 0.0, 0.0), Vector3.ZERO, "Dagger")
	Geo.cyl(d, 0.014, 0.015, 0.11, Vector3(0, 0, 0.0), Mats.leather(), Vector3(90, 0, 0))
	for k in 5:
		Geo.torus(d, 0.013, 0.017, Vector3(0, 0, -0.045 + k * 0.022), Mats.leather_dark(), Vector3(90, 0, 0))  # wrap
	Geo.sphere(d, 0.02, Vector3(0, 0, 0.07), Mats.blackened_steel(), Vector3(1, 1, 1.3), false, 12)  # pommel
	Geo.sphere(d, 0.008, Vector3(0, 0, 0.092), Mats.glossy(Color(0.4, 0.1, 0.7)), Vector3.ONE, false, 8)  # amethyst
	Geo.box(d, Vector3(0.1, 0.016, 0.02), Vector3(0, 0, -0.065), Mats.blackened_steel())  # crossguard
	for x in [-1.0, 1.0]:
		Geo.sphere(d, 0.011, Vector3(x * 0.05, 0, -0.068), Mats.blackened_steel(), Vector3.ONE, false, 8)
	var bl := Mats.blade()
	Geo.box(d, Vector3(0.034, 0.006, 0.2), Vector3(0, 0, -0.17), bl)
	Geo.box(d, Vector3(0.008, 0.008, 0.16), Vector3(0, 0, -0.15), Mats.blackened_steel())  # spine ridge
	Geo.prism(d, Vector3(0.034, 0.075, 0.006), Vector3(0, 0, -0.307), bl, Vector3(-90, 0, 0))
	var base := Geo.node(root, Vector3(-0.012, 0, -0.08), Vector3.ZERO, "BladeBase")
	var tip := Geo.node(root, Vector3(-0.012, 0, -0.34), Vector3.ZERO, "BladeTip")
	base.name = "BladeBase"
	tip.name = "BladeTip"
	return root


static func build_left_hand() -> Node3D:
	var root := Node3D.new()
	root.name = "LeftHandRig"
	var glove := Mats.leather_dark()
	var visual := Geo.node(root, Vector3.ZERO, Vector3.ZERO, "Visual")
	_glove(visual, -1.0, glove, true)
	# Rune ring around the palm.
	var rune := Mats.emissive(Color(0.55, 0.3, 1.0), 2.5)
	Geo.torus(visual, 0.03, 0.034, Vector3(0.02, 0.0, 0.0), rune, Vector3(0, 0, 90))
	# Spell orb hovering above the palm.
	var orb_root := Geo.node(root, Vector3(0.0, 0.07, -0.06), Vector3.ZERO, "OrbRoot")
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.6, 0.4, 1.0)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.6, 0.4, 1.0)
	orb_mat.emission_energy_multiplier = 3.0
	var orb := Geo.sphere(orb_root, 0.022, Vector3.ZERO, orb_mat, Vector3.ONE, false, 16)
	orb.name = "Orb"
	var halo_mat := Mats.glow(Color(0.6, 0.4, 1.0, 0.18), 0.8)
	var halo := Geo.sphere(orb_root, 0.04, Vector3.ZERO, halo_mat, Vector3.ONE, false, 12)
	halo.name = "Halo"
	var ring := Geo.torus(orb_root, 0.036, 0.04, Vector3.ZERO, rune, Vector3(70, 0, 0))
	ring.name = "Ring"
	# Wrist display (spell, mana, health) on top of the forearm.
	var wrist := Geo.node(root, Vector3(0.005, 0.045, 0.12), Vector3(-55, 0, 0), "Wrist")
	Geo.box(wrist, Vector3(0.09, 0.004, 0.06), Vector3(0, -0.003, 0), Mats.blackened_steel())
	var lbl := Label3D.new()
	lbl.name = "Label"
	lbl.font_size = 40
	lbl.outline_size = 8
	lbl.pixel_size = 0.00042
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.position = Vector3(0, 0.002, -0.012)
	lbl.text = "Blinding Hex"
	lbl.modulate = Color(0.85, 0.75, 1.0)
	wrist.add_child(lbl)
	var mana_bg := Geo.box(wrist, Vector3(0.08, 0.002, 0.007), Vector3(0, 0.001, 0.012), Mats.flat(Color(0.05, 0.05, 0.1)))
	mana_bg.name = "ManaBg"
	var mana := Geo.box(wrist, Vector3(0.08, 0.003, 0.006), Vector3(0, 0.002, 0.012), Mats.emissive(Color(0.35, 0.45, 1.0), 2.0))
	mana.name = "Mana"
	var hp := Geo.box(wrist, Vector3(0.08, 0.003, 0.006), Vector3(0, 0.002, 0.022), Mats.emissive(Color(0.9, 0.15, 0.1), 1.8))
	hp.name = "Health"
	# Light gem: glows as you become visible.
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.1, 0.1, 0.1)
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(1.0, 0.85, 0.5)
	gem_mat.emission_energy_multiplier = 0.2
	gem_mat.roughness = 0.1
	var gem := Geo.sphere(wrist, 0.012, Vector3(0.052, 0.008, 0.0), gem_mat, Vector3(1.0, 1.4, 1.0), false, 4)
	gem.name = "Gem"
	Geo.torus(wrist, 0.012, 0.016, Vector3(0.052, 0.002, 0.0), Mats.brass())
	return root
