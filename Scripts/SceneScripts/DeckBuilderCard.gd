class_name DeckBuilderCard extends PanelContainer

enum Context {AVAILABLE, DECK, VIEW}

signal add_requested(id: StringName, add_max: bool)
signal remove_requested(id: StringName)
var add_disabled : bool = false
var remove_disabled : bool = true
var context : Context = Context.AVAILABLE

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $Labels/Name/NameLabel
@onready var attack_label: Label = $Labels/StatsLabel/AttackLabel/AttackLabel
@onready var endurance_label: Label = $Labels/StatsLabel/EnduranceLabel/EnduranceLabel
@onready var gate_label: Label = $Labels/StatsLabel/Gate/GateLabel
@onready var count_node: Control = $Labels/Count
@onready var count_label: Label = $Labels/Count/CountLabel
@onready var hidden_overlay: ColorRect = $HiddenOverlay

var definition : CardDefinition

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(def: CardDefinition) -> void:
	definition = def
	sprite.texture = def.art
	name_label.text = def.card_name.to_upper()
	TextHandler.fit_name_label(name_label)
	gate_label.text = CardViewManager.format_gate_label(def.gate)

	if def is CreatureCardDefinition:
		attack_label.text = str(def.attack)
		endurance_label.text = str(def.endurance)
	else:
		attack_label.visible = false
		endurance_label.visible = false

func set_context(c: Context) -> void:
	context = c
	count_node.visible = context == Context.DECK

func refresh_state(count: int, max_copies: int, can_add: bool, can_remove: bool) -> void:
	add_disabled = not can_add
	remove_disabled = not can_remove

	if context == Context.DECK:
		count_label.text = "x%d" % count
	else:
		hidden_overlay.visible = not can_add


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and context!=Context.VIEW:
		if event.button_index == MOUSE_BUTTON_LEFT and not add_disabled:
			add_requested.emit(definition.id, event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not remove_disabled:
			remove_requested.emit(definition.id)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			CardInspector.open_definition(definition)
			get_viewport().set_input_as_handled()
