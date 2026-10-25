extends Node2D

## Bajkowa, rysowana proceduralnie mapa startowa.
## Wszystkie elementy są tymczasowe i można je później zastąpić sprite'ami.

const MAP_SIZE := Vector2(1152.0, 648.0)
const GRASS := Color("#8fcf78")
const GRASS_LIGHT := Color("#a8df88")
const GRASS_DARK := Color("#6fb367")
const PATH := Color("#e7c889")
const PATH_EDGE := Color("#c69c5a")
const WATER := Color("#65bfd1")
const WATER_DARK := Color("#4399b5")
const TREE_TRUNK := Color("#78513f")
const TREE_TOP := Color("#4e9d61")
const TREE_LIGHT := Color("#72bf6e")
const FLOWER_PINK := Color("#f58fa6")
const FLOWER_YELLOW := Color("#ffe27a")
const MOB_SCRIPT = preload("res://mob.gd")
const TILESET_TEXTURE_PATH := "res://art/tilesets/fairy_tilesheet.png"
const TILE_SIZE: int = 32

const MOB_SPAWN_POINTS := [
	Vector2(145, 326), Vector2(318, 170), Vector2(492, 235),
	Vector2(705, 190), Vector2(905, 380), Vector2(785, 525),
	Vector2(1010, 520), Vector2(1008, 145)
]

const MAX_MOBS: int = -1
var mob_spawn_timer: float = 5.0
var mob_spawn_index: int = 0
var coins: int = 0
var upgrade_levels: Array[int] = [0, 0, 0]
var coin_label: Label
var upgrade_buttons: Array[Button] = []
var combat_log_button: Button
var combat_log_panel: PanelContainer
var combat_log_text: TextEdit
var tile_map_layer: TileMapLayer
var use_tilemap_background: bool = true

func _ready() -> void:
	_create_tilemap()
	_create_hud()
	_connect_combat_log()
	queue_redraw()

func _process(delta: float) -> void:
	mob_spawn_timer -= delta
	if mob_spawn_timer <= 0.0 and (MAX_MOBS < 0 or get_tree().get_nodes_in_group("mobs").size() < MAX_MOBS):
		_spawn_mob()
		mob_spawn_timer = 5.0

func add_coin(amount: int) -> void:
	coins += amount
	_refresh_hud()

func _create_tilemap() -> void:
	var tileset_image: Image = Image.load_from_file(ProjectSettings.globalize_path(TILESET_TEXTURE_PATH))
	if tileset_image == null or tileset_image.is_empty():
		return
	var tileset_texture: ImageTexture = ImageTexture.create_from_image(tileset_image)
	if tileset_texture == null:
		return

	tile_map_layer = TileMapLayer.new()
	tile_map_layer.name = "FairyTileMap"

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = tileset_texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for y in range(8):
		for x in range(8):
			atlas.create_tile(Vector2i(x, y))
	tile_set.add_source(atlas, 0)
	tile_map_layer.tile_set = tile_set
	add_child(tile_map_layer)
	_paint_tilemap_demo()

func _paint_tilemap_demo() -> void:
	var grass_tiles: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1)
	]
	for y in range(-6, 27):
		for x in range(-10, 46):
			var variant_index: int = abs(x * 17 + y * 11) % grass_tiles.size()
			tile_map_layer.set_cell(Vector2i(x, y), 0, grass_tiles[variant_index])

	# Prosty staw z kafelków wody.
	for y in range(3, 7):
		for x in range(4, 10):
			tile_map_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 4))

	# Główna droga i odchodząca od niej odnoga.
	for x in range(1, 35):
		tile_map_layer.set_cell(Vector2i(x, 14), 0, Vector2i(1, 2))
	for y in range(8, 15):
		tile_map_layer.set_cell(Vector2i(18, y), 0, Vector2i(3, 2))
	tile_map_layer.set_cell(Vector2i(18, 14), 0, Vector2i(6, 2))

	# Drzewa są na razie pojedynczymi kafelkami dekoracyjnymi.
	var tree_positions: Array[Vector2i] = [
		Vector2i(2, 1), Vector2i(9, 1), Vector2i(16, 1), Vector2i(27, 1),
		Vector2i(33, 2), Vector2i(2, 17), Vector2i(10, 18), Vector2i(29, 17),
		Vector2i(34, 7)
	]
	var tree_tiles: Array[Vector2i] = [
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
		Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6)
	]
	for index in range(tree_positions.size()):
		tile_map_layer.set_cell(tree_positions[index], 0, tree_tiles[index % tree_tiles.size()])

func _create_hud() -> void:
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)

	var hud_root: Control = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_layer.add_child(hud_root)

	var coin_panel: PanelContainer = PanelContainer.new()
	coin_panel.position = Vector2(20, 18)
	coin_panel.custom_minimum_size = Vector2(190, 52)
	coin_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#fff0bf"), Color("#9b6745")))
	hud_root.add_child(coin_panel)

	coin_label = Label.new()
	coin_label.text = "Monety: 0"
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_label.add_theme_font_size_override("font_size", 22)
	coin_label.add_theme_color_override("font_color", Color("#684534"))
	coin_panel.add_child(coin_label)

	var bottom_panel: PanelContainer = PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 28.0
	bottom_panel.offset_top = -112.0
	bottom_panel.offset_right = -28.0
	bottom_panel.offset_bottom = -18.0
	bottom_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.16, 0.22, 0.29, 0.92), Color("#d2ae68")))
	hud_root.add_child(bottom_panel)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_panel.add_child(button_row)

	var button_colors: Array[Color] = [Color("#d87a72"), Color("#6f9bd4"), Color("#76bd79")]
	var button_names: Array[String] = ["Atak", "Obrona", "HP"]
	for index in range(3):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("#fff9e8"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _make_button_style(button_colors[index], Color("#f3d98d")))
		button.add_theme_stylebox_override("hover", _make_button_style(button_colors[index].lightened(0.12), Color.WHITE))
		button.add_theme_stylebox_override("pressed", _make_button_style(button_colors[index].darkened(0.12), Color("#f3d98d")))
		button.add_theme_stylebox_override("disabled", _make_button_style(Color("#65707a"), Color("#89919a")))
		button.tooltip_text = "Ulepsz " + button_names[index] + " bez limitu poziomu"
		button.pressed.connect(_on_upgrade_pressed.bind(index))
		button_row.add_child(button)
		upgrade_buttons.append(button)

	_create_combat_log_ui(hud_root)
	_refresh_hud()

func _create_combat_log_ui(hud_root: Control) -> void:
	if not _debug_mode_enabled():
		return

	combat_log_button = Button.new()
	combat_log_button.text = "Combat log"
	combat_log_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	combat_log_button.offset_left = -180.0
	combat_log_button.offset_top = 18.0
	combat_log_button.offset_right = -20.0
	combat_log_button.offset_bottom = 58.0
	combat_log_button.add_theme_font_size_override("font_size", 16)
	combat_log_button.add_theme_color_override("font_color", Color("#fff9e8"))
	combat_log_button.add_theme_stylebox_override("normal", _make_button_style(Color("#6e789c"), Color("#d2ae68")))
	combat_log_button.add_theme_stylebox_override("hover", _make_button_style(Color("#8793bd"), Color.WHITE))
	combat_log_button.add_theme_stylebox_override("pressed", _make_button_style(Color("#515b7e"), Color("#d2ae68")))
	combat_log_button.pressed.connect(_toggle_combat_log)
	hud_root.add_child(combat_log_button)

	combat_log_panel = PanelContainer.new()
	combat_log_panel.name = "CombatLogPopup"
	combat_log_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	combat_log_panel.offset_left = -430.0
	combat_log_panel.offset_top = 72.0
	combat_log_panel.offset_right = -20.0
	combat_log_panel.offset_bottom = 610.0
	combat_log_panel.visible = false
	combat_log_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.16, 0.22, 0.97), Color("#d2ae68")))
	hud_root.add_child(combat_log_panel)

	var panel_content: VBoxContainer = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 8)
	combat_log_panel.add_child(panel_content)

	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 36.0)
	panel_content.add_child(header)

	var title: Label = Label.new()
	title.text = "Combat log"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#fff9e8"))
	header.add_child(title)

	var close_button: Button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(36.0, 32.0)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(_close_combat_log)
	header.add_child(close_button)

	combat_log_text = TextEdit.new()
	combat_log_text.custom_minimum_size = Vector2(380.0, 470.0)
	combat_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log_text.editable = false
	combat_log_text.placeholder_text = "Brak wpisów."
	combat_log_text.add_theme_font_size_override("font_size", 15)
	combat_log_text.add_theme_color_override("font_color", Color("#fff9e8"))
	combat_log_text.add_theme_color_override("font_readonly_color", Color("#fff9e8"))
	panel_content.add_child(combat_log_text)

func _connect_combat_log() -> void:
	var combat_system: Node = get_node_or_null("/root/CombatSystem")
	if combat_system != null and combat_system.has_signal("combat_log_entry"):
		combat_system.connect("combat_log_entry", Callable(self, "_on_combat_log_entry"))

func _toggle_combat_log() -> void:
	if is_instance_valid(combat_log_panel):
		combat_log_panel.visible = not combat_log_panel.visible

func _close_combat_log() -> void:
	if is_instance_valid(combat_log_panel):
		combat_log_panel.visible = false

func _on_combat_log_entry(frame_number: int, lines: Array) -> void:
	if not _debug_mode_enabled() or not is_instance_valid(combat_log_text):
		return

	var entry_lines: PackedStringArray = PackedStringArray(["klatka nr %d:" % frame_number])
	for line in lines:
		entry_lines.append(str(line))
	var entry: String = "\n".join(entry_lines)
	if not combat_log_text.text.is_empty():
		combat_log_text.text += "\n\n"
	combat_log_text.text += entry
	combat_log_text.set_deferred("scroll_vertical", 999999)

func _refresh_hud() -> void:
	if not is_instance_valid(coin_label):
		return
	coin_label.text = "Monety: %d" % coins
	var button_names: Array[String] = ["Atak", "Obrona", "HP"]
	for index in range(upgrade_buttons.size()):
		var level: int = upgrade_levels[index]
		var cost: int = level + 1
		upgrade_buttons[index].text = "%s +1\nPoziom %d | Koszt: %d" % [button_names[index], level, cost]
		upgrade_buttons[index].disabled = coins < cost

func _on_upgrade_pressed(index: int) -> void:
	var cost: int = upgrade_levels[index] + 1
	if coins < cost:
		return

	coins -= cost
	upgrade_levels[index] += 1
	var knight: Node = get_node("Knight")
	match index:
		0:
			knight.set("attack", int(knight.get("attack")) + 1)
		1:
			var new_defense: int = int(knight.get("defense")) + 1
			knight.set("defense", new_defense)
			knight.set("current_defense", new_defense)
		2:
			knight.set("max_hp", int(knight.get("max_hp")) + 1)
			knight.set("hp", mini(int(knight.get("hp")) + 1, int(knight.get("max_hp"))))
	if knight.has_method("queue_redraw"):
		knight.queue_redraw()
	_refresh_hud()

func _debug_mode_enabled() -> bool:
	var globals_node: Node = get_node_or_null("/root/Globals")
	return globals_node != null and int(globals_node.get("debug_mode")) == 1

func _make_panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _spawn_mob() -> void:
	var mob: Node2D = Node2D.new()
	mob.set_script(MOB_SCRIPT)
	mob.name = "Mob_%02d" % (mob_spawn_index + 1)
	mob.position = MOB_SPAWN_POINTS[mob_spawn_index % MOB_SPAWN_POINTS.size()]
	mob.z_index = 8
	add_child(mob)
	mob_spawn_index += 1

func _draw() -> void:
	if use_tilemap_background and is_instance_valid(tile_map_layer):
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var scale_factor: float = min(viewport_size.x / MAP_SIZE.x, viewport_size.y / MAP_SIZE.y)
	var offset: Vector2 = (viewport_size - MAP_SIZE * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2(scale_factor, scale_factor))

	# Tło i delikatny wzór trawy.
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), GRASS)
	for y in range(24, 648, 34):
		for x in range(22, 1152, 38):
			var wobble := sin(float(x * 13 + y * 7)) * 2.0
			draw_line(Vector2(x, y), Vector2(x + wobble, y - 5), Color("#7fc572"), 1.5)

	# Główna ścieżka prowadząca przez całą polanę.
	var path_points := PackedVector2Array([
		Vector2(-30, 505), Vector2(180, 478), Vector2(340, 505),
		Vector2(505, 465), Vector2(680, 420), Vector2(825, 330),
		Vector2(1000, 294), Vector2(1180, 320)
	])
	draw_polyline(path_points, PATH_EDGE, 92.0, true)
	draw_polyline(path_points, PATH, 78.0, true)

	# Mały staw w lewym górnym rogu.
	_draw_oval(Vector2(202, 171), Vector2(142, 77), Color("#518d6d"))
	_draw_oval(Vector2(202, 163), Vector2(137, 72), WATER_DARK)
	_draw_oval(Vector2(202, 158), Vector2(126, 62), WATER)
	draw_arc(Vector2(172, 148), 28.0, 0.2, 2.0, 24, Color("#a2e7e1"), 3.0)
	draw_arc(Vector2(239, 173), 22.0, 3.2, 5.7, 20, Color("#a2e7e1"), 3.0)

	# Drewniany mostek nad odnogą ścieżki.
	draw_rect(Rect2(354, 460, 104, 46), Color("#8c6244"), true)
	for x in range(362, 454, 18):
		draw_line(Vector2(x, 462), Vector2(x, 505), Color("#b98555"), 5.0)
	draw_line(Vector2(350, 458), Vector2(462, 458), Color("#684534"), 6.0)
	draw_line(Vector2(350, 508), Vector2(462, 508), Color("#684534"), 6.0)

	# Ozdobne wysepki i kamienie.
	_draw_rock(Vector2(82, 394), 0.9)
	_draw_rock(Vector2(935, 484), 0.7)
	_draw_rock(Vector2(1080, 168), 0.8)
	_draw_rock(Vector2(760, 542), 0.6)

	# Drzewa tworzące ramę mapy.
	for tree in [
		Vector2(72, 110), Vector2(332, 88), Vector2(535, 115), Vector2(774, 92),
		Vector2(1054, 92), Vector2(1110, 418), Vector2(1005, 570), Vector2(170, 585),
		Vector2(46, 266)
	]:
		_draw_tree(tree, 0.88 + fmod(tree.x, 23.0) / 100.0)

	# Krzaki i kwiaty w pobliżu drogi.
	for bush in [Vector2(290, 247), Vector2(430, 285), Vector2(892, 210), Vector2(630, 560), Vector2(520, 195)]:
		_draw_bush(bush)

	for flower in [
		Vector2(118, 202), Vector2(284, 377), Vector2(474, 351), Vector2(575, 525),
		Vector2(730, 267), Vector2(879, 395), Vector2(1010, 358), Vector2(1090, 535),
		Vector2(260, 560), Vector2(620, 142)
	]:
		_draw_flower(flower)

	# Szyld z nazwą lokacji.
	draw_line(Vector2(910, 278), Vector2(910, 218), Color("#684534"), 6.0)
	draw_rect(Rect2(850, 190, 121, 42), Color("#9b6745"), true)
	draw_rect(Rect2(856, 196, 109, 30), Color("#edca82"), true)
	draw_string(ThemeDB.fallback_font, Vector2(864, 217), "Bajkowa Polana", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#684534"))

func _draw_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		var angle := TAU * float(i) / 48.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _draw_tree(position: Vector2, tree_scale: float) -> void:
	_draw_oval(position + Vector2(0, 27) * tree_scale, Vector2(34, 12) * tree_scale, Color(0.22, 0.38, 0.24, 0.18))
	draw_rect(Rect2(position + Vector2(-8, 9) * tree_scale, Vector2(16, 44) * tree_scale), TREE_TRUNK, true)
	_draw_oval(position + Vector2(-16, -5) * tree_scale, Vector2(33, 28) * tree_scale, TREE_TOP)
	_draw_oval(position + Vector2(15, -8) * tree_scale, Vector2(33, 31) * tree_scale, TREE_LIGHT)
	_draw_oval(position + Vector2(0, -29) * tree_scale, Vector2(31, 27) * tree_scale, TREE_TOP)
	draw_circle(position + Vector2(-12, -20) * tree_scale, 7.0 * tree_scale, Color("#94d77b"))

func _draw_bush(position: Vector2) -> void:
	_draw_oval(position + Vector2(0, 9), Vector2(39, 13), Color(0.22, 0.38, 0.24, 0.16))
	draw_circle(position + Vector2(-23, 0), 18.0, Color("#5aab65"))
	draw_circle(position + Vector2(0, -9), 23.0, Color("#6fbd6e"))
	draw_circle(position + Vector2(24, 1), 18.0, Color("#4f9d5d"))
	draw_circle(position + Vector2(-5, -16), 6.0, Color("#a0dc7f"))

func _draw_flower(position: Vector2) -> void:
	draw_line(position + Vector2(0, 3), position + Vector2(0, 15), Color("#4e9254"), 2.0)
	var petal_color := FLOWER_PINK if int(position.x) % 2 == 0 else FLOWER_YELLOW
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		draw_circle(position + Vector2(cos(angle), sin(angle)) * 5.0, 3.5, petal_color)
	draw_circle(position, 2.5, Color("#f8a943"))

func _draw_rock(position: Vector2, rock_scale: float) -> void:
	var points := PackedVector2Array([
		position + Vector2(-22, 8) * rock_scale,
		position + Vector2(-13, -12) * rock_scale,
		position + Vector2(8, -16) * rock_scale,
		position + Vector2(23, 4) * rock_scale,
		position + Vector2(12, 15) * rock_scale,
		position + Vector2(-12, 17) * rock_scale
	])
	draw_colored_polygon(points, Color("#8e9b9a"))
	draw_polyline(PackedVector2Array([points[1], points[2], points[3]]), Color("#b7c0b5"), 3.0, true)
