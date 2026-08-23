extends Node
##Autoload

##Handles zone changes in cards
#The only place any card's current_zone should actually change
#Also makes sure all cards are followed when changing zones

#signal to sync visuals - seperate from game logic
signal card_zone_changed(card: CardInstance, from_zone: Zone.Type, to_zone: Zone.Type, from_lane: int, to_lane: int)

func move_to(
	card: CardInstance, 
	to_zone: Zone.Type,
	reason: ZoneChangeEvent.Reason = ZoneChangeEvent.Reason.MANUAL, 
	lane: int = -1,
	anim_group : StringName = &"") -> void:
	
	var from_zone := card.current_zone
	var from_lane := card.lane
	var player := card.owner
	
	if from_zone == Zone.Type.ARENA:
		player.arena_lanes[card.lane] = null
		card.lane = -1
	else:
		player.zone_array(from_zone).erase(card)
	
	if to_zone == Zone.Type.ARENA:
		player.arena_lanes[lane] = card
		card.lane = lane
		SoundManager.play(&"enter_arena")
	else:
		player.zone_array(to_zone).append(card)
	
	
	card.current_zone = to_zone
	if GameState.is_continuous_source_active(card):
		card.continuous_since = GameState.next_timestamp()
	card_zone_changed.emit(card, from_zone, to_zone, from_lane, lane, anim_group)
	await TriggerSystem.emit(Events.ZONE_CHANGE, 
		ZoneChangeEvent.new(card, from_zone, to_zone, reason, lane))
