extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.demo = true
	root.add_child(app)
	OS.low_processor_usage_mode = false
	await process_frame
	var failed := false
	for destination in ["summary", "menu", "today", "week", "settings", "avatars", "decorate"]:
		app._show_view(destination)
		app._finish_typing()
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		print(destination, " bubble: ", app.bubble.position, " / ", app.bubble.size)
		if app.bubble.position.y + app.bubble.size.y > 398 or app.bubble.size.x > 480:
			failed = true
		root.get_texture().get_image().save_png("res://output/" + destination + ".png")
	for index in range(2):
		app._set_appearance(index)
		app._show_view("summary")
		app._finish_typing()
		await create_timer(0.5).timeout
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/character_%d.png" % index)
	quit(1 if failed else 0)
