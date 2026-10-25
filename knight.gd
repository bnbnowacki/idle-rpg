extends CharacterBase

## Tymczasowy bohater prototypu: samodzielnie spaceruje po mapie.

const ARMOR := Color("#e8edf2")
const ARMOR_DARK := Color("#8795a4")
const BLUE := Color("#4779bd")
const BLUE_DARK := Color("#31588d")
const GOLD := Color("#f2c65c")
const SKIN := Color("#f1bf91")
const OUTLINE := Color("#354455")
var turn_timer: float = 0.0
var walk_time: float = 0.0
var target: Node2D
var target_refresh_timer: float = 0.0
var is_dead: bool = false
var respawn_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 73421
	hp = max_hp
	add_to_group("player")
	_choose_direction()
	queue_redraw()

func _process(delta: float) -> void:
	if is_dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	walk_time += delta
	turn_timer -= delta
	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0:
		target = _find_nearest_mob()
		target_refresh_timer = 0.2

	if is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() > ATTACK_RANGE:
			direction = to_target.normalized()
			position += direction * speed * delta
		else:
			direction = Vector2.ZERO
			_try_attack_target(delta)
	else:
		var at_edge: bool = (
			position.x <= WALK_BOUNDS.position.x or
			position.x >= WALK_BOUNDS.end.x or
			position.y <= WALK_BOUNDS.position.y or
			position.y >= WALK_BOUNDS.end.y
		)
		if turn_timer <= 0.0 or at_edge:
			_choose_direction()
		position += direction * speed * delta

	position.x = clampf(position.x, WALK_BOUNDS.position.x, WALK_BOUNDS.end.x)
	position.y = clampf(position.y, WALK_BOUNDS.position.y, WALK_BOUNDS.end.y)
	if abs(direction.x) > 0.08:
		facing = sign(direction.x)
	queue_redraw()

func _try_attack_target(delta: float) -> void:
	attack_timer -= delta
	if attack_timer > 0.0 or not is_instance_valid(target):
		return
	var target_defense: int = int(target.get("defense"))
	var damage: int = maxi(attack - target_defense, 0)
	target.call("take_damage", damage)
	attack_timer = 1.0 / maxf(attack_speed, 0.1)

func _on_defeated() -> void:
	is_dead = true
	hp = 0
	respawn_timer = 3.0
	target = null
	direction = Vector2.ZERO
	visible = false

func _respawn() -> void:
	is_dead = false
	hp = max_hp
	position = Vector2(
		rng.randf_range(WALK_BOUNDS.position.x, WALK_BOUNDS.end.x),
		rng.randf_range(WALK_BOUNDS.position.y, WALK_BOUNDS.end.y)
	)
	attack_timer = 0.0
	target_refresh_timer = 0.0
	visible = true
	_choose_direction()
	queue_redraw()

func _find_nearest_mob() -> Node2D:
	var nearest: Node2D
	var nearest_distance: float = INF
	for mob_node in get_tree().get_nodes_in_group("mobs"):
		if not mob_node is Node2D:
			continue
		var mob: Node2D = mob_node as Node2D
		var distance: float = global_position.distance_squared_to(mob.global_position)
		if distance < nearest_distance:
			nearest = mob
			nearest_distance = distance
	return nearest

func _choose_direction() -> void:
	var angle: float = rng.randf_range(-PI, PI)
	direction = Vector2.from_angle(angle)
	turn_timer = rng.randf_range(1.2, 3.0)

func _draw_visual() -> void:
	var step: float = sin(walk_time * 9.0) * 3.0
	var bob: float = abs(sin(walk_time * 9.0)) * 1.2
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(facing, 1.0))

	# Cień.
	draw_set_transform(Vector2(0.0, 18.0), 0.0, Vector2(facing, 0.45))
	draw_circle(Vector2.ZERO, 20.0, Color(0.18, 0.30, 0.22, 0.28))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(facing, 1.0))

	# Peleryna.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -5), Vector2(-25, 11), Vector2(-18, 19),
		Vector2(-4, 13), Vector2(5, 4)
	]), BLUE_DARK)

	# Nogi w prostym cyklu chodzenia.
	draw_line(Vector2(-6, 13), Vector2(-8 + step, 27), OUTLINE, 5.0)
	draw_line(Vector2(6, 13), Vector2(8 - step, 27), OUTLINE, 5.0)
	draw_line(Vector2(-11 + step, 27), Vector2(-3 + step, 27), BLUE_DARK, 5.0)
	draw_line(Vector2(3 - step, 27), Vector2(12 - step, 27), BLUE_DARK, 5.0)

	# Tułów, pas i emblemat.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(14, 13),
		Vector2(0, 18), Vector2(-14, 13)
	]), ARMOR)
	draw_rect(Rect2(-13, 4, 26, 5), GOLD, true)
	draw_circle(Vector2(0, -1), 4.0, BLUE)
	draw_circle(Vector2(0, -1), 2.0, Color("#b9e3f4"))

	# Głowa, hełm i przyłbica.
	draw_circle(Vector2(0, -18), 12.0, SKIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -19), Vector2(-11, -29), Vector2(-4, -35),
		Vector2(8, -33), Vector2(14, -24), Vector2(11, -18), Vector2(-2, -21)
	]), ARMOR_DARK)
	draw_line(Vector2(-12, -22), Vector2(12, -22), OUTLINE, 3.0)
	draw_line(Vector2(1, -22), Vector2(1, -17), OUTLINE, 2.0)
	draw_circle(Vector2(7, -25), 2.0, Color("#d9f5ff"))

	# Miecz po prawej stronie sylwetki.
	draw_line(Vector2(14, 2), Vector2(25, -13), GOLD, 4.0)
	draw_line(Vector2(21, -12), Vector2(35, -29), Color("#f6f4df"), 5.0)
	draw_line(Vector2(22, -10), Vector2(36, -27), Color("#ffffff"), 2.0)

	# Baza narysuje HUD po zresetowaniu transformu.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _get_hud_bar_rect() -> Rect2:
	return Rect2(-23.0, -48.0, 46.0, 7.0)

func _get_debug_hp_text_position() -> Vector2:
	return Vector2(-48.0, -57.0)

func _get_debug_hp_text_width() -> float:
	return 32.0

func _get_debug_ring_center() -> Vector2:
	return Vector2(0.0, -62.0)

func _get_debug_ring_radius() -> float:
	return 12.0
