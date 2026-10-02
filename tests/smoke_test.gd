extends Node
## Headless gameplay smoke test:
##   godot --headless --path . res://tests/smoke_test.tscn -- --desktop
## Loads the real level, waits for navigation, then checks patrols move,
## perception works, sneak kills / blinding / slumber / echo / snuff behave,
## and the mission can be completed.

var main: Node
var frame := 0
var failures: Array = []
var phase := 0
var t0 := {}


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
				print("guards that moved: %d" % moved)
				check(moved >= 4, "patrolling guards move along their routes")
				check(gs.max_threat < 0.3, "player unseen at start (threat %.2f)" % gs.max_threat)
				check(p.visibility < 0.3, "start area is dark (vis %.2f)" % p.visibility)
				# Walk into the lit gate area in plain view of the gate guards.
				p.global_position = Vector3(0, 0.1, 35.0)
				phase = 2
				frame = 0
		2:
			if frame == 240:
				var bram = guard("Bram")
				print("bram state=%d awareness=%.2f, player vis=%.2f" % [bram.state, bram.awareness, p.visibility])
				check(bram.awareness > 0.3 or bram.state != 0, "gate guard notices player standing in torchlight")
				# Reset: hide player far away and calm everyone
				p.global_position = Vector3(-21, 0.1, 47)
				for g in gs.guards:
					g.awareness = 0.0
				phase = 3
				frame = 0
		3:
			if frame == 30:
				# Sneak kill: place player behind Garrick (barracks) and stab.
				var gar = guard("Garrick")
				gar.state = 0
				gar.awareness = 0.0
				var back: Vector3 = gar.global_transform.basis.z
				p.global_position = gar.global_position + back * 0.9
				var r: String = gar.receive_strike(p.global_position, gar.model.chest_center())
				check(r == "sneak", "stab from behind an unaware guard is a one-hit sneak kill (%s)" % r)
				check(not gar.is_alive(), "guard is dead after takedown")
				# Blind
				var osr = guard("Osric")
				check(osr.blind(5.0), "blinding hex blinds a guard")
				check(osr.state == 5, "blinded guard enters BLINDED/panic state")
				var r2: String = osr.receive_strike(osr.global_position - osr.global_transform.basis.z * 0.8, osr.model.chest_center())
				check(r2 == "sneak", "blinded guard can be killed even face to face")
				# Slumber on unaware guard, fails on alerted guard
				var tam = guard("Tamsin")
				tam.state = 0
				tam.awareness = 0.0
				check(tam.try_sleep(20.0), "slumber works on an unaware guard")
				var wen = guard("Wendel")
				wen._enter_combat()
				check(not wen.try_sleep(20.0), "slumber fails on an alerted (combat) guard")
				phase = 4
				frame = 0
		4:
			if frame == 10:
				# Echo lure: noise draws a calm guard to investigate
				var ald = guard("Aldous")
				ald.state = 0
				ald.awareness = 0.0
				gs.emit_noise(ald.global_position + Vector3(6, 0, 3), 16.0, "lure")
				check(ald.state == 2, "echo lure sends guard to investigate (state %d)" % ald.state)
				# Snuff a light
				var lit_before := 0
				for l in gs.lights:
					if l.is_lit():
						lit_before += 1
				gs.lights[0].extinguish()
				var lit_after := 0
				for l in gs.lights:
					if l.is_lit():
						lit_after += 1
				check(lit_after == lit_before - 1, "snuff extinguishes a light source")
				# Shadow step target resolution onto the stable roof via ledge mantle
				var space = p.get_world_3d().direct_space_state
				var dest = p._blink_target(Vector3(20.0, 2.6, 15.0), Vector3(0.6, 0.25, 1.0).normalized(), space)
				print("blink dest: ", dest)
				check(dest != null, "shadow step finds a landing spot")
				# Kill the target and extract
				var lord = gs.target
				var r3: String = lord.receive_strike(lord.global_position - lord.global_transform.basis.z, lord.model.chest_center())
				check(r3 == "sneak" and gs.target_dead, "target can be assassinated")
				# Set up a live dagger takedown on Merrick using the real stab animation.
				var mer = guard("Merrick")
				mer.set_physics_process(false)
				mer.state = 0
				mer.awareness = 0.0
				var mf: Vector3 = -mer.global_transform.basis.z
				p.global_position = mer.global_position - mf * 1.0
				p.yaw = atan2(mf.x, mf.z) + PI
				p.pitch = deg_to_rad(-12.0)
				p.desktop_crouch = true
				p.stab_anim = 0.0
				phase = 6
				frame = 0
		6:
			if frame == 40:
				var mer = guard("Merrick")
				check(not mer.is_alive(), "desktop dagger stab (real input path) assassinates guard from behind")
				# Fire a real Blinding Hex projectile at Wendel's head.
				var wen = guard("Wendel")
				wen.set_physics_process(false)
				wen.state = 0
				var hp: Vector3 = wen.eye_pos()
				var from := hp + Vector3(0, 0.2, 6.0)
				var proj = load("res://scripts/magic/spell_projectile.gd").new()
				proj.launch("blind", (hp - from).normalized(), Color(0.8, 0.5, 1.0))
				add_child(proj)
				proj.global_position = from
				wen.set_physics_process(true)
				phase = 7
				frame = 0
		7:
			if frame == 60:
				var wen = guard("Wendel")
				check(wen.state == 5, "blinding hex projectile flies, hits and blinds (state %d)" % wen.state)
				p.global_position = gs.extraction_point + Vector3(0, 0.1, 0)
				phase = 5
				frame = 0
		5:
			if frame == 20:
				check(gs.mission_over and gs.mission_success, "reaching extraction after the kill completes the mission")
				print("summary stats: ", gs.stats)
				print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
				for f in failures:
					print("   - " + f)
				return true
	return false
