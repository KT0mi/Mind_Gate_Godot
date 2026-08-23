extends CreatureCardDefinition

func _init() -> void:
	id = &"weenie_the_familiar"
	card_name = "Weenie: The Familiar"
	card_text = "When played: Draw 1 card. While this card is in play: All your spells deal +1 damage."
	is_special = true
	gate = CardGate.BasicGate(20)
	attack = 2
	endurance = 3
	sets = [&"gifted_greenhorn"]

func _build_continuous_effects() -> Array[ContinuousEffect]:
	return [
		ContinuousEffect.new(
			ContinuousEffect.Kind.EFFECT_DAMAGE,
			func(_src:CardInstance, ctx:EffectDamageCheck) -> bool:
				return ctx.card.is_spell(),
			func(value:int, _src:CardInstance, _ctx:EffectDamageCheck)->int:
				return value + 1,
			ContinuousEffect.Layer.DELTA,
			"+1 Effect Damage"
		)
	]

func _build_abilities() -> Array[Ability]:
	return [
		Ability.new(
			Events.PLAY_CARD_RESOLVED,
			func(c:CardInstance,_e:PlayCardEvent): 
				await GameActions.draw_cards(c.owner, 1, DrawCardEvent.Reason.EFFECT),
			func(c:CardInstance,e:PlayCardEvent) -> bool: return e.card == c,
		)
	]
