extends CreatureCardDefinition

func _init() -> void:
	id = &"boulder_bear"
	card_name = "Boulder Bear"
	card_text = ""
	gate = CardGate.BasicGate(10)
	attack = 10
	endurance = 4
	sets = ["pantagruel_islet"]
