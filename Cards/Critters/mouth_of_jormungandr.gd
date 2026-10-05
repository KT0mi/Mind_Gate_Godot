extends CreatureCardDefinition

func _init() -> void:
	id = &"mouth_of_jormungandr"
	card_name = "Mouth of Jormungandr"
	card_text = "This card can only attack if you have both 'Eye of Jormungandr' and 'Body of Jormungandr' in your arena."
	gate = CardGate.BasicGate(15)
	attack = 10
	endurance = 10
	sets = [&"critters"]

func is_battle_ready(card: CardInstance) -> bool:
	var has_eye:bool=false
	var has_body:bool=false
	for c in card.owner.arena().duplicate():
		if c.get_id() == &"eye_of_jormungandr":
			has_eye = true
		elif c.get_id() == &"body_of_jormungandr":
			has_body = true
	
	return has_eye and has_body
