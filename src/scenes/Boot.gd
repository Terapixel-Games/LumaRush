extends Node

const VIEWPORT_WIDTH_SETTING := "display/window/size/viewport_width"
const VIEWPORT_HEIGHT_SETTING := "display/window/size/viewport_height"
const WindowSizing := preload("res://src/core/WindowSizing.gd")
var _boot_started_msec: int = Time.get_ticks_msec()

func _ready() -> void:
	if FeatureFlags.clear_high_score_on_boot():
		SaveStore.clear_high_score()
	if _is_headless_runtime():
		Telemetry.mark_scene_loaded("boot", _boot_started_msec)
		return
	_configure_window_for_display()
	MusicManager.start_all_synced()
	call_deferred("_go_game")

func _go_game() -> void:
	Telemetry.mark_scene_loaded("boot", _boot_started_msec)
	RunManager.start_game()

func _is_headless_runtime() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server")

func _configure_window_for_display() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var base_size := Vector2i(
		int(ProjectSettings.get_setting(VIEWPORT_WIDTH_SETTING, 1080)),
		int(ProjectSettings.get_setting(VIEWPORT_HEIGHT_SETTING, 1920))
	)
	var screen_index: int = DisplayServer.window_get_current_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var target_size: Vector2i = WindowSizing.compute_window_size_for_display(base_size, usable_rect)
	if target_size.x <= 0 or target_size.y <= 0:
		return
	DisplayServer.window_set_size(target_size)
	DisplayServer.window_set_position(WindowSizing.compute_window_position(usable_rect, target_size))
