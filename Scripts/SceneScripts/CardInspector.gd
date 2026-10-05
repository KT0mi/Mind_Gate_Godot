extends CanvasLayer
##Autoload

const CARD_SCENE := preload("res://Scenes/DeckBuilderCard.tscn")
@onready var _zone_inspector : Control = $ZoneInspector
@onready var _cards_container : GridContainer = $ZoneInspector/CardZoneContainer/CardsContainer
@onready var _zone_inspector_dim_background: ColorRect = $ZoneInspector/DimBackground

@onready var _overlay: Control = $Overlay
@onready var _dim_background: ColorRect = $Overlay/DimBackground

@onready var _name_label : Label = $Overlay/CardElementContainer/CardName
@onready var _text_box : RichTextLabel = $Overlay/CardElementContainer/CardText
@onready var _endurance_label : Label = $Overlay/CardElementContainer/StatContainer/EnduranceLabel
@onready var _gate_label : Label = $Overlay/CardElementContainer/StatContainer/GateLabel
@onready var _attack_label : Label = $Overlay/CardElementContainer/StatContainer/AttackLabel

@onready var _preview_card : Card = $Overlay/CardPreview/SubViewport/PreviewCard

@onready var _modifiers_list : VBoxContainer = $Overlay/CardModifierContainer

var DEFAULT_THEME : Theme = preload("res://Theme/default_theme.tres")
const MODIFIER_ENTRY_SCENE := preload("res://Scenes/UI/ModifierEntry.tscn")

var _card : CardInstance = null
var _is_definition_preview: bool = false

func _ready() -> void:
	layer = 90
	_zone_inspector.visible = false
	_overlay.visible = false
	_dim_background.gui_input.connect(_on_dim_background_input)
	_zone_inspector_dim_background.gui_input.connect(_on_dim_background_input)

func open(card: CardInstance) -> void:
	if card == null: return
	if card.current_zone == Zone.Type.GRAVEYARD or card.current_zone == Zone.Type.DECK:
		return open_zone_inspector(card)
	if CardViewManager.is_card_hidden_from_local_view(card): return
	_card = card
	_refresh()
	_overlay.visible = true
	HoverHandler.force_unfocus()

## For places with no live card (deck builder, collection, etc.)
func open_definition(def: CardDefinition) -> void:
	if def == null: return
	# Throwaway instance: never added to any zone array, so it can't affect the game.
	var dummy := CardInstance.new(def, GameState.player_one)
	dummy.current_zone = Zone.Type.ARENA  # see note below
	_is_definition_preview = true
	_card = dummy
	_refresh()
	_overlay.visible = true
	HoverHandler.force_unfocus()

func close() -> void:
	if is_open():
		_card = null
		_overlay.visible = false
		return
	if is_zone_inspector_open():
		_zone_inspector.visible = false

func is_open() -> bool:
	return _overlay.visible
	
func is_zone_inspector_open() -> bool:
	return _zone_inspector.visible

func _unhandled_input(event: InputEvent) -> void:
	if not is_open() and not is_zone_inspector_open():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _on_dim_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

## -- Zone Inspector --

func open_zone_inspector(card_instance: CardInstance) -> void:
	if card_instance.current_zone == Zone.Type.DECK and card_instance.owner != GameState.local_player: return
	_zone_inspector.visible = true
	
	var cards := card_instance.owner.zone_array(card_instance.current_zone).duplicate()
	_populate_zone_inspector(cards, card_instance.current_zone == Zone.Type.GRAVEYARD)

func _populate_zone_inspector(cards: Array[CardInstance], is_graveyard: bool) -> void:
	for c in _cards_container.get_children():
		c.queue_free()
	
	if is_graveyard: cards.shuffle()
	
	for c in cards:
		var def := c.definition
		var entry := _instantiate_entry(_cards_container, def)
		HoverHandler.register_hover(entry)

func _instantiate_entry(parent: Node, def: CardDefinition) -> DeckBuilderCard:
	var entry : DeckBuilderCard = CARD_SCENE.instantiate()
	parent.add_child(entry)   # add_child BEFORE setup() -- @onready vars need the node in the tree first
	entry.setup(def)
	entry.set_context(DeckBuilderCard.Context.VIEW)
	return entry


## --- Populating

func _refresh() -> void:
	var def: CardDefinition = _card.definition
	
	_preview_card.card_instance = _card
	_preview_card.set_interaction_mode(Card.InteractionMode.DISABLED)
	_preview_card._setup_visuals()
	_preview_card._refresh_visuals()
	
	_name_label.text = def.card_name
	_text_box.text = _card.get_display_text(true)
	
	if def is CreatureCardDefinition:
		_attack_label.visible = true
		_endurance_label.visible = true
		_attack_label.text = "Attack:\n%d" % _card.get_attack()
		_endurance_label.text = "Endurance:\n%d" % _card.get_endurance()
	else:
		_attack_label.visible = false
		_endurance_label.visible = false
	
	_gate_label.text = "Gate:\n%s" % CardViewManager.format_gate_label(_card.get_gate())
	
	_modifiers_list.visible = not _is_definition_preview
	if not _is_definition_preview:
		_rebuild_modifiers_list()

func _rebuild_modifiers_list() -> void:
	for child in _modifiers_list.get_children():
		child.queue_free()
	
	var modifier_list_label := Label.new()
	modifier_list_label.text = "Modifier List:"
	modifier_list_label.theme = DEFAULT_THEME
	modifier_list_label.add_theme_font_size_override("font_size", 50)
	
	var sections : Array = []
	if _card.definition is CreatureCardDefinition:
		sections.append(["Attack", ContinuousEffect.Kind.ATTACK, _card.current_attack, _card.attack_modifiers, AttackCheck.new(_card)])
		sections.append(["Endurance",ContinuousEffect.Kind.ENDURANCE, _card.current_endurance, _card.endurance_modifiers, EnduranceCheck.new(_card)])
	sections.append(["Gate",ContinuousEffect.Kind.GATE, _card.definition.gate, _card.gate_modifiers, GateCheck.new(_card)])
	
	var any_entries := false
	for section in sections:
		var entries := _build_timeline(section[1], section[2], section[3], section[4])
		if entries.is_empty():
			continue
		any_entries = true
		_add_header("All " + section[0] + " Modifiers")
		for entry in entries:
			_add_modifier_entry(
				section[2],
				section[0] + "Modifier",
				entry[0],
				entry[1],
				entry[2])
	
	if not any_entries:
		_add_header("No active modifiers or continuous effects.")

func _build_timeline(kind : ContinuousEffect.Kind, start_value, permanent_modifiers:Array, ctx : CheckContext) -> Array[Array]:
	var entries : Array[Array] = []
	var value = start_value
	
	for mod in permanent_modifiers:
		var before = value
		value = mod.apply(value)
		var label : String = mod.label if mod.label != "" else "Modifier"
		var src_name : String = mod.source.definition.card_name if mod.source else "Unknown"
		entries.append([
			src_name,
			label,
			_format_value(value, before)
		])
		
	for m in _collect_continuous(kind, ctx, ContinuousEffect.Layer.SET):
		var before = value
		value = m.ce.effect.call(value, m.source, ctx)
		entries.append([
			m.source.definition.card_name,
			m.ce.label,
			_format_value(value, before)
		])
	
	for m in _collect_continuous(kind, ctx, ContinuousEffect.Layer.DELTA):
		var before = value
		value = m.ce.effect.call(value, m.source, ctx)
		entries.append([
			m.source.definition.card_name,
			m.ce.label,
			_format_value(value, before)
		])
	
	return entries

func _format_value(value, before) -> String:
	if value is CardGate:
		return CardViewManager.format_gate_label(value)
	return str(value)
	

## Gathers every currently-active ContinuousEffect of the given kind/layer
## whose applies_to(source, this_card) matches, sorted oldest-source-first
## -- mirrors CheckSystem._collect, but scoped to a single card as target
## since that's all the popup needs.
func _collect_continuous(kind: ContinuousEffect.Kind, ctx:CheckContext, layer: ContinuousEffect.Layer) -> Array:
	var matches : Array = []
	for source : CardInstance in GameState.all_player_cards():
		if not GameState.is_continuous_source_active(source):
			continue
		for ce in source.definition.get_continuous_effects():
			if ce.kind != kind or ce.layer != layer:
				continue
			if ce.applies_to.call(source, ctx):
				matches.append({"source": source, "ce": ce})
	matches.sort_custom(func(a, b): return a.source.continuous_since < b.source.continuous_since)
	return matches

func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme = DEFAULT_THEME
	label.add_theme_font_size_override("font_size", 22)
	_modifiers_list.add_child(label)

func _add_modifier_entry(against, kind_text: String, source_text: String, modifier_text: String, new_value: String) -> void:
	var entry : ModifierEntry = MODIFIER_ENTRY_SCENE.instantiate()
	_modifiers_list.add_child(entry)
	
	entry.kind_text = kind_text
	entry.source_text = source_text
	if modifier_text == "": entry.modifier_label.visible = false
	else: entry.modifier_text = modifier_text
	if not against is CardGate:
		if against > int(new_value):
			entry.new_value_label.add_theme_color_override("font_color", Color.RED)
		elif against < int(new_value):
			entry.new_value_label.add_theme_color_override("font_color", Color.GREEN)
	entry.new_value_text = new_value
	
