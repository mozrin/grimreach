extends SceneTree

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")


func _initialize() -> void:
	var terrain = TERRAIN_SCRIPT.new()
	root.add_child(terrain)
	await process_frame
	var opening: Dictionary = terrain.veins[Vector2i.ZERO]
	if opening.id != "vein:0:0" or terrain.nearest_vein(opening.position, 1.0).id != opening.id:
		push_error("Starting mineral vein is missing or cannot be surveyed")
		quit(1)
		return
	for attribute in ["conductivity", "hardness", "malleability", "purity"]:
		if opening[attribute] < 100 or opening[attribute] > 1000:
			push_error("Mineral attribute is outside the quality range")
			quit(1)
			return
	terrain.update_around(Vector3(1000, 0, 1000))
	if terrain.veins.has(Vector2i.ZERO):
		push_error("Faraway mineral vein stayed loaded")
		quit(1)
		return
	terrain.update_around(Vector3.ZERO)
	var returned: Dictionary = terrain.veins[Vector2i.ZERO]
	if returned.id != opening.id or returned.conductivity != opening.conductivity or returned.purity != opening.purity:
		push_error("Returning to a vein changed its identity or quality")
		quit(1)
		return
	print("Mineral vein smoke test passed")
	quit()
