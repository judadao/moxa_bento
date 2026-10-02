extends Control

const FOOD_URL = "https://foodcourt.moxa.com/foodCourt/staff/home.action"
const PALETTE = {"ordered": "#83d4c1", "missing": "#f5b08c", "unknown": "#9babc3", "past": "#68738b"}
const STATUS_TEXT = {"ordered": "已訂", "missing": "未訂", "unknown": "待確認", "past": "已過"}
var data_dir := ""
var demo := false
var week := 0
var state: Dictionary = {}
var bubble: PanelContainer
var headline: Label
var detail: Label
var sync_label: Label
var day_labels: Array[Label] = []
var week_picker: OptionButton
var snooze_until := 0
var last_reminder := ""
var last_content := ""
var last_health := ""
var config := ConfigFile.new()

func _ready() -> void:
	get_viewport().transparent_bg = true
	OS.low_processor_usage_mode = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--data-dir="):
			data_dir = arg.trim_prefix("--data-dir=")
		if arg == "--demo":
			demo = true
	config.load("user://settings.cfg")
	week = int(config.get_value("reminder", "week", 0))
	_build_ui()
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect()
		get_window().position = usable.end - get_window().size - Vector2i(24, 24)
	_poll()
	var timer := Timer.new()
	timer.wait_time = 2
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()
	_update_hit_area.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _style(bg: String, border: String, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(bg)
	box.border_color = Color(border)
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _label(value: String, size_px: int, color: String) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", size_px)
	item.add_theme_color_override("font_color", Color(color))
	return item

func _button(value: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("182d35" if primary else "d8e1ec"))
	button.add_theme_stylebox_override("normal", _style("#8ad6c2" if primary else "#28364c", "#8ad6c2" if primary else "#40516c", 6))
	button.add_theme_stylebox_override("hover", _style("#b0ead7" if primary else "#3d5269", "#b0ead7", 6))
	button.add_theme_stylebox_override("pressed", _style("#71b8a7", "#b0ead7", 6))
	var focus := _style("#00000000", "#ffe0a0", 6)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/buddy.otf")
	ui_theme.default_font_size = 16
	theme = ui_theme
	bubble = PanelContainer.new()
	add_child(bubble)
	bubble.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bubble.offset_left = 14
	bubble.offset_right = -14
	bubble.offset_top = 12
	bubble.add_theme_stylebox_override("panel", _style("#1e293e", "#526078", 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	bubble.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := _label("●  便當小夜班", 15, "#8ad6c2")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := _button("×", func(): get_tree().quit())
	close.tooltip_text = "結束桌面精靈"
	title_row.add_child(close)
	headline = _label("寫程式，也要記得吃飯。", 23, "#f6e8d2")
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(headline)
	detail = _label("準備檢查本週的午餐預約。", 15, "#b7c5d9")
	detail.custom_minimum_size.y = 44
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	var days := HBoxContainer.new()
	days.add_theme_constant_override("separation", 6)
	column.add_child(days)
	for index in range(5):
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", _style("#172237", "#35435b", 6))
		days.add_child(cell)
		var label := _label("週%s\n—\n待確認" % "一二三四五"[index], 14, "#9babc3")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(label)
		day_labels.append(label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var order := _button("去訂便當 ↗", func(): OS.shell_open(FOOD_URL), true)
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(order)
	actions.add_child(_button("30 分鐘後提醒", _snooze))
	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 6)
	column.add_child(tools_row)
	week_picker = OptionButton.new()
	week_picker.add_item("本週午餐")
	week_picker.add_item("下週午餐")
	week_picker.select(clampi(week, 0, 1))
	week_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	week_picker.item_selected.connect(func(index: int):
		week = index
		config.set_value("reminder", "week", week)
		config.save("user://settings.cfg")
		last_reminder = ""
		snooze_until = 0
		_render()
	)
	tools_row.add_child(week_picker)
	tools_row.add_child(_button("登入", func(): _command("login")))
	tools_row.add_child(_button("檢查", func(): _command("refresh")))
	sync_label = _label("每 5 分鐘檢查 · 只檢查午餐", 12, "#8595ad")
	column.add_child(sync_label)
	var pet := Control.new()
	pet.set_script(preload("res://scripts/pixel_engineer.gd"))
	pet.custom_minimum_size = Vector2(360, 224)
	add_child(pet)
	pet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pet.position = Vector2(40, 408)
	pet.size = Vector2(360, 224)
	pet.mouse_default_cursor_shape = Control.CURSOR_MOVE
	pet.tooltip_text = "拖曳移動 · 右鍵顯示／隱藏對話 · 雙擊開啟訂餐"
	pet.gui_input.connect(_pet_input)
	# Small speech tail, drawn separately so the bubble can use flowing containers.
	bubble.resized.connect(func():
		queue_redraw()
		_update_hit_area.call_deferred()
	)
	week_picker.grab_focus()

func _draw() -> void:
	if is_instance_valid(bubble) and bubble.visible:
		var y := bubble.position.y + bubble.size.y
		draw_colored_polygon(PackedVector2Array([Vector2(91, y - 2), Vector2(119, y - 2), Vector2(107, y + 15)]), Color("526078"))
		draw_colored_polygon(PackedVector2Array([Vector2(95, y - 3), Vector2(115, y - 3), Vector2(107, y + 10)]), Color("1e293e"))

func _pet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			bubble.visible = not bubble.visible
			_update_hit_area()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				OS.shell_open(FOOD_URL)
			else:
				DisplayServer.window_start_drag()

func _update_hit_area() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var points := PackedVector2Array([Vector2(40, 408), Vector2(400, 408), Vector2(400, 632), Vector2(40, 632)])
	if bubble.visible:
		var split := maxf(408, bubble.position.y + bubble.size.y + 18)
		points = PackedVector2Array([Vector2(10, 8), Vector2(430, 8), Vector2(430, split), Vector2(400, split), Vector2(400, 636), Vector2(40, 636), Vector2(40, split), Vector2(10, split)])
	DisplayServer.window_set_mouse_passthrough(points)

func _command(action: String) -> void:
	if demo:
		detail.text = "展示模式不會查詢真實訂單。正式啟動請移除 --demo。"
		return
	if data_dir.is_empty():
		detail.text = "請用 start-windows.bat 或 start-linux.sh 啟動連線工具。"
		return
	var path := data_dir.path_join("command.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"id": str(Time.get_unix_time_from_system()) + str(Time.get_ticks_usec()), "action": action}))
		file.close()
		if DirAccess.rename_absolute(path + ".tmp", path) != OK:
			detail.text = "無法送出檢查，請重新啟動精靈。"
		else:
			detail.text = "正在開啟登入視窗…" if action == "login" else "正在重新檢查…"

func _poll() -> void:
	if demo:
		if state.is_empty():
			var sample: Array = []
			for index in range(5):
				sample.append({"date": "2026-10-%02d" % (5 + index), "weekday": "一二三四五"[index], "status": "missing" if index in [1, 3] else "ordered"})
			state = {"status": "ok", "weeks": [sample, sample]}
			_render()
	else:
		var path := data_dir.path_join("state.json")
		if not data_dir.is_empty() and FileAccess.file_exists(path):
			var content := FileAccess.get_file_as_string(path)
			var parsed: Variant = JSON.parse_string(content)
			if parsed is Dictionary:
				state = parsed
				var health := _health()
				if content != last_content or health != last_health:
					last_content = content
					last_health = health
					_render()
		elif state.is_empty():
			state = {"status": "setup", "message": "請用啟動腳本執行，再按「登入」連接訂餐網站。"}
			_render()
	if snooze_until > 0 and Time.get_unix_time_from_system() >= snooze_until:
		snooze_until = 0
		last_reminder = ""
		_render()

func _health() -> String:
	if demo or state.get("status") != "ok":
		return str(state.get("status", "unknown"))
	var checked := str(state.get("checked_at", ""))
	# Python publishes ISO timestamps in Asia/Taipei (+08:00).
	var timestamp := Time.get_unix_time_from_datetime_string(checked.left(19)) - 28800
	var now := Time.get_unix_time_from_system()
	var taipei_day := Time.get_date_string_from_unix_time(int(now) + 28800)
	if now - timestamp > 900 or str(state.get("today", "")) != taipei_day:
		return "stale"
	return "ok"

func _render() -> void:
	var health := _health()
	if health != "ok":
		headline.text = "先連線，再幫你顧午餐。"
		detail.text = "資料已過期，請按「檢查」重新同步。" if health == "stale" else str(state.get("message", "暫時無法確認訂餐狀態。"))
		for index in range(5):
			day_labels[index].text = "週%s\n—\n待確認" % "一二三四五"[index]
			day_labels[index].add_theme_color_override("font_color", Color(PALETTE.unknown))
		sync_label.text = "尚未確認 · 不會將連線失敗當成未訂"
		last_reminder = ""
		return
	var weeks: Array = state.get("weeks", [])
	if weeks.size() < 2:
		return
	var days: Array = weeks[week]
	if days.size() != 5:
		return
	var missing: Array[String] = []
	var unknown := false
	var actionable := 0
	for index in range(5):
		var day: Dictionary = days[index]
		var status := str(day.get("status", "unknown"))
		var date_text := str(day.get("date", "")).substr(5).replace("-", "/")
		day_labels[index].text = "週%s\n%s\n%s" % [day.get("weekday", ""), date_text, STATUS_TEXT.get(status, "待確認")]
		day_labels[index].add_theme_color_override("font_color", Color(PALETTE.get(status, PALETTE.unknown)))
		if status == "missing":
			missing.append(str(day.get("weekday", "")))
		if status == "unknown":
			unknown = true
		if status != "past":
			actionable += 1
	if not missing.is_empty():
		headline.text = "要訂便當了喔！"
		detail.text = "星期%s還沒訂。忙著修 bug，也別餓肚子。" % "、".join(missing)
		var key := str(week) + JSON.stringify(days)
		if key != last_reminder and snooze_until == 0:
			bubble.show()
			last_reminder = key
			_update_hit_area()
			queue_redraw()
	elif unknown:
		headline.text = "有些日期還需要確認。"
		detail.text = "網站未列出可預約日期，可能尚未開放或不供餐。"
	elif actionable == 0:
		headline.text = "這週辛苦了。"
		detail.text = "本週用餐日已過，可以切到下週看看。"
	else:
		headline.text = "便當都訂好了，安心寫。"
		detail.text = "接下來的午餐有著落了。也記得早點休息。"
	if demo:
		sync_label.text = "展示模式 · 範例資料，非真實訂單"
	else:
		var checked := str(state.get("checked_at", ""))
		sync_label.text = "台北時間 %s 更新 · 每 5 分鐘檢查" % checked.substr(11, 5)

func _snooze() -> void:
	snooze_until = int(Time.get_unix_time_from_system()) + 1800
	bubble.hide()
	_update_hit_area()
	queue_redraw()

func _capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/preview.png")
	get_tree().quit()
