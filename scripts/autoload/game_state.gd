extends Node
## Global mission state: noise bus, alarm, lights registry, objectives, stats.

signal noise_emitted(pos: Vector3, radius: float, kind: String)
signal alarm_changed(active: bool)
signal objective_changed(text: String)
signal notify(text: String, duration: float)
signal mission_ended(success: bool, summary: String)
signal spotted(guard: Node)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_NPC := 4
const MOON_DIR := Vector3(0.45, 0.62, -0.64)  # direction TOWARD the moon
const MOON_OPEN := 0.10
const MOON_COVERED := 0.025
const ALARM_DURATION := 90.0

var player: Node3D = null
var target: Node3D = null
var guards: Array = []
var lights: Array = []
var hiding_zones: Array = []  # [{pos: Vector3, radius: float, top: float}]
var alarm_active := false
var alarm_timer := 0.0
var target_dead := false
var mission_over := false
var mission_success := false
var nav_ready := false
var is_vr := false
var mission_time := 0.0
var extraction_point := Vector3.ZERO
var objective := ""
var stats := {}
var max_threat := 0.0  # highest guard awareness of the player this frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	reset()


func reset() -> void:
	guards.clear()
	lights.clear()
	hiding_zones.clear()
	player = null
	target = null
	alarm_active = false
	alarm_timer = 0.0
	target_dead = false
	mission_over = false
	mission_success = false
	nav_ready = false
	mission_time = 0.0
	max_threat = 0.0
	objective = ""
	stats = {"kills": 0, "sneak_kills": 0, "knockouts": 0, "detections": 0, "spells": 0, "bodies_found": 0}


func _process(delta: float) -> void:
	if mission_over or not nav_ready:
		return
	mission_time += delta
	var mt := 0.0
	for g in guards:
		if is_instance_valid(g) and g.has_method("threat_level"):
			mt = maxf(mt, g.threat_level())
	max_threat = mt
	if alarm_active:
		alarm_timer -= delta
		if alarm_timer <= 0.0:
			alarm_active = false
			alarm_changed.emit(false)
			notify.emit("The alarm has died down... for now.", 3.5)


func emit_noise(pos: Vector3, radius: float, kind := "noise") -> void:
	noise_emitted.emit(pos, radius, kind)


func raise_alarm() -> void:
	alarm_timer = ALARM_DURATION
	if not alarm_active:
		alarm_active = true
		stats.detections += 1
		alarm_changed.emit(true)
		notify.emit("ALARM RAISED!  Break line of sight and hide.", 4.0)
		Sfx.play_ui("alarm_bell", -4.0)


func on_spotted(g: Node) -> void:
	spotted.emit(g)


func set_objective(t: String) -> void:
	objective = t
	objective_changed.emit(t)


func on_target_killed() -> void:
	if target_dead:
		return
	target_dead = true
	set_objective("Target eliminated. Escape to the extraction point (blue light, south forest).")
	notify.emit("Lord Vane is dead. Now vanish.", 5.0)


func complete_mission() -> void:
	if mission_over:
		return
	mission_over = true
	mission_success = true
	Sfx.play_ui("success", -2.0)
	mission_ended.emit(true, _summary())


func fail_mission(reason: String) -> void:
	if mission_over:
		return
	mission_over = true
	mission_success = false
	mission_ended.emit(false, reason + "\n\n" + _summary())


func _summary() -> String:
	var mins := int(mission_time) / 60
	var secs := int(mission_time) % 60
	var rating := "Shadow"
	var extra_kills: int = stats.kills - (1 if target_dead else 0)
	if stats.detections == 0 and extra_kills == 0:
		rating = "SILENT ASSASSIN"
	elif stats.detections == 0:
		rating = "Ghost Blade"
	elif stats.detections <= 1:
		rating = "Nightstalker"
	else:
		rating = "Butcher"
	return "Time %d:%02d   Kills %d (%d from the shadows)   Sleepers %d\nAlarms %d   Spells cast %d   Bodies found %d\n\nRating: %s" % [
		mins, secs, stats.kills, stats.sneak_kills, stats.knockouts, stats.detections, stats.spells, stats.bodies_found, rating]


func light_level_at(pos: Vector3, space: PhysicsDirectSpaceState3D) -> float:
	## How lit is this point? 0 = pitch black, 1+ = brightly lit.
	var total := MOON_OPEN
	var q := PhysicsRayQueryParameters3D.create(pos, pos + MOON_DIR.normalized() * 60.0, LAYER_WORLD)
	if not space.intersect_ray(q).is_empty():
		total = MOON_COVERED
	for l in lights:
		if not is_instance_valid(l) or not l.is_lit():
			continue
		var lp: Vector3 = l.light_position()
		var r: float = l.light_range()
		var d := lp.distance_to(pos)
		if d >= r:
			continue
		var lq := PhysicsRayQueryParameters3D.create(lp, pos, LAYER_WORLD)
		if space.intersect_ray(lq).is_empty():
			var f := 1.0 - d / r
			total += f * f * l.light_strength()
	return clampf(total, 0.0, 1.3)


func add_hiding_zone(pos: Vector3, radius: float, top: float) -> void:
	hiding_zones.append({"pos": pos, "radius": radius, "top": top})


func in_hiding_zone(feet: Vector3, head_height: float) -> bool:
	for z in hiding_zones:
		var zp: Vector3 = z.pos
		var dx := feet.x - zp.x
		var dz := feet.z - zp.z
		if dx * dx + dz * dz < z.radius * z.radius and feet.y + head_height < zp.y + z.top + 0.25 and absf(feet.y - zp.y) < 1.0:
			return true
	return false


# ---------------------------------------------------------------- desktop input map

func _setup_input() -> void:
	_key("move_forward", KEY_W)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_S)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	_key("sprint", KEY_SHIFT)
	_key("crouch", KEY_C)
	_key("crouch", KEY_CTRL)
	_key("spell_prev", KEY_Q)
	_key("spell_next", KEY_E)
	_key("restart", KEY_R)
	_key("toggle_mouse", KEY_ESCAPE)
	_key("help", KEY_H)
	_key("draw_dagger", KEY_F)
	_key("draw_crossbow", KEY_B)
	_key("grab", KEY_V)
	for i in 6:
		_key("spell_%d" % (i + 1), KEY_1 + i)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_mouse("cast", MOUSE_BUTTON_RIGHT)
	_mouse("spell_prev", MOUSE_BUTTON_WHEEL_UP)
	_mouse("spell_next", MOUSE_BUTTON_WHEEL_DOWN)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _key(action: String, code: Key) -> void:
	_ensure(action)
	var e := InputEventKey.new()
	e.physical_keycode = code
	InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
