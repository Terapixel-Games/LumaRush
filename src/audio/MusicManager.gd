extends Node

# Scene expectation:
# MusicManager node has 4 child AudioStreamPlayer nodes:
#   $Synth -> background layer
#   $Bass  -> hype layer
#   $Drums -> match layer
#   $Fx    -> fx layer
#
# All stems must be loop-enabled and start in sync once.
# Never restart stems individually; only adjust volume_db.

const DEFAULT_SYNTH_PATH := "res://assets/stems/default/background_layer.ogg"
const DEFAULT_BASS_PATH := "res://assets/stems/default/hype_layer.ogg"
const DEFAULT_DRUMS_PATH := "res://assets/stems/default/match_layer.ogg"
const DEFAULT_FX_PATH := "res://assets/stems/default/fx_layer.ogg"

const GLASSGRID_SYNTH_PATH := "res://assets/stems/glassgrid/background_layer.ogg"
const GLASSGRID_BASS_PATH := "res://assets/stems/glassgrid/hype_layer.ogg"
const GLASSGRID_DRUMS_PATH := "res://assets/stems/glassgrid/match_layer.ogg"
const GLASSGRID_FX_PATH := "res://assets/stems/glassgrid/fx_layer.ogg"

const MATCH_REWARD_SAMPLE_RATE := 44100
const MATCH_REWARD_NOTES := [740.0, 932.0, 1244.0]

var synth: AudioStreamPlayer
var bass: AudioStreamPlayer
var drums: AudioStreamPlayer
var fx: AudioStreamPlayer

var _drums_fade_tween: Tween
var _mix_fade_tween: Tween
var _fx_cooldown_until_ms := 0
var _tracks: Dictionary = {}
var _track_bpms: Dictionary = {}
var _match_reward_streams: Dictionary = {}
var _current_track_id: String = ""
var _input_audio_unlock_consumed := false
var _friendly_names := {
	"default": "Luma Theme",
	"glassgrid": "Neon Drift",
	"chrome": "Chrome Surge",
	"off": "Off",
}

func _ready() -> void:
	if _is_headless_singleton():
		_ensure_music_bus()
		_set_music_bus_muted(true)
		return
	_ensure_music_bus()
	synth = _ensure_player("Synth")
	bass = _ensure_player("Bass")
	drums = _ensure_player("Drums")
	fx = _ensure_player("Fx")
	_register_builtin_tracks()
	_load_tracks_from_manifest(FeatureFlags.audio_track_manifest_path())
	set_track(_initial_track_id(), false)
	set_process_input(true)

func _exit_tree() -> void:
	if is_instance_valid(_drums_fade_tween):
		_drums_fade_tween.kill()
	if is_instance_valid(_mix_fade_tween):
		_mix_fade_tween.kill()
	for player_var in [synth, bass, drums, fx]:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player == null:
			continue
		player.stop()
		player.stream_paused = true
		player.stream = null
	_tracks.clear()
	_track_bpms.clear()
	_current_track_id = ""
	_input_audio_unlock_consumed = false

func start_all_synced() -> void:
	if synth == null or bass == null or drums == null or fx == null:
		return
	if _current_track_id.is_empty():
		set_track(_initial_track_id(), false)
	for p in [synth, bass, drums, fx]:
		p.stream_paused = false
		if not p.playing:
			p.play()
	set_calm()

func resume_after_user_gesture() -> bool:
	if synth == null or bass == null or drums == null or fx == null:
		return false
	if _current_track_id == "off":
		return false
	_set_music_bus_muted(false)
	_start_missing_stems_without_rewinding()
	return true

func set_calm() -> void:
	if synth == null or bass == null or drums == null or fx == null:
		return
	synth.volume_db = 0.0
	bass.volume_db  = FeatureFlags.COMBO_FLOOR_DB
	drums.volume_db = FeatureFlags.COMBO_FLOOR_DB
	fx.volume_db    = FeatureFlags.COMBO_FLOOR_DB

func fade_out_hype_layers(duration: float = 0.45) -> void:
	if drums == null or fx == null:
		return
	if is_instance_valid(_mix_fade_tween):
		_mix_fade_tween.kill()
	_mix_fade_tween = create_tween()
	_mix_fade_tween.set_parallel(true)
	_mix_fade_tween.tween_property(drums, "volume_db", FeatureFlags.COMBO_FLOOR_DB, duration)
	_mix_fade_tween.tween_property(fx, "volume_db", FeatureFlags.COMBO_FLOOR_DB, duration)

func fade_to_calm(duration: float = 0.5) -> void:
	if synth == null or bass == null or drums == null or fx == null:
		return
	if is_instance_valid(_mix_fade_tween):
		_mix_fade_tween.kill()
	_mix_fade_tween = create_tween()
	_mix_fade_tween.set_parallel(true)
	_mix_fade_tween.tween_property(synth, "volume_db", 0.0, duration)
	_mix_fade_tween.tween_property(bass, "volume_db", FeatureFlags.COMBO_FLOOR_DB, duration)
	_mix_fade_tween.tween_property(drums, "volume_db", FeatureFlags.COMBO_FLOOR_DB, duration)
	_mix_fade_tween.tween_property(fx, "volume_db", FeatureFlags.COMBO_FLOOR_DB, duration)

func set_gameplay() -> void:
	if bass == null:
		return
	# Fade bass in for gameplay energy bed
	var t := create_tween()
	t.tween_property(bass, "volume_db", -8.0, 0.5)

func on_match_made() -> void:
	if drums == null:
		return
	if FeatureFlags.is_audio_test_mode():
		return

	if is_instance_valid(_drums_fade_tween):
		_drums_fade_tween.kill()

	drums.volume_db = FeatureFlags.COMBO_PEAK_DB
	_drums_fade_tween = create_tween()
	_drums_fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_drums_fade_tween.tween_interval(FeatureFlags.combo_decay_delay_seconds())
	_drums_fade_tween.tween_property(
		drums,
		"volume_db",
		FeatureFlags.combo_decay_target_db(),
		FeatureFlags.combo_decay_seconds()
	)

func maybe_trigger_high_combo_fx() -> void:
	if fx == null:
		return
	if FeatureFlags.is_audio_test_mode():
		return

	var now := Time.get_ticks_msec()
	if now < _fx_cooldown_until_ms:
		return
	_fx_cooldown_until_ms = now + int(FeatureFlags.FX_COOLDOWN_SECONDS * 1000.0)

	# Treat fx loop as a short accent envelope (no restarts).
	fx.volume_db = -10.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(fx, "volume_db", FeatureFlags.COMBO_FLOOR_DB, 0.6)

func play_match_reward(group_size: int = 3, combo_value: int = 1) -> bool:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_sfx"):
		return false
	var tier: int = clampi(max(0, group_size - 3) + max(0, combo_value - 1), 0, 5)
	var stream: AudioStream = _match_reward_stream(tier)
	if stream == null:
		return false
	var pitch: float = clamp(1.0 + (float(tier) * 0.035), 1.0, 1.18)
	audio_manager.call("play_sfx", stream, -5.0, pitch)
	return true

func set_ads_paused(paused: bool) -> void:
	if synth == null or bass == null or drums == null or fx == null:
		return
	for p in [synth, bass, drums, fx]:
		p.stream_paused = paused

func set_ads_ducked(ducked: bool) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, -12.0 if ducked else 0.0)

func list_track_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in _tracks.keys():
		ids.append(str(id))
	ids.append("off")
	ids.sort()
	return ids

func get_available_tracks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in list_track_ids():
		out.append({
			"id": id,
			"name": _friendly_names.get(id, id.capitalize()),
		})
	return out

func get_current_track_id() -> String:
	return _current_track_id

func get_current_track_bpm() -> float:
	if _track_bpms.has(_current_track_id):
		return float(_track_bpms[_current_track_id])
	return float(FeatureFlags.BPM)

func register_track(id: String, synth_stream: AudioStream, bass_stream: AudioStream, drums_stream: AudioStream, fx_stream: AudioStream, bpm: float = FeatureFlags.BPM) -> bool:
	if id.is_empty():
		return false
	if synth_stream == null or bass_stream == null or drums_stream == null or fx_stream == null:
		return false
	_tracks[id] = {
		"synth": synth_stream,
		"bass": bass_stream,
		"drums": drums_stream,
		"fx": fx_stream,
	}
	_track_bpms[id] = max(40.0, bpm)
	return true

func set_track(id: String, restart_if_playing: bool = true) -> bool:
	if synth == null or bass == null or drums == null or fx == null:
		if id == "off":
			_set_music_bus_muted(true)
			_current_track_id = id
			_input_audio_unlock_consumed = false
			SaveStore.set_selected_track_id(id)
			return true
		return false
	if id == "off":
		_set_music_bus_muted(true)
		_current_track_id = id
		_input_audio_unlock_consumed = false
		SaveStore.set_selected_track_id(id)
		return true
	if not _tracks.has(id):
		if _tracks.has("default"):
			id = "default"
		else:
			return false
	var data: Dictionary = _tracks[id]
	var switching_tracks: bool = id != _current_track_id
	if switching_tracks:
		synth.stream = data["synth"] as AudioStream
		bass.stream = data["bass"] as AudioStream
		drums.stream = data["drums"] as AudioStream
		fx.stream = data["fx"] as AudioStream
	if restart_if_playing:
		if switching_tracks:
			for p in [synth, bass, drums, fx]:
				p.stop()
				p.stream_paused = false
				p.play()
		else:
			_start_missing_stems_without_rewinding()
	_set_music_bus_muted(false)
	_current_track_id = id
	if switching_tracks:
		_input_audio_unlock_consumed = false
	SaveStore.set_selected_track_id(id)
	return true

func _start_missing_stems_without_rewinding() -> void:
	var stems: Array[AudioStreamPlayer] = [synth, bass, drums, fx]
	var resume_position := 0.0
	var has_active_stem := false
	for p in stems:
		if p.playing:
			resume_position = p.get_playback_position()
			has_active_stem = true
			break
	for p in stems:
		p.stream_paused = false
		if p.playing:
			continue
		p.play(resume_position if has_active_stem else 0.0)

func _input(event: InputEvent) -> void:
	if _input_audio_unlock_consumed:
		return
	if not _is_audio_unlock_event(event):
		return
	_input_audio_unlock_consumed = resume_after_user_gesture()

func _register_builtin_tracks() -> void:
	_register_track_from_paths(
		"default",
		DEFAULT_SYNTH_PATH,
		DEFAULT_BASS_PATH,
		DEFAULT_DRUMS_PATH,
		DEFAULT_FX_PATH,
		95.0
	)
	_register_track_from_paths(
		"glassgrid",
		GLASSGRID_SYNTH_PATH,
		GLASSGRID_BASS_PATH,
		GLASSGRID_DRUMS_PATH,
		GLASSGRID_FX_PATH,
		95.0
	)

func _ensure_player(node_name: String) -> AudioStreamPlayer:
	var existing: Node = get_node_or_null(node_name)
	if existing is AudioStreamPlayer:
		var existing_player: AudioStreamPlayer = existing as AudioStreamPlayer
		existing_player.bus = "Music"
		return existing_player
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = "Music"
	player.stream_paused = true
	add_child(player)
	return player

func _initial_track_id() -> String:
	var pinned: String = VisualTestMode.pinned_track_id_or_empty()
	if not pinned.is_empty():
		return pinned
	var saved: String = str(SaveStore.data.get("selected_track_id", ""))
	if not saved.is_empty():
		return saved
	return FeatureFlags.audio_track_id()

func _music_bus_index() -> int:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx != -1:
		return idx
	return AudioServer.get_bus_index("Master")

func _set_music_bus_muted(muted: bool) -> void:
	var idx: int = _music_bus_index()
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)

func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index("Music") != -1:
		return
	var index: int = AudioServer.get_bus_count()
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, "Music")

func _load_tracks_from_manifest(path: String) -> void:
	if path.is_empty():
		return
	if not FileAccess.file_exists(path):
		return
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null:
		return
	if parsed is Dictionary:
		_register_track_entry(parsed as Dictionary)
		return
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary:
				_register_track_entry(entry as Dictionary)

func _register_track_entry(entry: Dictionary) -> void:
	var id: String = str(entry.get("id", ""))
	var synth_path: String = str(entry.get("synth", ""))
	var bass_path: String = str(entry.get("bass", ""))
	var drums_path: String = str(entry.get("drums", ""))
	var fx_path: String = str(entry.get("fx", ""))
	var bpm: float = float(entry.get("bpm", FeatureFlags.BPM))
	if id.is_empty() or synth_path.is_empty() or bass_path.is_empty() or drums_path.is_empty() or fx_path.is_empty():
		return
	if not FileAccess.file_exists(synth_path):
		return
	if not FileAccess.file_exists(bass_path):
		return
	if not FileAccess.file_exists(drums_path):
		return
	if not FileAccess.file_exists(fx_path):
		return
	_register_track_from_paths(id, synth_path, bass_path, drums_path, fx_path, bpm)

func _register_track_from_paths(id: String, synth_path: String, bass_path: String, drums_path: String, fx_path: String, bpm: float) -> void:
	var synth_stream: AudioStream = _load_stream(synth_path)
	var bass_stream: AudioStream = _load_stream(bass_path)
	var drums_stream: AudioStream = _load_stream(drums_path)
	var fx_stream: AudioStream = _load_stream(fx_path)
	if synth_stream == null or bass_stream == null or drums_stream == null or fx_stream == null:
		return
	register_track(id, synth_stream, bass_stream, drums_stream, fx_stream, bpm)

func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource is AudioStream:
		return resource as AudioStream
	return null

func _match_reward_stream(tier: int) -> AudioStreamWAV:
	if _match_reward_streams.has(tier):
		return _match_reward_streams[tier] as AudioStreamWAV
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MATCH_REWARD_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = _build_match_reward_wav_data(tier)
	_match_reward_streams[tier] = stream
	return stream

func _build_match_reward_wav_data(tier: int) -> PackedByteArray:
	var duration: float = 0.24 + (float(tier) * 0.012)
	var sample_count: int = int(float(MATCH_REWARD_SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / float(MATCH_REWARD_SAMPLE_RATE)
		var progress: float = float(i) / float(max(1, sample_count - 1))
		var note_position: float = min(progress * float(MATCH_REWARD_NOTES.size()), float(MATCH_REWARD_NOTES.size()) - 0.001)
		var note_index: int = int(note_position)
		var note_progress: float = note_position - float(note_index)
		var freq: float = float(MATCH_REWARD_NOTES[note_index])
		var attack: float = clamp(t / 0.018, 0.0, 1.0)
		var release: float = clamp((duration - t) / 0.085, 0.0, 1.0)
		var envelope: float = attack * release * (1.0 - (note_progress * 0.16))
		var tone: float = sin(TAU * freq * t) + (0.32 * sin(TAU * freq * 2.0 * t))
		var sample_value: int = int(clamp(tone * envelope * 0.22 * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, sample_value)
	return data

func _is_audio_unlock_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	return false

func _is_headless_singleton() -> bool:
	if DisplayServer.get_name() != "headless":
		return false
	return str(get_path()) == "/root/MusicManager"
