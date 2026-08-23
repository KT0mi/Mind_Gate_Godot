extends CreatureCardDefinition

func _init() -> void:
	id = &"target_bot"
	card_name = "Target-Bot"
	card_text = "Taunt."
	gate = CardGate.BasicGate(30)
	attack = 0
	endurance = 3
	sets = ["dr_steelwrights_appliances"]

func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "%s." % CardText.keyword(CardKeywords.TAUNT, context)

func _build_abilities() -> Array[Ability]:
	return [CardKeywords.TAUNT_ABILITY()]
