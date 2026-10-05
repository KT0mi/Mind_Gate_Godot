class_name ChoicePresenter extends Control


@onready var prompt_label: Label = $ChoiceUI/ChoiceLabelContainer/PromptLabel
@onready var selection_label: Label = $ChoiceUI/ChoiceLabelContainer/SelectionLabel
@onready var confirm_button: Button = $ChoiceUI/ChoiceLabelContainer/ConfirmButton
@onready var battle_button : Button = $BattleButton

enum State {IDLE, LOCAL_CHOICE, WAITING_FOR_OTHER_PLAYER}
var _state: State = State.IDLE

var _request: ChoiceRequest = null
var _selected: Array = []

func _ready() -> void:
	visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	battle_button.pressed.connect(_on_confirm_pressed)
	battle_button.visible = false
	HoverHandler.register_hover(battle_button)
	HoverHandler.register_hover(confirm_button)
	ChoiceManager.choice_requested.connect(begin)
	ChoiceManager.choice_resolved.connect(_on_choice_resolved)

func _refresh() -> void:
	if _request == null:
		return
	
	selection_label.text = "%d/%d selected" % [_selected.size(), _request.max_count]
	
	confirm_button.disabled =  not _request.is_valid(_selected)
	battle_button.disabled =  not _request.is_valid(_selected)

#region Generic Methods

func begin(request: ChoiceRequest) -> void:
	assert(_request == null, "ChoicePresenter already has an active request.")
	
	_request = request
	_selected.clear()
	
	if request.requesting_player != GameState.local_player:
		_state = State.WAITING_FOR_OTHER_PLAYER
		_waiting_state()
		return
	
	_state = State.LOCAL_CHOICE
	prompt_label.text = request.prompt
	
	#Branch into specific ChoiceRequest
	if request is CardChoiceRequest:
		setup_card_choice(request)
	
	_refresh()
	visible = true

func _finish(request : ChoiceRequest) -> void:
	#Identity guard
	#This means that I never allow a cleanup of an old request to influence a new request
	if _request != request:
		return
	
	if request != null:
		if request is CardChoiceRequest:
			_card_request_cleanup(request)
	
	_selected.clear()
	_request = null
	
	prompt_label.text = ""
	selection_label.text = ""
	confirm_button.disabled = true
	
	visible = false

func _on_confirm_pressed() -> void:
	if _request == null:
		return
		
	if not _request.is_valid(_selected):
		return
	
	var finishing_request := _request
	
	var response: Array = []
	response.append_array(_selected)
	
	
	var submitted := await ChoiceManager.submit(response)
	
	if not submitted:
		push_error(
			"CardChoicePresenter: valid active request was rejected."
		)
		
func _waiting_state() -> void:
	visible = true
	prompt_label.text = "Waiting for opponent choice..."
	confirm_button.visible = false

func _finish_waiting_state(request : ChoiceRequest) -> void:
	_selected.clear()
	_request = null
	
	prompt_label.text = ""
	selection_label.text = ""
	confirm_button.visible = true
	confirm_button.disabled = true
	
	visible = false


func _on_choice_resolved(request : ChoiceRequest) -> void:
	match _state:
		State.IDLE:
			return
		State.LOCAL_CHOICE:
			_finish(request)
		State.WAITING_FOR_OTHER_PLAYER:
			_finish_waiting_state(request)

#endregion

#region CardChoiceRequest presenting methods

func setup_card_choice(request: CardChoiceRequest) -> void:
	match request.context.origin:
		ChoiceContext.Origin.BATTLE:
			confirm_button.visible=false
			battle_button.visible=true
			_set_cards_for_choice(request)
		_:
			_set_cards_for_choice(request)

func _card_request_cleanup(request : CardChoiceRequest) -> void:
	_clear_card_selection()
	
	match request.context.origin:
		ChoiceContext.Origin.BATTLE:
			battle_button.visible=false
			confirm_button.visible=true
		_:
			pass
	
	for card in request.card_options:
		var node := CardViewManager.card_node_for(card)
		
		if node == null:
			push_warning("ChoicePresenter: No card node for %s" % card.get_id())
			continue
			
		if node.selection_pressed.is_connected(_on_card_selection_pressed):
			node.selection_pressed.disconnect(_on_card_selection_pressed)
			
	for node : Card in CardViewManager.get_all_card_nodes():
		if node:
			node.set_interaction_mode(Card.InteractionMode.NORMAL)
			node._refresh_visuals()

func _set_cards_for_choice(request: CardChoiceRequest) -> void:
	#Block Normal card interaction by disabling card
	for node : Card in CardViewManager.get_all_card_nodes():
		if node == null: continue
		
		node.set_interaction_mode(Card.InteractionMode.DISABLED)
	
	for card in request.card_options:
		var node := CardViewManager.card_node_for(card)
		
		if node == null:
			push_warning("ChoicePresenter: no Card node found for %s" % card.definition.id)
			continue
		
		node.set_interaction_mode(Card.InteractionMode.SELECTABLE)
		
		node.selection_pressed.connect(_on_card_selection_pressed)

func _on_card_selection_pressed(node: Card) -> void:
	if _request == null:
		push_warning("ChoicePresenter: Trying to select card node for null ChoiceRequest")
		return
		
	var card := node.card_instance
	
	if card not in _request.card_options:
		push_warning("ChoicePresenter: Trying to select card that is not in ChoiceRequest options")
		return
		
	if card in _selected:
		_selected.erase(card)
		node.set_selected(false)
	elif _request.max_count == 1:
		_clear_card_selection()
		
		_selected.append(card)
		node.set_selected(true)
		
	elif _selected.size() < _request.max_count:
		_selected.append(card)
		node.set_selected(true)
		
	_refresh()

func _clear_card_selection() -> void:
	for card : CardInstance in _selected:
		var node := CardViewManager.card_node_for(card)
		
		if node:
			node.set_selected(false)
	
	_selected.clear()
	
#endregion

func _exit_tree() -> void:
	if ChoiceManager.choice_requested.is_connected(begin):
		ChoiceManager.choice_requested.disconnect(begin)
	if ChoiceManager.choice_resolved.is_connected(_on_choice_resolved):
		ChoiceManager.choice_resolved.disconnect(_on_choice_resolved)
