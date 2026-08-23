extends CreatureCardDefinition

func _init() -> void:
	id = &"vac_bot"
	card_name = "Vac-Bot"
	card_text = "When this enter the arena, place a 1/1 'Dust' with Block in the opposite lane, if it is empty."
	gate = CardGate.BasicGate(25)
	attack = 2
	endurance = 2
	sets = ["dr_steelwrights_appliances"]

func get_display_text(_instance: CardInstance, context : bool = false) -> String:
	return "When this enter the arena, place a 1/1 'Dust' with %s in the opposite lane." \
		% CardText.keyword(CardKeywords.BLOCK, context)

func _build_abilities() -> Array[Ability]:
	return [
		Ability.new(
			Events.PLAY_CARD_RESOLVED,
			func(c:CardInstance,e:PlayCardEvent):
				if c.lane == -1: return
				
				GameActions.try_summon_card(GameState.opponent_of(c.owner), &"dust_token", Zone.Type.ARENA, c.lane),
			func(c:CardInstance,e:PlayCardEvent) -> bool: return e.card == c
		)
	]
