class_name Card extends Area2D

signal picked_up(card: Card)
signal dropped(card: Card)
signal selection_pressed(card: Card)

##Player Interaction Variables
enum InteractionMode {NORMAL, SELECTABLE, DISABLED}
var interaction_mode : InteractionMode = InteractionMode.NORMAL
func set_interaction_mode(mode : InteractionMode) -> void:
	interaction_mode = mode
	queue_redraw()

var hovered: bool = false
var selected: bool = false
var _drop_target: CardHolder = null

#Movement vars
@export var spring_stiffness: float = 0.2
@export var damping: float = 0.1
@export var tilt_strength: float = 1.0
@export var max_tilt_degrees: float = 10.0
@export var tilt_recover_speed: float = 10.0

var dragging: bool = false
var velocity: Vector2 = Vector2.ZERO
var rest_rotation_degrees: float = 0.0
func set_rest_rotation(degrees: float) -> void:
	rest_rotation_degrees = degrees

static var _active_drag: Card = null
const HOVER_Z_INDEX := 100

#Visual Vars
@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $Labels/Name/NameLabel
@onready var stat_label : Control = $Labels/StatsLabel
@onready var attack_label : Label = $Labels/StatsLabel/AttackLabel/AttackLabel
@onready var endurance_label : Label = $Labels/StatsLabel/EnduranceLabel/EnduranceLabel
@onready var gate_label: Label = $Labels/StatsLabel/Gate/GateLabel
@onready var set_label: Label = $Labels/SetLabel/SetLabel
@onready var card_back: TextureRect = $CardBack
@onready var hidden_overlay: ColorRect = $HiddenOverlay
@onready var card_fx: Control = $CardFX

var card_instance: CardInstance = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("cards")
	input_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	get_viewport().physics_object_picking_first_only = true
	DebugSettings.reveal_hidden_cards_changed.connect(func(_v): _update_hidden_state())
	
func bind(instance: CardInstance) -> void:
	card_instance = instance
	CardViewManager.register_card_node(instance, self)
	_refresh_visuals()

func _setup_visuals() -> void:
	var def : CardDefinition = card_instance.definition
	sprite.texture = def.art
	if def is SpellCardDefinition:
		attack_label.visible = false
		endurance_label.visible = false
	else: #this makes sure the stats on a dummy card aren't set invisible and never undone
		attack_label.visible = true
		endurance_label.visible = true

func _refresh_visuals() -> void:
	#Fill with visual representation of card instance
	var def : CardDefinition = card_instance.definition
	name_label.text = def.card_name.to_upper()
	TextHandler.fit_name_label(name_label)
	gate_label.text = CardViewManager.format_gate_label(card_instance.get_gate())
	set_label.text = CardSetDatabase.get_set(def.sets[0]).display_name
	_gated_feedback(card_instance)
	card_fx.get_active_fx(card_instance)
	if def is CreatureCardDefinition:
		endurance_label.text = "%d" % card_instance.get_endurance()
		attack_label.text = "%d" % card_instance.get_attack()
		
		_apply_modified_feedback(attack_label, card_instance.get_attack(), def.attack)
		_apply_modified_feedback(endurance_label, card_instance.get_endurance(), def.endurance)
	_update_hidden_state()

func _gated_feedback(card : CardInstance) -> void:
	if card.current_zone == Zone.Type.HAND:
		if card.is_not_gated(card.owner.get_player_card().get_endurance()):
			gate_label.add_theme_color_override("font_color", Color(0.0, 0.823, 0.0, 1.0))
		else:
			gate_label.add_theme_color_override("font_color", Color(0.82, 0.0, 0.0, 1.0))
	else:
		gate_label.remove_theme_color_override("font_color")

func _apply_modified_feedback(label: Label, current: int, base: int) -> void:
	if current > base:
		label.add_theme_color_override("font_color", Color(0.0, 0.823, 0.0, 1.0))
	elif current < base:
		label.add_theme_color_override("font_color", Color(0.82, 0.0, 0.0, 1.0))
	else:
		label.remove_theme_color_override("font_color")

func _update_hidden_state() -> void:
	var hidden := CardViewManager.is_card_hidden_from_local_view(card_instance)
	var reveal := DebugSettings.reveal_hidden_cards
	
	card_back.visible = hidden and not reveal
	hidden_overlay.visible = hidden and reveal

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()
 
func _on_mouse_entered() -> void:
	hovered = true
	queue_redraw()
	if interaction_mode != InteractionMode.DISABLED:
		HoverHandler.focus(self, _collision_local_rect())

func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()
	HoverHandler.unfocus(self)

func _collision_local_rect() -> Rect2:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return Rect2()
	var size: Vector2 = shape_node.shape.size
	return Rect2(shape_node.position - size / 2, size)
 
func _draw() -> void:
	#Selection wins over hover when both are true, so you can tell a
	#chosen card apart from one you're merely mousing over while choosing.
	match interaction_mode:
		InteractionMode.NORMAL:
			return
		InteractionMode.SELECTABLE:
			if selected:
				_draw_outline(Color(0.168, 0.722, 0.0, 0.95), 5.0)
			elif hovered:
				_draw_outline(Color(1, 1, 1, 0.6), 5)
			else:
				_draw_outline(Color(0.774, 0.557, 0.0, 0.95), 5)
 
func _draw_outline(color: Color, width: float) -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return
	var size: Vector2 = shape_node.shape.size
	var rect := Rect2(shape_node.position - size / 2, size)
	draw_rect(rect, color, false, width)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	
	if not event.is_pressed():
		return
	
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		CardInspector.open(card_instance)
		return
	
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	match interaction_mode:
		InteractionMode.NORMAL:
			if not dragging:
				_start_drag()
		
		InteractionMode.SELECTABLE:
			selection_pressed.emit(self)
			
		InteractionMode.DISABLED:
			pass

func _unhandled_input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
			await _end_drag()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if dragging:
		var target := get_global_mouse_position()
		velocity = velocity * damping + (target - global_position) * spring_stiffness
		global_position += velocity
		
		rotation_degrees = clamp(velocity.x * tilt_strength, -max_tilt_degrees, max_tilt_degrees)
		_update_drop_target(target)
		
		if interaction_mode != InteractionMode.DISABLED:
			HoverHandler.focus(self, _collision_local_rect(), true)
	else:
		rotation_degrees = move_toward(rotation_degrees, rest_rotation_degrees, tilt_recover_speed)
		
	
func _start_drag() -> void:
	if _active_drag != null:
		return
		
	_active_drag = self
	dragging = true
	velocity = Vector2.ZERO
	z_index = HOVER_Z_INDEX
	
	picked_up.emit(self)
	SoundManager.play(&"card_interact")
	
func _update_drop_target(mouse_pos: Vector2) -> void:
	var candidate := CardViewManager.holder_at_point(mouse_pos)
	if candidate == _drop_target:
		return
	if _drop_target:
		_drop_target.set_hovered(false)
	_drop_target = candidate
	if _drop_target:
		_drop_target.set_hovered(true)

func _end_drag() -> void:
	dragging = false
	z_index = 0
	
	if _active_drag == self:
		_active_drag = null
	
	dropped.emit(self)
	SoundManager.play(&"card_interact")
	
	var holder := _drop_target
	if holder:
		holder.set_hovered(false)
	_drop_target = null
	
	var moved := false
	if holder and card_instance:
		moved = await _attempt_card_action(holder)
	
	HoverHandler.unfocus(self)
	
	if not moved:
		await _snap_back_to_current_holder()

func _attempt_card_action(holder: CardHolder) -> bool:
	if card_instance.is_spell() and holder.zone_type == Zone.Type.SPELLBOOK:
		return await GameActions.try_play_card(card_instance.owner, card_instance)
	if holder.zone_type == Zone.Type.ARENA:
		return await GameActions.try_play_card(card_instance.owner, card_instance, holder.lane_index)
	return false

func _snap_back_to_current_holder() -> void:
	#Illegal move or dropped from empty space
	var holder: CardHolder = CardViewManager.holder_for(card_instance)
	if holder:
		await holder.add_card(self)


#region Animation Methods

func play_attack_lunge(target_global_pos:Vector2, lunge_ratio:float =0.80) -> void:
	var start_pos := global_position
	var start_rot := global_rotation
	var lunge_pos := start_pos.lerp(target_global_pos, lunge_ratio)
	
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", lunge_pos, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", start_pos, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.step_finished
	SoundManager.play(&"card_attack", -15.0)
	await tween.finished
	
#endregion
