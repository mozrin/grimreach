extends Node3D

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")
const PORT := 7777
const MOVE_INTERVAL := 0.1
const JOYSTICK_RADIUS := 78.0

var connection := StreamPeerTCP.new()
var connected := false
var sent_hello := false
var incoming := ""
var own_id := ""
var avatars := {}
var camera_yaw := 0.0
var input_elapsed := 0.0
var animation_elapsed := 0.0
var move_touch_index := -1
var move_touch_origin := Vector2.ZERO
var move_touch_offset := Vector2.ZERO

var camera: Camera3D
var terrain
var joystick_visual: Node2D
var status_label: Label
var host_edit: LineEdit


func _ready() -> void:
	_build_world()
	_build_interface()
	_build_avatar("preview", Color(0.95, 0.68, 0.29))
	_update_status("Disconnected — enter a server address")
	_connect_to_server()


func _process(delta: float) -> void:
	animation_elapsed += delta
	_poll_connection()
	_animate_avatars()
	if Input.is_key_pressed(KEY_Q):
		camera_yaw += delta * 1.8
	if Input.is_key_pressed(KEY_E):
		camera_yaw -= delta * 1.8
	var target := Vector3.ZERO
	if own_id != "" and avatars.has(own_id):
		target = avatars[own_id].position
	terrain.update_around(target)
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
	var state := connection.get_status()
	if state == StreamPeerTCP.STATUS_CONNECTED and not sent_hello:
		sent_hello = true
		connected = true
		_send({"type": "hello", "role": "player"})
		_update_status("Connected — waiting for world state")
	elif state == StreamPeerTCP.STATUS_ERROR or (sent_hello and state == StreamPeerTCP.STATUS_NONE):
		connected = false
		sent_hello = false
		own_id = ""
		move_touch_index = -1
		move_touch_offset = Vector2.ZERO
		joystick_visual.queue_redraw()
		_update_status("Connection lost")
	if state != StreamPeerTCP.STATUS_CONNECTED:
		return
	var count := connection.get_available_bytes()
	if count <= 0:
		return
	var result := connection.get_data(count)
	if result[0] != OK:
		return
	incoming += result[1].get_string_from_utf8()
	while incoming.contains("\n"):
		var end := incoming.find("\n")
		var line := incoming.substr(0, end)
		incoming = incoming.substr(end + 1)
		var value = JSON.parse_string(line)
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
				var travel := Vector2(x - avatar.position.x, z - avatar.position.z)
				avatar.set_meta("walking", travel.length() > 0.02)
				if travel.length() > 0.02:
					avatar.rotation.y = atan2(travel.x, travel.y)
				avatar.position = Vector3(x, terrain.height_at(x, z), z)
			for id in avatars.keys():
				if not seen.has(id):
					avatars[id].queue_free()
					avatars.erase(id)


func _send_input() -> void:
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


func _send(value: Dictionary) -> void:
	if connection.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		connection.put_data((JSON.stringify(value) + "\n").to_utf8_buffer())


func _connect_to_server() -> void:
	if connected:
		connection.disconnect_from_host()
	connected = false
	sent_hello = false
	incoming = ""
	var host := host_edit.text.strip_edges()
	if host == "":
		_update_status("Enter a server address")
		return
	var error := connection.connect_to_host(host, PORT)
	_update_status("Connecting to %s…" % host if error == OK else "Connection failed: %s" % error_string(error))


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
	var avatar := Node3D.new()
	avatar.name = id
	add_child(avatar)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	_add_avatar_part(avatar, "torso", Vector3(0.7, 0.9, 0.42), Vector3(0, 1.05, 0), material)
	_add_avatar_part(avatar, "head", Vector3(0.48, 0.48, 0.48), Vector3(0, 1.75, 0), material)
	_add_avatar_part(avatar, "left_arm", Vector3(0.22, 0.78, 0.25), Vector3(-0.48, 1.0, 0), material)
	_add_avatar_part(avatar, "right_arm", Vector3(0.22, 0.78, 0.25), Vector3(0.48, 1.0, 0), material)
	_add_avatar_part(avatar, "left_leg", Vector3(0.25, 0.8, 0.3), Vector3(-0.2, 0.4, 0), material)
	_add_avatar_part(avatar, "right_leg", Vector3(0.25, 0.8, 0.3), Vector3(0.2, 0.4, 0), material)
	avatars[id] = avatar


func _add_avatar_part(avatar: Node3D, part_name: String, size: Vector3, placement: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = placement
	avatar.add_child(part)


func _animate_avatars() -> void:
	for avatar: Node3D in avatars.values():
		var stride := sin(animation_elapsed * 11.0) * 0.55 if avatar.get_meta("walking", false) else 0.0
		avatar.get_node("left_leg").rotation.x = stride
		avatar.get_node("right_leg").rotation.x = -stride
		avatar.get_node("left_arm").rotation.x = -stride
		avatar.get_node("right_arm").rotation.x = stride
		avatar.get_node("torso").position.y = 1.05 + abs(sin(animation_elapsed * 11.0)) * 0.06 if avatar.get_meta("walking", false) else 1.05


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
	host_edit = LineEdit.new()
	host_edit.text = "127.0.0.1"
	host_edit.placeholder_text = "Server IP"
	host_edit.custom_minimum_size.x = 190
	top.add_child(host_edit)
	var connect_button := Button.new()
	connect_button.text = "Connect"
	connect_button.pressed.connect(_connect_to_server)
	top.add_child(connect_button)
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
