extends SceneTree
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
	for frame in range(8):
		await process_frame
func _run() -> void:
	app = load("res://main.tscn").instantiate()
	app.demo = true
	root.add_child(app)
	await settle()
	await click_at(app.headline.get_global_rect().get_center())
	assert(app.headline.visible_characters == -1)
	await click_at(app.pet.get_global_rect().get_center())
	assert(app.view == "menu")
	await settle()
	await click_at(app.menu_controls.get_child(3).get_global_rect().get_center())
	assert(app.view == "avatars")
	await settle()
	await click_at(app.avatar_controls.get_child(1).get_global_rect().get_center())
	assert(app.pet.appearance == 1)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.CORAL)
	img.save_png("user://fixture.png")
	app.import_target = "character"
	app._select_image(ProjectSettings.globalize_path("user://fixture.png"))
	assert(app.pet.custom_texture != null)
	app._set_appearance(0)
	assert(app.pet.custom_texture == null)
	app._show_view("decorate")
	app.pet.selected = "monitor"
	await settle()
	var before: Vector2 = app.pet.objects.monitor.position
	await click_at(app.page_box.get_child(3).get_child(3).get_global_rect().get_center())
	assert(app.pet.objects.monitor.position.x == before.x + 4)
	app._show_view("menu")
	await settle()
	print("INTERACTION_OK: typewriter click, pet menu, woman knight, custom PNG, independent movement; exit")
	await click_at(app.close_button.get_global_rect().get_center())
	await create_timer(1).timeout
	push_error("Exit button did not close app")
	quit(1)
