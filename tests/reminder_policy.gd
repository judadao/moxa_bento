extends SceneTree
const Policy = preload("res://scripts/reminder_policy.gd")

func at(value: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(value)) - 28800

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var day := {"date": "2026-10-05", "weekday": "一", "status": "missing"}
	var future := {"date": "2026-10-06", "weekday": "二", "status": "missing"}
	assert(Policy.reminder_slot(at("2026-10-05T07:59:59")) == "")
	assert(Policy.reminder_slot(at("2026-10-05T08:00:00")) == "2026-10-05:480")
	assert(Policy.reminder_slot(at("2026-10-05T08:49:59")) == "2026-10-05:510")
	assert(Policy.reminder_slot(at("2026-10-05T08:50:00")) == "2026-10-05:530")
	assert(Policy.reminder_slot(at("2026-10-05T08:59:59")) != "")
	assert(Policy.reminder_slot(at("2026-10-05T09:00:00")) == "")
	assert(Policy.reminder_slot(at("2026-10-03T08:30:00")) == "")
	assert(Policy.reminder_slot(at("2026-10-04T08:30:00")) == "")
	assert(Policy.reminder_slot(at("2026-10-05T08:20:00"), true) == "")
	assert(Policy.reminder_slot(at("2026-10-05T08:50:00"), true) == "2026-10-05:510")
	assert(Policy.display_status(day, at("2026-10-05T08:59:59")) == "missing")
	assert(Policy.display_status(day, at("2026-10-05T09:00:00")) == "closed")
	assert(Policy.missing_days([day, future], at("2026-10-05T09:00:00")) == ["二"])
	assert(Policy.date_key(at("2026-12-31T23:59:59") + 1) == "2027-01-01")
	assert("快 9 點" in Policy.message([day], at("2026-10-05T08:50:00"), true))
	var app = load("res://main.tscn").instantiate()
	app.demo = true
	root.add_child(app)
	await process_frame
	app.demo = false
	app.clock_override = at("2026-10-05T08:30:00")
	app.state = {"status": "ok", "today": "2026-10-05", "checked_at": "2026-10-05T08:29:00+08:00", "weeks": [[day, future], []]}
	app.last_slot = ""
	app.snooze_until = 0
	app._check_notices()
	assert(app.last_slot == "2026-10-05:510")
	app.bubble.hide()
	app._check_notices()
	assert(not app.bubble.visible, "Do not repeat the same morning slot")
	app.clock_override = at("2026-10-05T08:50:00")
	app._check_notices()
	assert(not app.bubble.visible, "Stale data cannot trigger another reminder")
	app.state.checked_at = "2026-10-05T08:49:00+08:00"
	app._check_notices()
	assert(app.bubble.visible and app.last_slot == "2026-10-05:530")
	app.clock_override = at("2026-10-05T09:00:00")
	app.last_slot = ""
	app.bubble.hide()
	app._check_notices()
	assert(not app.bubble.visible and app.last_slot == "")
	app._show_view("today")
	assert("截止" in app.headline.text and "沒訂到" in app.headline.text)
	app.state.status = "login_required"
	app.clock_override = at("2026-10-06T08:00:00")
	app.bubble.hide()
	app._check_notices()
	assert(not app.bubble.visible)
	print("REMINDER_OK: Taipei, weekdays, all morning slots, 08:59:59/09:00 boundary, restart dedup, stale/login, future dates")
	quit()
