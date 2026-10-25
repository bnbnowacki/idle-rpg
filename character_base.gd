class_name CharacterBase
extends Node2D

## Wspólna baza dla wszystkich postaci poruszających się i walczących.
## Grafika postaci jest rysowana w _draw_visual(), a HUD zawsze w niezależnym
## transformie, więc odwracanie sprite'a nie odwraca pasków i debug overlay.

const WALK_BOUNDS := Rect2(48.0, 70.0, 1056.0, 520.0)
const ATTACK_RANGE: float = 44.0
const CAMERA_ZOOM: float = 2.0

@export var speed: float = 72.0
@export var max_hp: int = 5
@export var attack: int = 2
@export var defense: int = 1
@export var attack_speed: float = 1.0
@export var target_group: StringName = &""
@export var target_scan_range: float = -1.0
@export var target_refresh_interval: float = 0.2

var hp: int = 5
var attack_timer: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var facing: float = 1.0
var target: Node2D
var target_refresh_timer: float = 0.0
var is_defeated: bool = false
var visual_scale: float = 1.0 / CAMERA_ZOOM

func _process(delta: float) -> void:
	if is_defeated:
		_process_defeated(delta)
		queue_redraw()
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	_update_target(delta)
	if is_instance_valid(target):
		var target_distance: float = global_position.distance_to(target.global_position)
		if target_distance > ATTACK_RANGE:
			direction = global_position.direction_to(target.global_position)
			_move_towards_target(delta)
		else:
			direction = Vector2.ZERO
			_try_attack_target()
	else:
		_move_without_target(delta)

	_clamp_to_map()
	_update_facing()
	_update_animation(delta)
	queue_redraw()

func _update_target(delta: float) -> void:
	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0 or not is_instance_valid(target) or not _is_valid_target(target):
		target = _find_nearest_target()
		target_refresh_timer = target_refresh_interval

func _find_nearest_target() -> Node2D:
	if target_group == &"":
		return null

	var nearest: Node2D
	var nearest_distance: float = INF
	for candidate_node in get_tree().get_nodes_in_group(target_group):
		if not _is_valid_target(candidate_node):
			continue
		var candidate: Node2D = candidate_node as Node2D
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _is_valid_target(candidate_node) -> bool:
	if not is_instance_valid(candidate_node) or not candidate_node is Node2D:
		return false
	if candidate_node == self or not candidate_node.visible:
		return false
	var candidate_hp: Variant = candidate_node.get("hp")
	if candidate_hp == null or int(candidate_hp) <= 0:
		return false
	if target_scan_range >= 0.0:
		var scan_distance: float = global_position.distance_to(candidate_node.global_position)
		if scan_distance > target_scan_range:
			return false
	return true

func _move_towards_target(delta: float) -> void:
	_queue_movement(direction * speed * delta)

func _queue_movement(movement: Vector2) -> void:
	var combat_system: Node = get_node_or_null("/root/CombatSystem")
	if combat_system != null:
		combat_system.call("queue_movement", self, movement)

func apply_queued_movement(movement: Vector2) -> void:
	position += movement
	_clamp_to_map()

func _clamp_to_map() -> void:
	position.x = clampf(position.x, WALK_BOUNDS.position.x, WALK_BOUNDS.end.x)
	position.y = clampf(position.y, WALK_BOUNDS.position.y, WALK_BOUNDS.end.y)

func _update_facing() -> void:
	if abs(direction.x) > 0.08:
		facing = sign(direction.x)

func _try_attack_target() -> void:
	if attack_timer > 0.0 or not _is_valid_target(target):
		return
	var target_defense: Variant = target.get("defense")
	if target_defense == null:
		return
	var damage: int = maxi(attack - int(target_defense), 0)
	_queue_attack(target, damage)
	attack_timer = 1.0 / maxf(attack_speed, 0.1)

func _move_without_target(_delta: float) -> void:
	pass

func _update_animation(_delta: float) -> void:
	pass

func _process_defeated(_delta: float) -> void:
	pass

func _draw() -> void:
	_draw_visual()
	# Koniec grafiki postaci. HUD zawsze wraca do normalnej orientacji.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	_draw_common_hud()

func _draw_visual() -> void:
	pass

func take_damage(amount: int) -> void:
	if not _can_receive_damage():
		return
	hp = maxi(hp - amount, 0)
	if hp <= 0:
		is_defeated = true
		_on_defeated()
	queue_redraw()

func _queue_attack(target: Node, damage: int) -> void:
	var combat_system: Node = get_node_or_null("/root/CombatSystem")
	if combat_system != null:
		combat_system.call("queue_attack", self, target, damage)

func _can_receive_damage() -> bool:
	return visible and not is_defeated and hp > 0

func _on_defeated() -> void:
	pass

func _draw_common_hud() -> void:
	var bar_rect: Rect2 = _get_hud_bar_rect()
	draw_rect(bar_rect, Color("#3c3d4c"), true)
	var inner_position: Vector2 = bar_rect.position + Vector2(2.0, 2.0)
	var inner_size: Vector2 = bar_rect.size - Vector2(4.0, 4.0)
	var health_ratio: float = clampf(float(hp) / maxf(float(max_hp), 1.0), 0.0, 1.0)
	draw_rect(Rect2(inner_position, inner_size), Color("#ef6a6a"), true)
	draw_rect(Rect2(inner_position, Vector2(inner_size.x * health_ratio, inner_size.y)), Color("#80dc76"), true)

	if not _debug_mode_enabled():
		return

	var font: Font = ThemeDB.fallback_font
	var hp_text_position: Vector2 = _get_debug_hp_text_position()
	var hp_text_width: float = _get_debug_hp_text_width()
	var hp_font_size: int = _get_debug_hp_font_size()
	draw_string(font, hp_text_position + Vector2(1.0, 1.0), str(hp), HORIZONTAL_ALIGNMENT_RIGHT, hp_text_width, hp_font_size, Color("#6b2d32"))
	draw_string(font, hp_text_position, str(hp), HORIZONTAL_ALIGNMENT_RIGHT, hp_text_width, hp_font_size, Color("#e85353"))

	if attack_timer <= 0.0:
		return
	var attack_interval: float = 1.0 / maxf(attack_speed, 0.1)
	var progress: float = clampf(attack_timer / attack_interval, 0.0, 1.0)
	var ring_center: Vector2 = _get_debug_ring_center()
	var ring_radius: float = _get_debug_ring_radius()
	draw_arc(ring_center, ring_radius, 0.0, TAU, 32, Color(0.12, 0.16, 0.20, 0.78), 4.0)
	if progress > 0.0:
		draw_arc(ring_center, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, Color("#f6cf62"), 4.0)

func _get_hud_bar_rect() -> Rect2:
	return Rect2(-23.0, -48.0, 46.0, 7.0)

func _get_debug_hp_text_position() -> Vector2:
	return Vector2(-48.0, -57.0)

func _get_debug_hp_text_width() -> float:
	return 32.0

func _get_debug_hp_font_size() -> int:
	return 16

func _get_debug_ring_center() -> Vector2:
	return Vector2(0.0, -62.0)

func _get_debug_ring_radius() -> float:
	return 12.0

func _debug_mode_enabled() -> bool:
	var globals_node: Node = get_node_or_null("/root/Globals")
	return globals_node != null and int(globals_node.get("debug_mode")) == 1
