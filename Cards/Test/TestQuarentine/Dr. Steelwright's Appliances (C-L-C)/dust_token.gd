extends CreatureCardDefinition

func _init() -> void:
	id = &"dust_token"
	card_name = "Dust"
	card_text = "Block."
	gate = CardGate.None()
	attack = 1
	endurance = 1

func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "%s." % CardText.keyword(CardKeywords.BLOCK, context)

func _build_abilities() -> Array[Ability]:
	return [CardKeywords.BLOCK_ABILITY()]
