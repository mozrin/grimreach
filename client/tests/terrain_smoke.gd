extends SceneTree

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")


func _initialize() -> void:
	var terrain = TERRAIN_SCRIPT.new()
	root.add_child(terrain)
	await process_frame
	var origin_height: float = terrain.height_at(0.0, 0.0)
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
