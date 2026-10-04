extends SpellCardDefinition

func _init() -> void:
	id = &"magma_explosion"
	card_name = "Magma Explosion"
	card_text = "This card counts as a 'Magma Burst' card. Choose any card in the arena: Deal 1+1 damage to it."
	gate = CardGate.BasicGate(30)
	cast_type = CastType.INSTANT
	damage_tags = [&"magma_burst"]
	sets = ["fiery_tradition"]

func get_display_text(instance: CardInstance, _context : bool = false) -> String:
	var dmg := CardText.dynamic(CheckSystem.effect_damage_of(instance, 1))
	return "This card counts as a 'Magma Burst' card. Choose any card in the arena: Deal %s+%s damage to it." \
		% [dmg,dmg]

func resolve_effect(card: CardInstance, _event: PlayCardEvent) -> void:
	var candidates := GameState.all_cards_in_arena().duplicate()
	if candidates.is_empty(): return
	
	var damage := CheckSystem.effect_damage_of(card, 1)+CheckSystem.effect_damage_of(card, 1)
	
	var target := await ChoiceManager.request_card(
		"Choose any card from the arena:",
		candidates,
		card.owner,
		ChoiceContext.DAMAGE_EFFECT(card, damage)
	)
	
	await DamagePipeline.apply_damage(target, damage, card)
