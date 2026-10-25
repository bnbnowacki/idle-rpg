extends Node

signal combat_log_entry(frame_number: int, lines: Array)

## Rozlicza wszystkie ataki zakolejkowane w bieżącej klatce.
## Wysoki priorytet sprawia, że system działa po postaciach.

var pending_attacks: Array[Dictionary] = []
var pending_movements: Array[Dictionary] = []

func _ready() -> void:
	process_priority = 1000

func queue_attack(attacker: Node, target: Node, damage: int) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return
	pending_attacks.append({
		"attacker": attacker,
		"target": target,
		"damage": damage,
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
	for attack_event in attacks_to_resolve:
		log_lines.append("%s - %d HP - %s" % [
			_get_combatant_type(attack_event["attacker"]),
			int(attack_event["damage"]),
			_get_combatant_type(attack_event["target"])
		])
	emit_signal("combat_log_entry", frame_number, log_lines)

	var damage_by_target: Dictionary = {}

	# Wszystkie ataki z tego ticka są zebrane przed zastosowaniem obrażeń.
	for attack_event in attacks_to_resolve:
		var target = attack_event["target"]
		if not is_instance_valid(target) or not target.has_method("take_damage"):
			continue

		var target_id: int = target.get_instance_id()
		if not damage_by_target.has(target_id):
			damage_by_target[target_id] = {
				"target": target,
				"damage": 0
			}
		var target_event: Dictionary = damage_by_target[target_id]
		target_event["damage"] = int(target_event["damage"]) + int(attack_event["damage"])
		damage_by_target[target_id] = target_event

	# Teraz dopiero odpalają się take_damage() i efekty śmierci.
	for target_id in damage_by_target:
		var target_event: Dictionary = damage_by_target[target_id]
		var target = target_event["target"]
		if is_instance_valid(target):
			target.call("take_damage", int(target_event["damage"]))

func _get_combatant_type(actor) -> String:
	if not is_instance_valid(actor):
		return "Nieznany"
	if actor.is_in_group("player"):
		return "Knight"
	if actor.is_in_group("mobs"):
		return "Mob"
	return str(actor.name)
