extends SceneTree

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")


func _initialize() -> void:
	var terrain = TERRAIN_SCRIPT.new()
	root.add_child(terrain)
	await process_frame
	if terrain.dragons.is_empty():
		push_error("The starting region needs a visible dragon")
		quit(1)
		return
	var wing: Node3D = terrain.dragons[0].get_node("left_wing")
	var initial_angle := wing.rotation.z
	await create_timer(0.2).timeout
	if absf(wing.rotation.z - initial_angle) < 0.01:
		push_error("Dragon wing did not animate")
		quit(1)
		return
	print("World life smoke test passed")
	quit()
