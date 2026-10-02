extends Node3D
## Procedurally built, procedurally animated humanoid.
## Faces -Z. Origin at the feet. Built from ~70 PBR primitive parts:
## armour plates, chainmail, tabard with heraldry, helmet, face (eyes, brows,
## nose, ears, beard), gloves, boots, cloak, sword - or a noble's robe, fur
## mantle, gold chain and feathered hat.

const Mats = preload("res://scripts/util/mats.gd")
const Geo = preload("res://scripts/util/geo.gd")

var cfg: Dictionary = {}
var body: Node3D
var hips: Node3D
var spine: Node3D
var neck: Node3D
var head: Node3D
var sh_l: Node3D
var sh_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var kn_l: Node3D
var kn_r: Node3D
var ft_l: Node3D
var ft_r: Node3D
var cloak: Node3D
var sword: Node3D
var joints: Dictionary = {}

# animation inputs
var speed := 0.0
var pose := "idle"  # idle, alert, blind, cower, read, gesture, panic
var head_yaw := 0.0
var head_pitch := 0.0
var attack_p := -1.0
var carry_lantern := false
var fall_mode := ""  # "", dead_fwd, dead_back, sleep
var frozen := false  # statues

var _phase := 0.0
var _t := 0.0
var _fall := 0.0
var _hips_base := 0.95
var _seed := 0.0


func build(p_cfg: Dictionary) -> void:
	cfg = p_cfg
	_seed = float(cfg.get("seed", 0)) * 1.37
	body = Geo.node(self, Vector3.ZERO, Vector3.ZERO, "Body")
	hips = Geo.node(body, Vector3(0, _hips_base, 0), Vector3.ZERO, "Hips")
	spine = Geo.node(hips, Vector3(0, 0.1, 0), Vector3.ZERO, "Spine")
	neck = Geo.node(spine, Vector3(0, 0.55, 0), Vector3.ZERO, "Neck")
	head = Geo.node(neck, Vector3(0, 0.08, 0), Vector3.ZERO, "Head")
	sh_l = Geo.node(spine, Vector3(-0.215, 0.47, 0), Vector3.ZERO, "ShoulderL")
	sh_r = Geo.node(spine, Vector3(0.215, 0.47, 0), Vector3.ZERO, "ShoulderR")
	el_l = Geo.node(sh_l, Vector3(0, -0.29, 0))
	el_r = Geo.node(sh_r, Vector3(0, -0.29, 0))
	hand_l = Geo.node(el_l, Vector3(0, -0.27, 0))
	hand_r = Geo.node(el_r, Vector3(0, -0.27, 0))
	hip_l = Geo.node(hips, Vector3(-0.1, -0.05, 0))
	hip_r = Geo.node(hips, Vector3(0.1, -0.05, 0))
	kn_l = Geo.node(hip_l, Vector3(0, -0.44, 0))
	kn_r = Geo.node(hip_r, Vector3(0, -0.44, 0))
	ft_l = Geo.node(kn_l, Vector3(0, -0.41, 0))
	ft_r = Geo.node(kn_r, Vector3(0, -0.41, 0))
	joints = {"spine": spine, "neck": neck, "head": head, "sh_l": sh_l, "sh_r": sh_r, "el_l": el_l, "el_r": el_r,
		"hip_l": hip_l, "hip_r": hip_r, "kn_l": kn_l, "kn_r": kn_r, "ft_l": ft_l, "ft_r": ft_r, "hand_l": hand_l, "hand_r": hand_r}

	if cfg.get("type", "guard") == "noble":
		_build_noble()
	else:
		_build_guard()


# ================================================================ construction

func _build_face(skin: Material, hair_c: Color, beard: bool, old := false) -> void:
	var hair := Mats.hair(hair_c)
	var eye_w := Mats.flat(Color(0.85, 0.83, 0.78), 0.2)
	var iris := Mats.glossy(Color(0.12, 0.08, 0.04) if not old else Color(0.15, 0.2, 0.25))
	var lips := Mats.flat(Color(0.42, 0.2, 0.18), 0.5)
	Geo.cyl(neck, 0.055, 0.062, 0.13, Vector3(0, 0.03, 0), skin)
	Geo.sphere(head, 0.105, Vector3(0, 0.105, 0), skin, Vector3(0.9, 1.1, 0.98))  # cranium
	Geo.sphere(head, 0.085, Vector3(0, 0.05, -0.022), skin, Vector3(0.94, 0.85, 1.0))  # jaw
	Geo.sphere(head, 0.03, Vector3(0, 0.022, -0.075), skin, Vector3(1.2, 0.9, 0.9))  # chin
	for s in [-1.0, 1.0]:
		Geo.sphere(head, 0.026, Vector3(s * 0.05, 0.085, -0.075), skin, Vector3(1.1, 0.8, 0.8))  # cheekbones
		Geo.sphere(head, 0.017, Vector3(s * 0.036, 0.122, -0.083), eye_w, Vector3(1.15, 0.85, 0.7), false, 10)
		Geo.sphere(head, 0.008, Vector3(s * 0.036, 0.122, -0.094), iris, Vector3.ONE, false, 8)
		Geo.box(head, Vector3(0.04, 0.009, 0.014), Vector3(s * 0.037, 0.142, -0.092), hair, Vector3(0, 0, -s * (14.0 if old else 6.0)))  # brow
		Geo.box(head, Vector3(0.036, 0.012, 0.01), Vector3(s * 0.037, 0.133, -0.093), skin)  # eyelid ridge
		Geo.sphere(head, 0.024, Vector3(s * 0.096, 0.1, 0.005), skin, Vector3(0.45, 1.0, 0.75), false, 10)  # ear
	Geo.box(head, Vector3(0.024, 0.052, 0.026), Vector3(0, 0.1, -0.098), skin, Vector3(-18, 0, 0))  # nose bridge
	Geo.sphere(head, 0.017, Vector3(0, 0.077, -0.108), skin, Vector3(1.2, 0.9, 1.0), false, 10)  # nose tip
	Geo.box(head, Vector3(0.042, 0.008, 0.012), Vector3(0, 0.05, -0.093), lips)
	if beard:
		Geo.sphere(head, 0.078, Vector3(0, 0.035, -0.04), hair, Vector3(1.02, 1.05, 0.85))
		Geo.box(head, Vector3(0.07, 0.014, 0.018), Vector3(0, 0.062, -0.095), hair, Vector3(0, 0, 0))  # moustache
	if not cfg.get("helmet", "nasal" if cfg.get("type", "guard") != "noble" else "none") in ["nasal", "kettle", "plumed", "great"]:
		Geo.sphere(head, 0.108, Vector3(0, 0.12, 0.012), hair, Vector3(0.94, 1.0, 1.02), true)


func _build_guard() -> void:
	var steel := Mats.steel()
	var chain := Mats.chainmail()
	var lea := Mats.leather()
	var lea_d := Mats.leather_dark()
	var gold := Mats.gold()
	var tab := Mats.cloth(cfg.get("tabard", Color(0.45, 0.06, 0.05)))
	var pants := Mats.cloth(cfg.get("pants", Color(0.14, 0.12, 0.1)))
	var skin := Mats.skin(cfg.get("skin", Color(0.62, 0.45, 0.35)))
	var sole := Mats.flat(Color(0.04, 0.03, 0.02), 0.9)

	# ---- legs
	for side in [-1.0, 1.0]:
		var hip: Node3D = hip_l if side < 0 else hip_r
		var kn: Node3D = kn_l if side < 0 else kn_r
		var ft: Node3D = ft_l if side < 0 else ft_r
		Geo.capsule(hip, 0.088, 0.47, Vector3(0, -0.22, 0), pants)
		Geo.capsule(hip, 0.092, 0.26, Vector3(0, -0.1, -0.01), chain)  # mail chausses upper
		Geo.capsule(kn, 0.068, 0.44, Vector3(0, -0.2, 0), pants)
		Geo.cyl(kn, 0.084, 0.072, 0.3, Vector3(0, -0.24, 0.0), lea_d)  # tall boot shaft
		Geo.cyl(kn, 0.088, 0.088, 0.035, Vector3(0, -0.1, 0.0), lea_d)  # boot cuff
		Geo.box(kn, Vector3(0.07, 0.24, 0.02), Vector3(0, -0.2, -0.075), steel, Vector3(-4, 0, 0))  # greave
		Geo.sphere(kn, 0.07, Vector3(0, 0.0, -0.035), steel, Vector3(1.0, 1.0, 0.75), false, 12)  # knee cop
		Geo.box(ft, Vector3(0.11, 0.09, 0.22), Vector3(0, -0.005, -0.045), lea_d)
		Geo.sphere(ft, 0.056, Vector3(0, -0.012, -0.15), lea_d, Vector3(1.0, 0.75, 1.3), false, 12)
		Geo.box(ft, Vector3(0.118, 0.022, 0.27), Vector3(0, -0.052, -0.06), sole)

	# ---- pelvis & belt
	Geo.capsule(hips, 0.15, 0.38, Vector3(0, 0.0, 0), pants, Vector3(0, 0, 90), Vector3(1, 1, 0.75))
	Geo.cyl(hips, 0.175, 0.205, 0.32, Vector3(0, -0.12, 0), chain, Vector3.ZERO, Vector3(1.0, 1.0, 0.82))  # mail skirt
	Geo.cyl(hips, 0.172, 0.172, 0.055, Vector3(0, 0.075, 0), lea, Vector3.ZERO, Vector3(1.0, 1.0, 0.8))  # belt
	Geo.box(hips, Vector3(0.06, 0.05, 0.02), Vector3(0, 0.075, -0.14), gold)
	Geo.box(hips, Vector3(0.03, 0.03, 0.022), Vector3(0, 0.075, -0.141), lea_d)
	Geo.box(hips, Vector3(0.08, 0.09, 0.045), Vector3(0.13, 0.01, -0.09), lea, Vector3(0, -30, 0))  # pouch
	Geo.box(hips, Vector3(0.08, 0.025, 0.05), Vector3(0.13, 0.06, -0.09), lea_d, Vector3(0, -30, 0))  # pouch flap
	Geo.cyl(hips, 0.024, 0.018, 0.78, Vector3(-0.2, -0.27, 0.06), lea_d, Vector3(16, 0, 7))  # scabbard
	Geo.cyl(hips, 0.026, 0.026, 0.04, Vector3(-0.19, 0.08, 0.03), steel, Vector3(16, 0, 7))  # scabbard throat
	# tabard skirt panels
	Geo.box(hips, Vector3(0.28, 0.46, 0.02), Vector3(0, -0.18, -0.148), tab, Vector3(-5, 0, 0))
	Geo.box(hips, Vector3(0.28, 0.46, 0.02), Vector3(0, -0.18, 0.14), tab, Vector3(5, 0, 0))
	Geo.box(hips, Vector3(0.282, 0.03, 0.022), Vector3(0, -0.4, -0.168), gold, Vector3(-5, 0, 0))

	# ---- torso
	Geo.capsule(spine, 0.17, 0.62, Vector3(0, 0.26, 0), chain, Vector3.ZERO, Vector3(1.12, 1.0, 0.8))
	Geo.capsule(spine, 0.165, 0.42, Vector3(0, 0.33, -0.012), steel, Vector3.ZERO, Vector3(1.1, 1.0, 0.82))  # breastplate
	Geo.box(spine, Vector3(0.3, 0.52, 0.02), Vector3(0, 0.22, -0.158), tab, Vector3(4, 0, 0))  # tabard front
	Geo.box(spine, Vector3(0.3, 0.52, 0.02), Vector3(0, 0.24, 0.15), tab, Vector3(-3, 0, 0))  # tabard back
	for s in [-1.0, 1.0]:
		Geo.box(spine, Vector3(0.018, 0.52, 0.022), Vector3(s * 0.15, 0.22, -0.16), gold, Vector3(4, 0, 0))  # gold trim
	# heraldic shield emblem
	Geo.box(spine, Vector3(0.11, 0.08, 0.012), Vector3(0, 0.31, -0.172), Mats.flat(cfg.get("emblem", Color(0.9, 0.75, 0.3)), 0.35, 0.6), Vector3(4, 0, 0))
	Geo.prism(spine, Vector3(0.11, 0.07, 0.012), Vector3(0, 0.236, -0.167), Mats.flat(cfg.get("emblem", Color(0.9, 0.75, 0.3)), 0.35, 0.6), Vector3(4, 0, 180))
	Geo.sphere(spine, 0.022, Vector3(0, 0.29, -0.181), Mats.flat(Color(0.08, 0.05, 0.05), 0.4), Vector3(1, 1, 0.4), false, 10)
	# baldric across chest
	Geo.box(spine, Vector3(0.05, 0.62, 0.015), Vector3(0, 0.25, -0.172), lea, Vector3(4, 0, 35))
	Geo.cyl(spine, 0.085, 0.13, 0.09, Vector3(0, 0.52, 0), steel)  # gorget
	for s in [-1.0, 1.0]:
		Geo.sphere(spine, 0.115, Vector3(s * 0.205, 0.46, 0), steel, Vector3(1.15, 0.85, 1.1), true, 16, Vector3(0, 0, -s * 18.0))  # pauldron
		Geo.sphere(spine, 0.12, Vector3(s * 0.21, 0.41, 0), steel, Vector3(1.05, 0.5, 1.05), true, 16, Vector3(0, 0, -s * 30.0))  # lame
		Geo.sphere(spine, 0.012, Vector3(s * 0.22, 0.52, -0.06), gold, Vector3.ONE, false, 8)  # rivet

	# ---- cloak
	if cfg.get("cloak") != null:
		cloak = Geo.node(spine, Vector3(0, 0.5, 0.16), Vector3(6, 0, 0))
		var cm := Mats.cloth(cfg.cloak)
		Geo.box(cloak, Vector3(0.46, 1.08, 0.025), Vector3(0, -0.54, 0), cm)
		Geo.box(cloak, Vector3(0.5, 0.08, 0.04), Vector3(0, -0.02, -0.01), cm)
		for s in [-1.0, 1.0]:
			Geo.sphere(spine, 0.022, Vector3(s * 0.15, 0.5, -0.12), gold, Vector3.ONE, false, 10)

	# ---- head
	_build_face(skin, cfg.get("hair", Color(0.15, 0.1, 0.06)), cfg.get("beard", false))
	match cfg.get("helmet", "nasal"):
		"nasal", "plumed":
			Geo.sphere(head, 0.118, Vector3(0, 0.128, 0.004), steel, Vector3(0.96, 1.08, 1.04), true)
			Geo.cyl(head, 0.119, 0.119, 0.03, Vector3(0, 0.135, 0.004), Mats.iron(), Vector3.ZERO, Vector3(0.97, 1.0, 1.05))
			Geo.box(head, Vector3(0.022, 0.085, 0.012), Vector3(0, 0.1, -0.12), steel, Vector3(-6, 0, 0))
			Geo.cyl(head, 0.002, 0.016, 0.05, Vector3(0, 0.262, 0.004), steel)
			Geo.cyl(head, 0.12, 0.135, 0.11, Vector3(0, 0.045, 0.035), chain, Vector3(-8, 0, 0), Vector3(1.0, 1.0, 0.75))  # aventail (back)
			if cfg.get("helmet") == "plumed":
				var plume := Mats.cloth(cfg.get("plume", Color(0.7, 0.05, 0.05)))
				for i in 5:
					Geo.capsule(head, 0.02, 0.2, Vector3(0, 0.29 - i * 0.012, 0.03 + i * 0.03), plume, Vector3(55 + i * 12, 0, 0))
		"kettle":
			Geo.sphere(head, 0.118, Vector3(0, 0.128, 0.004), steel, Vector3(0.96, 1.1, 1.04), true)
			Geo.cyl(head, 0.19, 0.2, 0.014, Vector3(0, 0.14, 0.004), steel, Vector3(-4, 0, 0))
			Geo.torus(head, 0.185, 0.205, Vector3(0, 0.138, 0.004), Mats.iron(), Vector3(-4, 0, 0))

	# ---- arms
	for side in [-1.0, 1.0]:
		var sh: Node3D = sh_l if side < 0 else sh_r
		var el: Node3D = el_l if side < 0 else el_r
		var hd: Node3D = hand_l if side < 0 else hand_r
		Geo.capsule(sh, 0.062, 0.32, Vector3(0, -0.14, 0), chain)
		Geo.cyl(sh, 0.07, 0.066, 0.13, Vector3(0, -0.2, 0), steel)  # rerebrace
		Geo.sphere(el, 0.058, Vector3(0, 0, -0.01), steel, Vector3(1, 1, 1.15), false, 12)  # couter
		Geo.capsule(el, 0.052, 0.27, Vector3(0, -0.12, 0), lea)
		Geo.cyl(el, 0.062, 0.054, 0.16, Vector3(0, -0.15, 0), lea_d)  # bracer
		for k in 3:
			Geo.cyl(el, 0.064, 0.064, 0.012, Vector3(0, -0.1 - k * 0.045, 0), lea, Vector3.ZERO, Vector3.ONE, 12)  # straps
		_build_glove(hd, side, lea_d)

	# ---- sword in right hand
	sword = Geo.node(hand_r, Vector3(0, -0.075, -0.005), Vector3(-28, 0, 0), "Sword")
	_build_sword(sword)


func _build_glove(hd: Node3D, side: float, mat: Material) -> void:
	Geo.box(hd, Vector3(0.065, 0.085, 0.034), Vector3(0, -0.04, 0), mat)
	Geo.cyl(hd, 0.05, 0.045, 0.06, Vector3(0, 0.0, 0), mat, Vector3.ZERO, Vector3(1.0, 1.0, 0.7))  # cuff
	Geo.box(hd, Vector3(0.064, 0.04, 0.05), Vector3(0, -0.095, -0.012), mat)  # curled fingers
	for k in 4:
		Geo.sphere(hd, 0.012, Vector3(-0.024 + k * 0.016, -0.082, -0.032), mat, Vector3.ONE, false, 8)  # knuckles
	Geo.capsule(hd, 0.013, 0.06, Vector3(-side * 0.036, -0.06, -0.022), mat, Vector3(-30, 0, side * 25))  # thumb


func _build_sword(s: Node3D) -> void:
	var steel := Mats.blade()
	Geo.cyl(s, 0.016, 0.017, 0.13, Vector3(0, 0, 0.0), Mats.leather_dark(), Vector3(90, 0, 0))
	Geo.sphere(s, 0.026, Vector3(0, 0, 0.08), Mats.brass(), Vector3(1, 1, 0.8), false, 12)
	Geo.box(s, Vector3(0.21, 0.024, 0.026), Vector3(0, 0, -0.072), Mats.brass())
	for x in [-1.0, 1.0]:
		Geo.sphere(s, 0.017, Vector3(x * 0.105, 0, -0.072), Mats.brass(), Vector3.ONE, false, 8)
	Geo.box(s, Vector3(0.046, 0.008, 0.74), Vector3(0, 0, -0.45), steel)
	Geo.box(s, Vector3(0.012, 0.01, 0.56), Vector3(0, 0, -0.38), Mats.flat(Color(0.35, 0.36, 0.4), 0.2, 1.0))  # fuller
	Geo.prism(s, Vector3(0.046, 0.11, 0.008), Vector3(0, 0, -0.875), steel, Vector3(-90, 0, 0))


func _build_noble() -> void:
	var robe := Mats.velvet(cfg.get("robe", Color(0.25, 0.04, 0.22)))
	var robe2 := Mats.cloth(cfg.get("robe2", Color(0.5, 0.35, 0.12)))
	var gold := Mats.gold()
	var fur := Mats.fur()
	var skin := Mats.skin(cfg.get("skin", Color(0.72, 0.5, 0.42)))
	var shoe := Mats.leather_dark()
	var hose := Mats.cloth(Color(0.12, 0.08, 0.1))
	for side in [-1.0, 1.0]:
		var hip: Node3D = hip_l if side < 0 else hip_r
		var kn: Node3D = kn_l if side < 0 else kn_r
		var ft: Node3D = ft_l if side < 0 else ft_r
		Geo.capsule(hip, 0.09, 0.47, Vector3(0, -0.22, 0), hose)
		Geo.capsule(kn, 0.065, 0.44, Vector3(0, -0.2, 0), hose)
		Geo.box(ft, Vector3(0.1, 0.08, 0.22), Vector3(0, -0.01, -0.05), shoe)
		Geo.sphere(ft, 0.05, Vector3(0, -0.02, -0.16), shoe, Vector3(1.0, 0.7, 1.6), false, 10)
		Geo.box(ft, Vector3(0.05, 0.03, 0.03), Vector3(0, 0.03, -0.12), gold)  # buckle
	# long robe (hangs from hips; legs move inside)
	Geo.cyl(hips, 0.21, 0.36, 0.95, Vector3(0, -0.4, 0), robe, Vector3.ZERO, Vector3(1.0, 1.0, 0.9), 24)
	Geo.cyl(hips, 0.365, 0.365, 0.05, Vector3(0, -0.86, 0), gold, Vector3.ZERO, Vector3(1.0, 1.0, 0.9), 24)  # hem trim
	Geo.box(hips, Vector3(0.1, 0.92, 0.02), Vector3(0, -0.4, -0.27), robe2, Vector3(-9, 0, 0))  # front panel
	Geo.box(hips, Vector3(0.11, 0.92, 0.012), Vector3(0, -0.4, -0.273), gold, Vector3(-9, 0, 0), Vector3(1.15, 1.0, 0.5))
	Geo.cyl(hips, 0.22, 0.22, 0.07, Vector3(0, 0.07, 0), robe2, Vector3.ZERO, Vector3(1, 1, 0.92))  # sash
	Geo.box(hips, Vector3(0.07, 0.3, 0.02), Vector3(0.12, -0.08, -0.19), robe2, Vector3(-6, 0, 8))  # sash tail
	Geo.box(hips, Vector3(0.07, 0.09, 0.05), Vector3(-0.17, -0.02, -0.12), Mats.leather(), Vector3(0, 30, 0))  # coin purse
	# torso with paunch
	Geo.capsule(spine, 0.19, 0.6, Vector3(0, 0.24, 0), robe, Vector3.ZERO, Vector3(1.15, 1.0, 0.95))
	Geo.sphere(spine, 0.2, Vector3(0, 0.1, -0.06), robe, Vector3(1.05, 0.95, 1.0))
	for k in 5:
		Geo.sphere(spine, 0.013, Vector3(0, 0.42 - k * 0.075, -0.215 + absf(k - 2) * 0.012), gold, Vector3.ONE, false, 8)  # buttons
	Geo.torus(spine, 0.1, 0.25, Vector3(0, 0.5, 0.0), fur, Vector3(0, 0, 0), Vector3(1.0, 1.7, 0.95))  # fur mantle
	Geo.torus(spine, 0.13, 0.142, Vector3(0, 0.42, -0.1), gold, Vector3(62, 0, 0), Vector3(1.0, 1.0, 1.3))  # chain of office
	Geo.cyl(spine, 0.045, 0.045, 0.012, Vector3(0, 0.26, -0.2), gold, Vector3(80, 0, 0))  # medallion
	Geo.sphere(spine, 0.018, Vector3(0, 0.26, -0.208), Mats.glossy(Color(0.5, 0.0, 0.05)), Vector3(1, 1, 0.5), false, 10)
	# fur-lined cape
	cloak = Geo.node(spine, Vector3(0, 0.5, 0.18), Vector3(5, 0, 0))
	Geo.box(cloak, Vector3(0.56, 1.35, 0.03), Vector3(0, -0.66, 0), robe)
	Geo.box(cloak, Vector3(0.58, 1.35, 0.01), Vector3(0, -0.66, -0.02), fur, Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
	Geo.box(cloak, Vector3(0.6, 0.05, 0.04), Vector3(0, -1.33, 0), gold)
	# head
	_build_face(skin, cfg.get("hair", Color(0.55, 0.55, 0.55)), true, true)
	var hat := Mats.velvet(cfg.get("hat", Color(0.08, 0.05, 0.12)))
	Geo.cyl(head, 0.13, 0.118, 0.08, Vector3(0, 0.215, 0.0), hat, Vector3(-6, 0, 0))
	Geo.sphere(head, 0.13, Vector3(0, 0.265, 0.01), hat, Vector3(1.05, 0.45, 1.05))
	Geo.torus(head, 0.115, 0.135, Vector3(0, 0.185, 0.0), gold, Vector3(-6, 0, 0))
	Geo.sphere(head, 0.018, Vector3(0.0, 0.21, -0.13), Mats.glossy(Color(0.1, 0.3, 0.8)), Vector3(1, 1, 0.5), false, 10)
	var feather := Mats.cloth(Color(0.85, 0.82, 0.75))
	Geo.capsule(head, 0.016, 0.32, Vector3(0.1, 0.33, 0.06), feather, Vector3(-30, 0, -28), Vector3(1.0, 1.0, 0.35))
	# arms in wide sleeves
	for side in [-1.0, 1.0]:
		var sh: Node3D = sh_l if side < 0 else sh_r
		var el: Node3D = el_l if side < 0 else el_r
		var hd: Node3D = hand_l if side < 0 else hand_r
		Geo.sphere(sh, 0.085, Vector3(0, -0.02, 0), robe, Vector3(1.1, 1.0, 1.1), false, 12)
		Geo.cyl(sh, 0.07, 0.085, 0.32, Vector3(0, -0.15, 0), robe)
		Geo.cyl(el, 0.08, 0.115, 0.26, Vector3(0, -0.12, 0), robe)
		Geo.torus(el, 0.08, 0.125, Vector3(0, -0.24, 0), fur)
		Geo.box(hd, Vector3(0.06, 0.08, 0.032), Vector3(0, -0.04, 0), skin)
		Geo.box(hd, Vector3(0.06, 0.04, 0.045), Vector3(0, -0.09, -0.01), skin)
		Geo.capsule(hd, 0.012, 0.055, Vector3(-side * 0.034, -0.06, -0.02), skin, Vector3(-30, 0, side * 25))
		Geo.torus(hd, 0.008, 0.013, Vector3(side * 0.02, -0.09, -0.01), gold, Vector3(0, 0, 90))  # ring
	# goblet
	var gob := Geo.node(hand_r, Vector3(0, -0.1, -0.04), Vector3(0, 0, 0))
	Geo.cyl(gob, 0.03, 0.03, 0.006, Vector3(0, -0.05, 0), gold)
	Geo.cyl(gob, 0.006, 0.006, 0.07, Vector3(0, -0.015, 0), gold)
	Geo.cyl(gob, 0.04, 0.012, 0.07, Vector3(0, 0.05, 0), gold)
	Geo.cyl(gob, 0.036, 0.036, 0.005, Vector3(0, 0.082, 0), Mats.glossy(Color(0.25, 0.0, 0.03)))


# ================================================================ animation

func fall(mode: String) -> void:
	fall_mode = mode
	_fall = 0.0


func get_up() -> void:
	fall_mode = ""


func _process(delta: float) -> void:
	if frozen:
		return
	_t += delta
	var k := 1.0 - exp(-12.0 * delta)
	var tg := {}
	for j in joints:
		tg[j] = Vector3.ZERO

	var s := speed
	var run := clampf((s - 2.2) / 2.0, 0.0, 1.0)
	var amp := clampf(s / 1.3, 0.0, 1.0)
	_phase += delta * s * lerpf(4.3, 2.7, run)
	var sw := sin(_phase)
	var leg := sw * lerpf(26.0, 44.0, run) * amp
	var hip_y := _hips_base + (absf(cos(_phase)) * 0.035 - 0.015) * amp - run * 0.05

	# locomotion
	tg.hip_l = Vector3(leg, 0, 0)
	tg.hip_r = Vector3(-leg, 0, 0)
	tg.kn_l = Vector3(-(maxf(0.0, -cos(_phase + 0.3)) * lerpf(40.0, 90.0, run) + 4.0) * amp, 0, 0)
	tg.kn_r = Vector3(-(maxf(0.0, cos(_phase + 0.3)) * lerpf(40.0, 90.0, run) + 4.0) * amp, 0, 0)
	tg.ft_l = Vector3(-leg * 0.3, 0, 0)
	tg.ft_r = Vector3(leg * 0.3, 0, 0)
	tg.sh_l = Vector3(-leg * 0.75, 0, -4)
	tg.sh_r = Vector3(leg * 0.75, 0, 4)
	tg.el_l = Vector3(12.0 + run * 70.0, 0, 0)
	tg.el_r = Vector3(12.0 + run * 70.0, 0, 0)
	tg.spine = Vector3(-run * 14.0 + sin(_t * 1.6 + _seed) * 1.2, sw * 4.0 * amp, 0)
	tg.head = Vector3(head_pitch, head_yaw, 0)

	match pose:
		"alert":
			tg.sh_r = Vector3(55, 0, 10)
			tg.el_r = Vector3(55, 0, 0)
			tg.sh_l = Vector3(25 - leg * 0.4, 0, -12)
			tg.el_l = Vector3(50, 0, 0)
			if s < 0.5:
				tg.hip_l = Vector3(18, 0, -6)
				tg.hip_r = Vector3(-6, 0, 6)
				tg.kn_l = Vector3(-24, 0, 0)
				tg.kn_r = Vector3(-14, 0, 0)
				hip_y -= 0.05
			tg.spine = tg.spine + Vector3(-8, 0, 0)
		"blind":
			tg.sh_l = Vector3(125, 0, -22)
			tg.sh_r = Vector3(125, 0, 22)
			tg.el_l = Vector3(115, 0, 0)
			tg.el_r = Vector3(115, 0, 0)
			tg.head = Vector3(-25 + sin(_t * 9.0) * 8.0, sin(_t * 5.0) * 25.0, 0)
			tg.spine = Vector3(-18, 0, sin(_t * 6.0) * 10.0)
		"panic":
			tg.sh_l = Vector3(150 + sin(_t * 14.0) * 20.0, 0, -35)
			tg.sh_r = Vector3(150 - sin(_t * 14.0) * 20.0, 0, 35)
			tg.el_l = Vector3(40, 0, 0)
			tg.el_r = Vector3(40, 0, 0)
		"cower":
			tg.hip_l = Vector3(80, 0, -10)
			tg.hip_r = Vector3(80, 0, 10)
			tg.kn_l = Vector3(-125, 0, 0)
			tg.kn_r = Vector3(-125, 0, 0)
			tg.ft_l = Vector3(40, 0, 0)
			tg.ft_r = Vector3(40, 0, 0)
			tg.spine = Vector3(-35, 0, sin(_t * 18.0) * 2.0)
			tg.sh_l = Vector3(150, 0, -30)
			tg.sh_r = Vector3(150, 0, 30)
			tg.el_l = Vector3(110, 0, 0)
			tg.el_r = Vector3(110, 0, 0)
			tg.head = Vector3(-30, 0, 0)
			hip_y = 0.5
		"read":
			tg.sh_l = Vector3(38, 0, 6)
			tg.sh_r = Vector3(38, 0, -6)
			tg.el_l = Vector3(60, 0, 0)
			tg.el_r = Vector3(60, 0, 0)
			tg.head = Vector3(-22, head_yaw * 0.3, 0)
		"gesture":
			tg.sh_r = Vector3(30 + sin(_t * 1.3) * 25.0, 0, 20 + sin(_t * 0.7) * 10.0)
			tg.el_r = Vector3(60 + sin(_t * 1.9) * 20.0, 0, 0)
			tg.sh_l = Vector3(10, 0, -12)
			tg.el_l = Vector3(70, 0, 0)

	if carry_lantern and pose in ["idle", "alert"]:
		tg.sh_l = Vector3(28, 0, -8)
		tg.el_l = Vector3(62, 0, 0)

	# attack swing overlay
	if attack_p >= 0.0:
		var p := attack_p
		if p < 0.45:
			var e := p / 0.45
			tg.sh_r = Vector3(lerpf(55, 165, e), 0, lerpf(10, 30, e))
			tg.el_r = Vector3(lerpf(55, 70, e), 0, 0)
			tg.spine = Vector3(tg.spine.x, lerpf(0, 22, e), 0)
		elif p < 0.62:
			var e2 := (p - 0.45) / 0.17
			tg.sh_r = Vector3(lerpf(165, 25, e2), 0, lerpf(30, -10, e2))
			tg.el_r = Vector3(lerpf(70, 5, e2), 0, 0)
			tg.spine = Vector3(-12, lerpf(22, -28, e2), 0)
		else:
			tg.sh_r = Vector3(25, 0, -10)
			tg.el_r = Vector3(10, 0, 0)
			tg.spine = Vector3(tg.spine.x, -28.0 * (1.0 - (p - 0.62) / 0.38), 0)
		k = 1.0 - exp(-30.0 * delta)

	# fallen states
	if fall_mode != "":
		_fall = minf(_fall + delta * 1.6, 1.0)
		var e3 := _fall * _fall * (3.0 - 2.0 * _fall)
		match fall_mode:
			"dead_fwd":
				body.rotation_degrees = Vector3(-88.0 * e3, 0, 0)
				body.position.y = 0.14 * e3
				body.position.z = 0.1 * e3
			"dead_back":
				body.rotation_degrees = Vector3(88.0 * e3, 0, 0)
				body.position.y = 0.14 * e3
			"sleep":
				body.rotation_degrees = Vector3(0, 0, 86.0 * e3)
				body.position.y = 0.16 * e3
		tg.sh_l = Vector3(20, 0, -50)
		tg.sh_r = Vector3(35, 0, 40)
		tg.el_l = Vector3(30, 0, 0)
		tg.el_r = Vector3(20, 0, 0)
		tg.hip_l = Vector3(10 if fall_mode != "sleep" else 45, 0, -4)
		tg.hip_r = Vector3(-5 if fall_mode != "sleep" else 35, 0, 6)
		tg.kn_l = Vector3(-12 if fall_mode != "sleep" else -70, 0, 0)
		tg.kn_r = Vector3(-4 if fall_mode != "sleep" else -55, 0, 0)
		tg.spine = Vector3(0, 0, 0)
		tg.head = Vector3(-10, 30 if fall_mode == "dead_fwd" else 15, 0)
		hip_y = _hips_base
		if fall_mode == "sleep":
			tg.spine = Vector3(-6.0 + sin(_t * 1.3) * 1.5, 0, 0)  # slow breathing
		k = 1.0 - exp(-6.0 * delta)
	elif _fall > 0.0:
		_fall = maxf(_fall - delta * 1.2, 0.0)
		body.rotation_degrees = body.rotation_degrees.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * delta))
		body.position = body.position.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * delta))

	hips.position.y = lerpf(hips.position.y, hip_y, k)
	for j in tg:
		var n: Node3D = joints[j]
		n.rotation_degrees = n.rotation_degrees.lerp(tg[j], k)

	if cloak:
		cloak.rotation_degrees.x = lerpf(cloak.rotation_degrees.x, 6.0 + clampf(s, 0.0, 5.0) * 7.0 + sin(_t * 2.1 + _seed) * 2.0, 1.0 - exp(-4.0 * delta))


func head_center() -> Vector3:
	return head.global_transform * Vector3(0, 0.1, -0.01)


func chest_center() -> Vector3:
	return spine.global_transform * Vector3(0, 0.28, 0)


func belly_center() -> Vector3:
	return hips.global_transform * Vector3(0, 0.02, 0)
