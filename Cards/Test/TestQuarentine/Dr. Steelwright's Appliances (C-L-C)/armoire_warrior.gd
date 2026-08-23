extends CreatureCardDefinition

func _init() -> void:
	id = &"armoire_warrior"
	card_name = "Armoire Warrior"
	card_text = "Taunt. This card cannot attack. Whenever anything attacks this card, it gets -1 Attack."
	gate = CardGate.BasicGate(20)
	attack = 0
	endurance = 6
	sets = ["dr_steelwrights_appliances"]

func is_battle_ready(_card: CardInstance) -> bool:
	return false

func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "%s. This card cannot attack. Whenever anything attacks this card, it gets -1 Attack." \
		% CardText.keyword(CardKeywords.TAUNT, context)

func _build_abilities() -> Array[Ability]:
	return [
		CardKeywords.TAUNT_ABILITY(),
		Ability.new(
			Events.ATTACK_RESOLVED,
			func(c:CardInstance, e:AttackEvent):
				await GameActions.try_add_attack_modifier(e.attacker, StatModifer.delta(-1, c)),
			func(c:CardInstance, e:AttackEvent)->bool: return e.target == c
		)
	]
