extends Node3D

var target_position := Vector3.ZERO
var target_yaw := 0.0
var has_snapshot := false
var moving := false
var gait_weight := 0.0
var gait_phase := 0.0

var body: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_elbow: Node3D
var right_elbow: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_knee: Node3D
var right_knee: Node3D
var head: Node3D


func configure(cloak_color: Color) -> void:
	var cloak := _material(cloak_color)
	var darker_cloak := _material(cloak_color.darkened(0.32))
	var shirt := _material(Color(0.31, 0.29, 0.25))
	var skin := _material(Color(0.76, 0.55, 0.40))
	var hair := _material(Color(0.18, 0.13, 0.10))
	var leather := _material(Color(0.25, 0.17, 0.12))
	var metal := _material(Color(0.76, 0.68, 0.42))
	var eye := _material(Color(0.09, 0.10, 0.10))

	body = Node3D.new()
	body.name = "body"
	add_child(body)
	_add_capsule(body, "torso", 0.42, 0.88, Vector3(0, 1.46, 0), cloak)
	_add_capsule(body, "chest", 0.36, 0.62, Vector3(0, 1.61, 0.09), shirt)
	_add_box(body, "belt", Vector3(0.77, 0.13, 0.51), Vector3(0, 1.10, 0), leather)
	_add_box(body, "buckle", Vector3(0.18, 0.12, 0.06), Vector3(0, 1.10, 0.29), metal)
	_add_capsule(body, "neck", 0.13, 0.25, Vector3(0, 1.96, 0), skin)

	head = Node3D.new()
	head.name = "head"
	head.position = Vector3(0, 2.14, 0)
	body.add_child(head)
	_add_sphere(head, "face", Vector3(0.31, 0.37, 0.30), Vector3.ZERO, skin)
	_add_sphere(head, "hair", Vector3(0.33, 0.18, 0.31), Vector3(0, 0.25, -0.025), hair)
	_add_sphere(head, "nose", Vector3(0.07, 0.10, 0.09), Vector3(0, -0.03, 0.32), skin)
	for side in [-1.0, 1.0]:
		_add_sphere(head, "eye_%s" % side, Vector3(0.045, 0.055, 0.025), Vector3(side * 0.12, 0.06, 0.29), eye)
	_add_box(head, "scarf", Vector3(0.64, 0.13, 0.43), Vector3(0, -0.31, 0), darker_cloak)

	left_arm = _make_arm(body, "left_arm", -1.0, cloak, skin, leather)
	right_arm = _make_arm(body, "right_arm", 1.0, cloak, skin, leather)
	left_elbow = left_arm.get_node("elbow")
	right_elbow = right_arm.get_node("elbow")
	left_leg = _make_leg(body, "left_leg", -1.0, darker_cloak, leather)
	right_leg = _make_leg(body, "right_leg", 1.0, darker_cloak, leather)
	left_knee = left_leg.get_node("knee")
	right_knee = right_leg.get_node("knee")


func accept_snapshot(world_position: Vector3) -> void:
	if not has_snapshot:
		position = world_position
		target_position = world_position
		has_snapshot = true
		return
	var travel := Vector2(world_position.x - target_position.x, world_position.z - target_position.z)
	moving = travel.length() > 0.025
	if moving:
		target_yaw = atan2(travel.x, travel.y)
	target_position = world_position


func advance(delta: float) -> void:
	if not has_snapshot:
		return
	var position_blend := 1.0 - exp(-delta * 12.0)
	position = position.lerp(target_position, position_blend)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-delta * 13.0))
	gait_weight = lerpf(gait_weight, 1.0 if moving else 0.0, 1.0 - exp(-delta * 9.0))
	if gait_weight < 0.005:
		gait_weight = 0.0
	gait_phase += delta * 9.2 * gait_weight
	var swing := sin(gait_phase) * gait_weight
	left_leg.rotation.x = swing * 0.55
	right_leg.rotation.x = -swing * 0.55
	left_knee.rotation.x = maxf(0.0, -swing) * 0.62
	right_knee.rotation.x = maxf(0.0, swing) * 0.62
	left_arm.rotation.x = -swing * 0.42
	right_arm.rotation.x = swing * 0.42
	left_elbow.rotation.x = -0.18 - maxf(0.0, swing) * 0.18
	right_elbow.rotation.x = -0.18 - maxf(0.0, -swing) * 0.18
	body.position.y = absf(sin(gait_phase)) * 0.075 * gait_weight
	body.rotation.z = sin(gait_phase) * 0.025 * gait_weight
	body.rotation.x = -0.035 * gait_weight
	head.rotation.z = -body.rotation.z * 0.5


func _make_arm(parent: Node3D, part_name: String, side: float, sleeve: Material, skin: Material, leather: Material) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.name = part_name
	shoulder.position = Vector3(side * 0.48, 1.79, 0)
	parent.add_child(shoulder)
	_add_capsule(shoulder, "upper", 0.16, 0.57, Vector3(side * 0.04, -0.30, 0), sleeve)
	var elbow := Node3D.new()
	elbow.name = "elbow"
	elbow.position = Vector3(side * 0.05, -0.57, 0)
	shoulder.add_child(elbow)
	_add_capsule(elbow, "forearm", 0.13, 0.50, Vector3(0, -0.27, 0), skin)
	_add_sphere(elbow, "hand", Vector3(0.15, 0.15, 0.13), Vector3(0, -0.56, 0), leather)
	return shoulder


func _make_leg(parent: Node3D, part_name: String, side: float, trouser: Material, boot: Material) -> Node3D:
	var hip := Node3D.new()
	hip.name = part_name
	hip.position = Vector3(side * 0.22, 1.06, 0)
	parent.add_child(hip)
	_add_capsule(hip, "thigh", 0.19, 0.68, Vector3(0, -0.34, 0), trouser)
	var knee := Node3D.new()
	knee.name = "knee"
	knee.position = Vector3(0, -0.68, 0)
	hip.add_child(knee)
	_add_capsule(knee, "shin", 0.16, 0.58, Vector3(0, -0.30, 0), trouser)
	_add_box(knee, "boot", Vector3(0.31, 0.25, 0.49), Vector3(0, -0.62, 0.10), boot)
	return hip


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material


func _add_capsule(parent: Node3D, part_name: String, radius: float, height: float, offset: Vector3, material: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_add_mesh(parent, part_name, mesh, offset, material)


func _add_sphere(parent: Node3D, part_name: String, scale_size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var part := _add_mesh(parent, part_name, mesh, offset, material)
	part.scale = scale_size


func _add_box(parent: Node3D, part_name: String, dimensions: Vector3, offset: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_add_mesh(parent, part_name, mesh, offset, material)


func _add_mesh(parent: Node3D, part_name: String, mesh: Mesh, offset: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = offset
	parent.add_child(part)
	return part
