extends SceneTree
## Run on a real X11 display (including Xvfb :90), using Godot input dispatch.
var app: Control

func _initialize() -> void:
	_run.call_deferred()

func click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)
		await process_frame

func settle() -> void:
	for frame in range(5):
		await process_frame

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	app.demo = true
	root.add_child(app)
	OS.low_processor_usage_mode = false
	await settle()
	await click_at(app.pet.get_global_rect().get_center())
	assert(app.view == "menu", "Clicking the character must open the menu")
	await settle()
	await click_at(app.menu_controls.get_child(3).get_global_rect().get_center())
	assert(app.view == "avatars", "Avatar menu should open")
	await settle()
	await click_at(app.avatar_controls.get_child(1).get_global_rect().get_center())
	assert(app.pet.appearance == 1, "Female character must be selectable")
	# Test custom-image import without opening an interactive OS picker.
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.CORAL)
	img.save_png("user://fixture.png")
	app._select_image(ProjectSettings.globalize_path("user://fixture.png"))
	assert(app.pet.custom_texture != null, "Custom PNG must be displayed")
	assert(FileAccess.file_exists("user://custom_pet.png"))
	app._set_appearance(2)
	assert(app.pet.custom_texture == null)
	app._show_view("menu")
	await settle()
	# Quit through the same visible menu control the user clicks.
	print("INTERACTION_OK: pet click, female selection, PNG import; clicking exit now")
	if "--close-button" in OS.get_cmdline_user_args():
		var close_button := app.bubble.get_child(0).get_child(0).get_child(1) as Button
		await click_at(close_button.get_global_rect().get_center())
	else:
		await click_at(app.menu_controls.get_child(5).get_global_rect().get_center())
	await create_timer(1).timeout
	push_error("Exit button did not close the application")
	quit(1)
