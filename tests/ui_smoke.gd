extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.demo = true
	app.state = {}
	app._poll()
	assert(app.headline.text == "要訂便當了喔！")
	assert("星期二、四還沒訂" in app.detail.text)
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
	print("UI smoke passed: missing, all ordered, snooze/resume, stale, login failure")
	quit()
