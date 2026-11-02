extends Node3D

const CHUNK_SIZE := 48
const GRID_STEPS := 12
const VIEW_RADIUS := 2
const WORLD_SEED := 76341

var elevation := FastNoiseLite.new()
var ridge := FastNoiseLite.new()
var climate := FastNoiseLite.new()
var chunks := {}
var sites := {}
var center_chunk := Vector2i(2147483647, 2147483647)
var terrain_material := StandardMaterial3D.new()
var trunk_material := StandardMaterial3D.new()
var leaf_material := StandardMaterial3D.new()
var stone_material := StandardMaterial3D.new()
var flower_material := StandardMaterial3D.new()
var grass_material := StandardMaterial3D.new()
var dragon_material := StandardMaterial3D.new()
var biome_leaves: Array[StandardMaterial3D] = []
var biome_grass: Array[StandardMaterial3D] = []
var biome_flowers: Array[StandardMaterial3D] = []
var dragons: Array[Node3D] = []
var wing_time := 0.0


func _ready() -> void:
	elevation.seed = WORLD_SEED
	elevation.frequency = 0.013
	elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation.fractal_octaves = 3
	ridge.seed = WORLD_SEED + 601
	ridge.frequency = 0.0035
	ridge.fractal_type = FastNoiseLite.FRACTAL_FBM
	ridge.fractal_octaves = 2
	climate.seed = WORLD_SEED + 117
	climate.frequency = 0.0025
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
	trunk_material.albedo_color = Color(0.30, 0.22, 0.15)
	leaf_material.albedo_color = Color(0.19, 0.43, 0.25)
	stone_material.albedo_color = Color(0.48, 0.50, 0.48)
	flower_material.albedo_color = Color(0.92, 0.54, 0.69)
	grass_material.albedo_color = Color(0.45, 0.70, 0.35)
	dragon_material.albedo_color = Color(0.32, 0.21, 0.48)
	biome_leaves = [
		_colored_material(Color(0.14, 0.33, 0.31)),
		leaf_material,
		_colored_material(Color(0.44, 0.43, 0.22)),
	]
	biome_grass = [
		_colored_material(Color(0.35, 0.65, 0.51)),
		grass_material,
		_colored_material(Color(0.69, 0.61, 0.32)),
	]
	biome_flowers = [
		_colored_material(Color(0.71, 0.67, 0.94)),
		flower_material,
		_colored_material(Color(0.94, 0.64, 0.30)),
	]
	update_around(Vector3.ZERO)


func _colored_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _process(delta: float) -> void:
	wing_time += delta
	for index in range(dragons.size() - 1, -1, -1):
		var dragon := dragons[index]
		if not is_instance_valid(dragon) or dragon.is_queued_for_deletion():
			dragons.remove_at(index)
			continue
		dragon.position.y = dragon.get_meta("flight_height") + sin(wing_time * 1.6) * 0.45
		dragon.get_node("left_wing").rotation.z = sin(wing_time * 4.0) * 0.38
		dragon.get_node("right_wing").rotation.z = -sin(wing_time * 4.0) * 0.38
		dragon.rotation.y += delta * 0.35


func height_at(x: float, z: float) -> float:
	var ridge_value := maxf(0.0, ridge.get_noise_2d(x, z) + 0.18)
	return elevation.get_noise_2d(x, z) * 3.2 + ridge_value * ridge_value * 28.0


func update_around(world_position: Vector3) -> void:
	var next_center := Vector2i(floori(world_position.x / CHUNK_SIZE), floori(world_position.z / CHUNK_SIZE))
	if next_center == center_chunk:
		return
	center_chunk = next_center
	for key in chunks.keys():
		if abs(key.x - center_chunk.x) > VIEW_RADIUS or abs(key.y - center_chunk.y) > VIEW_RADIUS:
			chunks[key].queue_free()
			chunks.erase(key)
			sites.erase(key)
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
	var site := _site_for_chunk(key)
	if not site.is_empty():
		sites[key] = site
		_add_site(root, site)
	return root


func _site_for_chunk(key: Vector2i) -> Dictionary:
	var kind := ""
	if key == Vector2i.ZERO or (posmod(key.x, 7) == 0 and posmod(key.y, 7) == 0):
		kind = "ruin"
	elif key == Vector2i(-1, -1):
		kind = "camp"
	elif key == Vector2i(0, -1):
		kind = "shrine"
	elif _hash(key.x, key.y, 47) % 3 == 0:
		kind = ["ruin", "camp", "shrine"][_hash(key.x, key.y, 53) % 3]
	if kind == "":
		return {}
	var offset := 19.0 if kind == "ruin" else 24.0
	var position := Vector3(key.x * CHUNK_SIZE + offset, 0, key.y * CHUNK_SIZE + offset)
	position.y = height_at(position.x, position.z)
	var names := {
		"ruin": ["Fallen Court", "Ashen Court", "Mossgate Ruins"],
		"camp": ["Wayfarer Camp", "Cinder Camp", "Southwind Camp"],
		"shrine": ["Old Star Shrine", "Moonwell Shrine", "Stonewatch Shrine"],
	}
	var title: String = names[kind][_hash(key.x, key.y, 61) % 3]
	if key == Vector2i.ZERO:
		title = "Fallen Court"
	elif key == Vector2i(-1, -1):
		title = "Wayfarer Camp"
	elif key == Vector2i(0, -1):
		title = "Old Star Shrine"
	return {"id": "%s:%d:%d" % [kind, key.x, key.y], "kind": kind, "name": title, "position": position}


func nearest_site(world_position: Vector3, radius: float) -> Dictionary:
	var result := {}
	var nearest := radius
	for site in sites.values():
		var distance: float = Vector2(world_position.x, world_position.z).distance_to(Vector2(site.position.x, site.position.z))
		if distance < nearest:
			nearest = distance
			result = site
	return result


func _populate_chunk(root: Node3D, key: Vector2i) -> void:
	var site := _site_for_chunk(key)
	var climate_value := climate.get_noise_2d(key.x * CHUNK_SIZE + 24.0, key.y * CHUNK_SIZE + 24.0)
	var biome := 0 if climate_value < -0.12 else (2 if climate_value > 0.12 else 1)
	var grass_height := 0.9 if biome == 0 else (0.4 if biome == 2 else 0.65)
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
			var place := Vector3(x, height_at(x, z), z)
			var tree_limit := 7 + _hash(floori(float(grid_x) / 24.0), floori(float(grid_z) / 24.0), 7) % 9
			var choice := _hash(grid_x, grid_z, 11) % 100
			for tuft in range(3):
				if _is_route(x, z):
					continue
				var shift_x := float(_hash(grid_x, grid_z, 70 + tuft) % 300) / 100.0 - 1.5
				var shift_z := float(_hash(grid_x, grid_z, 80 + tuft) % 300) / 100.0 - 1.5
				var tuft_x := x + shift_x
				var tuft_z := z + shift_z
				grass.append(Transform3D(Basis().scaled(Vector3(0.35, grass_height, 0.35)), Vector3(tuft_x, height_at(tuft_x, tuft_z) + grass_height * 0.5, tuft_z)))
			if Vector2(x, z).length() < 7.0 or _is_route(x, z) or (not site.is_empty() and Vector2(x, z).distance_to(Vector2(site.position.x, site.position.z)) < 9.0):
				continue
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
	_add_instances(root, _cone_mesh(), biome_leaves[biome], leaves)
	_add_instances(root, _rock_mesh(), stone_material, stones)
	_add_instances(root, _flower_mesh(), biome_flowers[biome], flowers)
	_add_instances(root, _cone_mesh(), biome_grass[biome], grass)
	if key == Vector2i(0, -1) or (_hash(key.x, key.y, 91) % 31 == 0):
		_add_dragon(root, key)


func _is_route(x: float, z: float) -> bool:
	if absf(fposmod(x - 24.0 + 72.0, 144.0) - 72.0) < 3.5 or absf(fposmod(z - 24.0 + 72.0, 144.0) - 72.0) < 3.5:
		return true
	var point := Vector2(x, z)
	for destination in [Vector2(19, 19), Vector2(-24, -24), Vector2(24, -24)]:
		var closest := Geometry2D.get_closest_point_to_segment(point, Vector2.ZERO, destination)
		if point.distance_to(closest) < 3.0:
			return true
	return false


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


func _add_site(root: Node3D, site: Dictionary) -> void:
	match site.kind:
		"ruin":
			_add_ruin(root, site)
		"camp":
			_add_camp(root, site)
		"shrine":
			_add_shrine(root, site)
	var marker := Label3D.new()
	marker.text = site.name
	marker.font_size = 64
	marker.pixel_size = 0.006
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.position = site.position + Vector3(0, 8.0, 0)
	root.add_child(marker)


func _add_ruin(root: Node3D, site: Dictionary) -> void:
	var origin: Vector3 = site.position
	for piece in [
		[Vector3(-5, 1.6, -5), Vector3(1, 3.2, 1)],
		[Vector3(5, 1.6, -5), Vector3(1, 3.2, 1)],
		[Vector3(0, 3.3, -5), Vector3(11, 1, 1)],
		[Vector3(-5, 1.0, 5), Vector3(1, 2, 1)],
		[Vector3(5, 1.0, 5), Vector3(1, 2, 1)],
		[Vector3(0, -0.12, 0), Vector3(12, 0.25, 12)],
	]:
		var position: Vector3 = origin + piece[0]
		_add_site_block(root, Vector3(position.x, height_at(position.x, position.z) + piece[0].y, position.z), piece[1], stone_material)


func _add_camp(root: Node3D, site: Dictionary) -> void:
	var origin: Vector3 = site.position
	var canvas := _colored_material(Color(0.62, 0.34, 0.22))
	var ember := _colored_material(Color(1.0, 0.53, 0.18))
	for offset in [Vector3(-4, 0, -1), Vector3(4, 0, -1)]:
		var tent := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.0
		shape.bottom_radius = 2.0
		shape.height = 3.0
		shape.radial_segments = 4
		tent.mesh = shape
		tent.material_override = canvas
		var x: float = origin.x + offset.x
		var z: float = origin.z + offset.z
		tent.position = Vector3(x, height_at(x, z) + 1.5, z)
		root.add_child(tent)
	_add_site_block(root, origin + Vector3(0, 0.25, 0), Vector3(1.4, 0.5, 1.4), stone_material)
	_add_site_block(root, origin + Vector3(0, 0.9, 0), Vector3(0.7, 1.1, 0.7), ember)
	_add_site_block(root, origin + Vector3(0, 1.8, 4), Vector3(0.18, 3.6, 0.18), trunk_material)
	_add_site_block(root, origin + Vector3(0.9, 3.1, 4), Vector3(1.8, 0.9, 0.08), canvas)


func _add_shrine(root: Node3D, site: Dictionary) -> void:
	var origin: Vector3 = site.position
	var glow := _colored_material(Color(0.45, 0.81, 0.91))
	glow.emission_enabled = true
	glow.emission = Color(0.25, 0.60, 0.84)
	_add_site_block(root, origin + Vector3(0, -0.12, 0), Vector3(10, 0.25, 10), stone_material)
	var spire := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.radial_segments = 4
	shape.bottom_radius = 1.0
	shape.top_radius = 0.2
	shape.height = 5.0
	spire.mesh = shape
	spire.material_override = stone_material
	spire.position = origin + Vector3(0, 2.7, 0)
	root.add_child(spire)
	for offset in [Vector3(-4, 1.2, -4), Vector3(4, 1.2, -4), Vector3(-4, 1.2, 4), Vector3(4, 1.2, 4)]:
		_add_site_block(root, origin + offset, Vector3(0.8, 2.4, 0.8), stone_material)
	var beacon := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.7
	orb.height = 1.4
	beacon.mesh = orb
	beacon.material_override = glow
	beacon.position = origin + Vector3(0, 5.8, 0)
	root.add_child(beacon)


func _add_site_block(root: Node3D, position: Vector3, dimensions: Vector3, material: Material) -> void:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	block.mesh = mesh
	block.material_override = material
	block.position = position
	root.add_child(block)


func _add_dragon(root: Node3D, key: Vector2i) -> void:
	var x := key.x * CHUNK_SIZE + (2.0 if key == Vector2i(0, -1) else 14.0)
	var z := key.y * CHUNK_SIZE + (38.0 if key == Vector2i(0, -1) else 30.0)
	var dragon := Node3D.new()
	dragon.name = "dragon"
	dragon.position = Vector3(x, height_at(x, z) + 5.0, z)
	dragon.set_meta("flight_height", dragon.position.y)
	root.add_child(dragon)
	_add_dragon_part(dragon, "body", Vector3(2.2, 0.8, 1.2), Vector3.ZERO)
	_add_dragon_part(dragon, "head", Vector3(0.75, 0.75, 0.8), Vector3(1.35, 0.25, 0))
	_add_dragon_part(dragon, "tail", Vector3(1.8, 0.3, 0.3), Vector3(-1.85, 0, 0))
	_add_dragon_part(dragon, "neck", Vector3(0.45, 0.75, 0.5), Vector3(1.0, 0.35, 0))
	for side in [-1, 1]:
		_add_dragon_part(dragon, "horn", Vector3(0.2, 0.55, 0.2), Vector3(1.4, 0.75, side * 0.25))
		_add_dragon_part(dragon, "claw", Vector3(0.25, 0.65, 0.25), Vector3(0.55, -0.55, side * 0.42))
		_add_dragon_part(dragon, "claw", Vector3(0.25, 0.65, 0.25), Vector3(-0.65, -0.55, side * 0.42))
	for side in [-1, 1]:
		var wing := Node3D.new()
		wing.name = "left_wing" if side < 0 else "right_wing"
		wing.position = Vector3(0, 0.3, side * 0.6)
		dragon.add_child(wing)
		_add_dragon_part(wing, "membrane", Vector3(1.2, 0.12, 3.2), Vector3(-0.4, 0, side * 1.55))
	dragons.append(dragon)


func _add_dragon_part(parent: Node3D, part_name: String, dimensions: Vector3, placement: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = dragon_material
	part.position = placement
	parent.add_child(part)


func _add_vertex(surface: SurfaceTool, point: Vector3) -> void:
	var climate_value := climate.get_noise_2d(point.x, point.z)
	var wet := Color(0.20, 0.39, 0.37)
	var meadow := Color(0.33, 0.55, 0.31)
	var dry := Color(0.61, 0.49, 0.31)
	var color := wet.lerp(meadow, clampf((climate_value + 0.5) * 2.0, 0.0, 1.0))
	color = color.lerp(dry, clampf(climate_value * 2.0, 0.0, 1.0))
	color = color.lerp(Color(0.52, 0.53, 0.48), clampf((point.y - 5.0) / 12.0, 0.0, 0.7))
	if _is_route(point.x, point.z):
		color = color.lerp(Color(0.68, 0.55, 0.37), 0.8)
	surface.set_color(color)
	surface.add_vertex(point)
