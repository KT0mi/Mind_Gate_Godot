extends CreatureCardDefinition

func _init() -> void:
	id = &"eye_of_jormungandr"
	card_name = "Eye of Jormungandr"
	card_text = "'The all seeing eye of the world serpent'"
	gate = CardGate.BasicGate(15)
	attack = 0
	endurance = 5
	sets = [&"critters"]
