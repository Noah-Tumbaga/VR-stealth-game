extends Node3D
## Entry point: starts OpenXR if a headset is available (desktop fallback
## otherwise), builds the level, spawns the player and HUD, bakes navigation.

const LevelBuilder = preload("res://scripts/world/level_builder.gd")
const Player = preload("res://scripts/player/player.gd")
const Hud = preload("res://scripts/ui/hud.gd")

var vr := false


func _ready() -> void:
	GameState.reset()
	vr = _init_xr()
	GameState.is_vr = vr

	var level := LevelBuilder.new()
	level.name = "World"
	add_child(level)
	level.build(vr)
	GameState.extraction_point = level.extraction

	var hud := Hud.new()
	hud.setup(vr)
	add_child(hud)

	var player := Player.new()
	player.name = "Player"
	player.setup(vr, hud)
	player.position = level.player_start
	add_child(player)

	GameState.set_objective("Assassinate Lord Aldric Vane inside Vane Manor. Then escape to the river.")
	level.bake_navigation()
	get_tree().create_timer(1.2).timeout.connect(func():
		GameState.notify.emit("Vane Manor. Midnight.\nThe lord walks his halls - and his garden.  Kill him unseen.", 6.0))


func _init_xr() -> bool:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--desktop" in args:
		return false
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var rr = xr.get("display_refresh_rate")
		if rr != null and float(rr) > 30.0:
			Engine.physics_ticks_per_second = int(round(float(rr)))
		return true
	return false
