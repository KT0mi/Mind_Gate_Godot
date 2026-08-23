extends SpellCardDefinition

func _init() -> void:
	id = &"forbidden_spell_kill"
	card_name = "Forbidden Spell: Kill"
	card_text = "If the opponent has 5 or less health, you win the game."
	gate = CardGate.BasicGate(15)
	cast_type = CastType.INSTANT
	sets = [&"gifted_greenhorn"]

func resolve_effect(card: CardInstance, _event: PlayCardEvent) -> void:
	if GameState.opponent_of(card.owner).get_player_card().get_endurance() <= 5:
		RulesEngine.player_defeated.emit(GameState.opponent_of(card.owner)) #TODO
	
