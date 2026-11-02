extends SceneTree

const EXPLORER_SCRIPT = preload("res://character/explorer.gd")


func _initialize() -> void:
	var explorer = EXPLORER_SCRIPT.new()
	root.add_child(explorer)
	explorer.configure(Color(0.95, 0.68, 0.29))
	for part in ["body/head/face", "body/head/nose", "body/left_arm/elbow/hand", "body/right_leg/knee/boot"]:
		if not explorer.has_node(part):
			push_error("Explorer anatomy is missing %s" % part)
			quit(1)
			return
	explorer.accept_snapshot(Vector3.ZERO)
	explorer.accept_snapshot(Vector3(0, 0, -1))
	explorer.advance(0.016)
	if explorer.position.z >= 0.0 or explorer.position.z <= -1.0:
		push_error("Visual position should interpolate between server snapshots")
		quit(1)
	for step in range(24):
		explorer.advance(0.016)
	if explorer.gait_weight < 0.5 or absf(explorer.left_leg.rotation.x) < 0.01:
		push_error("Walking did not blend into articulated movement")
		quit(1)
	explorer.accept_snapshot(Vector3(0, 0, -1))
	for step in range(50):
		explorer.advance(0.016)
	if explorer.gait_weight > 0.01 or absf(explorer.left_leg.rotation.x) > 0.01:
		push_error("Explorer did not settle into idle after movement stopped")
		quit(1)
	print("Explorer movement smoke test passed")
	quit()
