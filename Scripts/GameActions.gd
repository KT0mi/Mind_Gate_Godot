extends Node
##Autoload

#This holds all gameplay VERBS -> Game actions that may be performed by the
#pure game logic or the cards themselves
#Action shape: check phase legally -> emit a cancellable "_request" event ->
# bail if cancelled -> perform the state change -> emit the "resolved" notification.

signal card_stat_changed(card: CardInstance)
signal attack_performed(attacker: CardInstance, target: CardInstance)

func try_play_card(player: Player, card: CardInstance, lane : int = -1) -> bool:
	print("GameActions: Requested try_play_card action")
	if ChoiceManager.has_pending_request():
		print("GameActions: Cannot play card while a choice is pending")
		return false
	
	#Check with CheckSystem to see if the card is playable
	if not card.is_playable(lane):
		print("GameActions: Failed try_play_card action. Reason: Card not playable.")
		return false
	
	var event := PlayCardEvent.new(player, card)
	await TriggerSystem.emit(Events.PLAY_CARD_REQUEST, event)
	if event.cancelled:
		print("GameActions: Failed try_play_card action. Reason: Request intercepted")
		return false
	
	if card.is_creature():
		await ZoneManager.move_to(card, Zone.Type.ARENA, ZoneChangeEvent.Reason.PLAY, lane)
		if not card.definition.has_keyword(CardKeywords.QUICK): card.set_flag(CardKeywords.DAZED, true)
	else:
		if card.is_spell():
			print("GameActions: try_play_card: Resolving instant spell effect of %s." % card.definition.id)
			await (card.definition as SpellCardDefinition).resolve_effect(card, event)
			var def : SpellCardDefinition = card.definition
			if def.cast_type == SpellCardDefinition.CastType.INSTANT:
				await ZoneManager.move_to(card, Zone.Type.GRAVEYARD, ZoneChangeEvent.Reason.PLAY)
			else:
				await ZoneManager.move_to(card, Zone.Type.SPELLBOOK, ZoneChangeEvent.Reason.PLAY)
	
	#Store turn data
	TurnController.current_player.match_data.cards_played.append(card)
	TurnController.current_player.turn_data.cards_played.append(card)
	
	print("GameActions: Resolved try_play_card action sucessfully")
	await TriggerSystem.emit(Events.PLAY_CARD_RESOLVED, event)
	return true
	
func try_kill_card(card : CardInstance) -> bool:
	print("GameActions: Requested try_kill_card action")
	
	var event := DeathEvent.new(card)
	await TriggerSystem.emit(Events.KILL_REQUEST, event)
	if event.cancelled:
		print("GameActions: Failed try_kill_card action. Reason: Request intercepted")
		return false
	
	if card.current_zone == Zone.Type.GRAVEYARD:
		print("GameActions: Failed try_kill_card action. Reason: Card already in graveyard")
		return false
	
	#Hook point to change death mechanic
	await ZoneManager.move_to(card, Zone.Type.GRAVEYARD, ZoneChangeEvent.Reason.DEATH)
	
	#Clear Card Stats and Modifiers After Death
	card.clear_all_modifiers()
	card.reset_stats()
	card_stat_changed.emit(card)
	
	print("GameActions: Resolved try_kill_card action sucessfully")
	await TriggerSystem.emit(Events.KILL_RESOLVED, event)
	return true

func try_attack(attacker: CardInstance, target: CardInstance) -> bool:
	print("GameActions: Requested try_attack action")
	if attacker.current_zone == Zone.Type.GRAVEYARD:
		print("GameActions: Failed try_attack_action. Reason: Card is in graveyard")
		return false
	
	var event := AttackEvent.new(attacker, target)
	await TriggerSystem.emit(Events.ATTACK_REQUEST, event)
	if event.cancelled:
		print("GameActions: Failed try_attack action. Reason: Request intercepted")
		return false
		
	var actual_target := event.target
	if actual_target != target:
		print("GameActions: Attack target redirected")
	
	attack_performed.emit(attacker, actual_target)
	
	await DamagePipeline.apply_damage(actual_target, attacker.get_attack(), attacker, DamageEvent.Reason.ATTACK)
	await DamagePipeline.apply_damage(event.attacker, actual_target.get_attack(), actual_target, DamageEvent.Reason.ATTACK)
	
	print("GameActions: Resolved try_attack action sucessfully")
	await TriggerSystem.emit(Events.ATTACK_RESOLVED, event)
	return true

func draw_cards(player: Player, amount: int, reason : DrawCardEvent.Reason, anim_group:StringName=&"") -> void:
	print("GameActions: Requested draw_cards action for player %s of %d cards" % ["1" if player == GameState.player_one else "2", amount])
	var event := DrawCardEvent.new(player, amount, reason)
	for i in amount:
		if player.deck.is_empty():
			print("GameActions: Failed draw_cards action. Reason: Deck Out")
			return #Deck out
		if reason == DrawCardEvent.Reason.TURN and TurnController.forgetting:
			print("GameActions: Failed draw_cards action. Reason: Forgetting Turn")
			return
		var card: CardInstance = player.deck.pop_back()
		await ZoneManager.move_to(card, Zone.Type.HAND, ZoneChangeEvent.Reason.DRAW,-1,anim_group)
		TurnController.current_player.turn_data.drew_cards = true
	await TriggerSystem.emit(Events.DRAW_CARD_RESOLVED, event)

## For DURABLE, source-independent modifications only (e.g. a spell that
## permanently grants +N Attack). For "while [source] is in play" effects,
## don't call this -- declare a ContinuousEffect on the source's
## CardDefinition instead; CheckSystem picks it up with no add/remove step.
## See the comment on CardInstance.attack_modifiers for the full rationale.
func try_add_attack_modifier(target: CardInstance, mod : StatModifer) -> bool:
	print("GameActions: Requested try_add_attack_modifier action")
	var event := ModifierEvent.new(target, mod.source, mod)
	await TriggerSystem.emit(Events.MODIFY_ATTACK_REQUEST, event)
	if event.cancelled:
		print("GameActions: Failed try_add_attack_modifier action. Reason: Request intercepted")
		return false
	
	target.attack_modifiers.append(mod)
	card_stat_changed.emit(target)
	print("GameActions: Resolved try_add_attack_modifier action sucessfully.")
	await TriggerSystem.emit(Events.MODIFY_ATTACK_RESOLVE, event)
	return true
 
func try_add_endurance_modifier(target: CardInstance, mod : StatModifer) -> bool:
	print("GameActions: Requested try_add_endurance_modifier action")
	var event := ModifierEvent.new(target, mod.source, mod)
	await TriggerSystem.emit(Events.MODIFY_ENDURANCE_REQUEST, event)
	if event.cancelled:
		print("GameActions: Failed try_add_endurance_modifier action. Reason: Request intercepted")
		return false
	
	target.endurance_modifiers.append(mod)
	card_stat_changed.emit(target)
	print("GameActions: Resolved try_add_endurance_modifier action sucessfully.")
	
	#Check if card died, after modifying endurance
	RulesEngine.check_state_based_actions()
	
	await TriggerSystem.emit(Events.MODIFY_ENDURANCE_REQUEST, event)
	return true
 
func try_add_gate_modifier(target: CardInstance, mod : GateModifier) -> bool:
	print("GameActions: Requested try_add_gate_modifier action")
	var event := ModifierEvent.new(target, mod.source, mod)
	await TriggerSystem.emit(Events.MODIFY_GATE_REQUEST, event)
	if event.cancelled:
		print("GameActions: Failed try_add_gate_modifier action. Reason: Request intercepted")
		return false
	
	target.gate_modifiers.append(mod)
	card_stat_changed.emit(target)
	print("GameActions: Resolved try_add_gate_modifier action sucessfully.")
	await TriggerSystem.emit(Events.MODIFY_GATE_RESOLVE, event)
	return true

func try_summon_card(owner : Player, id : StringName, to_zone: Zone.Type, lane : int = -1) -> CardInstance:
	print("GameActions: Requested try_summon_card action")
	
	if to_zone == Zone.Type.ARENA:
		if owner.arena_lanes[lane] != null:
			print("GameActions: Failed try_summon_card action. Reason: Trying to summon a card on a filled lane")
			return
	
	var event := SummonEvent.new(owner, id)
	await TriggerSystem.emit(Events.SUMMON_REQUEST, event)
	if event.cancelled:
		print("GameActions: Failed try_summon_card action. Reason: Request intercepted")
		return null
	
	var card_instance := await CardFactory.create_instance(id, owner)
	CardViewManager.create_card_node(card_instance)
	
	#If the summoned card was a spell and it was added to the spellbook, resolve it's play effect
	if card_instance.is_spell() and to_zone == Zone.Type.SPELLBOOK:
		var e := PlayCardEvent.new(owner, card_instance)
		var def : SpellCardDefinition = card_instance.definition
		await def.resolve_effect(card_instance, e)
		await ZoneManager.move_to(card_instance, to_zone, ZoneChangeEvent.Reason.SUMMON, lane)
		if def.cast_type == SpellCardDefinition.CastType.INSTANT:
			await ZoneManager.move_to(card_instance, Zone.Type.GRAVEYARD, ZoneChangeEvent.Reason.RESOLVE, lane)
	else:
		await ZoneManager.move_to(card_instance, to_zone, ZoneChangeEvent.Reason.SUMMON, lane)
	
	print("GameActions: Resolved try_summon_card action sucessfully.")
	await TriggerSystem.emit(Events.SUMMON_RESOLVED, event)
	return card_instance
