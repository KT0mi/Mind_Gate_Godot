extends CreatureCardDefinition

func _init() -> void:
	id = &"obsidian_boar"
	card_name = "Obsidian Boar"
	card_text = "Quick. If this attacks on the first turn it was played: -4 Attack."
	gate = CardGate.BasicGate(15)
	attack = 5
	endurance = 4
	sets = ["pantagruel_islet"]
	
func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "%s. If this attacks on the first turn it was played: -4 Attack." \
		% CardText.keyword(CardKeywords.QUICK, context)

func _build_abilities() -> Array[Ability]:
	return [
		CardKeywords.QUICK_ABILITY(),
		Ability.new(
			Events.ATTACK_RESOLVED,
			func(c:CardInstance, _e:AttackEvent):
				await GameActions.try_add_attack_modifier(c, StatModifer.delta(-4,c, "-4 Attack")),
			func(c:CardInstance, e:AttackEvent)->bool: return e.attacker == c and c.owner.turn_data.cards_played.has(c)
		)
	]
