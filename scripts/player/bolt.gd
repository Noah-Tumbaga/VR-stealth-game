extends Node3D
## Crossbow bolt: fast, slight drop. Headshots kill silently. Body shots wound
## and start a fight. Misses thunk into walls, and guards hear the thunk.

const HandModels = preload("res://scripts/player/hand_models.gd")
const Geo = preload("res://scripts/util/geo.gd")
const Fx = preload("res://scripts/fx/fx.gd")

const SPEED := 72.0
const DROP := 3.0
const LIFETIME := 2.5

var vel := Vector3.ZERO
var shooter_pos := Vector3.ZERO
var result := ""
var _t := 0.0
var _stuck := false


func launch(dir: Vector3, from_pos: Vector3) -> void:
	vel = dir.normalized() * SPEED
	shooter_pos = from_pos


func _ready() -> void:
	HandModels.build_bolt_mesh(self)


func _physics_process(delta: float) -> void:
	if _stuck:
		return
	_t += delta
	vel.y -= DROP * delta
	var from := global_position
	var to := from + vel * delta
	# Guards first: find the closest hit along this step.
	var best = null
	var best_part := ""
	var best_d := INF
	for g in GameState.guards:
		if not is_instance_valid(g) or not g.is_alive():
			continue
		if g.global_position.distance_to(from) > vel.length() * delta + 3.0:
			continue
		var sph: Array = g.hit_spheres()
		for i in sph.size():
			var c: Vector3 = sph[i][0]
			var r: float = sph[i][1] * (0.85 if i == 0 else 1.0)
			if Geo.seg_point_dist(from, to, c) < r:
				var d := from.distance_to(c)
				if d < best_d:
					best_d = d
					best = g
					best_part = "head" if i == 0 else "body"
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, GameState.LAYER_WORLD))
	if best != null and (hit.is_empty() or from.distance_to(hit.position) > best_d - 0.3):
		var hp: Vector3 = from + (to - from).normalized() * best_d
		result = best.receive_bolt(best_part, shooter_pos, hp)
		Sfx.play_at("stab", hp, -6.0 if best_part == "head" else 0.0)
		if GameState.player and GameState.player.has_method("on_bolt_result"):
			GameState.player.on_bolt_result(result)
		_stick(best.model.head if best_part == "head" else best.model.spine, hp)
		return
	if not hit.is_empty():
		global_position = hit.position - vel.normalized() * 0.12
		Sfx.play_at("bolt_hit", hit.position, 0.0)
		Fx.burst(get_tree().current_scene, hit.position, [Color(0.4, 0.38, 0.35, 0.8), Color(0.3, 0.3, 0.3, 0.0)], 8, 0.5, Vector2(0.5, 1.5), 0.04, Vector3(0, -6, 0), false, 50.0, hit.normal)
		GameState.emit_noise(hit.position, 6.0, "lure")
		_stick(null, global_position)
		return
	global_position = to
	look_at(to + vel, Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT)
	if _t > LIFETIME:
		queue_free()


func _stick(parent: Node3D, pos: Vector3) -> void:
	_stuck = true
	if parent:
		var xf := global_transform
		xf.origin = pos - vel.normalized() * 0.1
		reparent(parent)
		global_transform = xf
	get_tree().create_timer(90.0).timeout.connect(queue_free)
