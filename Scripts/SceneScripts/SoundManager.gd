extends Node
#Autoload

const POOL_SIZE := 8

var _sfx_players : Array[AudioStreamPlayer] = []
var _next_player := 0
var _library : Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in POOL_SIZE:
		var p: = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_register_sounds()

func _register_sounds() -> void:
	_library[&"hover"]   = preload("res://Assets/Audio/click.mp3")
	_library[&"card_interact"] = preload("res://Assets/Audio/card_slide_fx.mp3")
	_library[&"enter_arena"] = preload("res://Assets/Audio/swoosh.mp3")
	_library[&"card_death"] = preload("res://Assets/Audio/bell_toll_fx.mp3")
	_library[&"card_attack"] = preload("res://Assets/Audio/punch.mp3")

## Fire-and-forget. Pooled players mean overlapping calls (e.g. Fireball
## hitting 3 cards in one frame) don't cut each other off.
func play(id: StringName, volume_db: float = 0.0, pitch_variance: float = 0.05) -> void:
	if not _library.has(id):
		push_warning("SoundManager: no sound registered for '%s'" % id)
		return
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	player.stream = _library[id]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()
