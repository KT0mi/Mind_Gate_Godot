extends SpellCardDefinition

func _init() -> void:
	id = &"summon_mana_spirits"
	card_name = "Summon Mana Spirits"
	card_text = "Summon 3 1/1 'Mana Squirrels' with Quick to the Arena."
	gate = CardGate.BasicGate(25)
	cast_type = CastType.INSTANT
	sets = [&"gifted_greenhorn"]

func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "Summon 3 1/1 'Mana Squirrels' with %s to the Arena." % CardText.keyword(CardKeywords.QUICK, context)

func resolve_effect(card: CardInstance, _event: PlayCardEvent) -> void:
	for l in range(card.owner.ARENA_LANES):
		if card.owner.arena_lanes[l] == null:
			await GameActions.try_summon_card(card.owner, &"mana_squirrel", Zone.Type.ARENA, l)
