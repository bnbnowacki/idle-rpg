extends CharacterBase

## Uniwersalny mob testowy. Walka zostanie podpięta w kolejnym kroku.

const BODY := Color("#8c6ac8")
const BODY_LIGHT := Color("#b38ae6")
const BODY_DARK := Color("#624699")
const OUTLINE := Color("#41345c")
const AGGRO_RANGE: float = 132.0

var pulse_time: float = 0.0
var is_idle: bool = true
var idle_timer: float = 0.0
var wander_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = int(Time.get_ticks_msec()) + int(position.x * 31.0) + int(position.y * 17.0)
	hp = max_hp
	idle_timer = rng.randf_range(3.0, 4.0)
	direction = Vector2.ZERO
	add_to_group("mobs")
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	attack_timer -= delta
	var player: Node2D = _find_player()
	if is_instance_valid(player) and player.visible:
		var to_player: Vector2 = player.global_position - global_position
		var player_distance: float = to_player.length()
		if player_distance <= AGGRO_RANGE:
			if player_distance > ATTACK_RANGE:
				direction = to_player.normalized()
				position += direction * speed * delta
			else:
				direction = Vector2.ZERO
				_try_attack_player(player)
			_clamp_to_map()
			_update_facing()
			queue_redraw()
			return

	_update_wander(delta)
	queue_redraw()

func _try_attack_player(player: Node2D) -> void:
	if attack_timer > 0.0:
		return
	var player_defense: int = int(player.get("defense"))
	var damage: int = maxi(attack - player_defense, 0)
	player.call("take_damage", damage)
	attack_timer = 1.0 / maxf(attack_speed, 0.1)

func _update_wander(delta: float) -> void:
	if is_idle:
		direction = Vector2.ZERO
		idle_timer -= delta
		if idle_timer <= 0.0:
			_begin_wander()
		return

	position += direction * speed * delta
	_clamp_to_map()
	wander_timer -= delta
	if wander_timer <= 0.0:
		_begin_idle()
	_update_facing()

func _begin_wander() -> void:
	is_idle = false
	var angle: float = rng.randf_range(-PI, PI)
	direction = Vector2.from_angle(angle)
	wander_timer = rng.randf_range(0.9, 1.8)
	_update_facing()

func _begin_idle() -> void:
	is_idle = true
	direction = Vector2.ZERO
	idle_timer = rng.randf_range(3.0, 4.0)

func _clamp_to_map() -> void:
	position.x = clampf(position.x, WALK_BOUNDS.position.x, WALK_BOUNDS.end.x)
	position.y = clampf(position.y, WALK_BOUNDS.position.y, WALK_BOUNDS.end.y)

func _update_facing() -> void:
	if abs(direction.x) > 0.08:
		facing = sign(direction.x)

func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty() or not players[0] is Node2D:
		return null
	return players[0] as Node2D

func _on_defeated() -> void:
	var game: Node = get_parent()
	if game != null and game.has_method("add_coin"):
		game.add_coin(1)
	queue_free()

func _draw_visual() -> void:
	var pulse: float = sin(pulse_time * 3.0) * 1.2

	# Cień.
	draw_set_transform(Vector2(0.0, 14.0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 20.0, Color(0.18, 0.30, 0.22, 0.25))
	draw_set_transform(Vector2(0.0, pulse), 0.0, Vector2.ONE)

	# Jeden uniwersalny, bajkowy potworek.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 10), Vector2(-19, -9), Vector2(-11, -22),
		Vector2(-3, -15), Vector2(5, -24), Vector2(16, -15),
		Vector2(21, 5), Vector2(13, 18), Vector2(-8, 19)
	]), BODY_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 8), Vector2(-16, -8), Vector2(-9, -18),
		Vector2(-2, -11), Vector2(5, -20), Vector2(13, -12),
		Vector2(17, 4), Vector2(10, 14), Vector2(-7, 15)
	]), BODY)
	draw_circle(Vector2(-7, -7), 5.0, BODY_LIGHT)

	# Oczy.
	draw_circle(Vector2(-7, -2), 4.0, Color("#fff5cf"))
	draw_circle(Vector2(8, -2), 4.0, Color("#fff5cf"))
	draw_circle(Vector2(-6, -1), 1.8, OUTLINE)
	draw_circle(Vector2(9, -1), 1.8, OUTLINE)
	draw_line(Vector2(-4, 8), Vector2(7, 8), OUTLINE, 2.0)

	# Baza narysuje HUD po zresetowaniu transformu.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _get_hud_bar_rect() -> Rect2:
	return Rect2(-23.0, -36.0, 46.0, 7.0)

func _get_debug_hp_text_position() -> Vector2:
	return Vector2(-43.0, -46.0)

func _get_debug_hp_text_width() -> float:
	return 28.0

func _get_debug_hp_font_size() -> int:
	return 15

func _get_debug_ring_center() -> Vector2:
	return Vector2(0.0, -51.0)

func _get_debug_ring_radius() -> float:
	return 10.0
