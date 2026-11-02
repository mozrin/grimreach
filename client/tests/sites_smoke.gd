extends SceneTree

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")


func _initialize() -> void:
	var terrain = TERRAIN_SCRIPT.new()
	root.add_child(terrain)
	await process_frame
	var expected := {
		Vector2i.ZERO: "ruin:0:0",
		Vector2i(-1, -1): "camp:-1:-1",
		Vector2i(0, -1): "shrine:0:-1",
	}
	for key in expected:
		if not terrain.sites.has(key) or terrain.sites[key].id != expected[key]:
			push_error("Starting area is missing a distinct destination")
			quit(1)
			return
	var original: Dictionary = terrain.sites[Vector2i(0, -1)]
	terrain.update_around(Vector3(1000, 0, 1000))
	if terrain.sites.has(Vector2i(0, -1)):
		push_error("Distant travel retained a faraway site")
		quit(1)
		return
	terrain.update_around(Vector3.ZERO)
	if terrain.sites[Vector2i(0, -1)].id != original.id:
		push_error("Returning to a site changed its identity")
		quit(1)
		return
	print("Site streaming smoke test passed")
	quit()
