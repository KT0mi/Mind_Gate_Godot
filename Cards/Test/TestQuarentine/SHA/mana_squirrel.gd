extends CreatureCardDefinition

func _init() -> void:
	id = &"mana_squirrel"
	card_name = "Mana Squirrel"
	card_text = "Quick."
	gate = CardGate.None()
	attack = 1
	endurance = 1

func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "%s." % CardText.keyword(CardKeywords.QUICK, context)

func _build_abilities() -> Array[Ability]:
	return [CardKeywords.QUICK_ABILITY()]
