extends Control

@onready var duel_button : Button = $DuelButton
@onready var deck_builder_button : Button = $DeckBuilderButton
@onready var quit_button : Button = $QuitButton
@onready var deck_selector : ScrollContainer = $DeckSelector

const DUEL_SCENE := "res://Scenes/TestScene.tscn"
const DECK_BUILDER_SCENE := "res://Scenes/DeckBuilder.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MusicManager.play_track(&"test", MusicManager.DEFAULT_FADE, -25.0)
	duel_button.pressed.connect(_on_duel_pressed)
	deck_builder_button.pressed.connect(_on_deck_builder_pressed)
	deck_selector.choose_deck.connect(func(id): StateData.chosen_deck = id)
	deck_selector.choose_enemy_deck.connect(func(id): StateData.enemy_chosen_deck = id)
	quit_button.pressed.connect(_on_quit_pressed)
	HoverHandler.register_hover(duel_button)
	HoverHandler.register_hover(deck_builder_button)
	HoverHandler.register_hover(quit_button)

func _on_duel_pressed() -> void:
	get_tree().change_scene_to_file(DUEL_SCENE)
	
func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
