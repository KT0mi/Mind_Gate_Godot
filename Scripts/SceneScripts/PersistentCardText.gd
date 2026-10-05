extends Control

@onready var _card_text_ui : Control = $CardTextUI
@onready var _card_name_label : Label = $CardTextUI/CardTextContainer/CardNameLabel
@onready var _card_text_label : RichTextLabel = $CardTextUI/CardTextContainer/CardTextLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	HoverHandler.hover_source_changed.connect(_on_hover_source_changed)
	_card_text_ui.visible = false

## --- Hover context (persistent, lightweight inspect)
func _on_hover_source_changed(source: Node) -> void:
	if source == null:
		_hide_hover_context()
		return
	if source is Card:
		_show_hover_instance(source.card_instance)
	elif source is DeckBuilderCard:
		_show_hover_definition(source.definition)
	else:
		_hide_hover_context()

func _show_hover_instance(card: CardInstance) -> void:
	if card == null:
		_hide_hover_context()
		return
	if CardViewManager.is_card_hidden_from_local_view(card) and not DebugSettings.reveal_hidden_cards:
		_hide_hover_context()
		return
	_show_hover_text(card)

func _show_hover_definition(def: CardDefinition) -> void:
	if def == null:
		_hide_hover_context()
		return
	var dummy := CardInstance.new(def, null)
	_show_hover_text(dummy)

func _show_hover_text(card: CardInstance) -> void:
	_card_text_ui.visible = true
	
	var text := card.get_display_text(false)
	_card_name_label.text = card.definition.card_name
	_card_text_label.text = text
	_card_text_ui.visible = text != ""

func _hide_hover_context() -> void:
	_card_text_ui.visible = false
