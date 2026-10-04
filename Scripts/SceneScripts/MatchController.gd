extends Node2D
######################################
######## PLACEHOLDER SCRIPT ##########
######################################
#Since this is a connection between game logic and scene control, spawning, and debugging
#this must later be refactored into smaller scripts and if possible passing as must logic 
#into autoloaders

#This sets up a match by building decks, spawning cards, cardholders
#sets up a minimal debug ui

@onready var end_phase_button : Button = $UI/EndPhaseButton
@onready var forget_turn_button : Button = $UI/ForgetTurnButton
#Game End Label
@onready var game_end_label : Label = $UI/GameEndLabel

@export var player_one_deck : DeckData
@export var player_two_deck: DeckData

const FALLBACK_DECK_IDS: Array[StringName] = [
	&"test_creature", &"test_creature", &"test_creature", &"test_creature",
	&"test_spell", &"test_spell", &"test_spell", &"test_spell"
]

var _canvas: CanvasLayer
var _phase_label : Label
var _zones_label : Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.reset()
	TurnController.reset()
	CardViewManager.reset()
	ChoiceManager.reset()
	
	_build_debug_ui()
	#ChoiceManager.choice_requested.connect(_on_choice_requested)
	TurnController.phase_changed.connect(_on_phase_changed)
	
	#Connect UI Elements
	end_phase_button.pressed.connect(_on_advance_pressed)
	forget_turn_button.pressed.connect(_on_forget_pressed)
	HoverHandler.register_hover(end_phase_button)
	HoverHandler.register_hover(forget_turn_button)
	
	await _setup_decks()
	await _setup_players()
	await TurnController.start_match()
	
	RulesEngine.player_defeated.connect(_game_end)
	
	_refresh_ui()

func _on_phase_changed(_phase, _player, _forgetting) -> void: _refresh_ui()

func _setup_decks() -> void:
	var deck : DeckData
	deck = DeckStorage.load_deck(StateData.chosen_deck)
	if deck != null:
		player_one_deck = deck
	
	var enemy_deck : DeckData
	enemy_deck = DeckStorage.load_deck(StateData.enemy_chosen_deck)
	if enemy_deck != null:
		player_two_deck = enemy_deck
	
func _setup_players() -> void:
	GameState.local_player = GameState.player_one #Default value for testing
	
	for entry in [
		{player = GameState.player_one, deck = player_one_deck},
		{player = GameState.player_two, deck = player_two_deck},
	]:
		var player: Player = entry.player
		var deck: DeckData = entry.deck
		
		var instances: Array[CardInstance] = build_deck(player, deck)
		for instance in instances:
			CardViewManager.create_card_node(instance)
			await ZoneManager.move_to(instance, Zone.Type.DECK, ZoneChangeEvent.Reason.MANUAL, -1, &"setup")
		

func build_deck(player: Player, deck: DeckData) -> Array[CardInstance]:
	if deck:
		return CardFactory.build_deck(deck, player)
	return CardFactory.build_deck_from_ids(FALLBACK_DECK_IDS, player)
 
func _build_debug_ui() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)
 
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(32, 128)
	_canvas.add_child(vbox)
 
	_phase_label = Label.new()
	vbox.add_child(_phase_label)
 
	_zones_label = Label.new()
	vbox.add_child(_zones_label)
	
	var reveal_checkbox := CheckBox.new()
	reveal_checkbox.text = "Reveal hidden cards (debug)"
	reveal_checkbox.toggled.connect(func(pressed: bool): DebugSettings.reveal_hidden_cards = pressed)
	vbox.add_child(reveal_checkbox)
	
	var show_all_choices_checkbox := CheckBox.new()
	show_all_choices_checkbox.text = "Show all choices, incl. AI's (debug)"
	show_all_choices_checkbox.toggled.connect(func(pressed: bool): DebugSettings.show_all_choices_in_debug_ui = pressed)
	vbox.add_child(show_all_choices_checkbox)

func _on_advance_pressed() -> void:
	if TurnController.current_player != GameState.local_player:
		return
	if ChoiceManager.has_pending_request():
		return
	await TurnController.advance_phase()
	_refresh_ui()
 
func _on_forget_pressed() -> void:
	if TurnController.current_player != GameState.local_player:
		return
	if ChoiceManager.has_pending_request():
		return
	await TurnController.forget_turn()
	_refresh_ui()

func _refresh_ui() -> void:
	_phase_label.text = "Turn %d -- %s's %s phase" % [
		TurnController.turn_counter,
		TurnController.current_player.player_name,
		TurnController.Phase.keys()[TurnController.current_phase],
	]
	_zones_label.text = "P1  hand:%d  arena:%d  deck:%d  graveyard:%d\nP2  hand:%d  arena:%d  deck:%d  graveyard:%d" % [
		GameState.player_one.hand.size(), GameState.player_one.arena().size(),
		GameState.player_one.deck.size(), GameState.player_one.graveyard.size(),
		GameState.player_two.hand.size(), GameState.player_two.arena().size(),
		GameState.player_two.deck.size(), GameState.player_two.graveyard.size(),
	]

func _game_end(losing_player : Player) -> void:
	if losing_player != GameState.local_player:
		game_end_label.text = "You Win!"
		game_end_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		game_end_label.text = "You Lose!"
		game_end_label.add_theme_color_override("font_color", Color.RED)
	
	game_end_label.visible = true

func _exit_tree() -> void:
	if TurnController.phase_changed.is_connected(_on_phase_changed):
		TurnController.phase_changed.disconnect(_on_phase_changed)
	if RulesEngine.player_defeated.is_connected(_game_end):
		RulesEngine.player_defeated.disconnect(_game_end)
