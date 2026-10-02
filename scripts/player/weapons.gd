extends Node
## The assassin's kit and the kill mechanics.
##
##  * Dagger: lives in a sheath on your chest. In VR, reach to it with your right
##    hand and squeeze grip to draw. Let go of grip to sheathe it again.
##    Only a cut ACROSS or a stab INTO the throat kills. Hitting the body just
##    wounds the guard, and a wounded guard screams and fights.
##  * Mouth cover: left grip on a guard's face from behind restrains him for a
##    moment. A throat kill while he's restrained is completely silent.
##    Otherwise he dies with a choked cry that carries.
##  * Hand crossbow: holstered on your right hip. Draw it the same way; right
##    trigger fires. Headshots kill silently, body shots only wound. It cranks
##    itself back after each shot, and you have a limited supply of bolts.

const HandModels = preload("res://scripts/player/hand_models.gd")
const Geo = preload("res://scripts/util/geo.gd")
const Fx = preload("res://scripts/fx/fx.gd")
const Bolt = preload("res://scripts/player/bolt.gd")

const HOLSTER_REACH := 0.22
const MOUTH_REACH := 0.22
const MAX_BOLTS := 7  # plus one already loaded
const RELOAD_TIME := 2.4
const DESK_DAGGER := Vector3(0.25, -0.27, -0.4)
const DESK_DAGGER_ROT := Vector3(32, 14, 0)
const DESK_BOW := Vector3(0.14, -0.19, -0.36)
const DESK_BOW_ROT := Vector3(1, 3, 0)
const DESK_EMPTY := Vector3(0.28, -0.5, -0.32)

var p  # player
var body_rig: Node3D
var sheath: Node3D
var holster: Node3D
var dagger: Node3D
var crossbow: Node3D
var mount: Node3D
var blade_base: Node3D
var blade_tip: Node3D

var held := ""  # "", "dagger", "crossbow"
var bolts := MAX_BOLTS
var loaded := true
var reload_t := 0.0
var grabbed = null
var strike_cd := 0.0
var swing_cd := 0.0
var stab_anim := -1.0
var stab_done := false
var recoil := 0.0
var last_tip := Vector3.ZERO
var _grip_r := false
var _grip_l := false
var _trig_r := false
var desk_grab_held := false
var desk_fire := false


func setup(player) -> void:
	p = player
	body_rig = Node3D.new()
	body_rig.name = "BodyRig"
	body_rig.top_level = true
	p.add_child(body_rig)
	sheath = HandModels.build_sheath()
	body_rig.add_child(sheath)
	# Cross-draw: on the left of the chest, handle tilted toward the right hand.
	sheath.position = Vector3(-0.06, -0.34, -0.14)
	sheath.rotation_degrees = Vector3(-10, 0, -32)
	holster = HandModels.build_holster()
	body_rig.add_child(holster)
	holster.position = Vector3(0.22, -0.78, -0.04)
	holster.rotation_degrees = Vector3(-15, 0, 8)
	mount = p.right_rig.get_node("WeaponMount")
	dagger = HandModels.build_dagger()
	crossbow = HandModels.build_crossbow()
	sheath.get_node("Slot").add_child(dagger)
	holster.get_node("Slot").add_child(crossbow)
	blade_base = dagger.get_node("BladeBase")
	blade_tip = dagger.get_node("BladeTip")
	if not p.vr:
		# On desktop the body kit is out of view; hands animate to the camera.
		p.right_rig.position = DESK_EMPTY
	_update_body_rig()


# ================================================================ public

func status_text() -> String:
	var w := "Unarmed"
	if held == "dagger":
		w = "Dagger"
	elif held == "crossbow":
		w = "Crossbow"
	var b := "Bolts %d%s" % [bolts + (1 if loaded else 0), "" if loaded or bolts == 0 else " (cranking)"]
	var g := "  · COVERING MOUTH" if grabbed != null else ""
	return "%s · %s%s" % [w, b, g]


func desktop_input(event: InputEvent) -> void:
	if event.is_action_pressed("draw_dagger"):
		if held == "dagger":
			sheathe()
		else:
			draw("dagger")
	if event.is_action_pressed("draw_crossbow"):
		if held == "crossbow":
			sheathe()
		else:
			draw("crossbow")
	if event.is_action_pressed("grab"):
		desk_grab_held = true
	if event.is_action_released("grab"):
		desk_grab_held = false
	if event.is_action_pressed("attack"):
		if held == "dagger" and stab_anim < 0.0:
			stab_anim = 0.0
			stab_done = false
		elif held == "crossbow":
			desk_fire = true
		elif held == "":
			GameState.notify.emit("Draw a weapon first:  F = dagger,  B = crossbow.", 1.5)


func draw(kind: String) -> void:
	if held == kind:
		return
	if held != "":
		sheathe()
	var n: Node3D = dagger if kind == "dagger" else crossbow
	n.reparent(mount, false)
	n.transform = Transform3D.IDENTITY
	held = kind
	Sfx.play_at("draw" if kind == "dagger" else "sheathe", mount.global_position, -6.0)
	p._haptic(p.right_ctrl, 0.4, 0.06)
	last_tip = blade_tip.global_position


func sheathe() -> void:
	if held == "":
		return
	var n: Node3D = dagger if held == "dagger" else crossbow
	var slot: Node3D = sheath.get_node("Slot") if held == "dagger" else holster.get_node("Slot")
	n.reparent(slot, false)
	n.transform = Transform3D.IDENTITY
	held = ""
	Sfx.play_at("sheathe", slot.global_position, -10.0)


func release_grab() -> void:
	if grabbed != null and is_instance_valid(grabbed):
		grabbed.release_restraint()
	grabbed = null


# ================================================================ per frame

func update(delta: float) -> void:
	strike_cd -= delta
	swing_cd -= delta
	_update_body_rig()
	if p.vr:
		_vr_hands()
	else:
		_desktop_hands(delta)
	if grabbed != null and (not is_instance_valid(grabbed) or not grabbed.restrained):
		grabbed = null
	if held == "dagger":
		if p.vr:
			_vr_blade(delta)
	elif held == "crossbow":
		_crossbow(delta)
	if not loaded and bolts > 0:
		reload_t -= delta
		if reload_t <= 0.0:
			loaded = true
			bolts -= 1
			crossbow.get_node("LoadedBolt").visible = true
			crossbow.get_node("StringDrawn").visible = true
			crossbow.get_node("StringRest").visible = false
			Sfx.play_at("click", crossbow.global_position, -8.0)


func _update_body_rig() -> void:
	## Kit hangs off your torso: follows the head's position and yaw only.
	var cam: Node3D = p.camera
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.1:
		f = cam.global_transform.basis.y
		f.y = 0.0
	f = f.normalized()
	var yaw := atan2(-f.x, -f.z)
	body_rig.global_transform = Transform3D(Basis(Vector3.UP, yaw), cam.global_position)


# ---------------------------------------------------------------- VR

func _vr_hands() -> void:
	var rg: bool = p.right_ctrl.get_float("grip") > 0.6
	if rg and not _grip_r and held == "":
		var hp: Vector3 = p.right_rig.global_position
		var dd := hp.distance_to(sheath.get_node("Slot").global_position)
		var bd := hp.distance_to(holster.get_node("Slot").global_position)
		if dd < HOLSTER_REACH and dd <= bd:
			draw("dagger")
		elif bd < HOLSTER_REACH:
			draw("crossbow")
	elif not rg and _grip_r and held != "":
		sheathe()
	_grip_r = rg

	var lg: bool = p.left_ctrl.get_float("grip") > 0.6
	if lg and not _grip_l and grabbed == null:
		var lh: Vector3 = p.left_rig.global_position
		var best = null
		var best_d := MOUTH_REACH
		for g in GameState.guards:
			if is_instance_valid(g) and g.is_alive():
				var d: float = lh.distance_to(g.mouth_pos())
				if d < best_d:
					best_d = d
					best = g
		if best != null and best.try_restrain():
			grabbed = best
			p._haptic(p.left_ctrl, 0.8, 0.15)
	elif not lg and _grip_l and grabbed != null:
		release_grab()
	_grip_l = lg
	if grabbed != null:
		p._haptic(p.left_ctrl, 0.25, 0.03)  # he's struggling


func _vr_blade(delta: float) -> void:
	var tip := blade_tip.global_position
	var base := blade_base.global_position
	var vel := (tip - last_tip).length() / maxf(delta, 0.0001)
	last_tip = tip
	if vel > 3.0 and swing_cd <= 0.0:
		swing_cd = 0.35
		Sfx.play_at("swing", tip, -10.0)
	if strike_cd > 0.0 or vel < 1.1:
		return
	for g in GameState.guards:
		if not is_instance_valid(g) or not g.is_alive():
			continue
		if g.global_position.distance_to(p.global_position) > 2.5:
			continue
		if g.throat_test(base, tip, 0.015):
			_strike(g, true, g.throat_pos())
			return
	if vel < 1.7:
		return
	for g in GameState.guards:
		if not is_instance_valid(g) or not g.is_alive():
			continue
		if g.global_position.distance_to(p.global_position) > 2.5:
			continue
		if g.blade_hit_test(base, tip, 0.0):
			_strike(g, false, tip)
			return


# ---------------------------------------------------------------- desktop

func _desktop_hands(delta: float) -> void:
	var rig: Node3D = p.right_rig
	var target := DESK_EMPTY
	var trot := Vector3(10, 0, 0)
	if held == "dagger":
		target = DESK_DAGGER
		trot = DESK_DAGGER_ROT
	elif held == "crossbow":
		target = DESK_BOW + Vector3(0, 0.02, 0.06) * recoil
		trot = DESK_BOW_ROT + Vector3(14, 0, 0) * recoil
	recoil = maxf(0.0, recoil - delta * 5.0)
	if stab_anim >= 0.0:
		stab_anim += delta
		var t := stab_anim / 0.32
		var reach := sin(clampf(t, 0.0, 1.0) * PI)
		if grabbed != null:
			# Slit: a hard sweep across the throat.
			target = DESK_DAGGER + Vector3(-0.32, 0.12, -0.3) * reach
			trot = DESK_DAGGER_ROT + Vector3(-60.0, 70.0, -40.0) * reach
		else:
			target = DESK_DAGGER + Vector3(-0.14, 0.12, -0.5) * reach
			trot = DESK_DAGGER_ROT + Vector3(-30.0, 6.0, -25.0) * reach
		if t > 0.15 and t < 0.25 and swing_cd <= 0.0:
			swing_cd = 0.3
			Sfx.play_at("swing", rig.global_position, -8.0)
		if t > 0.35 and not stab_done:
			stab_done = true
			_desktop_stab_resolve()
		if stab_anim > 0.32:
			stab_anim = -1.0
		rig.position = target
		rig.rotation_degrees = trot
	else:
		var k := minf(1.0, 14.0 * delta)
		rig.position = rig.position.lerp(target, k)
		rig.rotation_degrees = rig.rotation_degrees.lerp(trot, k)
	# Mouth cover (hold V) on a guard right in front of you.
	if desk_grab_held and grabbed == null:
		var cam: Node3D = p.camera
		var cf := -cam.global_transform.basis.z
		for g in GameState.guards:
			if not is_instance_valid(g) or not g.is_alive() or g.restrained:
				continue
			var to: Vector3 = g.mouth_pos() - cam.global_position
			if to.length() < 1.5 and rad_to_deg(cf.angle_to(to)) < 40.0:
				if g.try_restrain():
					grabbed = g
				desk_grab_held = g == grabbed  # one attempt per press
				break
	elif not desk_grab_held and grabbed != null:
		release_grab()
	# Left hand reaches out while covering a mouth.
	if grabbed != null and is_instance_valid(grabbed):
		p.left_rig.global_position = p.left_rig.global_position.lerp(grabbed.mouth_pos(), minf(1.0, 12.0 * delta))


func _desktop_stab_resolve() -> void:
	var cam: Node3D = p.camera
	var o := cam.global_position
	var f := -cam.global_transform.basis.z
	if grabbed != null and is_instance_valid(grabbed) and grabbed.is_alive():
		_strike(grabbed, true, grabbed.throat_pos())  # restrained: you go for the throat
		return
	for g in GameState.guards:
		if not is_instance_valid(g) or not g.is_alive():
			continue
		var tp: Vector3 = g.throat_pos()
		if o.distance_to(tp) < 1.6 and Geo.seg_point_dist(o, o + f * 1.7, tp) < 0.13:
			_strike(g, true, tp)
			return
	for g in GameState.guards:
		if not is_instance_valid(g) or not g.is_alive():
			continue
		for s in g.hit_spheres():
			var c: Vector3 = s[0]
			if o.distance_to(c) < 1.7 and Geo.seg_point_dist(o, o + f * 1.8, c) < s[1] + 0.05:
				_strike(g, false, c)
				return


# ---------------------------------------------------------------- shared

func _strike(g, throat: bool, pos: Vector3) -> void:
	strike_cd = 0.5
	p._end_shroud()
	var silenced: bool = grabbed == g and g.restrained
	var r: String = g.receive_strike(p.global_position, pos, throat, silenced)
	match r:
		"silent":
			grabbed = null
			Sfx.play_at("stab", pos, -12.0)
			Sfx.play_ui("kill", -3.0)
			p._haptic(p.right_ctrl, 1.0, 0.4)
			p._haptic(p.left_ctrl, 0.6, 0.4)
			GameState.notify.emit(["Silenced.", "Not a sound.", "Into the dark."][randi() % 3], 1.3)
		"throat":
			Sfx.play_at("stab", pos, 0.0)
			Sfx.play_ui("kill", -6.0)
			p._haptic(p.right_ctrl, 1.0, 0.35)
			GameState.notify.emit("He cried out as he died... someone may have heard.", 2.0)
		"wounded":
			Sfx.play_at("stab", pos, -2.0)
			p._haptic(p.right_ctrl, 0.8, 0.2)
			GameState.notify.emit("Not a killing blow! Go for the THROAT.", 2.0)
		"hit", "kill":
			Sfx.play_at("stab", pos, -2.0)
			p._haptic(p.right_ctrl, 0.8, 0.2)
		"block":
			strike_cd = 1.1
			p._haptic(p.right_ctrl, 1.0, 0.15)


func _crossbow(_delta: float) -> void:
	var fire := false
	if p.vr:
		var tr: float = p.right_ctrl.get_float("trigger")
		if tr > 0.8 and not _trig_r:
			fire = true
		_trig_r = tr > 0.6
	elif desk_fire:
		fire = true
	desk_fire = false
	if not fire:
		return
	if not loaded:
		Sfx.play_at("click", crossbow.global_position, -6.0)
		if bolts <= 0:
			GameState.notify.emit("Out of bolts.", 1.2)
		return
	var muzzle: Node3D = crossbow.get_node("Muzzle")
	var from := muzzle.global_position
	var dir := -muzzle.global_transform.basis.z
	if not p.vr:
		# Desktop: converge on the crosshair.
		var cam: Node3D = p.camera
		var co := cam.global_position
		var cf := -cam.global_transform.basis.z
		var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(co, co + cf * 80.0, GameState.LAYER_WORLD))
		var tgt: Vector3 = hit.position if not hit.is_empty() else co + cf * 80.0
		dir = (tgt - from).normalized()
		from = co + cf * 0.3
	var b := Bolt.new()
	b.launch(dir, p.global_position)
	p.get_tree().current_scene.add_child(b)
	b.global_position = from
	b.look_at(from + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT)
	loaded = false
	reload_t = RELOAD_TIME
	recoil = 1.0
	crossbow.get_node("LoadedBolt").visible = false
	crossbow.get_node("StringDrawn").visible = false
	crossbow.get_node("StringRest").visible = true
	p._end_shroud()
	Sfx.play_at("crossbow", from, -2.0)
	if bolts > 0:
		Sfx.play_at("reload", from, -10.0)
	GameState.emit_noise(from, 2.5, "lure")  # a soft twang
	p._haptic(p.right_ctrl, 0.9, 0.12)
