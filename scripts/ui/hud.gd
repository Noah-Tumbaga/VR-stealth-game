extends CanvasLayer
## Desktop HUD (in VR the same info lives on the left wrist + floating text).

var vr := false
var objective_lbl: Label
var msg_lbl: Label
var status_lbl: Label
var spells_box: HBoxContainer
var spell_panels: Array = []
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var gem: Panel
var gem_style: StyleBoxFlat
var eye_lbl: Label
var crosshair: Label
var help_panel: PanelContainer
var end_panel: PanelContainer
var end_title: Label
var end_text: Label
var _msg_t := 0.0
var _last_spell := -1


func setup(p_vr: bool) -> void:
	vr = p_vr


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	if vr:
		# Mirror window only gets a hint.
		var l := _label(root, "Shadowveil - VR mode. Put on your headset.", 18, Color(0.8, 0.8, 0.9))
		l.position = Vector2(16, 12)
		GameState.objective_changed.connect(func(_t): pass)
		return

	objective_lbl = _label(root, "", 20, Color(0.92, 0.88, 0.78))
	_place(objective_lbl, Control.PRESET_TOP_LEFT, 24, 18, 1000, 70)

	msg_lbl = _label(root, "", 26, Color(1, 1, 1))
	_place(msg_lbl, Control.PRESET_CENTER_TOP, -450, 100, 450, 230)
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	crosshair = _label(root, "·", 34, Color(1, 1, 1, 0.75))
	_place(crosshair, Control.PRESET_CENTER, -20, -24, 20, 16)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# bottom-left vitals
	var vit := VBoxContainer.new()
	_place(vit, Control.PRESET_BOTTOM_LEFT, 24, -190, 344, -110)
	vit.add_theme_constant_override("separation", 6)
	root.add_child(vit)
	var gem_row := HBoxContainer.new()
	gem_row.add_theme_constant_override("separation", 12)
	vit.add_child(gem_row)
	gem = Panel.new()
	gem.custom_minimum_size = Vector2(34, 34)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gem_style = StyleBoxFlat.new()
	gem_style.bg_color = Color(0.2, 0.2, 0.2)
	gem_style.set_corner_radius_all(17)
	gem_style.border_color = Color(0.6, 0.5, 0.3)
	gem_style.set_border_width_all(2)
	gem.add_theme_stylebox_override("panel", gem_style)
	gem_row.add_child(gem)
	status_lbl = _label(gem_row, "HIDDEN", 18, Color(0.7, 0.7, 0.8))
	eye_lbl = _label(gem_row, "", 18, Color(1, 0.8, 0.3))
	hp_bar = _bar(vit, Color(0.75, 0.12, 0.1))
	mana_bar = _bar(vit, Color(0.3, 0.42, 0.95))

	# bottom-center spells
	spells_box = HBoxContainer.new()
	_place(spells_box, Control.PRESET_CENTER_BOTTOM, -450, -92, 450, -16)
	spells_box.alignment = BoxContainer.ALIGNMENT_CENTER
	spells_box.add_theme_constant_override("separation", 8)
	root.add_child(spells_box)
	var spells: Array = preload("res://scripts/player/player.gd").SPELLS
	for i in spells.size():
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(138, 64)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.04, 0.08, 0.75)
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.25, 0.25, 0.3)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		pc.add_theme_stylebox_override("panel", sb)
		var l := _label(pc, "[%d] %s\n%d mana" % [i + 1, spells[i].name, int(spells[i].cost)], 14, (spells[i].color as Color).lightened(0.2))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		spells_box.add_child(pc)
		spell_panels.append([pc, sb, l])

	help_panel = _panel(root, Vector2(580, 600))
	_place(help_panel, Control.PRESET_CENTER_RIGHT, -610, -310, -24, 310)
	var ht := _label(help_panel, "", 15, Color(0.9, 0.9, 0.95))
	ht.text = """SHADOWVEIL - controls (desktop)    [H] toggle

WASD move   Mouse look   Shift sprint (loud!)
C / Ctrl  crouch (quiet, harder to see)
F  draw/sheathe dagger    B  draw/holster crossbow
V (hold)  cover a guard's mouth from behind
LMB  dagger: aim at the THROAT to kill
      (body hits only wound - he'll scream and fight)
      covering his mouth makes the kill silent
LMB  crossbow: headshot = silent kill
RMB  hold to aim, release to cast selected spell
1-6 / Q E / wheel  choose spell
Esc release mouse     Shift+R restart

Spells
 1 Blinding Hex - blind + panic guards in a burst
 2 Slumber - put an UNAWARE guard to sleep
 3 Echo Lure - phantom noise to pull guards away
 4 Snuff - put out a torch/lantern from afar
 5 Shadow Step - silent blink; aim at ledges
 6 Shroud - near-invisible for 10s

If you're SPOTTED you have under a second to
silence him before the alarm. Combat is lethal:
three sword hits and you're dead."""
	help_panel.visible = true

	end_panel = _panel(root, Vector2(760, 380))
	_place(end_panel, Control.PRESET_CENTER, -380, -190, 380, 190)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 14)
	end_panel.add_child(ev)
	end_title = _label(ev, "", 40, Color(1, 1, 1))
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_text = _label(ev, "", 18, Color(0.9, 0.9, 0.9))
	end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := _label(ev, "Press R to play again", 16, Color(0.7, 0.7, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.visible = false

	GameState.objective_changed.connect(_on_objective)
	GameState.notify.connect(_on_notify)
	GameState.mission_ended.connect(_on_end)
	_on_objective(GameState.objective)
	get_tree().create_timer(14.0).timeout.connect(func(): if is_instance_valid(help_panel): help_panel.visible = false)


func _place(c: Control, preset: Control.LayoutPreset, l: float, t: float, r: float, b: float) -> void:
	## Anchor to a preset, then offset relative to those anchors.
	c.set_anchors_preset(preset)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _label(parent: Node, text: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Node, c: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(300, 14)
	b.show_percentage = false
	b.max_value = 100.0
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	fg.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fg)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


func _panel(parent: Node, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.07, 0.86)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(0.4, 0.3, 0.6)
	sb.set_border_width_all(2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func toggle_help() -> void:
	if help_panel:
		help_panel.visible = not help_panel.visible


func _process(delta: float) -> void:
	if vr or msg_lbl == null:
		return
	if _msg_t > 0.0:
		_msg_t -= delta
		msg_lbl.modulate.a = clampf(_msg_t / 0.6, 0.0, 1.0)


func update_status(p) -> void:
	if vr or hp_bar == null:
		return
	hp_bar.value = p.health
	mana_bar.value = p.mana
	var v: float = p.visibility
	gem_style.bg_color = Color(0.08, 0.06, 0.14).lerp(Color(1.0, 0.85, 0.45), clampf(v * 1.2, 0.0, 1.0))
	var st := "HIDDEN"
	var sc := Color(0.55, 0.5, 0.8)
	if p.shroud_t > 0.0:
		st = "SHROUDED %.0fs" % p.shroud_t
		sc = Color(0.6, 0.4, 1.0)
	elif p.in_hiding:
		st = "CONCEALED"
		sc = Color(0.4, 0.8, 0.5)
	elif v > 0.55:
		st = "EXPOSED"
		sc = Color(1.0, 0.8, 0.4)
	elif v > 0.2:
		st = "DIM"
		sc = Color(0.8, 0.75, 0.6)
	if p.crouched:
		st += "  · crouched"
	status_lbl.text = st + "\n" + p.weapons.status_text()
	status_lbl.add_theme_color_override("font_color", sc)
	var th := GameState.max_threat
	if th >= 1.0:
		eye_lbl.text = "◉ DETECTED"
		eye_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.15))
	elif th > 0.05:
		eye_lbl.text = "◎ %d%%" % int(th * 100.0)
		eye_lbl.add_theme_color_override("font_color", Color(1, 0.85 - th * 0.5, 0.3))
	else:
		eye_lbl.text = ""
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.9) if p.aiming and p.aim_valid else Color(1, 1, 1, 0.5))
	if p.spell_idx != _last_spell:
		_last_spell = p.spell_idx
		for i in spell_panels.size():
			var sb: StyleBoxFlat = spell_panels[i][1]
			sb.border_color = Color(0.85, 0.7, 1.0) if i == p.spell_idx else Color(0.25, 0.25, 0.3)
			sb.bg_color = Color(0.12, 0.07, 0.2, 0.9) if i == p.spell_idx else Color(0.04, 0.04, 0.08, 0.75)
	for i in spell_panels.size():
		var l: Label = spell_panels[i][2]
		var cost: float = preload("res://scripts/player/player.gd").SPELLS[i].cost
		l.modulate.a = 1.0 if p.mana >= cost else 0.4


func _on_objective(t: String) -> void:
	if objective_lbl:
		objective_lbl.text = "OBJECTIVE: " + t


func _on_notify(t: String, d: float) -> void:
	if msg_lbl:
		msg_lbl.text = t
		_msg_t = d
		msg_lbl.modulate.a = 1.0


func _on_end(success: bool, summary: String) -> void:
	if end_panel == null:
		return
	end_panel.visible = true
	help_panel.visible = false
	end_title.text = "MISSION COMPLETE" if success else "MISSION FAILED"
	end_title.add_theme_color_override("font_color", Color(0.7, 0.55, 1.0) if success else Color(1.0, 0.3, 0.25))
	end_text.text = summary
