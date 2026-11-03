extends Node3D

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")
const JOURNAL_SCRIPT = preload("res://exploration/journal.gd")
const EXPLORER_SCRIPT = preload("res://character/explorer.gd")
const SERVER_URL := "wss://grimreach.mozrin.com/play"
const MOVE_INTERVAL := 0.1
const RECONNECT_DELAY := 3.0
const JOYSTICK_RADIUS := 78.0

var connection := WebSocketPeer.new()
var connected := false
var connection_active := false
var sent_hello := false
var reconnect_elapsed := 0.0
var own_id := ""
var avatars := {}
var camera_yaw := 0.0
var input_elapsed := 0.0
var move_touch_index := -1
var move_touch_origin := Vector2.ZERO
var move_touch_offset := Vector2.ZERO

var camera: Camera3D
var terrain
var journal
var joystick_visual: Node2D
var status_label: Label


func _ready() -> void:
	_build_world()
	_build_interface()
	journal = JOURNAL_SCRIPT.new()
	journal.terrain = terrain
	journal.opened.connect(_stop_touch_movement)
	add_child(journal)
	_build_avatar("preview", Color(0.95, 0.68, 0.29))
	_update_status("Connecting to grimreach.mozrin.com…")
	_connect_to_server()


func _process(delta: float) -> void:
	_poll_connection()
	if not connection_active and not connected:
		reconnect_elapsed += delta
		if reconnect_elapsed >= RECONNECT_DELAY:
			_connect_to_server()
	for avatar in avatars.values():
		avatar.advance(delta)
	if Input.is_key_pressed(KEY_Q):
		camera_yaw += delta * 1.8
	if Input.is_key_pressed(KEY_E):
		camera_yaw -= delta * 1.8
	var target := Vector3.ZERO
	if own_id != "" and avatars.has(own_id):
		target = avatars[own_id].position
	terrain.update_around(target)
	journal.update_position(target)
	var offset := Vector3(sin(camera_yaw) * 11.0, 12.0, cos(camera_yaw) * 11.0)
	camera.position = target + offset
	camera.look_at(target + Vector3(0, 1.0, 0))
	if connected:
		input_elapsed += delta
		if input_elapsed >= MOVE_INTERVAL:
			input_elapsed = 0.0
			_send_input()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == move_touch_index:
		move_touch_index = -1
		move_touch_offset = Vector2.ZERO
		joystick_visual.queue_redraw()
		if connected:
			_send_input()
	if event is InputEventScreenDrag and event.index != move_touch_index:
		camera_yaw -= event.relative.x * 0.006
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.006


func _unhandled_input(event: InputEvent) -> void:
	if journal.is_open():
		return
	if event is InputEventScreenTouch and event.pressed and move_touch_index == -1:
		move_touch_index = event.index
		move_touch_origin = event.position
		move_touch_offset = Vector2.ZERO
		joystick_visual.queue_redraw()
	if event is InputEventScreenDrag and event.index == move_touch_index:
		move_touch_offset = (event.position - move_touch_origin).limit_length(JOYSTICK_RADIUS)
		joystick_visual.queue_redraw()


func _draw_joystick() -> void:
	if move_touch_index == -1:
		return
	joystick_visual.draw_circle(move_touch_origin, JOYSTICK_RADIUS, Color(1.0, 1.0, 1.0, 0.12))
	joystick_visual.draw_arc(move_touch_origin, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.5), 3.0, true)
	joystick_visual.draw_circle(move_touch_origin + move_touch_offset, 29.0, Color(1.0, 1.0, 1.0, 0.72))


func _poll_connection() -> void:
	connection.poll()
	var state := connection.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not sent_hello:
		sent_hello = true
		connected = true
		_send({"type": "hello", "role": "player"})
		_update_status("Connected — waiting for world state")
	elif state == WebSocketPeer.STATE_CLOSED and connection_active:
		connected = false
		connection_active = false
		sent_hello = false
		own_id = ""
		move_touch_index = -1
		move_touch_offset = Vector2.ZERO
		joystick_visual.queue_redraw()
		_update_status("Server unavailable — reconnecting…")
	if state != WebSocketPeer.STATE_OPEN:
		return
	while connection.get_available_packet_count() > 0:
		var value = JSON.parse_string(connection.get_packet().get_string_from_utf8())
		if value is Dictionary:
			_on_message(value)


func _on_message(value: Dictionary) -> void:
	match value.get("type", ""):
		"welcome":
			own_id = str(value.get("id", ""))
			if avatars.has("preview"):
				avatars["preview"].queue_free()
				avatars.erase("preview")
			_update_status("Connected as %s" % own_id)
		"snapshot":
			var seen := {}
			for item in value.get("players", []):
				var id := str(item.get("id", ""))
				if id == "":
					continue
				seen[id] = true
				if not avatars.has(id):
					_build_avatar(id, Color(0.95, 0.68, 0.29) if id == own_id else Color(0.3, 0.7, 0.95))
				var avatar: Node3D = avatars[id]
				var x := float(item.get("x", 0.0))
				var z := float(item.get("z", 0.0))
				avatar.accept_snapshot(Vector3(x, terrain.height_at(x, z), z))
			for id in avatars.keys():
				if not seen.has(id):
					avatars[id].queue_free()
					avatars.erase(id)


func _send_input() -> void:
	if journal.is_open():
		_send({"type": "input", "dx": 0.0, "dz": 0.0})
		return
	var horizontal := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var vertical := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	var forward := Vector2(-sin(camera_yaw), -cos(camera_yaw))
	var right := Vector2(cos(camera_yaw), -sin(camera_yaw))
	var direction := right * horizontal + forward * -vertical
	if move_touch_index != -1 and move_touch_offset.length() > 12.0:
		var stick := move_touch_offset / JOYSTICK_RADIUS
		direction += right * stick.x + forward * -stick.y
	direction = direction.limit_length(1.0)
	_send({"type": "input", "dx": direction.x, "dz": direction.y})


func _stop_touch_movement() -> void:
	move_touch_index = -1
	move_touch_offset = Vector2.ZERO
	joystick_visual.queue_redraw()
	if connected:
		_send_input()


func _send(value: Dictionary) -> void:
	if connection.get_ready_state() == WebSocketPeer.STATE_OPEN:
		connection.send_text(JSON.stringify(value) + "\n")


func _connect_to_server() -> void:
	connection = WebSocketPeer.new()
	connected = false
	connection_active = false
	sent_hello = false
	reconnect_elapsed = 0.0
	var url := OS.get_environment("GRIMREACH_SERVER_URL")
	if url == "":
		url = SERVER_URL
	var error := connection.connect_to_url(url)
	connection_active = error == OK
	_update_status("Connecting to Grimreach…" if error == OK else "Connection failed: %s" % error_string(error))


func _update_status(value: String) -> void:
	status_label.text = value


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.48, 0.67, 0.76)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75, 0.8, 0.9)
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65.0
	add_child(camera)
	terrain = TERRAIN_SCRIPT.new()
	add_child(terrain)


func _build_avatar(id: String, color: Color) -> void:
	var avatar = EXPLORER_SCRIPT.new()
	avatar.name = id
	add_child(avatar)
	avatar.configure(color)
	avatars[id] = avatar


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	joystick_visual = Node2D.new()
	joystick_visual.draw.connect(_draw_joystick)
	layer.add_child(joystick_visual)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_top = 16
	top.offset_right = -20
	top.offset_bottom = 72
	layer.add_child(top)
	var title := Label.new()
	title.text = "GRIMREACH"
	title.add_theme_font_size_override("font_size", 22)
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var server_label := Label.new()
	server_label.text = "grimreach.mozrin.com"
	server_label.add_theme_font_size_override("font_size", 19)
	top.add_child(server_label)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_label.offset_left = 20
	status_label.offset_top = 78
	status_label.offset_right = 700
	status_label.offset_bottom = 120
	status_label.add_theme_font_size_override("font_size", 19)
	layer.add_child(status_label)
	var hint := Label.new()
	hint.text = "Drag the world to move  •  release to stop"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20
	hint.offset_top = -42
	hint.offset_right = 700
	hint.offset_bottom = -10
	layer.add_child(hint)
