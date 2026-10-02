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
	for destination in ["summary", "menu", "today", "week", "settings", "avatars"]:
		app._show_view(destination)
		# Containers settle over multiple frames after switching sections.
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		print(destination, " bubble: ", app.bubble.position, " / ", app.bubble.size)
		if app.bubble.position.y + app.bubble.size.y > 402:
			failed = true
		root.get_texture().get_image().save_png("res://output/" + destination + ".png")
	for index in range(3):
		app.appearance = index
		app._apply_appearance()
		app._show_view("avatars")
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/character_%d.png" % index)
	quit(1 if failed else 0)
