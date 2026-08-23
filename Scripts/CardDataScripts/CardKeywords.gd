class_name CardKeywords extends RefCounted
#This class stores StringName vars into constants for common use flags and counters
#For cards. I consider these "statuses" like "dazed" when a card is added to the arena.
#Because any card could have them since they are tied to Game State actions 
#and not specific card actions

class Keyword extends RefCounted:
	var id : StringName
	var name: String
	var description: String
	
	func _init(i:StringName, nm: String, dscpt: String) -> void:
		id = i
		name = nm
		description = dscpt

static var _keywords : Dictionary[StringName, Keyword] = {}

## ------ Flags ------
const DAZED := &"dazed"

## ------ Keywords ------
const TAUNT := &"taunt"
static var Taunt : Keyword 
const QUICK := &"quick"
static var Quick : Keyword 
const BLOCK := &"block"
static var Block : Keyword 

#Init all Keywords as data structures
static func _static_init() -> void:
	Taunt = Keyword.new(
		TAUNT,
		"Taunt",
		"All attacks against your player card are redirected to this card if they weren't redirected already."
	)
	Quick = Keyword.new(
		QUICK,
		"Quick",
		"When this card is played, it doesn't become 'Dazed'."
	)
	Block = Keyword.new(
		BLOCK,
		"Block",
		"This card receives all damage that the card on the opposing lane deals."
	)
	_keywords = {
		TAUNT: Taunt,
		QUICK: Quick,
		BLOCK: Block,
	}

static func get_keyword(i : StringName) -> Keyword:
		return _keywords.get(i)

## -------- IDs -----
const BLEEDING_HEART := &"bleeding_heart"

## ------ Abilities -----

static func QUICK_ABILITY() -> Ability:
	return Ability.new(Events.EMPTY, func(c,e): return, func(c,e): return false, [QUICK])

##Taunt Ability: A taunt card redirects all attacks that would target the player
##towards itself.
static func TAUNT_ABILITY() -> Ability:
	return Ability.new(
		Events.ATTACK_REQUEST,
		func(card, event: AttackEvent) -> void:
			event.redirect_target(card, card),
		_taunt_con,
		[TAUNT]
	)

static func _taunt_con(card : CardInstance, event: AttackEvent) -> bool:
	if event.attacker.owner == card.owner:
		return false
	if event.redirected:
		return false
	return true

##Block Ability: A block ability recieves all damage that is dealt by a creature in the opposing lane
##Opposing lane is the same lane index but on the opposing player's side.
static func BLOCK_ABILITY() -> Ability:
	return Ability.new(
		Events.DAMAGE_REQUEST,
		func(c, e : DamageEvent): e.redirect_target(c, c),
		_block_con,
		[BLOCK]
	)

static func _block_con(card: CardInstance, event: DamageEvent) -> bool:
	return event.source.owner != card.owner and event.source.lane == card.lane
