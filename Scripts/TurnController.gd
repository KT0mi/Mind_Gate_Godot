extends Node
##Autoload

#5-phase State machine

#Signal for systems that are external to game logic (UI, AI, etc.)
signal phase_changed(phase: Phase, player: Player, forgetting)

enum Phase {START_TURN, DRAW, PLAY, BATTLE, END_TURN}

var forgetting : bool = false

var turn_counter: int = 0
var current_phase: Phase = Phase.START_TURN
var current_player: Player
func round_counter() -> int:
	return ceili(turn_counter/2.0)

func start_match() -> void:
	MusicManager.play_track(&"match_song", MusicManager.DEFAULT_FADE, -25.0)
	await RulesEngine.setup_match()
	current_player = GameState.player_one
	turn_counter = 1
	await _enter_phase(Phase.START_TURN)

func advance_phase() -> void:
	match current_phase:
		Phase.START_TURN:	await _enter_phase(Phase.DRAW)
		Phase.DRAW:			await _enter_phase(Phase.PLAY)
		Phase.PLAY:			await _enter_phase(Phase.BATTLE)
		Phase.BATTLE:		await _enter_phase(Phase.END_TURN)
		Phase.END_TURN:		await _end_turn_and_pass()

func forget_turn() -> void:
	if current_phase != Phase.START_TURN:
		print("TurnController: Cannot forget turn. Reason: Not at turn start.")
		return
	
	if turn_counter < 3:
		print("TurnController: Cannot forget turn. Reason: Cannot forget before player's 2nd turn.")
		return
	
	var forgetting_player := current_player
	forgetting = true
	await DamagePipeline.apply_damage(forgetting_player.get_player_card(), 2, current_player.get_player_card(), DamageEvent.Reason.STATE)
	
	#Store Data
	current_player.match_data.turns_forgotten += 1
	current_player.turn_data.forgot = true
	
	for i in range(4):
		if forgetting_player == current_player:
			await advance_phase()
		else: 
			print("TurnController: Ending 'Forget Turn', current player is no longer the same.")
			break
	forgetting = false

func _enter_phase(phase: Phase) -> void:
	var event := PhaseEvent.new(current_player)
	
	
	match phase:
		Phase.START_TURN:
			current_phase = phase
			await TriggerSystem.emit(Events.START_PHASE_START, event)
		Phase.DRAW:
			await TriggerSystem.emit(Events.START_PHASE_END, event)
			current_phase = phase
			await TriggerSystem.emit(Events.DRAW_PHASE_START, event)
			if turn_counter > 1:
				await GameActions.draw_cards(current_player, 1, DrawCardEvent.Reason.TURN)
			else:
				await advance_phase()
		Phase.PLAY:
			await TriggerSystem.emit(Events.DRAW_PHASE_END, event)
			current_phase = phase
			await TriggerSystem.emit(Events.PLAY_PHASE_START, event)
		Phase.BATTLE:
			await TriggerSystem.emit(Events.PLAY_PHASE_END, event)
			current_phase = phase
			await TriggerSystem.emit(Events.BATTLE_PHASE_START, event)
			await _resolve_battle_phase()
		Phase.END_TURN:
			await TriggerSystem.emit(Events.BATTLE_PHASE_END, event)
			current_phase = phase
			await TriggerSystem.emit(Events.END_PHASE_START, event)
			await RulesEngine.check_end_phase_state()
		
	phase_changed.emit(phase, current_player, forgetting)

func _end_turn_and_pass() -> void:
	var event := PhaseEvent.new(current_player)
	await TriggerSystem.emit(Events.END_PHASE_END, event)
	
	#Save turn data into match data and reset turn data
	current_player.match_data.player_turns.append(current_player.turn_data)
	current_player.reset_turn_data()
	
	#Change current player
	current_player = GameState.opponent_of(current_player)
	turn_counter += 1
	await _enter_phase(Phase.START_TURN)

func _resolve_battle_phase() -> void:
	#If forgetting turn, return
	if forgetting:
		return
	
	#If no cards in arena skip battle phase resolve
	if current_player.arena().is_empty():
		return
	
	var candidates : Array[CardInstance]
	for c : CardInstance in current_player.arena().duplicate():
		if c.is_battle_ready(): candidates.append(c)
	
	#Skip battle phase if there are no candidates for battle
	if candidates.is_empty(): return
	
	#Prompt choice for player to choose atackers
	var attackers: Array[CardInstance] = await ChoiceManager.request_cards(
		"Choose attackers from arena cards",
		candidates,
		current_player,
		0,
		candidates.size(),
		ChoiceContext.BATTLE(current_player)
	)
	
	#If no attackers after choice, return
	if attackers.is_empty():
		return
	
	attackers.sort_custom(func(a, b): return a.lane < b.lane)
	var opponent := GameState.opponent_of(current_player)
	var face : CardInstance = opponent.player_zone[0]
	
	for attacker in attackers:
		await GameActions.try_attack(attacker, face)


# TurnController.gd
func reset() -> void:
	turn_counter = 0
	current_phase = Phase.START_TURN
	current_player = null
	forgetting = false
