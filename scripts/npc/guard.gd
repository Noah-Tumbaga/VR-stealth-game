extends CharacterBody3D
## Guard / target AI.
## Perception: vision cone with line-of-sight raycasts scaled by the player's
## light-based visibility, a short "sixth sense" radius, and hearing via the
## GameState noise bus. States: patrol -> suspicious -> investigate -> combat
## -> search, plus magic states (blinded/panic, asleep) and death.

const Humanoid = preload("res://scripts/npc/humanoid.gd")
const LightSource = preload("res://scripts/world/light_source.gd")
const Geo = preload("res://scripts/util/geo.gd")
const Mats = preload("res://scripts/util/mats.gd")
const Fx = preload("res://scripts/fx/fx.gd")

enum S { PATROL, SUSPICIOUS, INVESTIGATE, COMBAT, SEARCH, BLINDED, ASLEEP, DEAD, FLEE, COWER, SPOTTED }

const VIEW_RANGE := 17.0
const FOV_HALF := 57.0
const GRAVITY := 9.8
const REACTION_TIME := 0.85  # seconds between "Hey--!" and the alarm: your only chance
const RESTRAIN_TIME := 1.8   # how long a mouth-covered guard struggles before breaking free
const ATTACK_TIME := 0.8
const ATTACK_HIT := 0.42
const ATTACK_DAMAGE := 40.0
const COMBAT_SPEED := 5.1
const BARKS := {
	"suspicious": ["Hm? What was that?", "Who's there?", "Something moved...", "Hello?"],
	"calm": ["Must be the wind.", "Just shadows.", "Bah. Rats again.", "Getting jumpy..."],
	"investigate": ["I'll take a look.", "Better check that out.", "Who's skulking about?"],
	"combat": ["INTRUDER!", "There! Assassin!", "To arms! To arms!", "I see you!"],
	"lost": ["Where'd they go?", "Spread out! Find them!", "Show yourself, coward!"],
	"search_end": ["I'll keep my eyes open.", "They're long gone...", "Back to my post."],
	"body": ["Murder! Sound the alarm!", "Gods... he's dead!", "Man down! MAN DOWN!"],
	"sleeper": ["Oi! Wake up!", "Sleeping on watch?!"],
	"woke": ["Wha-? Who's there?!", "Ugh... my head..."],
	"blind": ["AAGH! MY EYES!", "I can't see! I CAN'T SEE!", "Witchcraft! Help me!"],
	"sleep_resist": ["Nngh... no... sorcery!", "Not... so easily!"],
	"target_flee": ["ASSASSIN! Guards! GUARDS!", "Protect me, you fools!"],
	"spotted": ["Hey--!", "Wha--?! You there--", "Who in the--"],
	"muffled": ["Mmmph!", "Mmf-- mmMPH!", "Nnngh!"],
	"wounded": ["AARGH! I'm stabbed!", "Assassin! ASSASSIN!", "Gah! Here! HERE!"],
	"broke_free": ["*gasp* INTRUDER!", "HELP! HE'S HERE!"],
}

var display_name := "Guard"
var state: S = S.PATROL
var state_t := 0.0
var model: Node3D
var agent: NavigationAgent3D
var indicator: Label3D
var bark_label: Label3D
var lantern: Node3D = null
var snore: AudioStreamPlayer3D

var waypoints: Array = []
var waits: Array = []
var post_yaws: Array = []
var wp_poses: Array = []
var wp_i := 0
var wait_t := -1.0
var look_around := true
var idle_pose := "idle"

var is_target := false
var follow = null
var safe_point := Vector3.ZERO
var deep_sleep := false

var health := 100.0
var awareness := 0.0
var last_known := Vector3.ZERO
var investigate_pos := Vector3.ZERO
var investigate_run := false
var search_center := Vector3.ZERO
var search_pt := Vector3.ZERO
var search_pause := 0.0
var search_time := 0.0
var lost_t := 0.0
var attack_cd := 0.0
var attack_t := -1.0
var attack_hit_done := false
var blind_t := 0.0
var stumble_dir := Vector3.FORWARD
var stumble_t := 0.0
var sleep_t := 0.0
var discovered := false
var sees_player := false
var perceive_t := 0.0
var body_check_t := 0.0
var shout_t := 0.0
var wake_target = null
var stuck_t := 0.0
var spotted_t := 0.0
var restrained := false
var restrain_t := 0.0
var unstick_t := 0.0
var unstick_dir := Vector3.ZERO
var stuck_count := 0
var last_pos := Vector3.ZERO
var walk_speed := 1.45
var run_speed := 4.2
var cur_speed := 0.0
var _nav_goal := Vector3(INF, INF, INF)
var _bark_cd := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_cfg: Dictionary) -> void:
	display_name = p_cfg.get("name", "Guard")
	waypoints = p_cfg.get("waypoints", [])
	waits = p_cfg.get("waits", [])
	post_yaws = p_cfg.get("yaws", [])
	wp_poses = p_cfg.get("poses", [])
	is_target = p_cfg.get("target", false)
	safe_point = p_cfg.get("safe_point", Vector3.ZERO)
	deep_sleep = p_cfg.get("deep_sleep", false)
	idle_pose = p_cfg.get("idle_pose", "idle")
	walk_speed = p_cfg.get("walk_speed", 1.45)
	health = p_cfg.get("health", 100.0)
	set_meta("cfg", p_cfg)


func _ready() -> void:
	var p_cfg: Dictionary = get_meta("cfg", {})
	_rng.seed = hash(display_name)
	collision_layer = GameState.LAYER_NPC
	collision_mask = GameState.LAYER_WORLD | GameState.LAYER_PLAYER
	floor_max_angle = deg_to_rad(46.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	model = Humanoid.new()
	model.build(p_cfg.get("model", {}))
	add_child(model)

	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.35
	agent.target_desired_distance = 0.4
	agent.radius = 0.4
	agent.height = 1.8
	agent.path_max_distance = 3.0
	add_child(agent)

	indicator = Label3D.new()
	indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator.font_size = 128
	indicator.outline_size = 24
	indicator.pixel_size = 0.0028
	indicator.position = Vector3(0, 2.25, 0)
	indicator.modulate = Color(1, 0.85, 0.2, 0)
	indicator.outline_modulate = Color(0, 0, 0, 0)
	indicator.text = "?"
	add_child(indicator)

	bark_label = Label3D.new()
	bark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bark_label.font_size = 48
	bark_label.outline_size = 12
	bark_label.pixel_size = 0.0026
	bark_label.position = Vector3(0, 2.6, 0)
	bark_label.modulate = Color(1, 1, 1, 0)
	bark_label.outline_modulate = Color(0, 0, 0, 0)
	add_child(bark_label)

	if p_cfg.get("lantern", false):
		model.carry_lantern = true
		lantern = LightSource.new().configure("lantern", 1.3, 7.0, 0.9, false)
		_build_lantern_body(lantern)
		model.hand_l.add_child(lantern)
		lantern.position = Vector3(0, -0.24, -0.02)

	if waypoints.is_empty():
		waypoints = [global_position]
	if waits.is_empty():
		for i in waypoints.size():
			waits.append(2.0)
	last_pos = global_position
	GameState.guards.append(self)
	GameState.noise_emitted.connect(_on_noise)
	GameState.alarm_changed.connect(_on_alarm)
	if p_cfg.get("asleep", false):
		_enter_sleep(1e9 if deep_sleep else 40.0, true)


func _build_lantern_body(l: Node3D) -> void:
	var iron := Mats.iron()
	Geo.box(l, Vector3(0.012, 0.16, 0.012), Vector3(0, 0.15, 0), iron)  # handle bail
	Geo.cyl(l, 0.06, 0.07, 0.03, Vector3(0, 0.07, 0), iron)  # top cap
	Geo.cyl(l, 0.0, 0.06, 0.05, Vector3(0, 0.1, 0), iron)
	Geo.cyl(l, 0.07, 0.07, 0.025, Vector3(0, -0.08, 0), iron)  # base
	var glass := Mats.emissive(Color(1.0, 0.7, 0.35), 1.5)
	Geo.cyl(l, 0.052, 0.052, 0.13, Vector3(0, 0.0, 0), glass, Vector3.ZERO, Vector3.ONE, 6)
	for i in 4:
		var a := deg_to_rad(45.0 + i * 90.0)
		Geo.box(l, Vector3(0.01, 0.15, 0.01), Vector3(cos(a) * 0.06, 0.0, sin(a) * 0.06), iron)


# ================================================================ helpers

func is_alive() -> bool:
	return state != S.DEAD


func eye_pos() -> Vector3:
	return model.head_center()


func forward() -> Vector3:
	return -global_transform.basis.z


func look_dir() -> Vector3:
	return -model.head.global_transform.basis.z


func threat_level() -> float:
	if state in [S.DEAD, S.ASLEEP, S.BLINDED]:
		return 0.0
	if state == S.COMBAT or state == S.SPOTTED:
		return 1.0
	return clampf(awareness, 0.0, 1.0)


func throat_pos() -> Vector3:
	return model.neck.global_transform * Vector3(0, 0.035, -0.055)


func mouth_pos() -> Vector3:
	return model.head.global_transform * Vector3(0, 0.05, -0.1)


func throat_test(a: Vector3, b: Vector3, extra := 0.0) -> bool:
	return Geo.seg_point_dist(a, b, throat_pos()) < 0.085 + extra


func hit_spheres() -> Array:
	return [[model.head_center(), 0.16], [model.chest_center(), 0.26], [model.belly_center(), 0.23]]


func blade_hit_test(a: Vector3, b: Vector3, extra := 0.0) -> bool:
	for s in hit_spheres():
		if Geo.seg_point_dist(a, b, s[0]) < s[1] + extra:
			return true
	return false


func bark(category: String, force := false) -> void:
	if _bark_cd > 0.0 and not force:
		return
	var lines: Array = BARKS.get(category, [])
	if lines.is_empty():
		return
	_bark_cd = 2.5
	bark_label.text = lines[_rng.randi() % lines.size()]
	bark_label.modulate.a = 1.0
	bark_label.outline_modulate.a = 1.0
	bark_label.set_meta("t", 2.8)


func _set_state(s: S) -> void:
	state = s
	state_t = 0.0


func _face_dir(dir: Vector3, delta: float, rate := 7.0) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, rate * delta))


func _face_point(p: Vector3, delta: float, rate := 7.0) -> void:
	_face_dir(p - global_position, delta, rate)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	cur_speed = 0.0


func _nav_move(target: Vector3, spd: float, delta: float) -> bool:
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() < 0.55:
		_stop()
		return true
	if _nav_goal.distance_to(target) > 0.4:
		_nav_goal = target
		agent.target_position = target
	if agent.is_navigation_finished():
		# Unreachable remainder (e.g. player on a rooftop). Treat as arrived.
		_stop()
		return true
	if unstick_t > 0.0:
		# Side-step away from whatever snagged us, then re-path.
		unstick_t -= delta
		velocity.x = unstick_dir.x * spd * 0.7
		velocity.z = unstick_dir.z * spd * 0.7
		cur_speed = spd
		if unstick_t <= 0.0:
			_nav_goal = Vector3(INF, INF, INF)
		return false
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = flat
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	cur_speed = spd
	_face_dir(dir, delta, 8.0)
	# stuck detection
	if global_position.distance_to(last_pos) < spd * delta * 0.2:
		stuck_t += delta
	else:
		stuck_t = maxf(0.0, stuck_t - delta)
	if stuck_t > 1.0:
		stuck_t = 0.0
		stuck_count += 1
		if stuck_count >= 4:
			stuck_count = 0
			_stop()
			return true  # give up on this point
		var side := Vector3(-dir.z, 0, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
		unstick_dir = (side - dir * 0.5).normalized()
		unstick_t = 0.45
	elif flat.length() < 0.55:
		stuck_count = 0
	return false


func _random_nav_point(center: Vector3, radius: float) -> Vector3:
	var map := get_world_3d().navigation_map
	for i in 6:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.5, radius)
		var c := center + Vector3(cos(a) * r, 0, sin(a) * r)
		var p := NavigationServer3D.map_get_closest_point(map, c)
		if p.distance_to(c) < 1.5 and absf(p.y - center.y) < 1.0:
			return p
	return center


# ================================================================ main loop

func _physics_process(delta: float) -> void:
	_update_labels(delta)
	if state == S.DEAD:
		return
	if not GameState.nav_ready:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	state_t += delta
	_bark_cd -= delta
	attack_cd -= delta
	if restrained:
		_do_restrained(delta)
		return
	if state != S.ASLEEP and state != S.BLINDED and state != S.SPOTTED:
		_perceive(delta)
		_check_bodies(delta)

	match state:
		S.PATROL:
			_do_patrol(delta)
		S.SUSPICIOUS:
			_do_suspicious(delta)
		S.INVESTIGATE:
			_do_investigate(delta)
		S.COMBAT:
			_do_combat(delta)
		S.SEARCH:
			_do_search(delta)
		S.BLINDED:
			_do_blinded(delta)
		S.ASLEEP:
			_do_asleep(delta)
		S.FLEE:
			_do_flee(delta)
		S.COWER:
			_stop()
			model.pose = "cower"
		S.SPOTTED:
			_do_spotted(delta)

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	last_pos = global_position
	if state != S.ASLEEP:
		move_and_slide()
	model.speed = Vector2(velocity.x, velocity.z).length() if state != S.ASLEEP else 0.0


func _update_labels(delta: float) -> void:
	var bt: float = bark_label.get_meta("t", 0.0)
	if bt > 0.0:
		bt -= delta
		bark_label.set_meta("t", bt)
		var a := clampf(bt / 0.6, 0.0, 1.0)
		bark_label.modulate.a = a
		bark_label.outline_modulate.a = a
	var txt := ""
	var col := Color(1, 0.85, 0.2, 0)
	match state:
		S.COMBAT:
			txt = "!"
			col = Color(1.0, 0.15, 0.1, 1.0)
		S.BLINDED:
			txt = "✸"
			col = Color(0.8, 0.5, 1.0, 0.9)
		S.ASLEEP:
			txt = "z z z"
			col = Color(0.5, 0.7, 1.0, 0.6 + 0.3 * sin(state_t * 2.0))
		S.DEAD:
			txt = ""
		S.SPOTTED:
			txt = "!"
			col = Color(1.0, 0.5, 0.05, 0.55 + 0.45 * sin(state_t * 40.0))
		S.FLEE, S.COWER:
			txt = "!!"
			col = Color(1.0, 0.5, 0.1, 1.0)
		_:
			if awareness > 0.08:
				txt = "?"
				col = Color(1.0, lerpf(0.95, 0.35, awareness), 0.2, clampf(awareness * 1.6, 0.2, 1.0))
	indicator.text = txt
	indicator.modulate = col
	indicator.outline_modulate = Color(0, 0, 0, col.a)


# ================================================================ perception

func _can_see_player() -> bool:
	var p = GameState.player
	if p == null or p.dead:
		return false
	var space := get_world_3d().direct_space_state
	var eye := eye_pos()
	var fwd := look_dir()
	var alert := state == S.COMBAT or GameState.alarm_active
	var rng := VIEW_RANGE * (1.35 if alert else 1.0)
	var fov := FOV_HALF + (22.0 if state == S.COMBAT else 0.0)
	for t in [p.head_position(), p.chest_position()]:
		var to: Vector3 = t - eye
		var d := to.length()
		if d > rng:
			continue
		var ang := rad_to_deg(fwd.angle_to(to))
		var sense: bool = d < 2.3 and ang < 150.0 and (not p.crouched or p.moving_fast())
		if ang > fov and not sense:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, t, GameState.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			return true
	return false


func _perceive(delta: float) -> void:
	perceive_t -= delta
	if perceive_t <= 0.0:
		perceive_t = 0.1
		sees_player = _can_see_player()
	var p = GameState.player
	if p == null or p.dead:
		sees_player = false
	if sees_player:
		var d := eye_pos().distance_to(p.chest_position())
		var rng := VIEW_RANGE * (1.35 if GameState.alarm_active else 1.0)
		var df := clampf(1.0 - d / rng, 0.0, 1.0)
		var rate: float = p.visibility * (0.3 + 2.6 * df * df) * 1.5
		if GameState.alarm_active:
			rate *= 1.7
		if state in [S.SUSPICIOUS, S.INVESTIGATE, S.SEARCH]:
			rate *= 1.4
		if d < 2.0:
			rate *= 2.5
		awareness = minf(awareness + rate * delta, 1.5)
		last_known = p.global_position
		lost_t = 0.0
	else:
		lost_t += delta
		if state != S.COMBAT:
			var decay := 0.1 if state == S.PATROL else 0.05
			awareness = maxf(0.0, awareness - decay * delta)

	if state in [S.PATROL, S.SUSPICIOUS, S.INVESTIGATE, S.SEARCH] and awareness >= 1.0:
		if GameState.alarm_active:
			_enter_combat()
		else:
			_enter_spotted()
	elif state == S.PATROL and awareness >= 0.3:
		_set_state(S.SUSPICIOUS)
		bark("suspicious")
		Sfx.play_at("huh", eye_pos(), -4.0)


func _on_noise(pos: Vector3, radius: float, kind: String) -> void:
	if state in [S.DEAD, S.BLINDED, S.COMBAT, S.FLEE, S.COWER, S.SPOTTED] or restrained:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	var r := radius
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.4, eye_pos(), GameState.LAYER_WORLD)
	if not space.intersect_ray(q).is_empty():
		r *= 0.5  # muffled through walls
	if d > r:
		return
	if state == S.ASLEEP:
		if deep_sleep and kind not in ["shout", "panic", "alarm", "deathcry"]:
			return
		if d < r * 0.6:
			wake_up()
			investigate(pos, kind in ["shout", "panic"])
		return
	if kind in ["shout", "panic", "body", "deathcry"]:
		investigate(pos, true)
		return
	# footsteps / lures / snuffs
	var gain := 0.35 if kind == "step" else 0.55
	awareness = clampf(awareness + gain * (1.0 - d / r * 0.5), 0.0, 0.95)
	investigate(pos, false)


func _on_alarm(active: bool) -> void:
	if not active or state in [S.DEAD, S.ASLEEP, S.BLINDED]:
		return
	if is_target and state not in [S.FLEE, S.COWER]:
		bark("target_flee", true)
		_set_state(S.FLEE)


func investigate(pos: Vector3, urgent: bool) -> void:
	if is_target:
		# The lord doesn't go poking around - he looks, then calls for guards.
		last_known = pos
		awareness = maxf(awareness, 0.35)
		if state == S.PATROL:
			_set_state(S.SUSPICIOUS)
			bark("suspicious")
		return
	investigate_pos = pos
	investigate_run = urgent or GameState.alarm_active
	awareness = maxf(awareness, 0.4)
	if state != S.INVESTIGATE:
		bark("investigate" if not urgent else "lost")
		Sfx.play_at("huh", eye_pos(), -5.0)
	_set_state(S.INVESTIGATE)


func _check_bodies(delta: float) -> void:
	body_check_t -= delta
	if body_check_t > 0.0 or state == S.COMBAT or is_target:
		return
	body_check_t = 0.5
	var space := get_world_3d().direct_space_state
	var eye := eye_pos()
	for g in GameState.guards:
		if g == self or not is_instance_valid(g) or g.discovered:
			continue
		if g.state != S.DEAD and g.state != S.ASLEEP:
			continue
		var bp: Vector3 = g.model.chest_center()
		var to := bp - eye
		if to.length() > 13.0 or rad_to_deg(look_dir().angle_to(to)) > 65.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, bp + Vector3.UP * 0.2, GameState.LAYER_WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		g.discovered = true
		if g.state == S.DEAD:
			GameState.stats.bodies_found += 1
			bark("body", true)
			Sfx.play_at("alert", eye, 0.0)
			GameState.raise_alarm()
			GameState.emit_noise(global_position, 20.0, "shout")
			if g.is_target:
				GameState.notify.emit("The lord's body has been found!", 3.0)
			_start_search(g.global_position)
		else:
			bark("sleeper", true)
			wake_target = g
			investigate_pos = g.global_position
			investigate_run = true
			_set_state(S.INVESTIGATE)
		return


# ================================================================ behaviours

func _do_patrol(delta: float) -> void:
	model.pose = idle_pose
	model.head_pitch = 0.0
	if follow != null and is_instance_valid(follow) and follow.is_alive():
		_do_follow(delta)
		return
	var wp: Vector3 = waypoints[wp_i]
	if wait_t >= 0.0:
		wait_t -= delta
		_stop()
		if wp_i < wp_poses.size() and wp_poses[wp_i] != null:
			model.pose = wp_poses[wp_i]
		if wp_i < post_yaws.size() and post_yaws[wp_i] != null:
			rotation.y = lerp_angle(rotation.y, deg_to_rad(post_yaws[wp_i]), minf(1.0, 3.0 * delta))
		if look_around:
			model.head_yaw = sin(state_t * 0.55 + float(wp_i)) * 55.0
		if wait_t < 0.0 and waypoints.size() > 1:
			wp_i = (wp_i + 1) % waypoints.size()
		return
	model.head_yaw = lerpf(model.head_yaw, sin(state_t * 0.4) * 20.0, delta * 2.0)
	if _nav_move(wp, walk_speed, delta):
		wait_t = waits[wp_i] if wp_i < waits.size() else 2.0
		if waypoints.size() == 1:
			wait_t = 1e9


func _do_follow(delta: float) -> void:
	var f := follow as Node3D
	var back := f.global_transform.basis.z
	var side := f.global_transform.basis.x
	var spot := f.global_position + back * 1.4 + side * 0.9
	if global_position.distance_to(spot) > 1.0:
		var spd := walk_speed * (1.4 if global_position.distance_to(spot) > 3.0 else 1.0)
		_nav_move(spot, spd, delta)
		model.head_yaw = lerpf(model.head_yaw, 0.0, delta * 2.0)
	else:
		_stop()
		rotation.y = lerp_angle(rotation.y, f.rotation.y, minf(1.0, 2.0 * delta))
		model.head_yaw = sin(state_t * 0.5) * 60.0


func _do_suspicious(delta: float) -> void:
	_stop()
	model.pose = "alert" if not is_target else "idle"
	_face_point(last_known, delta, 3.0)
	model.head_yaw = lerpf(model.head_yaw, 0.0, delta * 3.0)
	if awareness < 0.08 and state_t > 3.0:
		bark("calm")
		_set_state(S.PATROL)
	elif state_t > 2.2 and awareness >= 0.45 and not is_target:
		investigate(last_known, false)
	elif is_target and state_t > 6.0:
		_set_state(S.PATROL)


func _do_investigate(delta: float) -> void:
	model.pose = "alert" if investigate_run else idle_pose
	if wake_target != null:
		if not is_instance_valid(wake_target) or wake_target.state != S.ASLEEP:
			wake_target = null
		elif global_position.distance_to(wake_target.global_position) < 1.8:
			_stop()
			wake_target.wake_up()
			wake_target.investigate(global_position, true)
			wake_target = null
			GameState.raise_alarm()
			_start_search(global_position)
			return
		else:
			_nav_move(wake_target.global_position, run_speed * 0.8, delta)
			return
	var arrived := false
	if state_t < 60.0 and search_pause <= 0.0:
		arrived = _nav_move(investigate_pos, run_speed * 0.85 if investigate_run else 2.1, delta)
		if arrived:
			search_pause = 4.5
	if search_pause > 0.0:
		_stop()
		search_pause -= delta
		model.head_yaw = sin(state_t * 1.6) * 70.0
		if search_pause <= 0.0:
			if GameState.alarm_active or investigate_run:
				_start_search(investigate_pos)
			else:
				bark("calm")
				awareness = minf(awareness, 0.25)
				_set_state(S.PATROL)


func _enter_spotted() -> void:
	## The reaction window: he has seen you and is drawing breath to shout.
	_set_state(S.SPOTTED)
	spotted_t = REACTION_TIME
	lost_t = 0.0
	awareness = 1.2
	_stop()
	bark("spotted", true)
	Sfx.play_at("huh", eye_pos(), 2.0, 1.5)
	GameState.on_spotted(self)


func _do_spotted(delta: float) -> void:
	_stop()
	model.pose = "alert" if not is_target else "panic"
	var p = GameState.player
	if p:
		_face_point(p.global_position, delta, 10.0)
		last_known = p.global_position
	spotted_t -= delta
	if spotted_t <= 0.0:
		_enter_combat()


func _enter_combat() -> void:
	if is_target:
		GameState.raise_alarm()
		GameState.emit_noise(global_position, 22.0, "shout")
		bark("target_flee", true)
		Sfx.play_at("scream", eye_pos(), 0.0)
		_set_state(S.FLEE)
		return
	_set_state(S.COMBAT)
	awareness = 1.2
	shout_t = 0.0
	lost_t = 0.0
	if GameState.player:
		last_known = GameState.player.global_position
	bark("combat", true)
	Sfx.play_at("alert", eye_pos(), 2.0)
	GameState.raise_alarm()
	GameState.emit_noise(global_position, 22.0, "shout")


func _do_combat(delta: float) -> void:
	model.pose = "alert"
	model.head_yaw = lerpf(model.head_yaw, 0.0, delta * 5.0)
	var p = GameState.player
	if p == null or p.dead:
		_start_search(global_position)
		return
	shout_t -= delta
	if sees_player and shout_t <= 0.0:
		shout_t = 4.0
		GameState.emit_noise(global_position, 18.0, "shout")
		GameState.raise_alarm()
	var d := global_position.distance_to(p.global_position)
	if attack_t >= 0.0:
		_stop()
		_face_point(p.global_position, delta, 4.0)
		attack_t += delta
		model.attack_p = attack_t / ATTACK_TIME
		# Lunge into the swing - backing off barely helps.
		if attack_t > 0.15 and attack_t < ATTACK_HIT:
			var lunge: Vector3 = p.global_position - global_position
			lunge.y = 0.0
			if lunge.length() > 1.0:
				lunge = lunge.normalized() * 3.2
				velocity.x = lunge.x
				velocity.z = lunge.z
		if attack_t > ATTACK_HIT - 0.06 and attack_t < ATTACK_HIT and not attack_hit_done:
			Sfx.play_at("swing", eye_pos(), 0.0)
		if attack_t > ATTACK_HIT and not attack_hit_done:
			attack_hit_done = true
			var to: Vector3 = p.global_position - global_position
			to.y = 0.0
			if to.length() < 2.4 and rad_to_deg(forward().angle_to(to)) < 75.0:
				p.take_damage(ATTACK_DAMAGE, global_position)
		if attack_t >= ATTACK_TIME:
			attack_t = -1.0
			model.attack_p = -1.0
			attack_cd = _rng.randf_range(0.25, 0.6)
		return
	if sees_player and d < 2.3:
		_stop()
		_face_point(p.global_position, delta, 8.0)
		if attack_cd <= 0.0:
			attack_t = 0.0
			attack_hit_done = false
			Sfx.play_at("grunt", eye_pos(), -3.0)
	else:
		_nav_move(last_known, maxf(run_speed, COMBAT_SPEED), delta)
	if lost_t > 6.0:
		bark("lost", true)
		_start_search(last_known)


func _start_search(center: Vector3) -> void:
	search_center = center
	search_pt = center
	search_pause = 0.0
	search_time = 22.0
	awareness = clampf(awareness, 0.4, 0.8)
	_set_state(S.SEARCH)


func _do_search(delta: float) -> void:
	model.pose = "alert"
	search_time -= delta
	if search_pause > 0.0:
		search_pause -= delta
		_stop()
		model.head_yaw = sin(state_t * 1.4) * 75.0
		if search_pause <= 0.0:
			search_pt = _random_nav_point(search_center, 7.0)
	elif _nav_move(search_pt, run_speed * 0.55, delta):
		search_pause = _rng.randf_range(1.5, 3.0)
	if search_time <= 0.0:
		bark("search_end")
		awareness = 0.2
		wait_t = -1.0
		_set_state(S.PATROL)


func _do_flee(delta: float) -> void:
	model.pose = "panic"
	if _nav_move(safe_point, run_speed * 0.9, delta) or state_t > 25.0:
		_set_state(S.COWER)


# ================================================================ magic reactions

func blind(duration := 7.0) -> bool:
	if state in [S.DEAD, S.ASLEEP]:
		return false
	_set_state(S.BLINDED)
	blind_t = duration
	awareness = 0.0
	sees_player = false
	attack_t = -1.0
	model.attack_p = -1.0
	stumble_t = 0.0
	model.pose = "blind"
	bark("blind", true)
	Sfx.play_at("scream", eye_pos(), 1.0)
	# Their panic draws nearby guards to THEM, not to you.
	GameState.emit_noise(global_position, 13.0, "panic")
	return true


func _do_blinded(delta: float) -> void:
	model.pose = "blind"
	blind_t -= delta
	stumble_t -= delta
	if stumble_t <= 0.0:
		stumble_t = _rng.randf_range(0.7, 1.5)
		var a := _rng.randf() * TAU
		stumble_dir = Vector3(cos(a), 0, sin(a))
		if _rng.randf() < 0.35:
			bark("blind", true)
	var spd := 1.1 if stumble_t > 0.4 else 0.2
	velocity.x = stumble_dir.x * spd
	velocity.z = stumble_dir.z * spd
	cur_speed = spd
	_face_dir(stumble_dir, delta, 3.0)
	if blind_t <= 0.0:
		model.pose = "alert"
		if is_target:
			_set_state(S.FLEE)
		else:
			_start_search(global_position)


func try_sleep(duration := 35.0) -> bool:
	if state == S.DEAD or state == S.ASLEEP:
		return false
	if state == S.COMBAT or (sees_player and awareness >= 0.9):
		bark("sleep_resist", true)
		return false
	_enter_sleep(duration, false)
	GameState.stats.knockouts += 1
	return true


func _enter_sleep(duration: float, silent: bool) -> void:
	_set_state(S.ASLEEP)
	sleep_t = duration
	awareness = 0.0
	discovered = silent  # a guard asleep from the start is just off-duty, not suspicious
	model.fall("sleep")
	_stop()
	if snore == null:
		snore = Sfx.make_loop("snore", self, -10.0, 1.5, 10.0)
		snore.position.y = 0.4
	snore.play()
	if not silent:
		GameState.emit_noise(global_position, 3.0, "body")
		Sfx.play_at("fall", global_position, -8.0)


func _do_asleep(delta: float) -> void:
	_stop()
	sleep_t -= delta
	if sleep_t <= 0.0:
		wake_up()
		_start_search(global_position)


func wake_up() -> void:
	if state != S.ASLEEP:
		return
	model.get_up()
	if snore:
		snore.stop()
	bark("woke", true)
	awareness = 0.5
	discovered = true
	_set_state(S.SEARCH)
	search_center = global_position
	search_time = 18.0
	search_pause = 1.5


# ================================================================ taking hits

func receive_strike(attacker_pos: Vector3, hit_pos: Vector3, throat: bool, silenced: bool) -> String:
	## Only a blade across/into the throat kills outright, and only if he isn't
	## squared up fighting you. Anything else is a wound that starts a fight.
	if state == S.DEAD:
		return ""
	var to_att := attacker_pos - global_position
	to_att.y = 0.0
	var behind := rad_to_deg(forward().angle_to(to_att)) > 100.0
	var helpless := state in [S.ASLEEP, S.BLINDED, S.COWER, S.FLEE] or restrained
	var off_guard := state != S.COMBAT  # includes the SPOTTED reaction window
	var mid_swing := state == S.COMBAT and attack_t >= 0.0 and attack_t < ATTACK_HIT
	if throat:
		if is_target or helpless or off_guard or behind or mid_swing:
			die(attacker_pos, true, hit_pos, silenced)
			return "silent" if silenced else "throat"
		Sfx.play_at("clang", hit_pos, 0.0)
		attack_cd = 0.0
		return "block"
	# Body hit.
	if state == S.COMBAT and attack_t < 0.0 and _rng.randf() < 0.7:
		Sfx.play_at("clang", hit_pos, 0.0)
		attack_cd = 0.0  # riposte
		return "block"
	health -= 25.0
	Fx.blood(get_tree().current_scene, hit_pos, (hit_pos - attacker_pos).normalized())
	if health <= 0.0:
		die(attacker_pos, false, hit_pos, false)
		return "kill"
	if restrained:
		restrained = false
	if state == S.ASLEEP:
		model.get_up()
		if snore:
			snore.stop()
	attack_t = -1.0
	model.attack_p = -1.0
	if state != S.COMBAT:
		bark("wounded", true)
		Sfx.play_at("scream", eye_pos(), 2.0, 0.8)
		awareness = 1.5
		last_known = attacker_pos
		_enter_combat()
		return "wounded"
	Sfx.play_at("grunt", eye_pos(), 0.0)
	attack_cd = 0.3
	return "hit"


func receive_bolt(part: String, from_pos: Vector3, hit_pos: Vector3) -> String:
	if state == S.DEAD:
		return ""
	if part == "head":
		die(from_pos, state != S.COMBAT, hit_pos, true, 3.5)
		return "headshot"
	health -= 45.0
	if health <= 0.0:
		die(from_pos, false, hit_pos, false)
		return "kill"
	Fx.blood(get_tree().current_scene, hit_pos, (hit_pos - from_pos).normalized())
	if state == S.ASLEEP:
		model.get_up()
	restrained = false
	if state != S.COMBAT:
		bark("wounded", true)
		Sfx.play_at("scream", eye_pos(), 2.0, 0.8)
		last_known = from_pos
		awareness = 1.5
		_enter_combat()
		return "wounded"
	return "hit"


# ---------------------------------------------------------------- mouth cover

func try_restrain() -> bool:
	if state in [S.DEAD, S.COMBAT] or restrained:
		return false
	restrained = true
	restrain_t = RESTRAIN_TIME
	attack_t = -1.0
	model.attack_p = -1.0
	_stop()
	if state != S.ASLEEP:
		model.pose = "blind"
		bark("muffled", true)
		Sfx.play_at("muffled", eye_pos(), -8.0)
	return true


func release_restraint() -> void:
	if not restrained:
		return
	restrained = false
	if state == S.DEAD or state == S.ASLEEP or state == S.BLINDED:
		return
	# He got loose. He WILL scream.
	bark("broke_free", true)
	awareness = 1.5
	if GameState.player:
		last_known = GameState.player.global_position
	_enter_combat()


func _do_restrained(delta: float) -> void:
	_stop()
	velocity.y = 0.0
	model.speed = 0.0
	restrain_t -= delta
	if state != S.ASLEEP:
		model.pose = "blind"
		awareness = 1.0
		if _rng.randf() < delta * 2.0:
			Sfx.play_at("muffled", eye_pos(), -10.0, _rng.randf_range(0.9, 1.2))
		if restrain_t <= 0.0:
			release_restraint()


func die(attacker_pos: Vector3, sneak: bool, hit_pos: Vector3, silent := false, fall_noise := -1.0) -> void:
	if state == S.DEAD:
		return
	var was_restrained := restrained
	restrained = false
	var from_behind := forward().dot(attacker_pos - global_position) < 0.0
	_set_state(S.DEAD)
	_stop()
	discovered = false
	collision_layer = 0
	collision_mask = 0
	model.attack_p = -1.0
	model.pose = "idle"
	model.fall("dead_fwd" if from_behind else "dead_back")
	if snore:
		snore.stop()
	indicator.text = ""
	GameState.stats.kills += 1
	if sneak:
		GameState.stats.sneak_kills += 1
	Fx.blood(get_tree().current_scene, hit_pos, (hit_pos - attacker_pos).normalized() + Vector3.UP * 0.3)
	if silent:
		# Hand over the mouth: lowered quietly to the floor.
		var fn := fall_noise if fall_noise >= 0.0 else (1.2 if was_restrained else 2.5)
		Sfx.play_at("fall", global_position, -16.0 if was_restrained else -6.0)
		GameState.emit_noise(global_position, fn, "body")
	else:
		# A choked death-cry: everyone nearby comes running.
		Sfx.play_at("deathcry", eye_pos(), 4.0)
		Sfx.play_at("fall", global_position, -4.0)
		bark("wounded", true)
		GameState.emit_noise(global_position, 11.0, "deathcry")
	if lantern:
		# Drop the lantern; it keeps burning beside the body.
		var gp := lantern.global_position
		lantern.reparent(get_tree().current_scene)
		lantern.global_position = Vector3(gp.x, global_position.y + 0.09, gp.z)
		lantern.rotation = Vector3(0, 0, deg_to_rad(80.0))
	if is_target:
		GameState.on_target_killed()
