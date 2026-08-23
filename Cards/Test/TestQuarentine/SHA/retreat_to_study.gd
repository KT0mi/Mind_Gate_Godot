extends SpellCardDefinition

func _init() -> void:
	id = &"retreat_to_study"
	card_name = "Retreat to Study"
	card_text = "Discard 1 card from your hand: If this is your first played card of the turn draw 2 cards, if not, draw 1 card."
	gate = CardGate.BasicGate(20)
	cast_type = CastType.INSTANT
	sets = [&"gifted_greenhorn"]

func resolve_effect(card: CardInstance, _event: PlayCardEvent) -> void:
	var candidates := card.owner.hand.duplicate()
	if candidates.is_empty(): return
	
	var target := await ChoiceManager.request_card(
		"Choose 1 card to discard from your hand:",
		candidates,
		card.owner,
		ChoiceContext.DISCARD_EFFECT(card)
	)
	
	await ZoneManager.move_to(target, Zone.Type.GRAVEYARD, ZoneChangeEvent.Reason.DISCARD)
	
	if card.owner.cards_played_in_turn() == 0:
		await GameActions.draw_cards(card.owner, 2, DrawCardEvent.Reason.EFFECT)
	else:
		await GameActions.draw_cards(card.owner, 1, DrawCardEvent.Reason.EFFECT)
	
