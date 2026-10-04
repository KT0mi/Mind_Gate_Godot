extends Node
##Autoload

# Main script to sync visuals and card game logic

const CARD_SCENE := preload("res://Scenes/Card.tscn")
const DAMAGE_PROJECTILE_SCRIPT := preload("res://Scripts/SceneScripts/DamageProjectile.gd")

var _card_nodes: Dictionary = {} #CardInstance -> Card (Scene)
var _holder_nodes: Dictionary = {} #"player id: zone type" : CardHolder (Scene)

var _fx_layer : CanvasLayer
var _pending_group: Dictionary = {}  

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ZoneManager.card_zone_changed.connect(_on_zone_changed)
	GameActions.card_stat_changed.connect(_refresh_card_visuals)
	DamagePipeline.change_card_endurance.connect(_refresh_card_visuals)
	
	#AnimationQueue Points
	GameActions.attack_performed.connect(_on_attack_performed)
	DamagePipeline.effect_damage_dealt.connect(_on_effect_damage_dealt)
	
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 5
	add_child(_fx_layer)

#region Animation Methods
func _on_attack_performed(attacker: CardInstance, target:CardInstance) -> void:
	AnimationQueue.enqueue(func()->void:
		var attacker_node:=card_node_for(attacker)
		var target_node:=card_node_for(target)
		if attacker_node == null or target_node == null: return
		var prev_mode := attacker_node.interaction_mode
		attacker_node.set_interaction_mode(Card.InteractionMode.DISABLED)
		await attacker_node.play_attack_lunge(target_node.global_position)
		attacker_node.set_interaction_mode(prev_mode)
	)

func _card_group(card: CardInstance) -> StringName:
	return "card:%d" % card.get_instance_id()


func _on_zone_changed(card: CardInstance, from_zone: Zone.Type, to_zone: Zone.Type, from_lane: int = -1, to_lane: int = -1, anim_group:StringName=&"") -> void:
	var node: Card = _card_nodes.get(card)
	if node == null:
		return  # card has no visual representation yet/anymore -- fine, e.g. still in deck
	
	#Priority: an explicit group from the caller (e.g. "deal") > a pending
	#combat pin from an in-flight attack (correctness, not pacing -- keeps
	#a death from racing the lunge that caused it) > this card's own
	#independent group, which is the default for everything else.
	var group: StringName = anim_group
	if group == &"" and group != &"setup":
		group = _pending_group.get(card, _card_group(card))
	_pending_group.erase(card)
	
	if group == &"setup":
		var old_holder: CardHolder = _holder_nodes.get(_key(card.owner, from_zone, from_lane))
		if old_holder:
			old_holder.remove_card_instant(node)
		var holder: CardHolder = _holder_nodes.get(_key(card.owner, to_zone, to_lane))
		if holder:
			holder.add_card_instant(node)
		node._refresh_visuals()
		return
	
	
	
	AnimationQueue.enqueue(func() -> void:
		var old_holder : CardHolder = _holder_nodes.get(_key(card.owner, from_zone, from_lane))
		if old_holder:
			await old_holder.remove_card(node)
		
		if to_zone == Zone.Type.GRAVEYARD:
			SoundManager.play(&"card_death")
		
		var holder: CardHolder = _holder_nodes.get(_key(card.owner, to_zone, to_lane))
		if holder:
			var prev_mode := node.interaction_mode
			node.set_interaction_mode(Card.InteractionMode.DISABLED)
			await holder.add_card(node)
			node.set_interaction_mode(prev_mode)
		
		refresh_cards(GameState.all_visible_cards())
		)

func _on_effect_damage_dealt(target:CardInstance, source:CardInstance, amount:int):
	if source == null or source == target: return
	
	AnimationQueue.enqueue(func() -> void:
		var source_node := card_node_for(source)
		var target_node := card_node_for(target)
		if source_node == null or target_node == null:
			return
		
		var projectile: DamageProjectile = DAMAGE_PROJECTILE_SCRIPT.new()
		_fx_layer.add_child(projectile)
		projectile.global_position = source_node.global_position
		await projectile.fly_to(target_node.global_position)
	)
#endregion

func create_card_node(card_instance : CardInstance) -> Card:
	var node: Card = CARD_SCENE.instantiate()
	add_child(node)
	node.bind(card_instance)
	return node

#Called by CardHolder._ready()
func register_holder(holder: CardHolder) -> void:
	_holder_nodes["%s:%s:%s" % [holder.owner_is_player_one, holder.zone_type, holder.lane_index]] = holder

#Called by Card._ready()
func register_card_node(instance: CardInstance, node: Card) -> void:
	_card_nodes[instance] = node
	node._setup_visuals()
	#Connection point for each card to update their visuals when their counters or flags are changed
	instance.counter_changed.connect(func(_card, _counter): node._refresh_visuals())
	instance.flag_changed.connect(func(_card, _flag): node._refresh_visuals())



func _key(player: Player, zone: Zone.Type, lane : int = -1) -> String:
	var is_player_one:=player==GameState.player_one
	return "%s:%s:%s" % [is_player_one, zone, lane]
	
func holder_for(card_instance: CardInstance) -> CardHolder:
	if card_instance == null:
		return null
	return _holder_nodes.get(_key(card_instance.owner, card_instance.current_zone, card_instance.lane))
	
func card_node_for(instance: CardInstance) -> Card:
	return _card_nodes.get(instance)

func holder_at_point(global_point: Vector2) -> CardHolder:
	for holder in _holder_nodes.values():
		if holder.contains_point(global_point):
			return holder
	return null

func is_card_hidden_from_local_view(card_instance) -> bool:
	if card_instance == null:
		return false
	if card_instance.current_zone == Zone.Type.DECK:
		return true
	if card_instance.current_zone == Zone.Type.HAND and card_instance.owner != GameState.local_player:
		return true
	return false

func _refresh_card_visuals(card_instance: CardInstance) -> void:
	var card := card_node_for(card_instance)
	card._refresh_visuals()

func format_gate_label(gate : CardGate) -> String:
	if gate == null:
		return ""
	match gate.gate_type:
		CardGate.GateType.NONE:
			return "-"
		CardGate.GateType.LESS_THAN:
			return "<%d" % gate.value
		CardGate.GateType.GREATER_THAN:
			return ">%d" % gate.value
		CardGate.GateType.INTERVAL:
			return "%d-%d" % [gate.lower_bound, gate.upper_bound]
		_:
			return ""

# --- HELPER FUNCTIONS -------

func get_all_card_nodes() -> Array:
	return _card_nodes.values()

func refresh_cards(cards : Array[CardInstance]) -> void:
	for c in cards:
		var node := card_node_for(c)
		node._refresh_visuals()

func refresh_all_cards() -> void:
	for n: Card in _card_nodes.values():
		n._refresh_visuals()


# CardViewManager.gd
func reset() -> void:
	_card_nodes.clear()
	_pending_group.clear()
