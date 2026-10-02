extends Node
## Long patrol soak: player parked out of sight; records waypoint progress per guard.
##   godot --headless --fixed-fps 60 --path . res://tests/patrol_test.tscn -- --desktop

var main: Node
var frame := 0
var progress := {}
var last_wp := {}
var max_still := {}
var last_pos := {}
var still := {}


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func _process(_d: float) -> void:
	if not GameState.nav_ready:
		return
	frame += 1
	var p = GameState.player
	p.global_position = Vector3(-30.0, 0.1, 50.0)
	for g in GameState.guards:
		var n: String = g.display_name
		if not progress.has(n):
			progress[n] = 0
			last_wp[n] = g.wp_i
			last_pos[n] = g.global_position
			still[n] = 0
			max_still[n] = 0
		if g.wp_i != last_wp[n]:
			progress[n] += 1
			last_wp[n] = g.wp_i
		if g.wait_t < 0.0 and g.state == 0 and g.global_position.distance_to(last_pos[n]) < 0.005:
			still[n] += 1
			max_still[n] = max(max_still[n], still[n])
			if still[n] == 140:
				print("STALL %s at %s heading to wp %d %s" % [n, g.global_position.snapped(Vector3(0.1, 0.1, 0.1)), g.wp_i, g.waypoints[g.wp_i]])
		else:
			still[n] = 0
		last_pos[n] = g.global_position
	if frame == 7200:
		for n in progress:
			var g = null
			for gg in GameState.guards:
				if gg.display_name == n:
					g = gg
			print("%-18s wp_changes=%3d  state=%d  max_stuck_frames=%d  pos=%s" % [n, progress[n], g.state, max_still[n], g.global_position.snapped(Vector3(0.1, 0.1, 0.1))])
		print("max threat ", GameState.max_threat, " alarm ", GameState.alarm_active)
		get_tree().quit()
