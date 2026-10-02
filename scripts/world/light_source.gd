extends Node3D
## A flickering flame light: torch, brazier, candle cluster, chandelier, fireplace or lantern.
## Registers with GameState so the stealth system knows how lit the player is.
## Can be snuffed out with the Snuff spell.

const Mats = preload("res://scripts/util/mats.gd")
const Geo = preload("res://scripts/util/geo.gd")
const Fx = preload("res://scripts/fx/fx.gd")

var kind := "torch"
var lit := true
var base_energy := 2.2
var range_m := 7.0
var strength := 1.0
var cast_shadows := false
var flame_scale := 1.0
var snuffable := true
var light_color := Color(1.0, 0.62, 0.28)

var light: OmniLight3D
var flame_root: Node3D
var crackle: AudioStreamPlayer3D
var _t := 0.0
var _noise := FastNoiseLite.new()


func configure(p_kind: String, energy: float, rng: float, p_strength := 1.0, shadows := false, p_flame_scale := 1.0) -> Node3D:
	kind = p_kind
	base_energy = energy
	range_m = rng
	strength = p_strength
	cast_shadows = shadows
	flame_scale = p_flame_scale
	if kind == "lantern":
		light_color = Color(1.0, 0.7, 0.38)
	elif kind == "candle":
		light_color = Color(1.0, 0.68, 0.36)
	return self


func _ready() -> void:
	_t = randf() * 100.0
	_noise.frequency = 2.2
	_noise.seed = randi()
	light = OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = base_energy
	light.omni_range = range_m
	light.omni_attenuation = 1.3
	light.shadow_enabled = cast_shadows
	light.shadow_bias = 0.05
	light.light_volumetric_fog_energy = 1.4
	light.position = Vector3(0, 0.12 * flame_scale, 0)
	add_child(light)
	flame_root = Node3D.new()
	add_child(flame_root)
	_build_flame()
	GameState.lights.append(self)
	if kind in ["torch", "brazier", "fireplace"]:
		crackle = Sfx.make_loop("fire", self, -14.0 if kind == "torch" else -9.0, 1.5, 14.0)


func _build_flame() -> void:
	match kind:
		"candle":
			Geo.sphere(flame_root, 0.012, Vector3(0, 0.015, 0), Mats.emissive(Color(1.0, 0.75, 0.35), 6.0), Vector3(0.7, 1.8, 0.7), false, 8)
		"lantern":
			Geo.sphere(flame_root, 0.025, Vector3.ZERO, Mats.emissive(Color(1.0, 0.7, 0.35), 8.0), Vector3(0.7, 1.4, 0.7), false, 8)
		"chandelier":
			pass  # flames are on the individual candles
		_:
			_fire_particles()


func _fire_particles() -> void:
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.7
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05 * flame_scale
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.3 * flame_scale
	pm.initial_velocity_max = 0.8 * flame_scale
	pm.gravity = Vector3(0, 1.0, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.scale_curve = Fx.scale_curve(1.0, 0.1)
	pm.color_ramp = Fx.color_ramp([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.8, 0.2, 0.05, 0.5), Color(0.2, 0.05, 0.0, 0.0)])
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.2) * flame_scale
	var mat := Fx.particle_material(true)
	mat.albedo_color = Color(2.2, 1.6, 1.2)
	q.material = mat
	p.draw_pass_1 = q
	flame_root.add_child(p)
	# Embers
	var e := GPUParticles3D.new()
	e.amount = 6
	e.lifetime = 1.6
	e.local_coords = false
	var em := ParticleProcessMaterial.new()
	em.direction = Vector3.UP
	em.spread = 25.0
	em.initial_velocity_min = 0.4
	em.initial_velocity_max = 1.1
	em.gravity = Vector3(0, 0.4, 0)
	em.turbulence_enabled = true
	em.turbulence_noise_strength = 2.0
	em.color_ramp = Fx.color_ramp([Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.3, 0.05, 0.0)])
	e.process_material = em
	var eq := QuadMesh.new()
	eq.size = Vector2(0.015, 0.015)
	eq.material = Fx.particle_material(true)
	e.draw_pass_1 = eq
	flame_root.add_child(e)
	# Hot core
	Geo.sphere(flame_root, 0.045 * flame_scale, Vector3(0, 0.05 * flame_scale, 0), Mats.emissive(Color(1.0, 0.6, 0.2), 5.0), Vector3(1, 1.6, 1), false, 10)


func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	var f := 0.82 + 0.18 * _noise.get_noise_1d(_t * 10.0) + 0.06 * sin(_t * 23.0)
	if kind == "lantern" or kind == "candle" or kind == "chandelier":
		f = 0.92 + 0.08 * _noise.get_noise_1d(_t * 6.0)
	light.light_energy = base_energy * f


func is_lit() -> bool:
	return lit


func light_position() -> Vector3:
	return light.global_position


func light_range() -> float:
	return range_m * 0.85


func light_strength() -> float:
	return strength


func extinguish(silent := false) -> void:
	if not lit:
		return
	lit = false
	light.visible = false
	flame_root.visible = false
	if crackle:
		crackle.stop()
	if not silent:
		Fx.smoke(get_tree().current_scene, light.global_position)
		Sfx.play_at("snuff", light.global_position, -2.0)
		GameState.emit_noise(light.global_position, 2.5, "snuff")


func ignite() -> void:
	lit = true
	light.visible = true
	flame_root.visible = true
	if crackle:
		crackle.play()


func _exit_tree() -> void:
	GameState.lights.erase(self)
