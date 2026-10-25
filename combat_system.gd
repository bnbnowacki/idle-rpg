extends Node

signal combat_log_entry(frame_number: int, lines: Array)

## Resolves queued movement and attacks after all actors finish their _process().

var pending_attacks: Array[Dictionary] = []
var pending_movements: Array[Dictionary] = []

func _ready() -> void:
	process_priority = 1000

func queue_attack(attacker: Node, target: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return
	pending_attacks.append({
		"attacker": attacker,
		"target": target,
		"frame": Engine.get_process_frames()
	})

func queue_movement(actor: Node, movement: Vector2) -> void:
	if not is_instance_valid(actor):
		return
	pending_movements.append({
		"actor": actor,
		"movement": movement
	})

func _process(_delta: float) -> void:
	if pending_movements.is_empty() and pending_attacks.is_empty():
		return

	var movements_to_apply: Array[Dictionary] = pending_movements.duplicate()
	pending_movements.clear()
	for movement_event in movements_to_apply:
		var actor = movement_event["actor"]
		if is_instance_valid(actor) and actor.has_method("apply_queued_movement"):
			actor.call("apply_queued_movement", movement_event["movement"])

	if pending_attacks.is_empty():
		return

	var attacks_to_resolve: Array[Dictionary] = pending_attacks.duplicate()
	pending_attacks.clear()
	var frame_number: int = int(attacks_to_resolve[0]["frame"])
	var log_lines: Array[String] = []

	# Resolve attacks in queue order because each hit can reduce the target's defense.
	for attack_event in attacks_to_resolve:
		var attacker = attack_event["attacker"]
		var target = attack_event["target"]
		if not is_instance_valid(attacker):
			continue
		if not is_instance_valid(target):
			continue
		if not target.has_method("take_damage"):
			continue

		var damage: int = 0
		var can_receive_damage: bool = true
		if target.has_method("_can_receive_damage"):
			can_receive_damage = bool(target.call("_can_receive_damage"))
		if can_receive_damage:
			var attacker_attack: Variant = attacker.get("attack")
			var target_defense: Variant = target.get("current_defense")
			if attacker_attack == null or target_defense == null:
				continue
			var attacker_attack_value: int = int(attacker_attack)
			var target_defense_value: int = int(target_defense)
			damage = maxi(attacker_attack_value - target_defense_value, 0)
			target.set("current_defense", maxi(target_defense_value - attacker_attack_value, 0))
			target.call("take_damage", damage)

		log_lines.append("%s - %d HP - %s" % [
			_get_combatant_type(attacker),
			damage,
			_get_combatant_type(target)
		])

	if not log_lines.is_empty():
		emit_signal("combat_log_entry", frame_number, log_lines)

func _get_combatant_type(actor) -> String:
	if not is_instance_valid(actor):
		return "Nieznany"
	if actor.is_in_group("player"):
		return "Knight"
	if actor.is_in_group("mobs"):
		return "Mob"
	return str(actor.name)
