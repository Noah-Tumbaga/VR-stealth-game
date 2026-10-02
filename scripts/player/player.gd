extends CharacterBody3D
## The assassin. Works in OpenXR (room-scale + smooth locomotion, physical blade
## swings, gesture-free spell casting from the left hand) and falls back to
## mouse/keyboard on desktop when no headset is present.

const HandModels = preload("res://scripts/player/hand_models.gd")
const Projectile = preload("res://scripts/magic/spell_projectile.gd")
const Fx = preload("res://scripts/fx/fx.gd")
const Mats = preload("res://scripts/util/mats.gd")
const Geo = preload("res://scripts/util/geo.gd")
const Weapons = preload("res://scripts/player/weapons.gd")

const SPELLS := [
	{"id": "blind", "name": "Blinding Hex", "cost": 30.0, "color": Color(0.78, 0.5, 1.0),
		"desc": "Searing shadow-light. Guards in the burst go blind and panic - helpless prey."},
	{"id": "slumber", "name": "Slumber", "cost": 35.0, "color": Color(0.45, 0.7, 1.0),
		"desc": "Sends an UNAWARE mind into deep sleep. Fails against alerted guards."},
	{"id": "echo", "name": "Echo Lure", "cost": 15.0, "color": Color(0.35, 1.0, 0.7),
		"desc": "Hurls a phantom clatter. Guards nearby go to investigate it."},
	{"id": "snuff", "name": "Snuff", "cost": 10.0, "color": Color(1.0, 0.55, 0.25),
		"desc": "Extinguishes a torch, brazier or lantern you point at."},
	{"id": "step", "name": "Shadow Step", "cost": 25.0, "color": Color(0.55, 0.3, 1.0),
		"desc": "Silent blink. Aim at a wall's top edge to mount ledges and roofs."},
	{"id": "shroud", "name": "Shroud", "cost": 40.0, "color": Color(0.35, 0.3, 0.55),
		"desc": "Wraps you in living darkness for 10s. Broken by attacking."},
]

const WALK := 2.4
const CROUCH := 1.35
const SPRINT := 4.8
const STEP_MAX := 13.0
const MANA_REGEN := 6.5
const DESK_LEFT := Vector3(-0.26, -0.27, -0.42)

var vr := false
var hud: Node = null
var origin: XROrigin3D
var camera: XRCamera3D
var left_ctrl: XRController3D
var right_ctrl: XRController3D
var left_aim: XRController3D
var left_rig: Node3D
var right_rig: Node3D
var weapons: Node
var orb: MeshInstance3D
var orb_halo: MeshInstance3D
var orb_ring: MeshInstance3D
var wrist_label: Label3D
var mana_bar: MeshInstance3D
var health_bar: MeshInstance3D
var gem: MeshInstance3D
var capsule: CapsuleShape3D
var col_shape: CollisionShape3D
var overlay_mat: StandardMaterial3D
var aim_marker: MeshInstance3D
var aim_marker_mat: StandardMaterial3D
var aim_beam: MeshInstance3D
var step_ghost: MeshInstance3D
var vr_msg: Label3D
var ambience: AudioStreamPlayer
var crickets: AudioStreamPlayer

var health := 100.0
var mana := 100.0
var spell_idx := 0
var visibility := 0.1
var light_level := 0.1
var crouched := false
var in_hiding := false
var dead := false
var sprinting := false
var head_h := 1.65
var standing_h := 1.6
var shroud_t := 0.0
var step_accum := 0.0
var stagger_t := 0.0
var spotted_flash := 0.0
var cast_anim := -1.0
var damage_flash := 0.0
var fade := 1.0
var fade_target := 0.0
var regen_delay := 0.0
var vis_t := 0.0
var heart_t := 0.0
var yaw := 0.0
var pitch := 0.0
var desktop_crouch := false
var virtual_crouch := false
var snap_ready := true
var crouch_ready := true
var trig_l_high := false
var btn_prev := {}
var aiming := false
var aim_valid := false
var aim_point := Vector3.ZERO
var aim_torch = null
var horiz_speed := 0.0
var _prev_pos := Vector3.ZERO
var _msg_t := 0.0
var _orb_t := 0.0
var _hands_shrouded := false


func setup(p_vr: bool, p_hud: Node) -> void:
	vr = p_vr
	hud = p_hud


func _ready() -> void:
	collision_layer = GameState.LAYER_PLAYER
	collision_mask = GameState.LAYER_WORLD | GameState.LAYER_NPC
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.7
	col_shape = CollisionShape3D.new()
	col_shape.shape = capsule
	col_shape.position.y = 0.85
	add_child(col_shape)

	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	camera.near = 0.03
	camera.far = 400.0
	origin.add_child(camera)
	left_ctrl = XRController3D.new()
	left_ctrl.tracker = &"left_hand"
	left_ctrl.pose = &"grip"
	origin.add_child(left_ctrl)
	right_ctrl = XRController3D.new()
	right_ctrl.tracker = &"right_hand"
	right_ctrl.pose = &"grip"
	origin.add_child(right_ctrl)
	left_aim = XRController3D.new()
	left_aim.tracker = &"left_hand"
	left_aim.pose = &"aim"
	origin.add_child(left_aim)

	left_rig = HandModels.build_left_hand()
	right_rig = HandModels.build_right_hand()
	if vr:
		left_ctrl.add_child(left_rig)
		right_ctrl.add_child(right_rig)
	else:
		camera.position.y = 1.62
		camera.fov = 78.0
		camera.current = true
		camera.add_child(left_rig)
		camera.add_child(right_rig)
		left_rig.position = DESK_LEFT
		left_rig.rotation_degrees = Vector3(25, 20, -15)
		left_rig.scale = Vector3.ONE * 0.8
	orb = left_rig.get_node("OrbRoot/Orb")
	orb_halo = left_rig.get_node("OrbRoot/Halo")
	orb_ring = left_rig.get_node("OrbRoot/Ring")
	wrist_label = left_rig.get_node("Wrist/Label")
	mana_bar = left_rig.get_node("Wrist/Mana")
	health_bar = left_rig.get_node("Wrist/Health")
	gem = left_rig.get_node("Wrist/Gem")
	_build_overlay()
	_build_aim_visuals()
	weapons = Weapons.new()
	weapons.name = "Weapons"
	add_child(weapons)
	weapons.setup(self)

	ambience = AudioStreamPlayer.new()
	ambience.stream = Sfx.streams.get("wind")
	ambience.volume_db = -12.0
	ambience.autoplay = true
	add_child(ambience)
	crickets = AudioStreamPlayer.new()
	crickets.stream = Sfx.streams.get("crickets")
	crickets.volume_db = -22.0
	crickets.autoplay = true
	add_child(crickets)

	GameState.player = self
	GameState.notify.connect(_on_notify)
	GameState.mission_ended.connect(_on_mission_ended)
	GameState.spotted.connect(_on_spotted)
	_prev_pos = global_position
	_select_spell(0, true)
	if not vr:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_overlay() -> void:
	overlay_mat = StandardMaterial3D.new()
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	overlay_mat.no_depth_test = true
	overlay_mat.render_priority = 127
	overlay_mat.albedo_color = Color(0, 0, 0, 1)
	var s := Geo.sphere(camera, 0.12, Vector3.ZERO, overlay_mat, Vector3.ONE, false, 16)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vr_msg = Label3D.new()
	vr_msg.font_size = 44
	vr_msg.outline_size = 10
	vr_msg.pixel_size = 0.0011
	vr_msg.no_depth_test = true
	vr_msg.render_priority = 127
	vr_msg.outline_render_priority = 126
	vr_msg.position = Vector3(0, -0.12, -1.0)
	vr_msg.modulate = Color(1, 1, 1, 0)
	vr_msg.outline_modulate = Color(0, 0, 0, 0)
	vr_msg.width = 900.0
	vr_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camera.add_child(vr_msg)


func _build_aim_visuals() -> void:
	aim_marker_mat = StandardMaterial3D.new()
	aim_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_marker_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aim_marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aim_marker_mat.albedo_color = Color(0.6, 0.4, 1.0, 0.8)
	aim_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.22
	aim_marker.mesh = tm
	aim_marker.material_override = aim_marker_mat
	aim_marker.top_level = true
	aim_marker.visible = false
	add_child(aim_marker)
	step_ghost = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.28
	cm.height = 1.7
	cm.cap_top = false
	cm.cap_bottom = false
	step_ghost.mesh = cm
	var gm := aim_marker_mat.duplicate() as StandardMaterial3D
	gm.albedo_color = Color(0.4, 0.25, 0.9, 0.18)
	step_ghost.material_override = gm
	step_ghost.top_level = true
	step_ghost.visible = false
	add_child(step_ghost)
	aim_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.004
	bm.bottom_radius = 0.004
	bm.height = 1.0
	aim_beam.mesh = bm
	aim_beam.material_override = aim_marker_mat
	aim_beam.top_level = true
	aim_beam.visible = false
	add_child(aim_beam)


# ================================================================ queries used by AI

func head_position() -> Vector3:
	return camera.global_position


func chest_position() -> Vector3:
	return global_position + Vector3.UP * maxf(head_h * 0.62, 0.5)


func moving_fast() -> bool:
	return horiz_speed > 2.0


# ================================================================ main loop

func _physics_process(delta: float) -> void:
	if not dead and not GameState.mission_over:
		if vr:
			_vr_locomotion(delta)
		else:
			_desktop_locomotion(delta)
		_update_posture(delta)
		_footsteps(delta)
		_update_visibility(delta)
		weapons.update(delta)
		_update_spells(delta)
		_check_extraction()
	elif vr and GameState.mission_over:
		if _vr_pressed("menu_button", right_ctrl) or _vr_pressed("menu_button", left_ctrl) or _vr_pressed("ax_button", right_ctrl):
			_restart()
	_update_feedback(delta)


func _process(_delta: float) -> void:
	if not vr:
		origin.rotation.y = yaw
		camera.rotation.x = pitch


# ---------------------------------------------------------------- VR locomotion

func _vr_btn(btn: String, ctrl: XRController3D) -> bool:
	return ctrl.is_button_pressed(btn)


func _vr_pressed(btn: String, ctrl: XRController3D) -> bool:
	var key := "%s_%s" % [ctrl.tracker, btn]
	var now := ctrl.is_button_pressed(btn)
	var was: bool = btn_prev.get(key, false)
	btn_prev[key] = now
	return now and not was


func _vr_locomotion(delta: float) -> void:
	# 1) Room-scale: drag the body under the headset, keeping the camera fixed in world.
	var off := camera.global_position - global_position
	off.y = 0.0
	if off.length() > 0.03:
		var before := global_position
		velocity = off / delta
		velocity.y = 0.0
		move_and_slide()
		var moved := global_position - before
		moved.y = 0.0
		origin.global_position -= moved
	# 2) Smooth locomotion on the left stick, head-relative.
	var stick := left_ctrl.get_vector2("primary")
	if stick.length() < 0.15:
		stick = Vector2.ZERO
	var fwd := -camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	sprinting = _vr_btn("primary_click", left_ctrl) and stick.length() > 0.8 and not crouched
	var spd := (CROUCH if crouched else (SPRINT if sprinting else WALK)) * (0.35 if stagger_t > 0.0 else 1.0)
	var wish := (fwd * stick.y + right * stick.x) * spd
	velocity.x = wish.x
	velocity.z = wish.z
	if is_on_floor():
		velocity.y = -0.3
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()
	# 3) Snap turn & crouch toggle on the right stick.
	var rs := right_ctrl.get_vector2("primary")
	if absf(rs.x) > 0.7 and snap_ready:
		_rotate_around_camera(-signf(rs.x) * deg_to_rad(40.0))
		snap_ready = false
	elif absf(rs.x) < 0.3:
		snap_ready = true
	if rs.y < -0.75 and crouch_ready:
		virtual_crouch = not virtual_crouch
		crouch_ready = false
	elif rs.y > -0.3:
		crouch_ready = true
	origin.position.y = lerpf(origin.position.y, -0.6 if virtual_crouch else 0.0, minf(1.0, 10.0 * delta))
	if _vr_pressed("menu_button", left_ctrl):
		GameState.notify.emit(GameState.objective, 4.0)


func _rotate_around_camera(angle: float) -> void:
	var pivot := camera.global_position
	var t := origin.global_transform
	t.origin -= pivot
	t = Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO) * t
	t.origin += pivot
	origin.global_transform = t


# ---------------------------------------------------------------- desktop locomotion

func _unhandled_input(event: InputEvent) -> void:
	if vr:
		return
	if event.is_action_pressed("restart") and (GameState.mission_over or dead):
		_restart()
		return
	if event.is_action_pressed("restart") and Input.is_key_pressed(KEY_SHIFT):
		_restart()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.45, 1.45)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if dead or GameState.mission_over:
		return
	if event.is_action_pressed("crouch"):
		desktop_crouch = not desktop_crouch
	if event.is_action_pressed("spell_next"):
		_select_spell(spell_idx + 1)
	if event.is_action_pressed("spell_prev"):
		_select_spell(spell_idx - 1)
	for i in SPELLS.size():
		if event.is_action_pressed("spell_%d" % (i + 1)):
			_select_spell(i)
	weapons.desktop_input(event)
	if event.is_action_pressed("help") and hud:
		hud.toggle_help()


func _desktop_locomotion(delta: float) -> void:
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprinting = Input.is_action_pressed("sprint") and iv.length() > 0.1 and not desktop_crouch
	var spd := (CROUCH if desktop_crouch else (SPRINT if sprinting else WALK)) * (0.35 if stagger_t > 0.0 else 1.0)
	var dir := (origin.global_transform.basis * Vector3(iv.x, 0, iv.y))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var accel := minf(1.0, 12.0 * delta)
	velocity.x = lerpf(velocity.x, dir.x * spd, accel)
	velocity.z = lerpf(velocity.z, dir.z * spd, accel)
	if is_on_floor():
		velocity.y = -0.3
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()
	var target_h := 1.0 if desktop_crouch else 1.62
	camera.position.y = lerpf(camera.position.y, target_h, minf(1.0, 9.0 * delta))
	# bob
	var bob := sin(Time.get_ticks_msec() * 0.001 * (9.0 if sprinting else 6.5)) * clampf(horiz_speed / 4.0, 0.0, 1.0) * 0.025
	camera.position.y += bob * delta * 4.0


func _update_posture(delta: float) -> void:
	head_h = camera.global_position.y - global_position.y
	if vr:
		var raw_h := head_h + (0.6 if virtual_crouch else 0.0)
		if raw_h > standing_h:
			standing_h = lerpf(standing_h, raw_h, minf(1.0, 2.0 * delta))
		crouched = head_h < standing_h * 0.74
	else:
		crouched = desktop_crouch
	capsule.height = clampf(head_h + 0.08, 0.9, 1.9)
	col_shape.position.y = capsule.height * 0.5
	var moved := global_position - _prev_pos
	moved.y = 0.0
	horiz_speed = lerpf(horiz_speed, moved.length() / maxf(delta, 0.0001), minf(1.0, 10.0 * delta))
	_prev_pos = global_position


func _footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	step_accum += horiz_speed * delta
	var stride := 1.1 if sprinting else 0.72
	if step_accum < stride:
		return
	step_accum = 0.0
	var radius := 5.5
	if crouched:
		radius = 1.4
	elif horiz_speed > 3.2:
		radius = STEP_MAX
	elif horiz_speed < 1.2:
		radius = 3.0
	# Silent for you, but guards can still hear you moving.
	GameState.emit_noise(global_position, radius, "step")


# ---------------------------------------------------------------- stealth

func _update_visibility(delta: float) -> void:
	vis_t -= delta
	if vis_t > 0.0:
		return
	vis_t = 0.1
	var space := get_world_3d().direct_space_state
	light_level = GameState.light_level_at(chest_position(), space)
	var v := light_level
	if crouched:
		v *= 0.6
	v *= 1.0 + clampf(horiz_speed / 4.5, 0.0, 1.0) * 0.4
	in_hiding = GameState.in_hiding_zone(global_position, head_h)
	if in_hiding:
		v *= 0.18
	if shroud_t > 0.0:
		v *= 0.12
	visibility = clampf(v, 0.015, 1.0)


func take_damage(amount: float, _from_pos: Vector3) -> void:
	if dead or GameState.mission_over:
		return
	health -= amount
	damage_flash = 1.0
	regen_delay = 12.0
	stagger_t = 0.9  # the blow knocks you half off your feet
	_end_shroud()
	weapons.release_grab()
	Sfx.play_ui("hurt", 2.0)
	_haptic(left_ctrl, 1.0, 0.4)
	_haptic(right_ctrl, 1.0, 0.4)
	if health <= 0.0:
		health = 0.0
		dead = true
		fade_target = 0.85
		GameState.fail_mission("You were cut down.")


func _check_extraction() -> void:
	if GameState.target_dead and global_position.distance_to(GameState.extraction_point) < 2.6:
		fade_target = 0.7
		GameState.complete_mission()


func _restart() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- spells

func _select_spell(i: int, silent := false) -> void:
	spell_idx = posmod(i, SPELLS.size())
	var s: Dictionary = SPELLS[spell_idx]
	var c: Color = s.color
	var om := orb.material_override as StandardMaterial3D
	om.albedo_color = c
	om.emission = c
	var hm := orb_halo.material_override as StandardMaterial3D
	hm.albedo_color = Color(c.r * 1.0, c.g * 1.0, c.b * 1.0, 0.3)
	aim_marker_mat.albedo_color = Color(c.r, c.g, c.b, 0.8)
	if not silent:
		Sfx.play_ui("ui_tick", -6.0)
		_haptic(left_ctrl, 0.3, 0.05)
		if not vr:
			pass
		else:
			GameState.notify.emit("%s  (%d)\n%s" % [s.name, int(s.cost), s.desc], 2.5)


func _aim_ray() -> Array:
	## Returns [origin, direction]
	if vr:
		var t := left_aim.global_transform
		if t.origin.distance_to(left_ctrl.global_position) > 0.5 or not left_aim.get_has_tracking_data():
			t = left_ctrl.global_transform
		return [t.origin, -t.basis.z]
	return [camera.global_position, -camera.global_transform.basis.z]


func _update_spells(delta: float) -> void:
	_orb_t += delta
	mana = minf(100.0, mana + MANA_REGEN * delta)
	if regen_delay > 0.0:
		regen_delay -= delta
	elif health < 100.0 and not GameState.alarm_active:
		health = minf(100.0, health + 3.0 * delta)
	if shroud_t > 0.0:
		shroud_t -= delta
		if shroud_t <= 0.0:
			_end_shroud()
			GameState.notify.emit("The shroud fades.", 1.5)
	var cast := false
	if vr:
		var trig := left_ctrl.get_float("trigger")
		aiming = trig > 0.12
		if trig > 0.85 and not trig_l_high:
			cast = true
		if trig > 0.85:
			trig_l_high = true
		elif trig < 0.5:
			trig_l_high = false
		if _vr_pressed("by_button", left_ctrl):
			_select_spell(spell_idx + 1)
		if _vr_pressed("ax_button", left_ctrl):
			_select_spell(spell_idx - 1)
	else:
		aiming = Input.is_action_pressed("cast")
		if Input.is_action_just_released("cast"):
			cast = true
		var s_id: String = SPELLS[spell_idx].id
		if s_id == "step" or s_id == "snuff":
			aiming = true
	var ray := _aim_ray()
	_update_aim(ray)
	if cast:
		_cast(ray)
	# desktop: animate casting hand
	if not vr:
		if cast_anim >= 0.0:
			cast_anim += delta
			var e := sin(clampf(cast_anim / 0.3, 0.0, 1.0) * PI)
			left_rig.position = DESK_LEFT + Vector3(0.08, 0.1, -0.25) * e
			if cast_anim > 0.3:
				cast_anim = -1.0
		else:
			left_rig.position = left_rig.position.lerp(DESK_LEFT + (Vector3(0.04, 0.06, -0.08) if aiming else Vector3.ZERO), minf(1.0, 10.0 * delta))
	# orb pulse
	var has_mana := mana >= float(SPELLS[spell_idx].cost)
	var pulse := 0.8 + 0.2 * sin(_orb_t * 5.0)
	orb.scale = Vector3.ONE * (pulse * (1.25 if aiming else 1.0) * (1.0 if has_mana else 0.55) * (1.0 if vr else 0.6))
	(orb.material_override as StandardMaterial3D).emission_energy_multiplier = (4.0 if aiming else 2.2) * (1.0 if has_mana else 0.3)
	orb_ring.rotate_object_local(Vector3.UP, delta * 2.5)
	orb_halo.visible = has_mana


func _update_aim(ray: Array) -> void:
	aim_marker.visible = false
	step_ghost.visible = false
	aim_beam.visible = false
	aim_valid = false
	aim_torch = null
	if not aiming:
		return
	var s_id: String = SPELLS[spell_idx].id
	var from: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var space := get_world_3d().direct_space_state
	match s_id:
		"step":
			var dest = _blink_target(from, dir, space)
			if dest != null:
				aim_valid = true
				aim_point = dest
				aim_marker.visible = true
				aim_marker.global_position = dest + Vector3.UP * 0.03
				aim_marker.rotation = Vector3.ZERO
				step_ghost.visible = true
				step_ghost.global_position = dest + Vector3.UP * 0.85
		"snuff":
			aim_torch = _find_torch(from, dir, space)
			if aim_torch:
				aim_valid = true
				aim_marker.visible = true
				aim_marker.global_position = aim_torch.light_position()
				aim_marker.look_at(aim_marker.global_position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
				aim_marker.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		"shroud":
			aim_valid = true
		_:
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * 32.0, GameState.LAYER_WORLD)
			var hit := space.intersect_ray(q)
			aim_valid = true
			aim_point = hit.position if not hit.is_empty() else from + dir * 32.0
			aim_marker.visible = not hit.is_empty()
			if not hit.is_empty():
				aim_marker.global_position = hit.position + hit.normal * 0.02
				var n: Vector3 = hit.normal
				aim_marker.global_transform.basis = _basis_from_up(n)
	if vr and aim_valid and s_id != "shroud":
		var o := orb.global_position
		var target: Vector3 = aim_point if s_id != "snuff" else aim_torch.light_position()
		var blen := o.distance_to(target)
		if blen > 0.1:
			aim_beam.visible = true
			aim_beam.global_transform = Transform3D(_basis_from_up((target - o).normalized()), (o + target) * 0.5)
			aim_beam.scale = Vector3(1, blen, 1)


func _basis_from_up(up: Vector3) -> Basis:
	up = up.normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


func _find_torch(from: Vector3, dir: Vector3, space: PhysicsDirectSpaceState3D) -> Node3D:
	var best: Node3D = null
	var best_ang := 9.0
	for l in GameState.lights:
		if not is_instance_valid(l) or not l.is_lit() or not l.snuffable:
			continue
		var lp: Vector3 = l.light_position()
		var to := lp - from
		var d := to.length()
		if d > 30.0:
			continue
		var ang := rad_to_deg(dir.angle_to(to))
		if ang < best_ang:
			var q := PhysicsRayQueryParameters3D.create(from, lp - to.normalized() * 0.35, GameState.LAYER_WORLD)
			if space.intersect_ray(q).is_empty():
				best = l
				best_ang = ang
	return best


func _blink_target(from: Vector3, dir: Vector3, space: PhysicsDirectSpaceState3D):
	var max_d := 13.0
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_d, GameState.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	var p: Vector3
	if hit.is_empty():
		p = from + dir * max_d
		var dq := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 25.0, GameState.LAYER_WORLD)
		var dh := space.intersect_ray(dq)
		if dh.is_empty():
			return null
		p = dh.position
	else:
		var n: Vector3 = hit.normal
		if n.y > 0.6:
			p = hit.position
		else:
			# Ledge mantle: is there a walkable top just above where we hit?
			var probe: Vector3 = hit.position - Vector3(n.x, 0, n.z).normalized() * 0.45 + Vector3.UP * 2.2
			var lq := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 2.6, GameState.LAYER_WORLD)
			var lh := space.intersect_ray(lq)
			var mantled := false
			if not lh.is_empty() and lh.normal.y > 0.6 and lh.position.y > hit.position.y - 0.2:
				var free_q := PhysicsRayQueryParameters3D.create(hit.position + n * 0.3 + Vector3.UP * 2.2, probe, GameState.LAYER_WORLD)
				if space.intersect_ray(free_q).is_empty():
					p = lh.position
					mantled = true
			if not mantled:
				var back: Vector3 = hit.position + n * 0.45
				var dq2 := PhysicsRayQueryParameters3D.create(back, back + Vector3.DOWN * 25.0, GameState.LAYER_WORLD)
				var dh2 := space.intersect_ray(dq2)
				if dh2.is_empty():
					return null
				p = dh2.position
	# Headroom check
	var hq := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.1, p + Vector3.UP * 1.5, GameState.LAYER_WORLD)
	if not space.intersect_ray(hq).is_empty():
		return null
	return p


func _cast(ray: Array) -> void:
	var s: Dictionary = SPELLS[spell_idx]
	var cost: float = s.cost
	if mana < cost:
		Sfx.play_ui("fizzle", -6.0)
		GameState.notify.emit("Not enough mana.", 1.2)
		return
	var from: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var ok := true
	match s.id:
		"blind", "slumber", "echo":
			var o := orb.global_position
			var space := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * 32.0, GameState.LAYER_WORLD)
			var hit := space.intersect_ray(q)
			var target: Vector3 = hit.position if not hit.is_empty() else from + dir * 32.0
			var pdir := (target - o).normalized() if not vr else dir
			var p := Projectile.new()
			p.launch(s.id, pdir, s.color)
			get_tree().current_scene.add_child(p)
			p.global_position = o + pdir * 0.08
		"snuff":
			if aim_torch == null:
				aim_torch = _find_torch(from, dir, get_world_3d().direct_space_state)
			if aim_torch:
				aim_torch.extinguish()
				Fx.burst(get_tree().current_scene, orb.global_position, [Color(1, 0.6, 0.3, 1), Color(1, 0.3, 0.1, 0)], 12, 0.4, Vector2(0.5, 1.5), 0.03, Vector3.ZERO, true)
			else:
				ok = false
				GameState.notify.emit("No flame there to snuff.", 1.2)
		"step":
			var dest = _blink_target(from, dir, get_world_3d().direct_space_state)
			if dest == null:
				ok = false
				GameState.notify.emit("Can't step there.", 1.2)
			else:
				_teleport(dest)
		"shroud":
			shroud_t = 10.0
			Sfx.play_ui("shroud", -2.0)
			_set_hands_shrouded(true)
			GameState.notify.emit("Shrouded in darkness.", 1.5)
	if not ok:
		Sfx.play_ui("fizzle", -6.0)
		return
	mana -= cost
	GameState.stats.spells += 1
	cast_anim = 0.0
	Sfx.play_at("cast", orb.global_position, -6.0)
	_haptic(left_ctrl, 0.6, 0.12)


func _teleport(dest: Vector3) -> void:
	Fx.shadow_puff(get_tree().current_scene, global_position + Vector3.UP * 0.9)
	Sfx.play_ui("shadowstep", -2.0)
	var cam_off := camera.global_position - global_position
	cam_off.y = 0.0
	global_position = dest + Vector3.UP * 0.05
	velocity = Vector3.ZERO
	if vr:
		origin.global_position -= cam_off
	_prev_pos = global_position
	fade = maxf(fade, 0.75)
	Fx.shadow_puff(get_tree().current_scene, dest + Vector3.UP * 0.9)


func _set_hands_shrouded(on: bool) -> void:
	_hands_shrouded = on
	for rig in [left_rig.get_node("Visual"), right_rig.get_node("Visual")]:
		for c in rig.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			mi.transparency = 0.65 if on else 0.0


func _end_shroud() -> void:
	if shroud_t > 0.0 or _hands_shrouded:
		shroud_t = 0.0
		_set_hands_shrouded(false)


# ---------------------------------------------------------------- feedback / UI

func _haptic(ctrl: XRController3D, amp: float, dur: float) -> void:
	if vr and ctrl:
		ctrl.trigger_haptic_pulse("haptic", 0.0, amp, dur, 0.0)


func _update_feedback(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta * 1.6)
	spotted_flash = maxf(0.0, spotted_flash - delta * 2.5)
	stagger_t = maxf(0.0, stagger_t - delta)
	fade = move_toward(fade, fade_target, delta * (2.5 if fade > fade_target else 0.8))
	var low_hp := clampf(1.0 - health / 45.0, 0.0, 1.0) * (0.25 + 0.1 * sin(Time.get_ticks_msec() * 0.006))
	var col := Color(0, 0, 0, fade)
	var red := damage_flash * 0.65 + low_hp + spotted_flash * 0.3
	if red > 0.0:
		col = Color(lerpf(0.0, 0.5, red / (red + fade + 0.001)), 0.0, 0.0, clampf(fade + red, 0.0, 1.0))
	if shroud_t > 0.0 and fade < 0.1:
		col = Color(0.08, 0.03, 0.16, maxf(col.a, 0.22 if vr else 0.28))
	overlay_mat.albedo_color = col

	# heartbeat when being noticed
	var threat := GameState.max_threat
	if threat > 0.3 and not dead and not GameState.mission_over:
		heart_t -= delta
		if heart_t <= 0.0:
			heart_t = lerpf(1.1, 0.45, threat)
			Sfx.play_ui("heartbeat", lerpf(-14.0, -2.0, threat))
			_haptic(left_ctrl, 0.25 * threat, 0.06)
	else:
		heart_t = 0.0

	# wrist display
	var s: Dictionary = SPELLS[spell_idx]
	wrist_label.text = "%s  %d\n%s" % [s.name, int(s.cost), weapons.status_text()]
	var sc: Color = s.color
	wrist_label.modulate = sc.lightened(0.3) if mana >= float(s.cost) else Color(0.5, 0.5, 0.55)
	mana_bar.scale.x = maxf(mana / 100.0, 0.001)
	mana_bar.position.x = -0.04 * (1.0 - mana / 100.0)
	health_bar.scale.x = maxf(health / 100.0, 0.001)
	health_bar.position.x = -0.04 * (1.0 - health / 100.0)
	var gm := gem.material_override as StandardMaterial3D
	gm.emission_energy_multiplier = lerpf(0.05, 6.0, visibility)
	gm.emission = Color(1.0, 0.85, 0.5).lerp(Color(0.3, 0.2, 0.6), 1.0 - visibility)

	# messages in VR
	if _msg_t > 0.0:
		_msg_t -= delta
		var a := clampf(_msg_t / 0.5, 0.0, 1.0)
		vr_msg.modulate.a = a
		vr_msg.outline_modulate.a = a
	if hud:
		hud.update_status(self)


func _on_spotted(_g: Node) -> void:
	spotted_flash = 1.0
	Sfx.play_ui("spotted", 0.0)
	_haptic(left_ctrl, 1.0, 0.2)
	_haptic(right_ctrl, 1.0, 0.2)
	GameState.notify.emit("SPOTTED!  Silence him before he shouts!", 1.0)


func on_bolt_result(result: String) -> void:
	match result:
		"headshot":
			Sfx.play_ui("kill", -6.0)
			GameState.notify.emit("Headshot.", 1.0)
		"wounded":
			GameState.notify.emit("Only wounded! He's raising the alarm!", 1.8)


func _on_notify(text: String, duration: float) -> void:
	if vr:
		vr_msg.text = text
		_msg_t = duration
		vr_msg.modulate.a = 1.0


func _on_mission_ended(success: bool, summary: String) -> void:
	if vr:
		vr_msg.text = ("MISSION COMPLETE\n\n" if success else "MISSION FAILED\n\n") + summary + "\n\nPress MENU or A to play again."
		_msg_t = 1e9
		vr_msg.modulate.a = 1.0
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aim_marker.visible = false
	step_ghost.visible = false
	aim_beam.visible = false
	weapons.release_grab()
