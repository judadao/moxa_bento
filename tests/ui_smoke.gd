extends SceneTree
const Policy = preload("res://scripts/reminder_policy.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.demo = true
	root.add_child(app)
	await process_frame
	assert("星期二、四" in app.headline.text)
	assert(app.headline.visible_characters >= 0, "Dialogue must begin by revealing characters")
	await create_timer(0.2).timeout
	assert(app.headline.visible_characters > 0)
	app._acknowledge()
	assert(app.headline.visible_characters == -1 and app.bubble.visible, "First click completes speech")
	app._acknowledge()
	assert(not app.bubble.visible, "Second click dismisses speech")
	app._show_view("menu")
	assert(app.menu_controls.visible)
	app._show_view("today")
	assert("蔥鹽豬里肌" in app.headline.text and "總部" in app.headline.text)
	app._show_view("week")
	assert(app.days_row.visible and app.day_labels.size() == 5)
	assert(app._days(0)[0].date != app._days(1)[0].date)
	app._show_view("settings")
	assert(app.settings_options.visible)
	app._show_view("avatars")
	assert(app.avatar_controls.visible)
	app._set_appearance(1)
	assert(app.pet.appearance == 1)
	app._show_view("decorate")
	assert(app.pet.editing)
	var before: Vector2 = app.pet.objects.desk.position
	app.pet.selected = "desk"
	app.pet.move_selected(Vector2(4, 0))
	assert(app.pet.objects.desk.position.x == before.x + 4)
	var monitor_before: Vector2 = app.pet.objects.monitor.position
	app.pet.change("desk", "hidden", true)
	assert(not app.pet.objects.desk.visible and app.pet.objects.monitor.visible)
	assert(app.pet.objects.monitor.position == monitor_before)
	app.pet.change("desk", "hidden", false)
	for key in app.pet.objects:
		var sprite: Sprite2D = app.pet.objects[key]
		assert(sprite.texture != null, "Missing texture: " + key)
		assert(sprite.hframes * sprite.vframes == (8 if key == "character" else 4))
	var animation: Animation = app.pet.players[1].get_animation("work")
	assert(animation.loop_mode == Animation.LOOP_LINEAR)
	for player in app.pet.players:
		assert(player.has_animation("RESET"))
	app.pet.set_talking(false)
	await create_timer(0.4).timeout
	var seen: Dictionary = {}
	var seen_props: Dictionary = {}
	for tick in range(10):
		seen[app.pet.objects.character.frame] = true
		seen_props[app.pet.objects.coffee.frame] = true
		await create_timer(0.18).timeout
	assert(seen.size() == 8, "All eight work frames must actually play")
	assert(seen_props.size() == 4, "All four prop frames must actually play")
	app.pet.set_talking(true)
	await create_timer(0.5).timeout
	assert(app.pet.objects.character.frame >= 2, "Conversation must finish turning and face the viewer")
	app.pet.reduced_motion = true
	app.pet.apply()
	for player in app.pet.players:
		assert(not player.active)
	assert(app.pet.objects.character.frame == 2)
	app._show_view("summary")
	app.demo = false
	app.state = {"status": "ok", "checked_at": "2000-01-01T12:00:00+08:00", "today": "2000-01-01"}
	app._render()
	assert("舊" in app.detail.text)
	app.state = {"status": "login_required", "message": "請先登入"}
	app._render()
	assert(app.detail.text == "請先登入")
	print("UI_OK: typewriter/skip, simple pages, two coworkers, independent props, 8/4-frame animations, stale/login")
	quit()
