extends Node3D
## Magic bolt for Blinding Hex, Slumber and Echo Lure.

const Mats = preload("res://scripts/util/mats.gd")
const Geo = preload("res://scripts/util/geo.gd")
const Fx = preload("res://scripts/fx/fx.gd")

var spell := "blind"
var dir := Vector3.FORWARD
var color := Color(0.7, 0.4, 1.0)
var speed := 24.0
var max_dist := 32.0
var traveled := 0.0
var _done := false


func launch(p_spell: String, p_dir: Vector3, p_color: Color) -> void:
	spell = p_spell
	dir = p_dir.normalized()
	color = p_color


func _ready() -> void:
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = Color(color.r * 3.0, color.g * 3.0, color.b * 3.0)
	Geo.sphere(self, 0.05, Vector3.ZERO, core, Vector3.ONE, false, 12)
	Geo.sphere(self, 0.11, Vector3.ZERO, Mats.glow(Color(color.r, color.g, color.b, 0.3), 1.5), Vector3.ONE, false, 12)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.6
	l.omni_range = 3.5
	add_child(l)
	# Trail
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.45
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3.ZERO
	pm.scale_curve = Fx.scale_curve(1.0, 0.0)
	pm.color_ramp = Fx.color_ramp([Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.9), Color(color.r, color.g, color.b, 0.0)])
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = Fx.particle_material(true)
	p.draw_pass_1 = q
	add_child(p)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var from := global_position
	var step := dir * speed * delta
	var to := from + step
	for g in GameState.guards:
		if not is_instance_valid(g) or not g.is_alive():
			continue
		for s in g.hit_spheres():
			if Geo.seg_point_dist(from, to, s[0]) < s[1] + 0.3:
				_impact(s[0], g)
				return
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, GameState.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_impact(hit.position + hit.normal * 0.1, null)
		return
	global_position = to
	traveled += step.length()
	if traveled > max_dist:
		_impact(to, null)


func _impact(pos: Vector3, direct) -> void:
	_done = true
	var scene := get_tree().current_scene
	match spell:
		"blind":
			Sfx.play_at("blind", pos, 2.0)
			Fx.magic_burst(scene, pos, color, 1.4)
			Fx.flash(scene, pos, Color(0.9, 0.8, 1.0), 12.0, 10.0, 0.25)
			var n := 0
			for g in GameState.guards:
				if is_instance_valid(g) and g.is_alive() and g.eye_pos().distance_to(pos) < 3.0:
					var space := get_world_3d().direct_space_state
					var q := PhysicsRayQueryParameters3D.create(pos, g.eye_pos(), GameState.LAYER_WORLD)
					if g == direct or space.intersect_ray(q).is_empty():
						if g.blind(7.5):
							n += 1
			GameState.emit_noise(pos, 3.0, "snuff")
			if n == 0:
				GameState.notify.emit("The hex bursts harmlessly.", 1.5)
		"slumber":
			Sfx.play_at("sleep", pos, 0.0)
			Fx.sleep_mist(scene, pos)
			Fx.flash(scene, pos, color, 4.0, 2.0, 0.6)
			var slept := false
			for g in GameState.guards:
				if is_instance_valid(g) and g.is_alive() and (g == direct or g.eye_pos().distance_to(pos) < 1.6):
					if g.try_sleep(40.0):
						slept = true
					else:
						GameState.notify.emit("Slumber fails against an alert mind!", 2.0)
			if not slept and direct == null:
				GameState.notify.emit("The sleep mist drifts away.", 1.5)
		"echo":
			Sfx.play_at("clatter", pos, 4.0, 1.0, 50.0)
			Fx.magic_burst(scene, pos, color, 0.6)
			GameState.emit_noise(pos, 16.0, "lure")
	queue_free()
