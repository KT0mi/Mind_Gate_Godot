extends Node
## Autoload

const DEFAULT_FADE := 1.2

var _players: Array[AudioStreamPlayer] = []
var _active_index := 0
var _current_track: StringName = &""
var _library: Dictionary = {} # StringName -> AudioStream

func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0  # silent until faded in
		add_child(p)
		_players.append(p)
	_register_tracks()

func _register_tracks() -> void:
	_library[&"test"] = preload("res://Assets/Audio/song_placeholder.wav")
	_library[&"match_song"] = preload("res://Assets/Audio/pallete.wav")

## Crossfades to a new track. No-op if it's already playing.
func play_track(id: StringName, fade: float = DEFAULT_FADE, volume_db: float = 0.0) -> void:
	if id == _current_track:
		return
	if not _library.has(id):
		push_warning("MusicManager: no track registered for '%s'" % id)
		return

	var old_player := _players[_active_index]
	_active_index = (_active_index + 1) % _players.size()
	var new_player := _players[_active_index]

	new_player.stream = _library[id]
	new_player.volume_db = -80.0
	new_player.play()
	_current_track = id

	var tween := create_tween().set_parallel(true)
	tween.tween_property(new_player, "volume_db", volume_db, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old_player.playing:
		tween.tween_property(old_player, "volume_db", -80.0, fade) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.finished.connect(old_player.stop, CONNECT_ONE_SHOT)

func stop(fade: float = DEFAULT_FADE) -> void:
	var player := _players[_active_index]
	_current_track = &""
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -80.0, fade)
	tween.finished.connect(player.stop)
