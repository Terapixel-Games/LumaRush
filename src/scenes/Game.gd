extends Control

const NEON_RUN_DECK := preload("res://src/ui/NeonRunDeck.gd")

@onready var board: BoardView = $BoardView
@onready var top_bar_bg: Control = $UI/TopBarBg
@onready var top_bar: Control = $UI/TopBar
@onready var top_right_bar: Control = $UI/TopRightBar
@onready var powerups_row: Control = $UI/Powerups
@onready var score_box: VBoxContainer = $UI/TopBar/ScoreBox
@onready var score_caption_label: Label = $UI/TopBar/ScoreBox/ScoreCaption
@onready var account_button: Button = $UI/TopRightBar/Account
@onready var shop_button: Button = $UI/TopRightBar/Shop
@onready var audio_button: Button = $UI/TopRightBar/Audio
@onready var score_value_label: Label = $UI/TopBar/ScoreBox/ScoreValue
@onready var pause_button: Button = $UI/TopBar/Pause
@onready var pause_icon: TextureRect = $UI/TopBar/Pause/Center/PauseIcon
@onready var undo_button: Button = $UI/Powerups/Undo
@onready var remove_color_button: Button = $UI/Powerups/RemoveColor
@onready var hint_button: Button = $UI/Powerups/Hint
@onready var undo_badge_panel: PanelContainer = $UI/Powerups/Undo/Badge
@onready var prism_badge_panel: PanelContainer = $UI/Powerups/RemoveColor/Badge
@onready var hint_badge_panel: PanelContainer = $UI/Powerups/Hint/Badge
@onready var undo_badge: Label = $UI/Powerups/Undo/Badge/Value
@onready var prism_badge: Label = $UI/Powerups/RemoveColor/Badge/Value
@onready var hint_badge: Label = $UI/Powerups/Hint/Badge/Value
@onready var board_frame: ColorRect = $UI/BoardFrame
@onready var board_glow: ColorRect = $UI/BoardGlow
@onready var powerup_flash: ColorRect = $UI/PowerupFlash

var score := 0
var combo := 0
const HIGH_COMBO_THRESHOLD := 4
var _run_finished: bool = false
var _ending_transition_started: bool = false
var _undo_charges: int = 0
var _remove_color_charges: int = 0
var _hint_charges: int = 0
var _undo_stack: Array[Dictionary] = []
var _pending_powerup_refill_type: String = ""
var _prism_selecting: bool = false
var _powerup_coin_costs := {"undo": 120, "prism": 180, "hint": 140}
var _powerup_usage := {"undo": 0, "prism": 0, "hint": 0}
var _run_powerups_used_total: int = 0
var _run_coins_spent: int = 0
var _open_tip_shown_this_run: bool = false
var _open_tip_modal: Control
var _audio_overlay
var _pause_overlay: Control
var _current_mode: String = "PURE"
var _combo_label: Label
var _tutorial_overlay: Control
var _tutorial_panel: Panel
var _tutorial_title: Label
var _tutorial_message: Label
var _tutorial_next_button: Button
var _tutorial_skip_button: Button
var _tutorial_highlights: Array[Control] = []
var _tutorial_motion_tween: Tween
var _tutorial_focus_tween: Tween
var _tutorial_focus_target: Control
var _tutorial_step: int = 0
var _shake_strength: float = 0.0
var _shake_time_left: float = 0.0
var _board_anchor_pos: Vector2 = Vector2.ZERO
var _powerup_juice_tween: Tween
var _scene_opened_msec: int = Time.get_ticks_msec()
var _combo_timeout_remaining: float = -1.0
var _pressure_hud: PanelContainer
var _pressure_heat_label: Label
var _pressure_rival_label: Label
var _pressure_matches_label: Label
var _pressure_bar: ProgressBar
var _score_burst_label: Label
var _cabinet_title_label: Label
var _combo_pod_label: Label
var _rival_pod_label: Label
const COMBO_BREAK_TIMEOUT_SECONDS: float = 1.8

const ICON_UNDO: Texture2D = preload("res://assets/ui/icons/atlas/powerup_undo.tres")
const ICON_PRISM: Texture2D = preload("res://assets/ui/icons/atlas/powerup_prism.tres")
const ICON_HINT: Texture2D = preload("res://assets/ui/icons/atlas/powerup_hint.tres")
const ICON_CANCEL: Texture2D = preload("res://assets/ui/icons/atlas/powerup_cancel.tres")
const ICON_LOADING: Texture2D = preload("res://assets/ui/icons/atlas/powerup_loading.tres")
const AUDIO_TRACK_OVERLAY_SCENE := preload("res://src/scenes/AudioTrackOverlay.tscn")
const ICON_MUSIC_ON: Texture2D = preload("res://assets/ui/icons/atlas/music_on.tres")
const ICON_MUSIC_OFF: Texture2D = preload("res://assets/ui/icons/atlas/music_off.tres")
const TUTORIAL_TIP_SCENE := preload("res://addons/arcade_core/ui/TutorialTipModal.tscn")
const TUTORIAL_TEMPLATE := preload("res://addons/arcade_core/ui/ArcadeTutorialTemplate.gd")
const ACCOUNT_MODAL_SCENE := preload("res://src/scenes/AccountModal.tscn")
const SHOP_MODAL_SCENE := preload("res://src/scenes/ShopModal.tscn")
const HUD_MAX_WIDTH: float = 760.0
const HUD_MAX_WIDTH_LANDSCAPE: float = 1100.0
const POWERUPS_MAX_WIDTH: float = 700.0
const POWERUPS_MAX_WIDTH_LANDSCAPE: float = 980.0
const BADGE_BG_COLOR: Color = Color(0.96, 0.22, 0.24, 1.0)
const BADGE_BORDER_COLOR: Color = Color(1.0, 0.9, 0.92, 0.96)
const TUTORIAL_STEP_COUNT: int = 6
const TUTORIAL_STEP_UNDO: int = 2
const TUTORIAL_STEP_PRISM: int = 3
const TUTORIAL_STEP_HINT: int = 4
const TUTORIAL_STEP_DONE: int = 5

func _ready() -> void:
	var stale_overlay: Node = get_node_or_null("RunEndOverlay")
	if stale_overlay:
		stale_overlay.queue_free()
	stale_overlay = get_node_or_null("RunEnterOverlay")
	if stale_overlay:
		stale_overlay.queue_free()
	modulate = Color(1, 1, 1, 1)
	$BoardView.modulate = Color(1, 1, 1, 1)
	$UI.modulate = Color(1, 1, 1, 1)
	_current_mode = RunManager.get_selected_mode()
	Typography.style_game(self)
	ThemeManager.apply_to_scene(self)
	_apply_neon_run_deck()
	BackgroundMood.register_controller($BackgroundController)
	_update_gameplay_mood_from_matches(0.0)
	BackgroundMood.reset_starfield_emission_taper()
	MusicManager.set_gameplay()
	VisualTestMode.apply_if_enabled($BackgroundController, $BackgroundController)
	_force_cabinet_background_palette()
	board.connect("match_made", Callable(self, "_on_match_made"))
	if not board.is_connected("match_feedback", Callable(self, "_on_match_feedback")):
		board.connect("match_feedback", Callable(self, "_on_match_feedback"))
	board.connect("move_committed", Callable(self, "_on_move_committed"))
	board.connect("no_moves", Callable(self, "_on_no_moves"))
	if not board.is_connected("non_match_tapped", Callable(self, "_on_non_match_tapped")):
		board.connect("non_match_tapped", Callable(self, "_on_non_match_tapped"))
	if not board.is_connected("prism_color_selected", Callable(self, "_on_prism_color_selected")):
		board.connect("prism_color_selected", Callable(self, "_on_prism_color_selected"))
	if not AdManager.is_connected("rewarded_powerup_earned", Callable(self, "_on_powerup_rewarded_earned")):
		AdManager.connect("rewarded_powerup_earned", Callable(self, "_on_powerup_rewarded_earned"))
	if not AdManager.is_connected("rewarded_closed", Callable(self, "_on_powerup_rewarded_closed")):
		AdManager.connect("rewarded_closed", Callable(self, "_on_powerup_rewarded_closed"))
	_undo_charges = FeatureFlags.powerup_undo_charges()
	_remove_color_charges = FeatureFlags.powerup_remove_color_charges()
	_hint_charges = FeatureFlags.powerup_hint_charges()
	var wallet_shop: Dictionary = NakamaService.get_shop_state()
	var stored_powerups: Dictionary = wallet_shop.get("powerups", {})
	_undo_charges += int(stored_powerups.get("undo", 0))
	_remove_color_charges += int(stored_powerups.get("prism", 0))
	_hint_charges += int(stored_powerups.get("hint", 0))
	if board_frame:
		board_frame.visible = true
		board_frame.z_index = -6
	if board_glow:
		board_glow.visible = true
		board_glow.z_index = -7
	for badge in [undo_badge, prism_badge, hint_badge]:
		badge.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
		badge.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.05, 0.95))
		badge.add_theme_constant_override("outline_size", 3)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for badge_panel in [undo_badge_panel, prism_badge_panel, hint_badge_panel]:
		_style_badge_panel(badge_panel)
	undo_button.tooltip_text = "Undo"
	remove_color_button.tooltip_text = "Prism"
	hint_button.tooltip_text = "Hint"
	for button in [undo_button, remove_color_button, hint_button]:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.clip_contents = false
	_refresh_audio_icon()
	powerup_flash.visible = false
	_board_anchor_pos = board.position
	_setup_cabinet_hud()
	_setup_combo_label()
	_setup_pressure_hud()
	_maybe_show_micro_tutorial()
	_update_score()
	_update_pressure_hud()
	_update_powerup_buttons()
	_center_board()
	call_deferred("_refresh_button_pivots")
	_play_enter_transition()
	Telemetry.mark_scene_loaded("game", _scene_opened_msec)

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_game(self)
		_apply_neon_run_deck()
		_center_board()
		call_deferred("_refresh_button_pivots")

func _process(delta: float) -> void:
	_tick_combo_timeout(delta)
	if _shake_time_left <= 0.0:
		if board:
			var anchored_position := _board_position_for_scale(board.scale)
			if board.position != anchored_position:
				board.position = anchored_position
		return
	_shake_time_left = max(0.0, _shake_time_left - delta)
	var amplitude : float = max(0.0, _shake_strength * (_shake_time_left / 0.12))
	var jitter := Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude))
	if board:
		board.position = _board_position_for_scale(board.scale, jitter)

func _on_match_made(group: Array) -> void:
	combo += 1
	_arm_combo_timeout()
	var gained := group.size() * 10 * combo
	score += gained
	_update_score()
	_update_pressure_hud()
	UiFx.pop(score_value_label, 1.04, 0.14)
	_show_score_burst(gained)
	_show_combo_escalation()
	_kick_screen_shake(min(11.0, 2.0 + float(group.size()) + (combo * 0.35)))
	_update_gameplay_mood_from_matches()
	BackgroundMood.reset_starfield_emission_taper()
	_play_feedback_tier(group.size())
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay) and _tutorial_step <= 1:
		_advance_tutorial_step()

func _on_match_feedback(group: Array, center_global: Vector2, color_idx: int = -1) -> void:
	var next_combo: int = combo + 1
	var gained: int = group.size() * 10 * next_combo
	var intensity: float = _match_feedback_intensity(group.size(), next_combo)
	_show_match_center_score(center_global, gained, next_combo, group.size(), intensity)
	var match_color := Color(0, 0, 0, 0)
	if board != null and color_idx >= 0:
		match_color = board.tile_color_for_index(color_idx)
	BackgroundMood.pulse_starfield(intensity, match_color)
	_pulse_match_chrome(intensity)

func _on_move_committed(_group: Array, snapshot: Array) -> void:
	_push_undo(snapshot, score, combo)

func _on_non_match_tapped(_cell: Vector2i) -> void:
	_break_combo()

func _update_score() -> void:
	score_value_label.text = "%d" % score
	if _combo_pod_label:
		_combo_pod_label.text = "COMBO\nx%d" % max(1, combo)
	if _rival_pod_label:
		var target: int = max(1, RunManager.get_active_rival_target())
		var progress: int = int(round(clamp(float(score) / float(target), 0.0, 1.0) * 100.0))
		_rival_pod_label.text = "RIVAL\n%d%%" % progress

func _on_pause_pressed() -> void:
	_close_audio_overlay()
	_hide_tutorial_for_overlay()
	_clear_board_hint_indicator()
	_set_prism_selection(false)
	_sync_gameplay_overlay_state()
	var pause := preload("res://src/scenes/PauseOverlay.tscn").instantiate()
	_pause_overlay = pause
	add_child(pause)
	pause.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause.tree_exited.connect(func() -> void:
		if _pause_overlay == pause:
			_pause_overlay = null
			_sync_gameplay_overlay_state()
	)
	get_tree().paused = true
	pause.connect("resume", Callable(self, "_on_resume"))
	pause.connect("quit", Callable(self, "_on_quit"))
	pause.connect("tutorial_requested", Callable(self, "_on_tutorial_requested"))
	_sync_gameplay_overlay_state()

func _on_resume() -> void:
	get_tree().paused = false
	_sync_gameplay_overlay_state()

func _on_quit() -> void:
	_close_audio_overlay()
	get_tree().paused = false
	_finish_run(false)

func _on_tutorial_requested() -> void:
	get_tree().paused = false
	SaveStore.set_tutorial_seen(false)
	SaveStore.set_tip_dismissed(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, false)
	_show_tutorial(true)

func _on_account_pressed() -> void:
	_hide_tutorial_for_overlay()
	_clear_board_hint_indicator()
	var modal := ModalManager.open_scene(ACCOUNT_MODAL_SCENE, self)
	_track_gameplay_overlay_modal(modal)

func _on_shop_pressed() -> void:
	_hide_tutorial_for_overlay()
	_clear_board_hint_indicator()
	var modal := ModalManager.open_scene(SHOP_MODAL_SCENE, self)
	_track_gameplay_overlay_modal(modal)

func _on_undo_pressed() -> void:
	if _prism_selecting:
		return
	if _undo_charges <= 0:
		var purchased := await _try_purchase_powerup_with_coins("undo")
		if not purchased:
			_request_powerup_refill("undo")
			return
	if _undo_stack.is_empty():
		return
	if _ending_transition_started:
		return
	var open_confirmed: bool = await _confirm_open_mode_powerup("undo")
	if not open_confirmed:
		return
	var state: Dictionary = _undo_stack.pop_back()
	board.restore_snapshot(state["grid"] as Array)
	score = int(state["score"])
	combo = int(state["combo"])
	if combo > 0:
		_arm_combo_timeout()
	else:
		_combo_timeout_remaining = -1.0
	_undo_charges -= 1
	_record_powerup_use("undo")
	call_deferred("_consume_powerup_server", "undo")
	_update_score()
	_update_pressure_hud()
	_update_gameplay_mood_from_matches(0.3)
	_update_powerup_buttons()
	_play_powerup_juice(Color(0.72, 0.9, 1.0, FeatureFlags.powerup_flash_alpha()))

func _on_remove_color_pressed() -> void:
	if _prism_selecting:
		_set_prism_selection(false)
		_update_powerup_buttons()
		return
	if _remove_color_charges <= 0:
		var purchased := await _try_purchase_powerup_with_coins("prism")
		if not purchased:
			_request_powerup_refill("prism")
			return
	if _ending_transition_started:
		return
	var open_confirmed: bool = await _confirm_open_mode_powerup("prism")
	if not open_confirmed:
		return
	_set_prism_selection(true)
	_update_powerup_buttons()

func _on_prism_color_selected(color_idx: int) -> void:
	if not _prism_selecting:
		return
	_set_prism_selection(false)
	if _ending_transition_started or _remove_color_charges <= 0:
		_update_powerup_buttons()
		return
	var snapshot: Array = board.capture_snapshot()
	var score_before: int = score
	var combo_before: int = combo
	var result: Dictionary = await board.apply_remove_color_powerup(color_idx)
	var removed: int = int(result.get("removed", 0))
	if removed <= 0:
		_update_powerup_buttons()
		return
	_push_undo(snapshot, score_before, combo_before)
	_remove_color_charges -= 1
	_record_powerup_use("prism")
	call_deferred("_consume_powerup_server", "prism")
	combo += 1
	_arm_combo_timeout()
	score += removed * 12
	_update_score()
	_update_pressure_hud()
	_show_score_burst(removed * 12)
	_update_gameplay_mood_from_matches(0.3)
	_update_powerup_buttons()
	MusicManager.on_match_made()
	_play_powerup_juice(Color(1.0, 0.92, 0.7, FeatureFlags.powerup_flash_alpha()))

func _on_hint_pressed() -> void:
	if _prism_selecting:
		return
	if _hint_charges <= 0:
		var purchased := await _try_purchase_powerup_with_coins("hint")
		if not purchased:
			_request_powerup_refill("hint")
			return
	if _ending_transition_started:
		return
	var open_confirmed: bool = await _confirm_open_mode_powerup("hint")
	if not open_confirmed:
		return
	var changed: bool = await board.apply_hint_powerup()
	if not changed:
		return
	_hint_charges -= 1
	_record_powerup_use("hint")
	call_deferred("_consume_powerup_server", "hint")
	_update_powerup_buttons()
	_play_powerup_juice(Color(0.8, 0.86, 1.0, FeatureFlags.powerup_flash_alpha()))

func _update_gameplay_mood_from_matches(fade_seconds: float = -1.0) -> void:
	var matches_left: int = board.board.count_available_matches()
	var n: float = FeatureFlags.gameplay_matches_normalizer()
	var max_calm_weight: float = FeatureFlags.gameplay_matches_max_calm_weight()
	var raw_calm_weight: float = 1.0 - clamp(float(matches_left) / n, 0.0, 1.0)
	var calm_weight: float = raw_calm_weight * max_calm_weight
	var fade: float = fade_seconds if fade_seconds >= 0.0 else FeatureFlags.gameplay_matches_mood_fade_seconds()
	BackgroundMood.set_mood_mix(calm_weight, fade)
	_update_pressure_hud()

func _force_cabinet_background_palette() -> void:
	var bg_controller := get_node_or_null("BackgroundController")
	if bg_controller and bg_controller.has_method("set_theme_palette"):
		bg_controller.call(
			"set_theme_palette",
			Color(0.002, 0.006, 0.024, 1.0),
			Color(0.010, 0.025, 0.078, 1.0),
			Color(0.004, 0.060, 0.155, 1.0),
			Color(0.145, 0.000, 0.300, 1.0)
		)
		bg_controller.call("set_mood_mix", 0.52, 0.0)
	var bg_rect := get_node_or_null("BackgroundController/ColorRect") as ColorRect
	if bg_rect and bg_rect.material:
		bg_rect.material.set_shader_parameter("color_a", Color(0.002, 0.006, 0.024, 1.0))
		bg_rect.material.set_shader_parameter("color_b", Color(0.010, 0.025, 0.078, 1.0))

func _update_powerup_buttons() -> void:
	undo_button.icon = _powerup_button_icon(ICON_UNDO, "undo")
	remove_color_button.icon = _powerup_button_icon(ICON_PRISM, "prism")
	hint_button.icon = _powerup_button_icon(ICON_HINT, "hint")
	remove_color_button.tooltip_text = "Tap a tile color to clear it" if _prism_selecting else "Prism"
	_update_badge(undo_badge_panel, undo_badge, _undo_charges, _pending_powerup_refill_type == "undo")
	var prism_hint: String = "Tap Color" if _prism_selecting else ""
	_update_badge(prism_badge_panel, prism_badge, _remove_color_charges, _pending_powerup_refill_type == "prism", prism_hint)
	_update_badge(hint_badge_panel, hint_badge, _hint_charges, _pending_powerup_refill_type == "hint")
	var tutorial_unlocks_undo := _tutorial_overlay != null and is_instance_valid(_tutorial_overlay) and _tutorial_step == TUTORIAL_STEP_UNDO
	undo_button.disabled = not tutorial_unlocks_undo and ((_undo_charges > 0 and _undo_stack.is_empty()) or _is_other_refill_pending("undo") or _prism_selecting)
	remove_color_button.disabled = _is_other_refill_pending("prism")
	hint_button.disabled = _is_other_refill_pending("hint") or _prism_selecting
	undo_button.tooltip_text = "Undo"
	remove_color_button.tooltip_text = "Tap a tile color to clear it" if _prism_selecting else "Prism"
	hint_button.tooltip_text = "Hint"

func _push_undo(snapshot: Array, score_snapshot: int, combo_snapshot: int) -> void:
	_undo_stack.append({
		"grid": snapshot.duplicate(true),
		"score": score_snapshot,
		"combo": combo_snapshot,
	})
	if _undo_stack.size() > 6:
		_undo_stack.pop_front()
	_update_powerup_buttons()

func _play_powerup_juice(flash_color: Color) -> void:
	if is_instance_valid(_powerup_juice_tween):
		_powerup_juice_tween.kill()
		_powerup_juice_tween = null
	if board == null or not is_instance_valid(board):
		return
	_set_board_scale_centered(Vector2.ONE)
	powerup_flash.visible = true
	powerup_flash.color = flash_color
	var board_scale_start: Vector2 = Vector2.ONE
	var board_scale_peak: Vector2 = board_scale_start * Vector2(1.03, 1.03)
	var t: Tween = create_tween()
	_powerup_juice_tween = t
	t.set_parallel(true)
	t.tween_method(Callable(self, "_set_board_scale_centered"), board_scale_start, board_scale_peak, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(powerup_flash, "color:a", FeatureFlags.powerup_flash_alpha(), 0.08)
	t.chain().tween_method(Callable(self, "_set_board_scale_centered"), board_scale_peak, board_scale_start, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(powerup_flash, "color:a", 0.0, FeatureFlags.powerup_flash_seconds())
	t.finished.connect(func() -> void:
		if board != null and is_instance_valid(board):
			_set_board_scale_centered(Vector2.ONE)
		powerup_flash.visible = false
		if _powerup_juice_tween == t:
			_powerup_juice_tween = null
	)

func _set_board_scale_centered(target_scale: Vector2) -> void:
	board.scale = target_scale
	board.position = _board_position_for_scale(target_scale)

func _board_position_for_scale(target_scale: Vector2, offset: Vector2 = Vector2.ZERO) -> Vector2:
	if board == null:
		return _board_anchor_pos + offset
	var board_half_size: Vector2 = _board_unscaled_size() * 0.5
	var center_anchor: Vector2 = _board_anchor_pos + board_half_size
	return center_anchor - Vector2(board_half_size.x * target_scale.x, board_half_size.y * target_scale.y) + offset

func _board_unscaled_size() -> Vector2:
	if board == null:
		return Vector2.ZERO
	return Vector2(float(board.width) * board.tile_size, float(board.height) * board.tile_size)

func _grant_bonus_powerup(powerup_type: String) -> void:
	match powerup_type:
		"undo":
			_undo_charges += 1
		"prism":
			_remove_color_charges += 1
		"hint":
			_hint_charges += 1
	_update_powerup_buttons()
	_play_powerup_juice(Color(1.0, 0.94, 0.58, 0.28))
	Input.vibrate_handheld(38, 0.65)

func _on_powerup_rewarded_earned() -> void:
	if _pending_powerup_refill_type.is_empty():
		return
	var powerup_type: String = _pending_powerup_refill_type
	_pending_powerup_refill_type = ""
	_grant_bonus_powerup(powerup_type)

func _on_powerup_rewarded_closed() -> void:
	if not _pending_powerup_refill_type.is_empty():
		_pending_powerup_refill_type = ""
		_update_powerup_buttons()

func _request_powerup_refill(powerup_type: String) -> void:
	if _ending_transition_started:
		return
	_set_prism_selection(false)
	if not _pending_powerup_refill_type.is_empty():
		return
	_pending_powerup_refill_type = powerup_type
	_update_powerup_buttons()
	if not AdManager.show_rewarded_for_powerup():
		_pending_powerup_refill_type = ""
		_update_powerup_buttons()

func _try_purchase_powerup_with_coins(powerup_type: String) -> bool:
	var cost: int = int(_powerup_coin_costs.get(powerup_type, 0))
	if cost <= 0:
		return false
	var purchase_id := "%s_%d" % [powerup_type, Time.get_unix_time_from_system()]
	var result: Dictionary = await NakamaService.purchase_powerup(powerup_type, 1, cost, purchase_id)
	if not result.get("ok", false):
		return false
	match powerup_type:
		"undo":
			_undo_charges += 1
		"prism":
			_remove_color_charges += 1
		"hint":
			_hint_charges += 1
	_run_coins_spent += cost
	_update_powerup_buttons()
	return true

func _consume_powerup_server(powerup_type: String) -> void:
	await NakamaService.consume_powerup(powerup_type, 1)

func _record_powerup_use(powerup_type: String) -> void:
	if not _powerup_usage.has(powerup_type):
		_powerup_usage[powerup_type] = 0
	_powerup_usage[powerup_type] = int(_powerup_usage[powerup_type]) + 1
	_run_powerups_used_total += 1
	_current_mode = "OPEN"
	Telemetry.mark_powerup_used(powerup_type, "OPEN", _remaining_powerup_charges(powerup_type))

func _confirm_open_mode_powerup(powerup_type: String) -> bool:
	if _current_mode == "OPEN":
		return true
	if _open_tip_shown_this_run:
		return true
	if not SaveStore.should_show_tip(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, true):
		_open_tip_shown_this_run = true
		return true
	if _open_tip_modal != null and is_instance_valid(_open_tip_modal):
		return false
	_hide_tutorial_for_overlay()
	_clear_board_hint_indicator()
	var modal := TUTORIAL_TIP_SCENE.instantiate()
	if modal.has_method("configure"):
		modal.configure({
			"title": "Open Run",
			"message": "Power-ups start an Open run.\nPure scores stay separate.",
			"confirm_text": "Use Power-Up",
			"cancel_text": "Cancel",
			"show_cancel": true,
			"checkbox_text": "Don't show again",
			"show_checkbox": true,
			"icon_texture": _powerup_icon_for_type(powerup_type),
			"target_rect": _powerup_control_rect(powerup_type),
			"avoid_rect": _board_control_rect(),
			"bottom_offset": _open_tip_bottom_offset(),
		})
	var result := {
		"accepted": false,
		"do_not_show_again": false,
	}
	if modal.has_signal("confirmed"):
		modal.confirmed.connect(func(do_not_show_again: bool) -> void:
			result["accepted"] = true
			result["do_not_show_again"] = do_not_show_again
		)
	if modal.has_signal("canceled"):
		modal.canceled.connect(func(do_not_show_again: bool) -> void:
			result["accepted"] = false
			result["do_not_show_again"] = do_not_show_again
		)
	var board_input_was_enabled: bool = true
	if board != null and is_instance_valid(board):
		board_input_was_enabled = board.is_board_input_enabled()
		board.set_board_input_enabled(false)
	_open_tip_modal = modal
	add_child(modal)
	_sync_gameplay_overlay_state()
	await modal.tree_exited
	_open_tip_modal = null
	_sync_gameplay_overlay_state()
	if board != null and is_instance_valid(board):
		board.set_board_input_enabled(board_input_was_enabled and not _gameplay_affordances_blocked())
	if bool(result.get("do_not_show_again", false)):
		_on_open_mode_tip_dismissed(true)
	if bool(result.get("accepted", false)):
		_open_tip_shown_this_run = true
		return true
	return false

func _on_open_mode_tip_dismissed(do_not_show_again: bool) -> void:
	if do_not_show_again:
		SaveStore.set_tip_dismissed(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, true)

func _powerup_icon_for_type(powerup_type: String) -> Texture2D:
	match powerup_type:
		"undo":
			return ICON_UNDO
		"prism":
			return ICON_PRISM
		"hint":
			return ICON_HINT
	return null

func _powerup_control_rect(powerup_type: String) -> Rect2:
	var control: Control = null
	match powerup_type:
		"undo":
			control = undo_button
		"prism":
			control = remove_color_button
		"hint":
			control = hint_button
	if control == null or not is_instance_valid(control):
		return Rect2()
	return control.get_global_rect()

func _board_control_rect() -> Rect2:
	if board == null or not is_instance_valid(board):
		return Rect2()
	return Rect2(
		board.global_position,
		Vector2(float(board.width) * board.tile_size, float(board.height) * board.tile_size)
	)

func _open_tip_bottom_offset() -> float:
	var view_height: float = get_viewport_rect().size.y
	if powerups_row == null or not is_instance_valid(powerups_row):
		return 112.0
	return max(88.0, view_height - powerups_row.global_position.y + 18.0)

func _on_audio_pressed() -> void:
	if is_instance_valid(_audio_overlay):
		_close_audio_overlay()
		return
	var tracks: Array[Dictionary] = _music_tracks()
	if tracks.is_empty():
		return
	_hide_tutorial_for_overlay()
	_clear_board_hint_indicator()
	var overlay := AUDIO_TRACK_OVERLAY_SCENE.instantiate()
	if overlay == null:
		return
	add_child(overlay)
	_audio_overlay = overlay
	_sync_gameplay_overlay_state()
	overlay.setup(_track_names_from_tracks(tracks), _selected_track_index_for_current(tracks))
	overlay.track_selected.connect(_on_audio_overlay_track_selected)
	overlay.closed.connect(_on_audio_overlay_closed)

func _on_audio_overlay_track_selected(_track_name: String, index: int) -> void:
	_apply_audio_track_index(index)

func _on_audio_overlay_closed() -> void:
	_audio_overlay = null
	_sync_gameplay_overlay_state()

func _close_audio_overlay() -> void:
	if not is_instance_valid(_audio_overlay):
		_audio_overlay = null
		return
	_audio_overlay.queue_free()
	_audio_overlay = null
	_sync_gameplay_overlay_state()

func _music_tracks() -> Array[Dictionary]:
	return MusicManager.get_available_tracks()

func _track_names_from_tracks(tracks: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for track in tracks:
		names.append(str(track.get("name", "Track")))
	return names

func _selected_track_index_for_current(tracks: Array[Dictionary]) -> int:
	if tracks.is_empty():
		return 0
	var current_id: String = str(MusicManager.get_current_track_id())
	for i in range(tracks.size()):
		if str(tracks[i].get("id", "")) == current_id:
			return i
	return 0

func _apply_audio_track_index(index: int) -> void:
	var tracks: Array[Dictionary] = _music_tracks()
	if tracks.is_empty():
		return
	var selected: int = clampi(index, 0, tracks.size() - 1)
	var track_id: String = str(tracks[selected].get("id", ""))
	if track_id.is_empty():
		return
	MusicManager.set_track(track_id, true)
	_sync_audio_overlay_selection()
	_refresh_audio_icon()

func _sync_audio_overlay_selection() -> void:
	if not is_instance_valid(_audio_overlay):
		return
	var tracks: Array[Dictionary] = _music_tracks()
	_audio_overlay.set_selected_index(_selected_track_index_for_current(tracks))

static func is_muted_track(track_id: String) -> bool:
	return track_id.strip_edges().to_lower() == "off"

func _refresh_audio_icon() -> void:
	if audio_button == null:
		return
	var muted: bool = is_muted_track(str(MusicManager.get_current_track_id()))
	audio_button.set("icon_texture", ICON_MUSIC_OFF if muted else ICON_MUSIC_ON)
	var label: String = "Audio Off" if muted else "Audio"
	audio_button.set("tooltip_text_override", label)
	audio_button.set("accessibility_name_override", label)

func _powerup_button_icon(base_icon: Texture2D, powerup_type: String) -> Texture2D:
	if _prism_selecting and powerup_type == "prism":
		return ICON_CANCEL
	if _pending_powerup_refill_type == powerup_type:
		return ICON_LOADING
	return base_icon

func _update_badge(panel: PanelContainer, label: Label, charges: int, is_loading: bool, custom_text: String = "") -> void:
	if panel == null or label == null:
		return
	_style_badge_panel(panel)
	if _gameplay_affordances_blocked():
		panel.visible = false
		label.visible = false
		return
	label.visible = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not custom_text.is_empty():
		label.text = custom_text
		label.modulate = Color(0.98, 0.99, 1.0, 0.98)
		_set_badge_centered(panel, label)
	elif is_loading:
		label.text = "..."
		label.modulate = Color(0.78, 0.86, 1.0, 0.94)
		_set_badge_centered(panel, label)
	elif charges > 0:
		label.text = "x%d" % charges
		label.modulate = Color(0.98, 0.99, 1.0, 0.98)
		_set_badge_top_right(panel)
		_fit_badge_font_size(label)
	else:
		panel.visible = false
		label.visible = false
		label.text = ""

func _set_badge_top_right(panel: PanelContainer) -> void:
	if panel == null:
		return
	var row_height: float = 110.0
	if powerups_row and powerups_row.size.y > 0.0:
		row_height = powerups_row.size.y
	var radius: float = clamp(row_height * 0.17, 15.0, 22.0)
	panel.visible = true
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -radius
	panel.offset_top = -radius
	panel.offset_right = radius
	panel.offset_bottom = radius
	panel.z_index = 10
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END

func _set_badge_centered(panel: PanelContainer, label: Label) -> void:
	if panel == null or label == null:
		return
	panel.visible = true
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_top = 6.0
	panel.offset_right = -8.0
	panel.offset_bottom = -6.0
	label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_SEMIBOLD))
	label.add_theme_font_size_override("font_size", int(round(clamp(panel.size.y * 0.34, Typography.px(13.0), Typography.px(22.0)))))

func _fit_badge_font_size(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return
	if label.size.x <= 0.0:
		return
	var max_width: float = max(24.0, label.size.x - 10.0)
	var minimum_font_size: int = Typography.px(12.0)
	var font_size_candidate: int = max(minimum_font_size, label.get_theme_font_size("font_size"))
	while font_size_candidate > minimum_font_size:
		var measured_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size_candidate).x
		if measured_width <= max_width:
			break
		font_size_candidate -= 1
	label.add_theme_font_size_override("font_size", font_size_candidate)

func _style_badge_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_BG_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BADGE_BORDER_COLOR
	style.corner_radius_top_left = 128
	style.corner_radius_top_right = 128
	style.corner_radius_bottom_left = 128
	style.corner_radius_bottom_right = 128
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_neon_run_deck() -> void:
	NEON_RUN_DECK.apply_game(self)

func _is_other_refill_pending(powerup_type: String) -> bool:
	return not _pending_powerup_refill_type.is_empty() and _pending_powerup_refill_type != powerup_type

func _set_prism_selection(enabled: bool) -> void:
	_prism_selecting = enabled and _remove_color_charges > 0 and not _ending_transition_started
	if board:
		board.set_prism_pick_mode(_prism_selecting)

func _on_no_moves() -> void:
	_finish_run(true)

func _finish_run(completed_by_gameplay: bool) -> void:
	if _run_finished:
		return
	if _ending_transition_started:
		return
	_close_audio_overlay()
	_combo_timeout_remaining = -1.0
	get_tree().paused = false
	_ending_transition_started = true
	_set_prism_selection(false)
	await _play_end_transition()
	_run_finished = true
	RunManager.set_run_leaderboard_context(_run_powerups_used_total, _run_coins_spent, _powerup_usage)
	RunManager.end_game(score, completed_by_gameplay)

func _play_end_transition() -> void:
	set_process_input(false)
	MusicManager.fade_out_hype_layers(0.5)
	# End transition should always drive the background fully calm before white-out.
	BackgroundMood.set_mood(BackgroundMood.Mood.CALM, 0.45)
	var overlay := ColorRect.new()
	overlay.name = "RunEndOverlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_parallel(true)
	fade.tween_property($BoardView, "modulate:a", 0.0, 0.45)
	fade.tween_property($UI, "modulate:a", 0.0, 0.35)
	fade.tween_property(overlay, "color:a", 0.95, 0.45)
	await fade.finished

func _play_enter_transition() -> void:
	board.set_process_input(false)
	set_process_input(false)
	var overlay := ColorRect.new()
	overlay.name = "RunEnterOverlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(overlay, "color:a", 0.0, 0.35)
	t.finished.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		board.set_process_input(true)
		set_process_input(true)
	)

func _center_board() -> void:
	if board == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return

	var is_wide: bool = ArcadeResponsiveLayout.is_wide(view_size)
	var target_content_width: float = view_size.x * ArcadeResponsiveLayout.gameplay_content_ratio(view_size)
	var hud_width_cap: float = ArcadeResponsiveLayout.gameplay_hud_max_width(view_size, HUD_MAX_WIDTH, HUD_MAX_WIDTH_LANDSCAPE)
	var max_column_width: float = max(260.0, min(min(hud_width_cap, view_size.x - 8.0), target_content_width))
	var min_column_width_target: float = 500.0 if is_wide else 340.0
	var min_column_width: float = min(min_column_width_target, max_column_width)
	var content_width: float = clamp(target_content_width, min_column_width, max_column_width)
	var content_left: float = (view_size.x - content_width) * 0.5

	_layout_top_bar(view_size, content_left, content_width)
	_layout_top_right(view_size)

	var powerup_row_height: float = clamp(view_size.y * (0.13 if is_wide else 0.16), 84.0, 122.0)
	var powerups_width_cap: float = ArcadeResponsiveLayout.gameplay_powerups_max_width(
		view_size,
		POWERUPS_MAX_WIDTH,
		POWERUPS_MAX_WIDTH_LANDSCAPE
	)
	var max_row_width: float = max(280.0, min(powerups_width_cap, content_width))
	var min_row_width_target: float = 420.0 if is_wide else 320.0
	var min_row_width: float = min(min_row_width_target, max_row_width)
	var powerup_row_width: float = clamp(content_width, min_row_width, max_row_width)
	_layout_powerups(view_size, powerup_row_width, powerup_row_height)
	_apply_responsive_hud_typography(content_width, top_bar_bg.size.y, powerup_row_height)

	_layout_cabinet_title(view_size)
	var vertical_gap: float = clamp(view_size.y * (0.014 if is_wide else 0.018), 8.0, 22.0)
	var top_limit: float = view_size.y * 0.14
	if top_bar_bg and top_bar_bg.size.y > 0.0:
		top_limit = top_bar_bg.position.y + top_bar_bg.size.y + vertical_gap
	_layout_pressure_hud(view_size, content_left, content_width)
	if _pressure_hud and _pressure_hud.visible:
		top_limit = max(top_limit, _pressure_hud.position.y + _pressure_hud.size.y + vertical_gap)
	var bottom_limit: float = view_size.y * (0.84 if is_wide else 0.81)
	if powerups_row and powerups_row.size.y > 0.0:
		bottom_limit = powerups_row.position.y - vertical_gap
	var available_width: float = max(120.0, content_width)
	var available_height: float = max(120.0, bottom_limit - top_limit)
	var fit_w: float = floor(available_width / float(board.width))
	var fit_h: float = floor(available_height / float(board.height))
	var target_tile_size: float = clamp(min(fit_w, fit_h), 36.0, 188.0)
	board.set_tile_size(target_tile_size)
	var board_size: Vector2 = Vector2(board.width * board.tile_size, board.height * board.tile_size)
	var frame_padding: float = clamp(board.tile_size * 0.18, 12.0, 24.0)
	var framed_board_width: float = board_size.x + (frame_padding * 2.0)
	var final_hud_width: float = clamp(framed_board_width, min_column_width, max(view_size.x - 8.0, max_column_width))
	var final_hud_left: float = (view_size.x - final_hud_width) * 0.5
	_layout_top_bar(view_size, final_hud_left, final_hud_width)
	_layout_top_right(view_size)
	_layout_pressure_hud(view_size, final_hud_left, final_hud_width)
	_apply_responsive_hud_typography(final_hud_width, top_bar_bg.size.y, powerup_row_height)
	var board_bias: float = 0.42 if not is_wide else 0.48
	board.position = Vector2(
		(view_size.x - board_size.x) * 0.5,
		top_limit + ((available_height - board_size.y) * board_bias)
	)
	_board_anchor_pos = board.position

	powerup_row_width = clamp(board_size.x + max(84.0, board.tile_size * 0.8), min_row_width, max_row_width)
	_layout_powerups(view_size, powerup_row_width, powerup_row_height)
	_apply_responsive_hud_typography(content_width, top_bar_bg.size.y, powerup_row_height)
	_refresh_button_pivots()

	if board_frame:
		board_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board_frame.position = board.position - Vector2(frame_padding, frame_padding)
		board_frame.size = board_size + Vector2(frame_padding * 2.0, frame_padding * 2.0)
	if board_glow:
		var glow_padding: float = clamp(board.tile_size * 0.28, 18.0, 36.0)
		board_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board_glow.position = board.position - Vector2(glow_padding, glow_padding)
		board_glow.size = board_size + Vector2(glow_padding * 2.0, glow_padding * 2.0)
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_layout_tutorial_overlay()

func _layout_top_bar(view_size: Vector2, content_left: float, content_width: float) -> void:
	if top_bar_bg == null or top_bar == null:
		return
	var is_wide: bool = ArcadeResponsiveLayout.is_wide(view_size)
	var title_band: float = _cabinet_title_height(view_size)
	var top_margin: float = title_band + clamp(view_size.y * (0.006 if is_wide else 0.01), 4.0, 12.0)
	var bar_height: float = clamp(view_size.y * (0.16 if is_wide else 0.17), 96.0, 150.0)
	top_bar_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_bar_bg.position = Vector2(content_left, top_margin)
	top_bar_bg.size = Vector2(content_width, bar_height)

	var content_inset_x: float = clamp(content_width * 0.055, 14.0, 34.0)
	var content_inset_y: float = clamp(bar_height * 0.09, 8.0, 14.0)
	var content_height: float = max(56.0, bar_height - (content_inset_y * 2.0))
	var right_reserve: float = clamp(content_width * 0.03, 12.0, 28.0)
	top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_bar.position = Vector2(content_left + content_inset_x, top_margin)
	top_bar.size = Vector2(
		max(220.0, content_width - (content_inset_x * 2.0) - right_reserve),
		bar_height
	)
	top_bar.add_theme_constant_override("separation", int(round(clamp(content_width * 0.016, 10.0, 20.0))))
	if score_box:
		score_box.custom_minimum_size.y = 0.0
		score_box.alignment = BoxContainer.ALIGNMENT_CENTER
		score_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		score_box.add_theme_constant_override("separation", int(round(clamp(content_height * 0.02, 2.0, 5.0))))
	if pause_button:
		var pause_size: float = clamp(bar_height * 0.74, 52.0, 82.0)
		pause_button.custom_minimum_size = Vector2(pause_size, pause_size)
		pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		pause_button.icon = null
		pause_button.text = ""
		if pause_icon:
			var pause_icon_size: float = clamp(pause_size * 0.48, 28.0, 40.0)
			pause_icon.custom_minimum_size = Vector2(pause_icon_size, pause_icon_size)
	for pod in [_combo_pod_label, _rival_pod_label]:
		if pod:
			pod.custom_minimum_size = Vector2(clamp(content_width * 0.23, 104.0, 210.0), content_height)

func _layout_top_right(view_size: Vector2) -> void:
	if top_right_bar == null or audio_button == null:
		return
	var margin: float = clamp(min(view_size.x, view_size.y) * 0.045, 12.0, 32.0)
	var icon_size: float = clamp(min(view_size.x, view_size.y) * 0.105, 54.0, 82.0)
	var separation: float = clamp(icon_size * 0.13, 8.0, 12.0)
	var button_count: int = 3
	var cluster_width: float = (icon_size * float(button_count)) + (separation * float(button_count - 1))
	var visual_padding: float = 8.0
	var y_position: float = margin
	if top_bar_bg and top_bar_bg.size.y > 0.0:
		y_position = top_bar_bg.position.y + ((top_bar_bg.size.y - icon_size) * 0.5)
	top_right_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_right_bar.position = Vector2(view_size.x - margin - cluster_width - visual_padding, y_position - visual_padding)
	top_right_bar.size = Vector2(cluster_width + (visual_padding * 2.0), icon_size + (visual_padding * 2.0))
	top_right_bar.custom_minimum_size = top_right_bar.size
	if top_right_bar is BoxContainer:
		var box := top_right_bar as BoxContainer
		box.alignment = BoxContainer.ALIGNMENT_BEGIN
		box.add_theme_constant_override("separation", int(round(separation)))
	for button in [account_button, shop_button, audio_button]:
		if button:
			button.custom_minimum_size = Vector2(icon_size, icon_size)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _apply_responsive_hud_typography(content_width: float, bar_height: float, powerup_row_height: float) -> void:
	var content_inset_y: float = clamp(bar_height * 0.09, 8.0, 14.0)
	var score_inner_height: float = max(48.0, bar_height - (content_inset_y * 2.0))
	var caption_size: int = int(round(clamp(score_inner_height * 0.18, Typography.px(13.0), Typography.px(21.0))))
	var value_size: int = int(round(clamp(score_inner_height * 0.42, Typography.px(28.0), Typography.px(48.0))))
	if content_width < 520.0:
		caption_size = min(caption_size, Typography.px(16.0))
		value_size = min(value_size, Typography.px(36.0))
	if score_caption_label:
		score_caption_label.add_theme_font_size_override("font_size", caption_size)
		score_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_caption_label.custom_minimum_size.y = clamp(score_inner_height * 0.18, 16.0, 24.0)
	if score_value_label:
		score_value_label.add_theme_font_size_override("font_size", value_size)
		score_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_value_label.custom_minimum_size.y = clamp(score_inner_height * 0.42, 30.0, 50.0)
	var pressure_font: int = int(round(clamp(bar_height * 0.15, Typography.px(12.0), Typography.px(18.0))))
	for label in [_pressure_heat_label, _pressure_rival_label, _pressure_matches_label]:
		if label:
			label.add_theme_font_size_override("font_size", pressure_font)
	if _score_burst_label:
		_score_burst_label.add_theme_font_size_override("font_size", int(round(clamp(bar_height * 0.24, Typography.px(18.0), Typography.px(30.0)))))
	for pod in [_combo_pod_label, _rival_pod_label]:
		if pod:
			pod.add_theme_font_size_override("font_size", int(round(clamp(score_inner_height * 0.23, Typography.px(16.0), Typography.px(28.0)))))
	if _cabinet_title_label:
		_cabinet_title_label.add_theme_font_size_override("font_size", int(round(clamp(bar_height * 0.52, Typography.px(40.0), Typography.px(78.0)))))

	var badge_font_size: int = int(round(clamp(powerup_row_height * 0.32, Typography.px(14.0), Typography.px(26.0))))
	for badge in [undo_badge, prism_badge, hint_badge]:
		if badge:
			badge.add_theme_font_size_override("font_size", badge_font_size)
			_fit_badge_font_size(badge)

func _layout_powerups(view_size: Vector2, row_width: float, row_height: float) -> void:
	if powerups_row == null:
		return
	var is_wide: bool = ArcadeResponsiveLayout.is_wide(view_size)
	var bottom_margin: float = clamp(view_size.y * (0.024 if is_wide else 0.035), 10.0, 28.0)
	powerups_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	powerups_row.position = Vector2((view_size.x - row_width) * 0.5, view_size.y - bottom_margin - row_height)
	powerups_row.size = Vector2(row_width, row_height)
	powerups_row.add_theme_constant_override("separation", int(round(clamp(row_width * 0.03, 12.0, 22.0))))
	for button in [undo_button, remove_color_button, hint_button]:
		if button:
			button.custom_minimum_size = Vector2(0.0, row_height)

func _refresh_button_pivots() -> void:
	for button_variant in [pause_button, account_button, shop_button, audio_button, undo_button, remove_color_button, hint_button]:
		var button: Control = button_variant as Control
		if button == null:
			continue
		if button.size.x <= 0.0 or button.size.y <= 0.0:
			continue
		button.pivot_offset = button.size * 0.5

func _setup_combo_label() -> void:
	if _combo_label != null:
		return
	_combo_label = Label.new()
	_combo_label.name = "ComboEscalation"
	_combo_label.visible = false
	_combo_label.text = ""
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.5, 0.98))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.22, 0.95))
	_combo_label.add_theme_constant_override("outline_size", 3)
	_combo_label.add_theme_font_size_override("font_size", Typography.px(28.0))
	_combo_label.anchor_left = 0.5
	_combo_label.anchor_right = 0.5
	_combo_label.anchor_top = 0.0
	_combo_label.anchor_bottom = 0.0
	_combo_label.offset_left = -160.0
	_combo_label.offset_right = 160.0
	_combo_label.offset_top = 96.0
	_combo_label.offset_bottom = 146.0
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_combo_label)

func _setup_cabinet_hud() -> void:
	if _cabinet_title_label == null:
		_cabinet_title_label = Label.new()
		_cabinet_title_label.name = "CabinetTitle"
		_cabinet_title_label.text = "LUMARUSH"
		_cabinet_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cabinet_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cabinet_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cabinet_title_label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
		_cabinet_title_label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
		_cabinet_title_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.85, 1.0, 0.95))
		_cabinet_title_label.add_theme_color_override("font_outline_color", Color(0.95, 0.18, 1.0, 0.72))
		_cabinet_title_label.add_theme_constant_override("outline_size", 5)
		$UI.add_child(_cabinet_title_label)
	if _combo_pod_label == null:
		_combo_pod_label = _make_hud_pod("ComboPod", Color(1.0, 0.76, 0.1, 1.0))
		top_bar.add_child(_combo_pod_label)
		top_bar.move_child(_combo_pod_label, min(1, top_bar.get_child_count() - 1))
	if _rival_pod_label == null:
		_rival_pod_label = _make_hud_pod("RivalPod", Color(0.55, 0.24, 1.0, 1.0))
		top_bar.add_child(_rival_pod_label)
		top_bar.move_child(_rival_pod_label, min(2, top_bar.get_child_count() - 1))
	score_caption_label.text = "SCORE"
	_update_score()

func _make_hud_pod(node_name: String, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_SEMIBOLD))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.08, 0.98))
	label.add_theme_constant_override("outline_size", 4)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.010, 0.016, 0.054, 0.72)
	backing.border_color = color
	backing.border_width_left = 3
	backing.border_width_top = 3
	backing.border_width_right = 3
	backing.border_width_bottom = 3
	backing.corner_radius_top_left = 5
	backing.corner_radius_top_right = 5
	backing.corner_radius_bottom_left = 5
	backing.corner_radius_bottom_right = 5
	backing.shadow_color = Color(color.r, color.g, color.b, 0.30)
	backing.shadow_size = 14
	label.add_theme_stylebox_override("normal", backing)
	return label

func _cabinet_title_height(view_size: Vector2) -> float:
	return clamp(view_size.y * (0.085 if ArcadeResponsiveLayout.is_wide(view_size) else 0.092), 54.0, 104.0)

func _layout_cabinet_title(view_size: Vector2) -> void:
	if _cabinet_title_label == null:
		return
	var title_h: float = _cabinet_title_height(view_size)
	var title_w: float = min(view_size.x * 0.76, 960.0)
	_cabinet_title_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_cabinet_title_label.position = Vector2((view_size.x - title_w) * 0.5, clamp(view_size.y * 0.008, 4.0, 12.0))
	_cabinet_title_label.size = Vector2(title_w, title_h)
	_cabinet_title_label.pivot_offset = _cabinet_title_label.size * 0.5

func _setup_pressure_hud() -> void:
	if _pressure_hud != null:
		return
	_pressure_hud = PanelContainer.new()
	_pressure_hud.name = "PressureHud"
	_pressure_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pressure_hud.z_index = 8
	_pressure_hud.add_theme_stylebox_override("panel", _pressure_panel_style())
	$UI.add_child(_pressure_hud)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	_pressure_hud.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	_pressure_heat_label = _make_pressure_label("Heat")
	row.add_child(_pressure_heat_label)
	_pressure_bar = ProgressBar.new()
	_pressure_bar.name = "RivalMeter"
	_pressure_bar.min_value = 0.0
	_pressure_bar.max_value = 100.0
	_pressure_bar.value = 0.0
	_pressure_bar.show_percentage = false
	_pressure_bar.custom_minimum_size = Vector2(180.0, 14.0)
	_pressure_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pressure_bar.add_theme_stylebox_override("background", _pressure_bar_style(Color(0.05, 0.09, 0.16, 0.88)))
	_pressure_bar.add_theme_stylebox_override("fill", _pressure_bar_style(Color(0.18, 0.86, 1.0, 0.92)))
	row.add_child(_pressure_bar)
	_pressure_rival_label = _make_pressure_label("Rival")
	row.add_child(_pressure_rival_label)
	_pressure_matches_label = _make_pressure_label("Matches")
	row.add_child(_pressure_matches_label)

	_score_burst_label = Label.new()
	_score_burst_label.name = "ScoreBurst"
	_score_burst_label.visible = false
	_score_burst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_burst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_burst_label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
	_score_burst_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.42, 1.0))
	_score_burst_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.12, 0.96))
	_score_burst_label.add_theme_constant_override("outline_size", 4)
	$UI.add_child(_score_burst_label)

func _make_pressure_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_MEDIUM))
	label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.08, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	return label

func _pressure_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.11, 0.72)
	style.border_color = Color(0.12, 0.92, 1.0, 0.52)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.anti_aliasing = true
	return style

func _pressure_bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	return style

func _layout_pressure_hud(view_size: Vector2, content_left: float, content_width: float) -> void:
	if _pressure_hud == null or top_bar_bg == null:
		return
	var is_wide: bool = ArcadeResponsiveLayout.is_wide(view_size)
	var hud_height: float = clamp(view_size.y * (0.058 if is_wide else 0.064), 42.0, 58.0)
	var hud_gap: float = clamp(view_size.y * 0.007, 5.0, 9.0)
	_pressure_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pressure_hud.position = Vector2(content_left, top_bar_bg.position.y + top_bar_bg.size.y + hud_gap)
	_pressure_hud.size = Vector2(content_width, hud_height)
	_pressure_hud.custom_minimum_size = _pressure_hud.size
	if _pressure_bar:
		_pressure_bar.custom_minimum_size.x = clamp(content_width * 0.28, 90.0, 260.0)
	if _score_burst_label and board:
		var board_size: Vector2 = Vector2(float(board.width) * board.tile_size, float(board.height) * board.tile_size)
		_score_burst_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_score_burst_label.position = board.position + Vector2(board_size.x * 0.5 - 120.0, board_size.y * 0.14)
		_score_burst_label.size = Vector2(240.0, 46.0)

func _update_pressure_hud() -> void:
	if _pressure_hud == null:
		return
	var target: int = max(1, RunManager.get_active_rival_target())
	var progress: float = clamp(float(score) / float(target), 0.0, 1.0)
	var matches_left: int = 0
	if board and board.board:
		matches_left = board.board.count_available_matches()
	var heat_text: String = "HEAT x%d" % max(1, combo)
	if combo >= HIGH_COMBO_THRESHOLD:
		heat_text = "OVERDRIVE x%d" % combo
		_pressure_heat_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.50, 1.0))
	else:
		_pressure_heat_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 0.96))
	_pressure_heat_label.text = heat_text
	_pressure_rival_label.text = "RIVAL %d%%" % int(round(progress * 100.0))
	_pressure_matches_label.text = "%d LIVE MATCHES" % matches_left
	if _combo_pod_label:
		_combo_pod_label.text = "COMBO\nx%d" % max(1, combo)
	if _rival_pod_label:
		_rival_pod_label.text = "RIVAL\n%d%%" % int(round(progress * 100.0))
	_pressure_bar.value = progress * 100.0
	if progress >= 1.0:
		_pressure_bar.add_theme_stylebox_override("fill", _pressure_bar_style(Color(1.0, 0.82, 0.28, 0.95)))
	elif combo >= HIGH_COMBO_THRESHOLD:
		_pressure_bar.add_theme_stylebox_override("fill", _pressure_bar_style(Color(0.50, 0.20, 1.0, 0.92)))
	else:
		_pressure_bar.add_theme_stylebox_override("fill", _pressure_bar_style(Color(0.18, 0.86, 1.0, 0.92)))

func _show_score_burst(points: int) -> void:
	if _score_burst_label == null or points <= 0:
		return
	_score_burst_label.visible = true
	_score_burst_label.text = "+%d" % points
	_score_burst_label.modulate = Color(1, 1, 1, 1)
	_score_burst_label.scale = Vector2(0.82, 0.82)
	var start_y: float = _score_burst_label.position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_score_burst_label, "scale", Vector2(1.18, 1.18), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_score_burst_label, "position:y", start_y - 18.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_score_burst_label, "modulate:a", 0.0, 0.28)
	tween.finished.connect(func() -> void:
		if _score_burst_label:
			_score_burst_label.visible = false
			_score_burst_label.position.y = start_y
	)

func _show_combo_escalation() -> void:
	if _combo_label == null or combo < 2:
		return
	_combo_label.visible = true
	_combo_label.modulate = Color(1, 1, 1, 1)
	_combo_label.text = "COMBO x%d" % combo
	_combo_label.position.y = 82.0
	var tween := create_tween()
	tween.tween_property(_combo_label, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(_combo_label, "position:y", 64.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_combo_label, "modulate:a", 0.0, 0.38)
	tween.finished.connect(func() -> void:
		if _combo_label:
			_combo_label.visible = false
	)

func _show_match_center_score(center_global: Vector2, gained: int, next_combo: int, group_size: int, intensity: float) -> void:
	var label := Label.new()
	label.name = "MatchScoreBurst"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 80
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "+%d" % gained
	label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
	if next_combo >= 3:
		label.text = "+%d\nCHAIN x%d" % [gained, next_combo]
	elif group_size >= 5:
		label.text = "+%d\nBIG CLEAR" % gained
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.30, 1.0) if group_size < 5 else Color(1.0, 0.22, 0.30, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.08, 0.98))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", int(round(clamp(30.0 + (intensity * 8.0), 34.0, 58.0))))
	label.size = Vector2(260.0, 96.0)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.68, 0.68)
	$UI.add_child(label)
	label.global_position = center_global - (label.size * 0.5)
	var start_y: float = label.position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.22, 1.22), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", start_y - 54.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _pulse_match_chrome(intensity: float) -> void:
	if board_glow:
		board_glow.color.a = min(0.50, 0.18 + (intensity * 0.10))
		var glow_tween := create_tween()
		glow_tween.tween_property(board_glow, "color:a", 0.18, 0.34)
	if _combo_pod_label:
		UiFx.pop(_combo_pod_label, 1.05 + (intensity * 0.015), 0.16)
	if _rival_pod_label:
		UiFx.pop(_rival_pod_label, 1.03 + (intensity * 0.012), 0.14)

func _match_feedback_intensity(group_size: int, next_combo: int) -> float:
	var size_boost: float = max(0.0, float(group_size - 3)) * 0.22
	var combo_boost: float = max(0.0, float(next_combo - 1)) * 0.12
	return clamp(1.0 + size_boost + combo_boost, 1.0, 2.6)

func _kick_screen_shake(strength: float) -> void:
	_shake_strength = max(_shake_strength, strength)
	_shake_time_left = 0.12

func _play_feedback_tier(group_size: int) -> void:
	MusicManager.on_match_made()
	if combo >= HIGH_COMBO_THRESHOLD:
		MusicManager.maybe_trigger_high_combo_fx()
	if combo >= 7 or group_size >= 6:
		MusicManager.maybe_trigger_high_combo_fx()
	_kick_screen_shake(min(14.0, 3.0 + float(combo) * 0.55))

func _maybe_show_micro_tutorial() -> void:
	if SaveStore.is_tutorial_seen():
		return
	call_deferred("_show_tutorial", false)

func _show_tutorial(force: bool = false) -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_layout_tutorial_overlay()
		return
	if not force and SaveStore.is_tutorial_seen():
		return
	_close_tutorial(false)
	_tutorial_step = 0
	_tutorial_overlay = Control.new()
	_tutorial_overlay.name = "TutorialOverlay"
	_tutorial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.z_index = 60
	_tutorial_overlay.gui_input.connect(Callable(self, "_on_tutorial_gui_input"))
	$UI.add_child(_tutorial_overlay)

	_tutorial_panel = Panel.new()
	_tutorial_panel.name = "Panel"
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_panel.gui_input.connect(Callable(self, "_on_tutorial_gui_input"))
	TUTORIAL_TEMPLATE.style_panel(_tutorial_panel)
	_tutorial_overlay.add_child(_tutorial_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	TUTORIAL_TEMPLATE.apply_margins(margin)
	_tutorial_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	_tutorial_title = Label.new()
	_tutorial_title.name = "Title"
	TUTORIAL_TEMPLATE.style_label(_tutorial_title, true)
	box.add_child(_tutorial_title)
	_tutorial_message = Label.new()
	_tutorial_message.name = "Message"
	TUTORIAL_TEMPLATE.style_label(_tutorial_message, false)
	box.add_child(_tutorial_message)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	_tutorial_skip_button = Button.new()
	_tutorial_skip_button.name = "Skip"
	_tutorial_skip_button.text = "Skip Tutorial"
	TUTORIAL_TEMPLATE.style_button(_tutorial_skip_button, false)
	_tutorial_skip_button.pressed.connect(Callable(self, "_on_tutorial_skip_pressed"))
	buttons.add_child(_tutorial_skip_button)
	_tutorial_next_button = Button.new()
	_tutorial_next_button.name = "Next"
	_tutorial_next_button.text = "Next"
	TUTORIAL_TEMPLATE.style_button(_tutorial_next_button, true)
	_tutorial_next_button.pressed.connect(Callable(self, "_on_tutorial_next_pressed"))
	buttons.add_child(_tutorial_next_button)
	_update_tutorial_step()
	_layout_tutorial_overlay()
	_play_tutorial_step_motion()

func _on_tutorial_next_pressed() -> void:
	_advance_tutorial_step()

func _on_tutorial_gui_input(event: InputEvent) -> void:
	if not _is_tutorial_click_to_continue_step():
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if not click and not touch:
		return
	get_viewport().set_input_as_handled()
	_advance_tutorial_step()

func _advance_tutorial_step() -> void:
	if _tutorial_step >= TUTORIAL_STEP_COUNT - 1:
		_close_tutorial(true)
		return
	_tutorial_step += 1
	_update_tutorial_step()
	_layout_tutorial_overlay()
	_play_tutorial_step_motion()

func _on_tutorial_skip_pressed() -> void:
	_close_tutorial(true)

func _hide_tutorial_for_overlay() -> void:
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return
	_close_tutorial(false)

func _track_gameplay_overlay_modal(modal: Node) -> void:
	_sync_gameplay_overlay_state()
	if modal == null:
		return
	modal.tree_exited.connect(func() -> void:
		call_deferred("_sync_gameplay_overlay_state")
	)

func _sync_gameplay_overlay_state() -> void:
	var blocked := _gameplay_affordances_blocked()
	if board != null and is_instance_valid(board):
		board.set_board_input_enabled(not blocked)
	_update_powerup_buttons()

func _gameplay_affordances_blocked() -> bool:
	if get_tree().paused:
		return true
	if is_instance_valid(_pause_overlay):
		return true
	if is_instance_valid(_open_tip_modal):
		return true
	if is_instance_valid(_audio_overlay):
		return true
	return ModalManager.get_open_count() > 0

func _clear_board_hint_indicator() -> void:
	if board != null and is_instance_valid(board):
		board.clear_hint_indicator()

func _close_tutorial(mark_seen: bool) -> void:
	_clear_tutorial_highlights()
	if _tutorial_motion_tween:
		_tutorial_motion_tween.kill()
	if _tutorial_focus_tween:
		_tutorial_focus_tween.kill()
	if _tutorial_focus_target and is_instance_valid(_tutorial_focus_target):
		_tutorial_focus_target.scale = Vector2.ONE
	_tutorial_motion_tween = null
	_tutorial_focus_tween = null
	_tutorial_focus_target = null
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
	_tutorial_overlay = null
	_tutorial_panel = null
	_tutorial_title = null
	_tutorial_message = null
	_tutorial_next_button = null
	_tutorial_skip_button = null
	_update_powerup_buttons()
	if mark_seen:
		SaveStore.set_tutorial_seen(true)

func _update_tutorial_step() -> void:
	if _tutorial_title == null or _tutorial_message == null or _tutorial_next_button == null:
		return
	var title := ""
	var message := ""
	match _tutorial_step:
		0:
			title = "Tap a Group"
			message = "Tap a glowing group to clear it.\nThis lesson advances after your move."
		1:
			title = "Keep the Beat"
			message = "Clear groups quickly to build combo pressure.\nThe music rises as the run heats up."
		TUTORIAL_STEP_UNDO:
			title = "Undo"
			message = "Undo rewinds your last move.\nUse it when the board turns against you."
		TUTORIAL_STEP_PRISM:
			title = "Prism"
			message = "Prism clears one tile color.\nRefill with coins, ads, or shop packs."
		TUTORIAL_STEP_HINT:
			title = "Hint"
			message = "Hint points out a playable group.\nUse it when the board gets noisy."
		TUTORIAL_STEP_DONE:
			title = "You're Set"
			message = "Clear groups, build the music, and save power-ups for tough boards.\nTap anywhere to play."
	_tutorial_title.text = title
	_tutorial_message.text = message
	if _tutorial_step >= TUTORIAL_STEP_COUNT - 1:
		_tutorial_next_button.text = "Done"
	elif _is_tutorial_click_to_continue_step():
		_tutorial_next_button.text = "Tap Anywhere"
	else:
		_tutorial_next_button.text = "Next"
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if _is_tutorial_click_to_continue_step() else Control.MOUSE_FILTER_IGNORE
	_update_powerup_buttons()
	_refresh_tutorial_highlights()

func _layout_tutorial_overlay() -> void:
	if _tutorial_panel == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	var top_limit: float = _tutorial_top_limit()
	var bottom_limit: float = view_size.y - 18.0
	if powerups_row and _is_tutorial_powerup_step():
		bottom_limit = min(bottom_limit, powerups_row.global_position.y - 18.0)
	var board_rect := Rect2()
	if board:
		board_rect = Rect2(
			board.global_position,
			Vector2(float(board.width) * board.tile_size, float(board.height) * board.tile_size)
		)
	var layout: Dictionary = TUTORIAL_TEMPLATE.layout_panel({
		"view_size": view_size,
		"board_rect": board_rect,
		"top_limit": top_limit,
		"bottom_limit": bottom_limit,
		"early_step": _tutorial_step <= 1,
		"powerup_step": _is_tutorial_powerup_step(),
		"message": _tutorial_message.text if _tutorial_message else "",
	})
	_tutorial_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tutorial_panel.position = layout["position"]
	_tutorial_panel.size = layout["size"]
	_tutorial_panel.pivot_offset = _tutorial_panel.size * 0.5
	if _tutorial_next_button:
		_tutorial_next_button.pivot_offset = _tutorial_next_button.size * 0.5
	if _tutorial_skip_button:
		_tutorial_skip_button.pivot_offset = _tutorial_skip_button.size * 0.5
	_refresh_tutorial_highlights()

func _tutorial_top_limit() -> float:
	var top_limit: float = 18.0
	if top_bar_bg:
		top_limit = max(top_limit, top_bar_bg.global_position.y + top_bar_bg.size.y + 14.0)
	return top_limit

func _refresh_tutorial_highlights() -> void:
	_clear_tutorial_highlights()
	if _tutorial_overlay == null:
		return
	if _tutorial_step <= 1:
		_set_tutorial_focus_target(null)
		_add_board_group_highlights()
	else:
		var target: Control = _tutorial_powerup_target()
		_set_tutorial_focus_target(target)
		if target:
			_add_control_highlight(target)
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_overlay.move_child(_tutorial_panel, _tutorial_overlay.get_child_count() - 1)

func _add_board_group_highlights() -> void:
	if board == null or board.board == null:
		return
	var group: Array = _tutorial_group()
	var limit: int = min(group.size(), 4)
	for i in range(limit):
		var cell: Vector2i = group[i]
		var origin: Vector2 = board.global_position + (Vector2(float(cell.x), float(cell.y)) * board.tile_size)
		_add_highlight_rect(Rect2(origin + Vector2(2, 2), Vector2(board.tile_size - 4, board.tile_size - 4)), i + 1)

func _tutorial_group() -> Array:
	if board == null or board.board == null:
		return []
	var best: Array = []
	for y in range(board.height):
		for x in range(board.width):
			var group: Array = board.board.find_group(Vector2i(x, y))
			if group.size() > best.size():
				best = group
			if best.size() >= 4:
				return best
	return best

func _add_control_highlight(control: Control) -> void:
	if control == null:
		return
	_add_highlight_rect(control.get_global_rect().grow(10.0), 0)

func _play_tutorial_step_motion() -> void:
	if _tutorial_panel == null or not is_instance_valid(_tutorial_panel):
		return
	if _tutorial_motion_tween:
		_tutorial_motion_tween.kill()
	_tutorial_panel.pivot_offset = _tutorial_panel.size * 0.5
	_tutorial_panel.scale = Vector2(0.96, 0.96)
	_tutorial_panel.modulate = Color(1, 1, 1, 0.92)
	_tutorial_motion_tween = _tutorial_panel.create_tween()
	_tutorial_motion_tween.set_parallel(true)
	_tutorial_motion_tween.tween_property(_tutorial_panel, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tutorial_motion_tween.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.08)
	_tutorial_motion_tween.chain().tween_property(_tutorial_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_tutorial_focus_target(target: Control) -> void:
	if _tutorial_focus_tween:
		_tutorial_focus_tween.kill()
	if _tutorial_focus_target and is_instance_valid(_tutorial_focus_target):
		_tutorial_focus_target.scale = Vector2.ONE
	_tutorial_focus_target = target
	if target == null or not is_instance_valid(target):
		_tutorial_focus_tween = null
		return
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE
	_tutorial_focus_tween = target.create_tween()
	_tutorial_focus_tween.set_loops()
	_tutorial_focus_tween.tween_property(target, "scale", Vector2(1.13, 1.13), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tutorial_focus_tween.tween_property(target, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _is_tutorial_powerup_step() -> bool:
	return _tutorial_step == TUTORIAL_STEP_UNDO or _tutorial_step == TUTORIAL_STEP_PRISM or _tutorial_step == TUTORIAL_STEP_HINT

func _is_tutorial_click_to_continue_step() -> bool:
	return _tutorial_step >= TUTORIAL_STEP_UNDO

func _tutorial_powerup_target() -> Control:
	match _tutorial_step:
		TUTORIAL_STEP_UNDO:
			return undo_button
		TUTORIAL_STEP_PRISM:
			return remove_color_button
		TUTORIAL_STEP_HINT:
			return hint_button
	return null

func _add_highlight_rect(rect: Rect2, index: int) -> void:
	var highlight := Panel.new()
	highlight.name = "Highlight"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TUTORIAL_TEMPLATE.style_highlight(highlight)
	highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	highlight.global_position = rect.position
	highlight.size = rect.size
	highlight.pivot_offset = highlight.size * 0.5
	_tutorial_overlay.add_child(highlight)
	_tutorial_highlights.append(highlight)
	_pulse_tutorial_highlight(highlight, index)
	if index <= 0:
		return
	var marker := Label.new()
	marker.text = str(index)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
	marker.add_theme_font_size_override("font_size", Typography.px(22.0))
	marker.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03, 1.0))
	marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	marker.global_position = rect.position + Vector2(6, 6)
	marker.size = Vector2(34, 34)
	marker.pivot_offset = marker.size * 0.5
	_tutorial_overlay.add_child(marker)
	_tutorial_highlights.append(marker)

func _pulse_tutorial_highlight(highlight: Control, index: int) -> void:
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return
	highlight.scale = Vector2(0.94, 0.94)
	var pulse := highlight.create_tween()
	pulse.set_loops()
	var delay: float = float(max(index, 0)) * 0.04
	if delay > 0.0:
		pulse.tween_interval(delay)
	pulse.tween_property(highlight, "scale", Vector2(1.08, 1.08), 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(highlight, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _clear_tutorial_highlights() -> void:
	for node in _tutorial_highlights:
		if node and is_instance_valid(node):
			node.queue_free()
	_tutorial_highlights.clear()

func _remaining_powerup_charges(powerup_type: String) -> int:
	match powerup_type:
		"undo":
			return _undo_charges
		"prism":
			return _remove_color_charges
		"hint":
			return _hint_charges
	return 0

func _arm_combo_timeout() -> void:
	if combo <= 0:
		_combo_timeout_remaining = -1.0
		return
	_combo_timeout_remaining = COMBO_BREAK_TIMEOUT_SECONDS

func _tick_combo_timeout(delta: float) -> void:
	if combo <= 0:
		_combo_timeout_remaining = -1.0
		return
	if _ending_transition_started or _run_finished:
		return
	if get_tree().paused:
		return
	if _combo_timeout_remaining <= 0.0:
		return
	_combo_timeout_remaining = max(0.0, _combo_timeout_remaining - delta)
	if _combo_timeout_remaining <= 0.0:
		_break_combo()

func _break_combo() -> void:
	if combo <= 0:
		return
	combo = 0
	_combo_timeout_remaining = -1.0
