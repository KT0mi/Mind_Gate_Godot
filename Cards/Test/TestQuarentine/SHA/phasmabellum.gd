extends SpellCardDefinition

func _init() -> void:
	id = &"phasmabellum"
	card_name = "Phasmabellum"
	card_text = "Deal 3 damage to your opponent for each creature card in their arena."
	gate = CardGate.BasicGate(15)
	cast_type = CastType.INSTANT
	sets = [&"gifted_greenhorn"]

func get_display_text(instance: CardInstance, _context : bool = false) -> String:
	return "Deal %s damage to your opponent for each creature card in their arena." \
		% CardText.dynamic(CheckSystem.effect_damage_of(instance, 3))

func resolve_effect(card: CardInstance, _event: PlayCardEvent) -> void:
	var creatures := GameState.opponent_of(card.owner).arena()
	if creatures.is_empty(): return
	
	for c in creatures:
		await DamagePipeline.apply_damage(c.owner.get_player_card(), CheckSystem.effect_damage_of(card, 3), card)
