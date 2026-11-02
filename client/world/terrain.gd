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


func _ready() -> void:
	elevation.seed = WORLD_SEED
	elevation.frequency = 0.013
	elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation.fractal_octaves = 3
	climate.seed = WORLD_SEED + 117
	climate.frequency = 0.0025
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
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


func _create_chunk(key: Vector2i) -> MeshInstance3D:
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
	add_child(instance)
	return instance


func _add_vertex(surface: SurfaceTool, point: Vector3) -> void:
	var climate_value := climate.get_noise_2d(point.x, point.z)
	var wet := Color(0.20, 0.39, 0.37)
	var meadow := Color(0.33, 0.55, 0.31)
	var dry := Color(0.61, 0.49, 0.31)
	var color := wet.lerp(meadow, clampf((climate_value + 0.5) * 2.0, 0.0, 1.0))
	color = color.lerp(dry, clampf(climate_value * 2.0, 0.0, 1.0))
	surface.set_color(color)
	surface.add_vertex(point)
