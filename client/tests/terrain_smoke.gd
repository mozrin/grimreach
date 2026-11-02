extends SceneTree

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")


func _initialize() -> void:
	var terrain = TERRAIN_SCRIPT.new()
	root.add_child(terrain)
	await process_frame
	var origin_height: float = terrain.height_at(0.0, 0.0)
	var lowest := INF
	var highest := -INF
	var biome_types := {}
	for sample_z in range(-8, 9):
		for sample_x in range(-8, 9):
			var x := sample_x * 256.0
			var z := sample_z * 256.0
			var height: float = terrain.height_at(x, z)
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
			var climate_value: float = terrain.climate.get_noise_2d(x, z)
			var biome := 0 if climate_value < -0.12 else (2 if climate_value > 0.12 else 1)
			biome_types[biome] = true
	if highest - lowest < 8.0 or biome_types.size() != 3:
		push_error("Distant travel lacks distinct relief or biome climates")
		quit(1)
		return
	if terrain.chunks.size() != 25:
		push_error("Expected 25 nearby terrain regions at spawn")
		quit(1)
		return
	terrain.update_around(Vector3(1000.0, 0.0, 1000.0))
	if terrain.chunks.size() != 25:
		push_error("Terrain region count grew after traveling")
		quit(1)
		return
	terrain.update_around(Vector3.ZERO)
	if terrain.chunks.size() != 25 or terrain.height_at(0.0, 0.0) != origin_height:
		push_error("Returning to spawn did not reproduce its terrain")
		quit(1)
		return
	print("Terrain streaming smoke test passed")
	quit()
