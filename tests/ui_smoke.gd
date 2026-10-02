extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	app.demo = true
	root.add_child(app)
	await process_frame
	app.demo = true
	app.state = {}
	app._poll()
	assert(app.headline.text == "要訂便當了喔！")
	assert("星期二、四午餐還沒訂" in app.detail.text)
	assert("蔥鹽豬里肌" in app.lunch_label.text)
	app._show_view("menu")
	assert(app.headline.text == "想要我幫你做什麼？")
	assert(app.menu_controls.visible)
	app._show_view("today")
	assert("取餐地點：總部" in app.detail.text)
	assert(not app.days_row.visible)
	app._show_view("week")
	assert(app.days_row.visible)
	app._show_view("settings")
	assert(app.settings_options.visible)
	app._show_view("avatars")
	assert(app.avatar_controls.visible)
	app.appearance = 2
	app._apply_appearance()
	assert(app.pet.appearance == 2)
	app._show_view("summary")
	app._snooze()
	assert(not app.bubble.visible)
	app.snooze_until = 1
	app._poll()
	assert(app.bubble.visible)
	for day in app.state.weeks[0]:
		day.status = "ordered"
	app.week = 0
	app._render()
	assert(app.headline.text == "便當都訂好了，安心寫。")
	app.demo = false
	app.state = {"status": "ok", "checked_at": "2000-01-01T12:00:00+08:00", "today": "2000-01-01"}
	app._render()
	assert("已過期" in app.detail.text)
	app.state = {"status": "login_required", "message": "請先登入"}
	app._render()
	assert(app.detail.text == "請先登入")
	for label in app.day_labels:
		assert("待確認" in label.text)
	print("UI smoke passed: bubbles, menu, today, settings, avatars, missing, snooze, stale/login")
	quit()
