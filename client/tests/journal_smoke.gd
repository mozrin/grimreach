extends SceneTree

const TERRAIN_SCRIPT = preload("res://world/terrain.gd")
const JOURNAL_SCRIPT = preload("res://exploration/journal.gd")


func _initialize() -> void:
	var save_path := "user://journal_smoke.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var terrain = TERRAIN_SCRIPT.new()
	root.add_child(terrain)
	var journal = JOURNAL_SCRIPT.new()
	journal.terrain = terrain
	journal.save_path = save_path
	root.add_child(journal)
	await process_frame
	var shrine: Dictionary = terrain.sites[Vector2i(0, -1)]
	journal.update_position(shrine.position)
	if not journal.discovered.has(shrine.id):
		push_error("Approaching a site did not record discovery")
		quit(1)
		return
	journal._examine()
	if not journal.examined.has(shrine.id) or not journal.is_open():
		push_error("Examining a site did not record its finding")
		quit(1)
		return
	journal.queue_free()
	await process_frame
	var restored = JOURNAL_SCRIPT.new()
	restored.terrain = terrain
	restored.save_path = save_path
	root.add_child(restored)
	await process_frame
	if not restored.discovered.has(shrine.id) or not restored.examined.has(shrine.id):
		push_error("Discovery did not survive a client restart")
		quit(1)
		return
	terrain.update_around(Vector3(1000, 0, 1000))
	terrain.update_around(Vector3.ZERO)
	restored.update_position(terrain.sites[Vector2i(0, -1)].position)
	if restored.discovered.size() != 1:
		push_error("Returning to a streamed site duplicated its discovery")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("Journal persistence smoke test passed")
	quit()
