extends Node3D

const PORT := 7777
const MOVE_INTERVAL := 0.1

var connection := StreamPeerTCP.new()
var connected := false
var sent_hello := false
var incoming := ""
var own_id := ""
var avatars := {}
var held := {}
var camera_yaw := 0.0
var input_elapsed := 0.0

var camera: Camera3D
var status_label: Label
var host_edit: LineEdit


func _ready() -> void:
	_build_world()
	_build_interface()
	_build_avatar("preview", Color(0.95, 0.68, 0.29))
	_update_status("Disconnected — enter a server address")
	_connect_to_server()


func _process(delta: float) -> void:
	_poll_connection()
	if Input.is_key_pressed(KEY_Q):
		camera_yaw += delta * 1.8
	if Input.is_key_pressed(KEY_E):
		camera_yaw -= delta * 1.8
	var target := Vector3.ZERO
	if own_id != "" and avatars.has(own_id):
		target = avatars[own_id].position
	var offset := Vector3(sin(camera_yaw) * 7.0, 5.0, cos(camera_yaw) * 7.0)
	camera.position = target + offset
	camera.look_at(target + Vector3(0, 1.0, 0))
	if connected:
		input_elapsed += delta
		if input_elapsed >= MOVE_INTERVAL:
			input_elapsed = 0.0
			_send_input()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.52:
			camera_yaw -= event.relative.x * 0.006
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.006


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
				avatar.position = Vector3(float(item.get("x", 0.0)), 0.0, float(item.get("z", 0.0)))
			for id in avatars.keys():
				if not seen.has(id):
					avatars[id].queue_free()
					avatars.erase(id)


func _send_input() -> void:
	var horizontal := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var vertical := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	horizontal += float(held.get("right", false)) - float(held.get("left", false))
	vertical += float(held.get("back", false)) - float(held.get("forward", false))
	var forward := Vector2(-sin(camera_yaw), -cos(camera_yaw))
	var right := Vector2(cos(camera_yaw), -sin(camera_yaw))
	var direction := (right * horizontal + forward * -vertical).limit_length(1.0)
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


func _set_touch(action: String, pressed: bool) -> void:
	held[action] = pressed


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
	_box("grassland", Vector3(0, -0.15, 0), Vector3(100, 0.3, 100), Color(0.33, 0.52, 0.31))
	_box("village path", Vector3(0, 0.02, 0), Vector3(4, 0.04, 40), Color(0.55, 0.45, 0.32))
	_box("cross path", Vector3(0, 0.02, -10), Vector3(35, 0.04, 3), Color(0.55, 0.45, 0.32))
	for x in [-15.0, -9.0, 9.0, 15.0]:
		for z in [-18.0, -10.0, 8.0, 17.0]:
			_tree(Vector3(x, 0, z))
	for x in [-11.0, 11.0]:
		_box("cottage", Vector3(x, 1.2, -4), Vector3(4, 2.4, 4), Color(0.68, 0.54, 0.38))
		_box("roof", Vector3(x, 2.7, -4), Vector3(4.6, 0.7, 4.6), Color(0.3, 0.29, 0.35))
	_box("town marker", Vector3(0, 1.2, -17), Vector3(0.4, 2.4, 0.4), Color(0.8, 0.69, 0.44))
	_box("town banner", Vector3(0.7, 2.1, -17), Vector3(1.5, 0.7, 0.08), Color(0.7, 0.19, 0.21))


func _tree(at: Vector3) -> void:
	_box("trunk", at + Vector3(0, 1, 0), Vector3(0.55, 2, 0.55), Color(0.38, 0.27, 0.17))
	_box("canopy", at + Vector3(0, 2.8, 0), Vector3(2.2, 2.1, 2.2), Color(0.2, 0.4, 0.25))


func _box(label: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)


func _build_avatar(id: String, color: Color) -> void:
	var avatar := Node3D.new()
	avatar.name = id
	add_child(avatar)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.6
	body.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	body.material_override = material
	body.position.y = 0.8
	avatar.add_child(body)
	avatars[id] = avatar


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_top = 16
	top.offset_right = -20
	top.offset_bottom = 72
	layer.add_child(top)
	var title := Label.new()
	title.text = "GRIMREACH  •  WORLD PROOF OF CONCEPT"
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
	hint.text = "WASD / arrows to move  •  Q/E or right drag to turn camera"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20
	hint.offset_top = -42
	hint.offset_right = 700
	hint.offset_bottom = -10
	layer.add_child(hint)
	_touch_button(layer, "▲", "forward", Vector2(92, -192))
	_touch_button(layer, "◀", "left", Vector2(20, -120))
	_touch_button(layer, "▼", "back", Vector2(92, -120))
	_touch_button(layer, "▶", "right", Vector2(164, -120))


func _touch_button(layer: CanvasLayer, label: String, action: String, at: Vector2) -> void:
	var button := Button.new()
	button.text = label
	button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	button.offset_left = at.x
	button.offset_top = at.y
	button.offset_right = at.x + 66
	button.offset_bottom = at.y + 66
	button.button_down.connect(_set_touch.bind(action, true))
	button.button_up.connect(_set_touch.bind(action, false))
	layer.add_child(button)
