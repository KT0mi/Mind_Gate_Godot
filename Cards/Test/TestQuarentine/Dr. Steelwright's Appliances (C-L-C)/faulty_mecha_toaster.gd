extends CreatureCardDefinition

func _init() -> void:
	id = &"faulty_mecha_toaster"
	card_name = "Faulty Mecha-Toaster"
	card_text = "When this card is played, it attacks a random opponent creature, if it wins, it attacks again."
	gate = CardGate.BasicGate(25)
	attack = 2
	endurance = 2
	sets = ["dr_steelwrights_appliances"]
	
func _build_abilities() -> Array[Ability]:
	return [
		Ability.new(
			Events.PLAY_CARD_RESOLVED,
			_faulty_mecha_toaster_effect,
			func(c:CardInstance,e:PlayCardEvent)->bool: return e.card == c
		)
	]

func _faulty_mecha_toaster_effect(card:CardInstance, _event:PlayCardEvent) -> void:
	var candidates := GameState.opponent_of(card.owner).arena().duplicate()
	if candidates.is_empty(): return
	
	candidates.shuffle()
	for c in candidates:
		#Fail-Safe to see if the card is currently alive
		if card.current_zone == Zone.Type.ARENA:
			if not await GameActions.try_attack(card, c): return
