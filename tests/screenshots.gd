extends Node
## Renders a set of review screenshots (needs a display / xvfb):
##   godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- --desktop --out=/tmp/shots

var main: Node
var frame := 0
var shot := 0
var out_dir := "user://shots"
var wait := 0

# [name, player pos, yaw deg, pitch deg, crouch]
var views := [
	["13_crossbow", Vector3(-2.0, 0, 16.0), 0.0, 2.0, false, "", "crossbow"],
	["14_grab_dagger", Vector3(-6.0, 0, 18.0), 0.0, -8.0, false, "", "dagger_grab"],
	["15_look_down_kit", Vector3(-2.0, 0, 16.0), 0.0, -75.0, false, "", "none"],
	["00_guard_model", Vector3(-8.0, 0, 18.0), 0.0, -12.0, false, "Osric"],
	["00_lord_model", Vector3(-6.0, 0, 18.0), 0.0, -12.0, false, "Lord Aldric Vane"],
	["01_start_forest", Vector3(-21.0, 0, 46.0), 0.0, 4.0, false],
	["02_breach", Vector3(-21.5, 0, 36.0), 5.0, 6.0, true],
	["03_courtyard", Vector3(-6.0, 0, 26.0), -15.0, 2.0, false],
	["04_manor_front", Vector3(-3.5, 0, 0.0), 0.0, 8.0, false],
	["05_guard_closeup", Vector3(-1.6, 0, -8.6), 0.0, -8.0, false],
	["06_great_hall", Vector3(-3.5, 0, -14.2), 0.0, 4.0, false],
	["07_throne", Vector3(-3.5, 0, -22.5), 0.0, 4.0, false],
	["08_study", Vector3(7.4, 0, -15.6), -20.0, -6.0, false],
	["09_garden", Vector3(17.4, 0, -4.5), -21.0, 2.0, false],
	["10_barracks", Vector3(-19.0, 0, -2.0), 90.0, -8.0, false],
	["11_stable_roof", Vector3(22.0, 3.7, 20.0), 30.0, -12.0, false],
	["12_gate", Vector3(4.0, 0, 41.0), 10.0, 6.0, false],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		if a.begins_with("--only="):
			var keep := a.substr(7).split(",")
			views = views.filter(func(v): return keep.has(v[0].substr(0, 2)))
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func _freeze_ai() -> void:
	# Review mode: guards keep animating but stop thinking/moving.
	for g in GameState.guards:
		g.set_physics_process(false)
		g.model.speed = 0.0


func _process(_d: float) -> void:
	frame += 1
	if not GameState.nav_ready or frame < 120:
		return
	if frame == 120 or shot == 0:
		_freeze_ai()
	var p = GameState.player
	if wait == 0:
		if shot >= views.size():
			get_tree().quit()
			return
		var v: Array = views[shot]
		p.global_position = v[1] + Vector3(0, 0.05, 0)
		p.yaw = deg_to_rad(v[2])
		p.pitch = deg_to_rad(v[3])
		p.desktop_crouch = v[4]
		p.fade = 0.0
		if p.hud and p.hud.help_panel:
			p.hud.help_panel.visible = false
		p.fade_target = 0.0
		# freeze AI so guards don't spot the camera between shots
		for g in GameState.guards:
			g.awareness = 0.0
		if v.size() > 6:
			match v[6]:
				"crossbow":
					p.weapons.draw("crossbow")
				"dagger_grab":
					p.weapons.draw("dagger")
				_:
					p.weapons.sheathe()
		if v.size() > 5 and v[5] != "":
			for g in GameState.guards:
				if g.display_name == v[5]:
					var fwd := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
					var gp: Vector3 = v[1] + fwd * 1.9
					g.global_position = gp
					g.rotation.y = p.yaw + PI
					g.waypoints = [gp]
					g.waits = [1e9]
					g.post_yaws = [rad_to_deg(p.yaw + PI)]
					g.wp_i = 0
					g.wait_t = 1e9
					g.state = 0
					g.follow = null
					var l := OmniLight3D.new()
					l.omni_range = 4.0
					l.light_energy = 1.2
					l.light_color = Color(1.0, 0.75, 0.5)
					get_tree().current_scene.add_child(l)
					l.global_position = gp + Vector3(0.8, 2.0, 1.2)
		wait = 1
	else:
		wait += 1
		for g in GameState.guards:
			g.awareness = 0.0
		if wait > 25:
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s.png" % [out_dir, views[shot][0]])
			print("saved ", views[shot][0])
			shot += 1
			wait = 0
