extends Node
## Headless gameplay smoke test:
##   godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn -- --desktop
## Loads the real level and checks patrols, detection + the reaction window,
## throat-only takedowns, mouth-cover silencing, wounding, brutal combat,
## the crossbow, spells, reinforcements and mission completion.

const SPOTTED := 10

var main: Node
var frame := 0
var failures: Array = []
var phase := 0
var t0 := {}
var saw_spotted := false
var guards_at_alarm := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		failures.append(msg)


func guard(n: String):
	for g in GameState.guards:
		if g.display_name == n:
			return g
	return null


func calm(g) -> void:
	g.state = 0
	g.awareness = 0.0
	g.sees_player = false


func aim_at(p, target: Vector3) -> void:
	var d: Vector3 = target - p.camera.global_position
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(d.normalized().y)


func _process(_delta: float) -> void:
	if _step():
		get_tree().quit(1 if not failures.is_empty() else 0)


func _step() -> bool:
	frame += 1
	var gs = GameState
	var p = gs.player
	if p:
		p.health = 100.0  # keep the test player alive while guards are riled up
		p.regen_delay = 0.0
	var bram = guard("Bram")
	if bram and bram.state == SPOTTED:
		saw_spotted = true
	match phase:
		0:
			if gs.nav_ready:
				print("nav ready at frame %d, guards=%d lights=%d hiding=%d" % [frame, gs.guards.size(), gs.lights.size(), gs.hiding_zones.size()])
				for g in gs.guards:
					t0[g.display_name] = g.global_position
				phase = 1
				frame = 0
			elif frame > 2000:
				check(false, "navigation never became ready")
				return true
		1:
			if frame == 600:
				var moved := 0
				for g in gs.guards:
					if g.global_position.distance_to(t0[g.display_name]) > 2.0:
						moved += 1
				check(moved >= 4, "patrolling guards move along their routes (%d)" % moved)
				check(gs.max_threat < 0.3, "player unseen at start")
				check(not Sfx.streams.has("step") and not Sfx.streams.has("step_soft"), "footstep sounds removed")
				check(p.weapons.held == "", "player starts with dagger sheathed")
				# Reaction window: Hollis spots you, you kill him before he shouts.
				var hol = guard("Hollis")
				hol._enter_spotted()
				check(hol.state == SPOTTED, "being seen opens a short SPOTTED reaction window")
				check(not gs.alarm_active, "no alarm during the reaction window")
				hol.try_restrain()
				var r: String = hol.receive_strike(hol.global_position + hol.global_transform.basis.z, hol.throat_pos(), true, true)
				check(r == "silent" and not gs.alarm_active, "silencing a spotter in time prevents the alarm")
				# Now stand in the gate torchlight in front of Bram.
				p.global_position = Vector3(-1.9, 0.1, 36.0)
				phase = 2
				frame = 0
		2:
			if frame == 300:
				print("bram state=%d awareness=%.2f, player vis=%.2f" % [bram.state, bram.awareness, p.visibility])
				check(saw_spotted, "guard goes through SPOTTED before raising the alarm")
				check(gs.alarm_active and bram.state == 3, "if you don't react, the alarm is raised and he attacks")
				guards_at_alarm = gs.guards.size()
				p.global_position = Vector3(-21, 0.1, 47)
				phase = 3
				frame = 0
		3:
			if frame == 30:
				# Body poke on an unaware guard: only a wound, and he fights.
				var gar = guard("Garrick")
				gar.set_physics_process(false)
				calm(gar)
				var back: Vector3 = gar.global_transform.basis.z
				var r1: String = gar.receive_strike(gar.global_position + back, gar.model.chest_center(), false, false)
				check(r1 == "wounded" and gar.is_alive() and gar.state == 3, "stabbing the body only wounds; he screams and fights (%s)" % r1)
				# Throat from behind without covering the mouth: kill with a death-cry.
				var osr = guard("Osric")
				calm(osr)
				var heard_cry := [false]
				var cb := func(_pos, _r, kind): if kind == "deathcry": heard_cry[0] = true
				gs.noise_emitted.connect(cb)
				var r2: String = osr.receive_strike(osr.global_position + osr.global_transform.basis.z, osr.throat_pos(), true, false)
				gs.noise_emitted.disconnect(cb)
				check(r2 == "throat" and not osr.is_alive(), "throat strike from behind kills")
				check(heard_cry[0], "...but without a hand over his mouth he cries out")
				# Mouth cover + throat = silent.
				var tam = guard("Tamsin")
				calm(tam)
				check(tam.try_restrain(), "covering an unaware guard's mouth restrains him")
				var r3: String = tam.receive_strike(tam.global_position + tam.global_transform.basis.z, tam.throat_pos(), true, true)
				check(r3 == "silent", "throat kill while covering the mouth is silent")
				# Restraint doesn't last.
				var mer = guard("Merrick")
				calm(mer)
				mer.try_restrain()
				phase = 4
				frame = 0
		4:
			if frame == 140:
				var mer = guard("Merrick")
				check(not mer.restrained and mer.state == 3, "a restrained guard breaks free and attacks if you hesitate")
				# Squared-up fighter parries a throat strike; blinded one doesn't.
				var wen = guard("Wendel")
				wen._enter_combat()
				wen.attack_t = -1.0
				var r4: String = wen.receive_strike(wen.global_position - wen.global_transform.basis.z, wen.throat_pos(), true, false)
				check(r4 == "block", "an alerted guard facing you parries the throat strike")
				check(not wen.try_sleep(20.0), "slumber fails on an alerted guard")
				check(wen.blind(5.0), "blinding hex works even in combat")
				var r5: String = wen.receive_strike(wen.global_position - wen.global_transform.basis.z, wen.throat_pos(), true, false)
				check(r5 == "throat", "a blinded guard's throat is open, even face to face")
				check(Guard.ATTACK_DAMAGE >= 35.0, "guard sword hits are brutal (%d dmg)" % int(Guard.ATTACK_DAMAGE))
				# Crossbow headshot through the real desktop path.
				var ald = guard("Aldous")
				ald.set_physics_process(false)
				calm(ald)
				ald.global_position = Vector3(2.0, 0.0, 20.0)
				p.global_position = Vector3(2.0, 0.1, 12.0)
				p.weapons.draw("crossbow")
				phase = 5
				frame = 0
		5:
			var ald = guard("Aldous")
			if frame < 20:
				aim_at(p, ald.model.head_center())
			if frame == 20:
				p.weapons.desk_fire = true
			if frame == 50:
				check(not ald.is_alive(), "crossbow headshot kills")
				check(not p.weapons.loaded and p.weapons.bolts == p.weapons.MAX_BOLTS, "firing empties the crossbow; it cranks a new bolt")
				var cap = guard("Captain Roderick")
				var r6: String = cap.receive_bolt("body", p.global_position, cap.model.chest_center())
				check(r6 == "wounded" and cap.is_alive(), "a crossbow body shot only wounds")
				check(gs.guards.size() > guards_at_alarm, "alarm brings reinforcements through the gate (%d -> %d)" % [guards_at_alarm, gs.guards.size()])
				# Live desktop takedown on the lord: draw dagger, cover mouth, slit throat.
				var lord = gs.target
				lord.set_physics_process(false)
				calm(lord)
				var lf: Vector3 = -lord.global_transform.basis.z
				p.global_position = lord.global_position - lf * 0.7
				p.weapons.draw("dagger")
				p.pitch = deg_to_rad(-10.0)
				p.yaw = atan2(-lf.x, -lf.z)
				p.desktop_crouch = false
				phase = 6
				frame = 0
		6:
			if frame == 25:
				p.weapons.desk_grab_held = true
			if frame == 40:
				check(p.weapons.grabbed == gs.target, "desktop: hold V covers the lord's mouth")
				p.weapons.stab_anim = 0.0
				p.weapons.stab_done = false
			if frame == 80:
				check(gs.target_dead, "desktop: dagger slit while covering the mouth kills the target")
				check(gs.stats.kills >= 4, "kill stats tracked")
				p.weapons.desk_grab_held = false
				p.global_position = gs.extraction_point + Vector3(0, 0.1, 0)
				phase = 7
				frame = 0
		7:
			if frame == 20:
				check(gs.mission_over and gs.mission_success, "reaching extraction after the kill completes the mission")
				print("summary stats: ", gs.stats)
				print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
				for f in failures:
					print("   - " + f)
				return true
	return false


const Guard = preload("res://scripts/npc/guard.gd")
