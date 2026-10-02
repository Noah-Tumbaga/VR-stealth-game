extends Node
## Procedural sound synthesis. Every sound effect is generated at startup from
## oscillators and filtered noise, so the project has no audio asset dependencies.

const RATE := 22050

var streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 90210
	_build_all()


# ---------------------------------------------------------------- playback

func play_at(sound: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, max_dist := 40.0) -> void:
	if not streams.has(sound):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.max_distance = max_dist
	p.unit_size = 4.0
	p.attenuation_filter_cutoff_hz = 9000.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func play_ui(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func make_loop(sound: String, parent: Node3D, vol_db := 0.0, unit := 2.0, max_dist := 20.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams.get(sound)
	p.volume_db = vol_db
	p.unit_size = unit
	p.max_distance = max_dist
	p.autoplay = true
	parent.add_child(p)
	return p


# ---------------------------------------------------------------- synthesis helpers

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


func _env(t: float, dur: float, att: float, rel_pow: float) -> float:
	if t < att:
		return t / att
	return pow(maxf(1.0 - (t - att) / maxf(dur - att, 0.0001), 0.0), rel_pow)


func _noise(dur: float, c0: float, c1: float, att: float, rel_pow: float, highpass := false) -> PackedFloat32Array:
	var out := _buf(dur)
	var y := 0.0
	var n := out.size()
	for i in n:
		var t := float(i) / RATE
		var c := lerpf(c0, c1, t / dur)
		var k := 1.0 - exp(-TAU * c / RATE)
		var x := _rng.randf_range(-1.0, 1.0)
		y += k * (x - y)
		var v := (x - y) if highpass else y
		out[i] = v * _env(t, dur, att, rel_pow)
	return out


func _tone(dur: float, f0: float, f1: float, shape := "sine", att := 0.01, rel_pow := 1.0, vib_hz := 0.0, vib_depth := 0.0) -> PackedFloat32Array:
	var out := _buf(dur)
	var phase := 0.0
	var n := out.size()
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		if vib_hz > 0.0:
			f *= 1.0 + sin(TAU * vib_hz * t) * vib_depth
		phase += TAU * f / RATE
		var v := 0.0
		match shape:
			"sine":
				v = sin(phase)
			"saw":
				v = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
			"square":
				v = 1.0 if sin(phase) >= 0.0 else -1.0
			"tri":
				v = absf(fposmod(phase / TAU, 1.0) * 4.0 - 2.0) - 1.0
			"organ":
				v = sin(phase) * 0.6 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.15
		out[i] = v * _env(t, dur, att, rel_pow)
	return out


func _lowpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var k := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += k * (b[i] - y)
		b[i] = y
	return b


func _norm(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var s := peak / m
	for i in b.size():
		b[i] *= s
	return b


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0.0, gain := 1.0) -> PackedFloat32Array:
	var off := int(offset * RATE)
	var n := maxi(a.size(), b.size() + off)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in a.size():
		out[i] = a[i]
	for i in b.size():
		out[i + off] += b[i] * gain
	return out


func _loopify(b: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	## Crossfade the tail into the head so the buffer loops seamlessly.
	var f := int(fade * RATE)
	var n := b.size() - f
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in f:
		var w := float(i) / f
		out[i] = b[i] * w + b[n + i] * (1.0 - w)
	return out


func _stream(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = b.size()
	return s


# ---------------------------------------------------------------- sound design

func _build_all() -> void:
	# Footsteps: gritty low thump.
	var step := _mix(_norm(_noise(0.14, 1100.0, 250.0, 0.004, 3.0), 0.5), _norm(_tone(0.1, 110.0, 55.0, "sine", 0.002, 2.0), 0.45))
	streams["step"] = _stream(step)
	streams["step_soft"] = _stream(_norm(_noise(0.12, 500.0, 180.0, 0.01, 2.5), 0.22))

	# Blade whoosh.
	streams["swing"] = _stream(_norm(_noise(0.3, 500.0, 3200.0, 0.12, 2.0, true), 0.45))

	# Stab: wet slice + body thud.
	var stab := _mix(_norm(_noise(0.22, 3000.0, 500.0, 0.002, 2.0), 0.6), _norm(_tone(0.32, 120.0, 45.0, "sine", 0.002, 2.5), 0.75))
	stab = _mix(stab, _norm(_noise(0.4, 900.0, 200.0, 0.03, 3.0), 0.3), 0.05)
	streams["stab"] = _stream(stab)

	# Assassination sting: low ominous dyad.
	var sting := _mix(_norm(_tone(1.6, 73.4, 70.0, "organ", 0.01, 1.6), 0.35), _norm(_tone(1.6, 110.0, 104.0, "organ", 0.01, 1.8), 0.25))
	sting = _mix(sting, _norm(_noise(1.0, 200.0, 80.0, 0.3, 1.0), 0.15))
	streams["kill"] = _stream(sting)

	# Steel on steel.
	var clang := PackedFloat32Array()
	for f in [880.0, 1980.0, 2730.0, 3910.0]:
		clang = _mix(clang, _tone(0.6, f, f * 0.995, "sine", 0.001, 4.0), 0.0, 0.25)
	clang = _mix(clang, _norm(_noise(0.05, 6000.0, 3000.0, 0.001, 2.0, true), 0.5))
	streams["clang"] = _stream(_norm(clang, 0.55))

	# Casting shimmer.
	var cast := _mix(_norm(_tone(0.55, 320.0, 980.0, "sine", 0.02, 1.4, 16.0, 0.03), 0.35), _norm(_tone(0.55, 640.0, 1960.0, "sine", 0.02, 1.6), 0.15))
	cast = _mix(cast, _norm(_noise(0.5, 4000.0, 7000.0, 0.05, 1.5, true), 0.12))
	streams["cast"] = _stream(cast)
	streams["fizzle"] = _stream(_norm(_noise(0.35, 2500.0, 500.0, 0.005, 2.0, true), 0.3))

	# Blinding hex: crack of light + glassy chord.
	var blind := _norm(_noise(0.7, 9000.0, 2500.0, 0.003, 2.0, true), 0.5)
	for f in [1318.5, 1760.0, 2093.0, 2637.0]:
		blind = _mix(blind, _tone(1.0, f, f * 1.01, "sine", 0.005, 1.5, 7.0, 0.01), 0.0, 0.1)
	streams["blind"] = _stream(blind)

	# Slumber: descending lullaby sigh.
	var sleep := _mix(_norm(_tone(1.3, 660.0, 220.0, "sine", 0.12, 1.2, 5.0, 0.02), 0.32), _norm(_tone(1.3, 990.0, 330.0, "tri", 0.15, 1.4), 0.12))
	streams["sleep"] = _stream(sleep)

	# Echo lure: clattering pots and pans.
	var clatter := PackedFloat32Array()
	var hits := [0.0, 0.13, 0.31, 0.42, 0.66]
	for h in hits:
		var hit := PackedFloat32Array()
		var base := _rng.randf_range(600.0, 1100.0)
		for mult in [1.0, 2.31, 3.17, 4.53]:
			hit = _mix(hit, _tone(0.45, base * mult, base * mult * 0.99, "sine", 0.001, 5.0), 0.0, 0.2)
		hit = _mix(hit, _norm(_noise(0.04, 5000.0, 2000.0, 0.001, 2.0), 0.4))
		clatter = _mix(clatter, hit, h, 1.0 - h * 0.6)
	streams["clatter"] = _stream(_norm(clatter, 0.7))

	# Snuff: hiss.
	streams["snuff"] = _stream(_norm(_noise(0.7, 7000.0, 2000.0, 0.01, 1.5, true), 0.35))

	# Shadow step: reversed whoosh with sub drop.
	var stepw := _mix(_norm(_noise(0.45, 150.0, 2200.0, 0.38, 0.4), 0.45), _norm(_tone(0.5, 70.0, 35.0, "sine", 0.3, 0.6), 0.4))
	streams["shadowstep"] = _stream(stepw)

	# Shroud: breathy dark swell.
	streams["shroud"] = _stream(_mix(_norm(_noise(1.0, 300.0, 120.0, 0.4, 1.0), 0.4), _norm(_tone(1.0, 55.0, 49.0, "organ", 0.3, 1.0), 0.3)))

	# Guard vocalisations (stylised).
	streams["huh"] = _stream(_lowpass(_norm(_tone(0.32, 190.0, 290.0, "organ", 0.02, 1.4, 5.0, 0.02), 0.45), 1400.0))
	var alert := _mix(_tone(0.16, 330.0, 340.0, "saw", 0.01, 0.5), _tone(0.34, 440.0, 420.0, "saw", 0.01, 1.2), 0.15)
	streams["alert"] = _stream(_norm(_lowpass(alert, 2200.0), 0.5))
	var scream := _tone(1.1, 520.0, 380.0, "saw", 0.03, 1.2, 9.0, 0.07)
	scream = _mix(_lowpass(scream, 1800.0), _norm(_noise(1.1, 2500.0, 1500.0, 0.03, 1.2), 0.3))
	streams["scream"] = _stream(_norm(scream, 0.6))
	streams["grunt"] = _stream(_norm(_lowpass(_tone(0.25, 160.0, 110.0, "saw", 0.01, 1.5), 900.0), 0.5))
	streams["snore"] = _stream(_norm(_lowpass(_mix(_noise(1.2, 180.0, 220.0, 0.4, 1.0), _tone(1.2, 70.0, 62.0, "saw", 0.4, 1.0), 0.0, 0.3), 600.0), 0.25))

	# Player hurt / body fall.
	streams["hurt"] = _stream(_mix(_norm(_tone(0.3, 90.0, 40.0, "sine", 0.002, 2.0), 0.7), _norm(_noise(0.2, 1500.0, 300.0, 0.002, 2.0), 0.4)))
	streams["fall"] = _stream(_mix(_norm(_noise(0.45, 500.0, 90.0, 0.004, 2.5), 0.55), _norm(_tone(0.4, 70.0, 32.0, "sine", 0.003, 2.0), 0.6)))

	# Heartbeat (lub-dub).
	var beat := _norm(_lowpass(_tone(0.13, 60.0, 42.0, "sine", 0.005, 2.0), 300.0), 0.7)
	streams["heartbeat"] = _stream(_mix(_mix(_buf(0.7), beat), beat, 0.2, 0.7))

	# Mission complete arpeggio + alarm bell.
	var arp := PackedFloat32Array()
	var notes := [261.6, 311.1, 392.0, 523.3, 622.3]
	for i in notes.size():
		arp = _mix(arp, _tone(1.2, notes[i], notes[i], "organ", 0.01, 2.0), i * 0.13, 0.22)
	streams["success"] = _stream(_norm(arp, 0.6))
	var bell := PackedFloat32Array()
	for k in 3:
		var b := PackedFloat32Array()
		for mult in [1.0, 2.0, 2.76, 5.4]:
			b = _mix(b, _tone(1.1, 520.0 * mult, 520.0 * mult, "sine", 0.002, 3.0), 0.0, 0.25 / mult)
		bell = _mix(bell, b, k * 0.42)
	streams["alarm_bell"] = _stream(_norm(bell, 0.55))
	streams["ui_tick"] = _stream(_norm(_tone(0.06, 1400.0, 1200.0, "sine", 0.002, 2.0), 0.25))

	# Ambient loops.
	var wind := _buf(8.5)
	var y := 0.0
	var y2 := 0.0
	for i in wind.size():
		var t := float(i) / RATE
		var cut := 260.0 + 220.0 * sin(t * 0.7) + 120.0 * sin(t * 1.9 + 1.0)
		var k := 1.0 - exp(-TAU * cut / RATE)
		y += k * (_rng.randf_range(-1.0, 1.0) - y)
		y2 += k * (y - y2)
		wind[i] = y2 * (0.6 + 0.4 * sin(t * 0.45))
	streams["wind"] = _stream(_norm(_loopify(wind, 0.5), 0.35), true)

	var fire := _norm(_noise(2.5, 700.0, 700.0, 0.001, 0.0), 0.12)
	for c in 34:
		var at := int(_rng.randf_range(0.0, 2.3) * RATE)
		var amp := _rng.randf_range(0.15, 0.55)
		for j in 90:
			if at + j < fire.size():
				fire[at + j] += _rng.randf_range(-1.0, 1.0) * amp * exp(-j / 14.0)
	streams["fire"] = _stream(_loopify(fire, 0.2), true)

	var crickets := _buf(4.2)
	for i in crickets.size():
		var t := float(i) / RATE
		var chirp := 1.0 if fposmod(t * 3.1, 1.0) < 0.18 else 0.0
		var chirp2 := 1.0 if fposmod(t * 2.3 + 0.4, 1.0) < 0.14 else 0.0
		crickets[i] = sin(TAU * 4300.0 * t) * chirp * (0.5 + 0.5 * sin(TAU * 40.0 * t)) * 0.08 + sin(TAU * 3900.0 * t) * chirp2 * (0.5 + 0.5 * sin(TAU * 33.0 * t)) * 0.06
	streams["crickets"] = _stream(_loopify(crickets, 0.2), true)
