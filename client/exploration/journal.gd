extends CanvasLayer

signal opened

var terrain: Node3D
var save_path := "user://exploration_journal.json"
var discovered: Dictionary = {}
var examined: Dictionary = {}
var dark_mode := true
var nearby: Dictionary = {}
var last_position := Vector3.ZERO

var journal_button: Button
var examine_button: Button
var nearby_label: Label
var overlay: Control
var backdrop: ColorRect
var title_label: Label
var content_label: Label
var theme_button: Button
var back_button: Button


func _ready() -> void:
	_load()
	_build_interface()
	_apply_theme()
	_refresh_button()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and overlay.visible:
			_close_view()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and not overlay.visible and not nearby.is_empty():
			_examine()
			get_viewport().set_input_as_handled()


func is_open() -> bool:
	return overlay.visible


func update_position(position: Vector3) -> void:
	last_position = position
	var discovery: Dictionary = terrain.nearest_site(position, 13.0)
	if not discovery.is_empty() and not discovered.has(discovery.id):
		discovered[discovery.id] = {
			"name": discovery.name,
			"kind": discovery.kind,
			"x": discovery.position.x,
			"z": discovery.position.z,
		}
		_save()
		_refresh_button()
	nearby = terrain.nearest_site(position, 5.5)
	examine_button.visible = not nearby.is_empty() and not overlay.visible
	nearby_label.visible = not nearby.is_empty() and not overlay.visible
	if not nearby.is_empty():
		nearby_label.text = nearby.name


func _load() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		discovered = parsed.get("discovered", {})
		examined = parsed.get("examined", {})
		dark_mode = parsed.get("dark_mode", true)


func _save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save exploration journal")
		return
	file.store_string(JSON.stringify({"discovered": discovered, "examined": examined, "dark_mode": dark_mode}))
	file.close()


func _build_interface() -> void:
	journal_button = Button.new()
	journal_button.text = "Journal"
	journal_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	journal_button.offset_left = 20
	journal_button.offset_top = 132
	journal_button.offset_right = 210
	journal_button.offset_bottom = 194
	journal_button.add_theme_font_size_override("font_size", 25)
	journal_button.pressed.connect(_show_journal)
	add_child(journal_button)

	nearby_label = Label.new()
	nearby_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nearby_label.offset_left = 24
	nearby_label.offset_top = -235
	nearby_label.offset_right = -24
	nearby_label.offset_bottom = -190
	nearby_label.add_theme_font_size_override("font_size", 27)
	nearby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nearby_label.visible = false
	add_child(nearby_label)

	examine_button = Button.new()
	examine_button.text = "Examine"
	examine_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	examine_button.offset_left = -220
	examine_button.offset_top = -182
	examine_button.offset_right = -20
	examine_button.offset_bottom = -112
	examine_button.add_theme_font_size_override("font_size", 27)
	examine_button.visible = false
	examine_button.pressed.connect(_examine)
	add_child(examine_button)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)
	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_top", 36)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_bottom", 36)
	overlay.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margins.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	column.add_child(header)
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(145, 70)
	back_button.add_theme_font_size_override("font_size", 26)
	back_button.pressed.connect(_close_view)
	header.add_child(back_button)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 31)
	header.add_child(title_label)
	theme_button = Button.new()
	theme_button.custom_minimum_size = Vector2(115, 70)
	theme_button.add_theme_font_size_override("font_size", 22)
	theme_button.pressed.connect(_toggle_theme)
	header.add_child(theme_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	content_label = Label.new()
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.add_theme_font_size_override("font_size", 27)
	scroll.add_child(content_label)


func _show_journal() -> void:
	var lines := ["Follow the sandy routes. Three old places lie near the starting meadow.", "", "Places found: %d  ·  Findings: %d" % [discovered.size(), examined.size()], ""]
	for key in [Vector2i.ZERO, Vector2i(-1, -1), Vector2i(0, -1)]:
		if terrain.sites.has(key):
			var site: Dictionary = terrain.sites[key]
			var state := "Found" if discovered.has(site.id) else "Unexplored"
			lines.append("%s  ·  %s  ·  %s" % [site.name, state, _bearing_to(site.position)])
	var next_lead := {}
	var next_distance := INF
	for site in terrain.sites.values():
		if discovered.has(site.id):
			continue
		var distance: float = last_position.distance_to(site.position)
		if distance < next_distance:
			next_distance = distance
			next_lead = site
	if not next_lead.is_empty():
		lines.append("\nNearest new place: %s  ·  %s" % [next_lead.name, _bearing_to(next_lead.position)])
	lines.append("")
	var ids := discovered.keys()
	ids.sort()
	for id in ids:
		var record: Dictionary = discovered[id]
		var state := "Examined" if examined.has(id) else "Go closer to examine"
		lines.append("%s  (%d, %d)\n%s\n" % [record.name, int(record.x), int(record.z), state])
	lines.append("\nTap Examine when close to a site. On Ubuntu, press F.")
	_open_view("Exploration Journal", "\n".join(lines))


func _bearing_to(destination: Vector3) -> String:
	var offset := Vector2(destination.x - last_position.x, destination.z - last_position.z)
	var vertical := "north" if offset.y < -5.0 else ("south" if offset.y > 5.0 else "")
	var horizontal := "east" if offset.x > 5.0 else ("west" if offset.x < -5.0 else "")
	var direction := vertical + horizontal
	if direction == "":
		direction = "here"
	return "%dm %s" % [roundi(offset.length()), direction]


func _examine() -> void:
	if nearby.is_empty():
		return
	var first_visit := not examined.has(nearby.id)
	examined[nearby.id] = true
	_save()
	var finding := "New finding recorded.\n\n" if first_visit else "You have studied this place before.\n\n"
	_open_view(nearby.name, finding + _lore(nearby.kind))


func _lore(kind: String) -> String:
	match kind:
		"ruin":
			return "A spiral is carved beneath the fallen arch. Fresh petals rest on the old stone, though no traveler is in sight."
		"camp":
			return "The fire is warm. A weathered travel map points toward another road beyond the hills."
		"shrine":
			return "The blue crystal hums softly. Its base marks the night sky as it appeared before the roads were built."
	return "There is more to learn here."


func _open_view(title: String, content: String) -> void:
	title_label.text = title
	content_label.text = content
	overlay.visible = true
	examine_button.visible = false
	nearby_label.visible = false
	opened.emit()


func _close_view() -> void:
	overlay.visible = false
	examine_button.visible = not nearby.is_empty()
	nearby_label.visible = not nearby.is_empty()


func _toggle_theme() -> void:
	dark_mode = not dark_mode
	_apply_theme()
	_save()


func _apply_theme() -> void:
	backdrop.color = Color(0.07, 0.11, 0.14, 0.98) if dark_mode else Color(0.95, 0.93, 0.86, 0.98)
	var text_color := Color(0.94, 0.95, 0.89) if dark_mode else Color(0.15, 0.20, 0.18)
	var button_color := Color(0.13, 0.19, 0.22) if dark_mode else Color(0.82, 0.84, 0.78)
	title_label.add_theme_color_override("font_color", text_color)
	content_label.add_theme_color_override("font_color", text_color)
	for button in [back_button, theme_button]:
		var style := StyleBoxFlat.new()
		style.bg_color = button_color
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", text_color)
	theme_button.text = "Light" if dark_mode else "Dark"


func _refresh_button() -> void:
	journal_button.text = "Journal (%d)" % discovered.size()
