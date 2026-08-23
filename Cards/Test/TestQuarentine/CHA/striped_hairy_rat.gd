extends CreatureCardDefinition

func _init() -> void:
	id = &"striped_hairy_rat"
	card_name = "Stripped Hairy Rat"
	card_text = "Quick."
	gate = CardGate.BasicGate(15)
	attack = 3
	endurance = 2
	sets = ["pantagruel_islet"]
	
func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "%s." % CardText.keyword(CardKeywords.QUICK, context)

func _build_abilities() -> Array[Ability]:
	return [CardKeywords.QUICK_ABILITY()]
