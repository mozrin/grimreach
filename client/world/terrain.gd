extends Node3D

const CHUNK_SIZE := 48
const GRID_STEPS := 12
const VIEW_RADIUS := 2
const WORLD_SEED := 76341

var elevation := FastNoiseLite.new()
var climate := FastNoiseLite.new()
var chunks := {}
var center_chunk := Vector2i(2147483647, 2147483647)
var terrain_material := StandardMaterial3D.new()
var trunk_material := StandardMaterial3D.new()
var leaf_material := StandardMaterial3D.new()
var stone_material := StandardMaterial3D.new()
var flower_material := StandardMaterial3D.new()
var grass_material := StandardMaterial3D.new()


func _ready() -> void:
	elevation.seed = WORLD_SEED
	elevation.frequency = 0.013
	elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation.fractal_octaves = 3
	climate.seed = WORLD_SEED + 117
	climate.frequency = 0.0025
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
	trunk_material.albedo_color = Color(0.30, 0.22, 0.15)
	leaf_material.albedo_color = Color(0.19, 0.43, 0.25)
	stone_material.albedo_color = Color(0.48, 0.50, 0.48)
	flower_material.albedo_color = Color(0.92, 0.54, 0.69)
	grass_material.albedo_color = Color(0.45, 0.70, 0.35)
	update_around(Vector3.ZERO)


func height_at(x: float, z: float) -> float:
	return elevation.get_noise_2d(x, z) * 2.8


func update_around(world_position: Vector3) -> void:
	var next_center := Vector2i(floori(world_position.x / CHUNK_SIZE), floori(world_position.z / CHUNK_SIZE))
	if next_center == center_chunk:
		return
	center_chunk = next_center
	for key in chunks.keys():
		if abs(key.x - center_chunk.x) > VIEW_RADIUS or abs(key.y - center_chunk.y) > VIEW_RADIUS:
			chunks[key].queue_free()
			chunks.erase(key)
	for z in range(center_chunk.y - VIEW_RADIUS, center_chunk.y + VIEW_RADIUS + 1):
		for x in range(center_chunk.x - VIEW_RADIUS, center_chunk.x + VIEW_RADIUS + 1):
			var key := Vector2i(x, z)
			if not chunks.has(key):
				chunks[key] = _create_chunk(key)


func _create_chunk(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "region_%d_%d" % [key.x, key.y]
	add_child(root)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := float(CHUNK_SIZE) / GRID_STEPS
	for z_step in range(GRID_STEPS):
		for x_step in range(GRID_STEPS):
			var x := key.x * CHUNK_SIZE + x_step * step
			var z := key.y * CHUNK_SIZE + z_step * step
			var a := Vector3(x, height_at(x, z), z)
			var b := Vector3(x + step, height_at(x + step, z), z)
			var c := Vector3(x, height_at(x, z + step), z + step)
			var d := Vector3(x + step, height_at(x + step, z + step), z + step)
			_add_vertex(surface, a)
			_add_vertex(surface, b)
			_add_vertex(surface, c)
			_add_vertex(surface, b)
			_add_vertex(surface, d)
			_add_vertex(surface, c)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "terrain_%d_%d" % [key.x, key.y]
	instance.mesh = surface.commit()
	instance.material_override = terrain_material
	root.add_child(instance)
	_populate_chunk(root, key)
	return root


func _populate_chunk(root: Node3D, key: Vector2i) -> void:
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	for cell_z in range(12):
		for cell_x in range(12):
			var grid_x := key.x * 12 + cell_x
			var grid_z := key.y * 12 + cell_z
			var x := grid_x * 4.0 + 2.0
			var z := grid_z * 4.0 + 2.0
			if Vector2(x, z).length() < 7.0:
				continue
			var place := Vector3(x, height_at(x, z), z)
			var moisture := climate.get_noise_2d(x, z)
			var tree_limit := 15 if moisture > 0.1 else 7
			var choice := _hash(grid_x, grid_z, 11) % 100
			for tuft in range(3):
				var shift_x := float(_hash(grid_x, grid_z, 70 + tuft) % 300) / 100.0 - 1.5
				var shift_z := float(_hash(grid_x, grid_z, 80 + tuft) % 300) / 100.0 - 1.5
				var tuft_x := x + shift_x
				var tuft_z := z + shift_z
				grass.append(Transform3D(Basis().scaled(Vector3(0.35, 0.65, 0.35)), Vector3(tuft_x, height_at(tuft_x, tuft_z) + 0.32, tuft_z)))
			if choice < tree_limit:
				trunks.append(Transform3D(Basis().scaled(Vector3(0.55, 3.0, 0.55)), place + Vector3(0, 1.5, 0)))
				leaves.append(Transform3D(Basis().scaled(Vector3(2.4, 3.4, 2.4)), place + Vector3(0, 4.1, 0)))
			elif choice < tree_limit + 7:
				stones.append(Transform3D(Basis().scaled(Vector3(1.7, 1.2, 1.5)), place + Vector3(0, 0.5, 0)))
			else:
				for petal in range(2):
					if _hash(grid_x, grid_z, petal + 29) % 3 == 0:
						var offset := Vector3(petal * 0.9 - 0.45, 0, float(_hash(grid_x, grid_z, petal + 44) % 100) / 100.0)
						flowers.append(Transform3D(Basis().scaled(Vector3(0.4, 0.6, 0.4)), place + offset + Vector3(0, 0.3, 0)))
	_add_instances(root, _box_mesh(), trunk_material, trunks)
	_add_instances(root, _cone_mesh(), leaf_material, leaves)
	_add_instances(root, _rock_mesh(), stone_material, stones)
	_add_instances(root, _flower_mesh(), flower_material, flowers)
	_add_instances(root, _cone_mesh(), grass_material, grass)
	if key == Vector2i.ZERO or (posmod(key.x, 7) == 0 and posmod(key.y, 7) == 0):
		_add_ruin(root, key)


func _hash(x: int, z: int, salt: int) -> int:
	var value := (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791) ^ WORLD_SEED
	return abs(value)


func _add_instances(root: Node3D, mesh: Mesh, material: Material, placements: Array[Transform3D]) -> void:
	if placements.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = placements.size()
	for index in range(placements.size()):
		multi.set_instance_transform(index, placements[index])
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multi
	visual.material_override = material
	root.add_child(visual)


func _box_mesh() -> BoxMesh:
	return BoxMesh.new()


func _cone_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.5
	return mesh


func _rock_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 4
	return mesh


func _flower_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 3
	return mesh


func _add_ruin(root: Node3D, key: Vector2i) -> void:
	var origin := Vector3(key.x * CHUNK_SIZE + 19.0, 0, key.y * CHUNK_SIZE + 19.0)
	for piece in [
		[Vector3(-5, 1.6, -5), Vector3(1, 3.2, 1)],
		[Vector3(5, 1.6, -5), Vector3(1, 3.2, 1)],
		[Vector3(0, 3.3, -5), Vector3(11, 1, 1)],
		[Vector3(-5, 1.0, 5), Vector3(1, 2, 1)],
		[Vector3(5, 1.0, 5), Vector3(1, 2, 1)],
		[Vector3(0, 0.2, 0), Vector3(12, 0.4, 12)],
	]:
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = piece[1]
		block.mesh = mesh
		block.material_override = stone_material
		var position: Vector3 = origin + piece[0]
		block.position = Vector3(position.x, height_at(position.x, position.z) + piece[0].y, position.z)
		root.add_child(block)


func _add_vertex(surface: SurfaceTool, point: Vector3) -> void:
	var climate_value := climate.get_noise_2d(point.x, point.z)
	var wet := Color(0.20, 0.39, 0.37)
	var meadow := Color(0.33, 0.55, 0.31)
	var dry := Color(0.61, 0.49, 0.31)
	var color := wet.lerp(meadow, clampf((climate_value + 0.5) * 2.0, 0.0, 1.0))
	color = color.lerp(dry, clampf(climate_value * 2.0, 0.0, 1.0))
	surface.set_color(color)
	surface.add_vertex(point)
