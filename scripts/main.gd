extends Control

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
var view := "summary"
var lunch_label: Label
var days_row: HBoxContainer
var actions_row: HBoxContainer
var settings_row: HBoxContainer
var settings_options: VBoxContainer
var menu_controls: GridContainer
var avatar_controls: VBoxContainer
var back_button: Button
var pet: Control
var image_picker: FileDialog
var reminder_enabled := true
var lunch_enabled := true
var reminder_minutes := 30
var appearance := 0
var custom_image := ""
var lunch_notified_day := ""
var bubble_hide_at := 0
var pointer_start := Vector2i.ZERO
var dragging := false
var first_notice_pending := true

func _ready() -> void:
	get_viewport().transparent_bg = true
	OS.low_processor_usage_mode = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--data-dir="):
			data_dir = arg.trim_prefix("--data-dir=")
		if arg == "--demo":
			demo = true
	if not demo:
		config.load("user://settings.cfg")
	week = int(config.get_value("reminder", "week", 0))
	reminder_enabled = bool(config.get_value("reminder", "enabled", true))
	lunch_enabled = bool(config.get_value("reminder", "lunch", true))
	reminder_minutes = int(config.get_value("reminder", "minutes", 30))
	appearance = clampi(int(config.get_value("pet", "appearance", 0)), 0, 2)
	custom_image = str(config.get_value("pet", "image", ""))
	_build_ui()
	if not demo and data_dir.is_empty():
		_start_helper()
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

func _start_helper() -> void:
	# F5 / double-clicking an exported binary must start the same integration as run.py.
	var app_dir := ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	if not FileAccess.file_exists(app_dir.path_join("bridge_runner.py")):
		app_dir = app_dir.get_base_dir()
	var python := app_dir.path_join(".venv/Scripts/python.exe" if OS.get_name() == "Windows" else ".venv/bin/python")
	var runner := app_dir.path_join("bridge_runner.py")
	if not FileAccess.file_exists(python) or not FileAccess.file_exists(runner):
		state = {"status": "setup", "message": "請先執行 setup-windows.bat 或 setup-linux.sh 安裝查詢工具，再重開精靈。"}
		_render()
		return
	if OS.get_name() == "Windows":
		data_dir = OS.get_environment("LOCALAPPDATA").path_join("BentoBuddy")
	else:
		var base := OS.get_environment("XDG_DATA_HOME")
		if base.is_empty():
			base = OS.get_environment("HOME").path_join(".local/share")
		data_dir = base.path_join("bento-buddy")
	DirAccess.make_dir_recursive_absolute(data_dir)
	var pid := OS.create_process(python, PackedStringArray([runner, "--data-dir", data_dir, "--parent-pid", str(OS.get_process_id())]))
	if pid == -1:
		state = {"status": "error", "message": "無法啟動查詢工具，請確認 Python 安裝後重開精靈。"}
	else:
		state = {"status": "loading", "message": "正在自動啟動查詢工具…"}
	_render()

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
	bubble.custom_minimum_size.x = 412
	add_child(bubble)
	bubble.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bubble.offset_left = 14
	bubble.offset_right = -14
	bubble.offset_top = 12
	bubble.add_theme_stylebox_override("panel", _style("#1e293e", "#526078", 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.minimum_size_changed.connect(func(): bubble.reset_size.call_deferred())
	bubble.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := _label("●  便當小夜班", 15, "#8ad6c2")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := _button("×", func(): get_tree().quit())
	close.tooltip_text = "結束精靈與背景查詢"
	title_row.add_child(close)
	headline = _label("寫程式，也要記得吃飯。", 23, "#f6e8d2")
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(headline)
	detail = _label("準備檢查本週的午餐預約。", 15, "#b7c5d9")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 5
	column.add_child(detail)
	lunch_label = _label("", 16, "#8ad6c2")
	lunch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lunch_label.max_lines_visible = 3
	column.add_child(lunch_label)
	days_row = HBoxContainer.new()
	days_row.add_theme_constant_override("separation", 6)
	column.add_child(days_row)
	for index in range(5):
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", _style("#172237", "#35435b", 6))
		days_row.add_child(cell)
		var label := _label("週%s\n—\n待確認" % "一二三四五"[index], 14, "#9babc3")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(label)
		day_labels.append(label)
	actions_row = HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 8)
	column.add_child(actions_row)
	var order := _button("去訂便當 ↗", func(): _command("login"), true)
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(order)
	actions_row.add_child(_button("知道了", _snooze))
	settings_row = HBoxContainer.new()
	settings_row.add_theme_constant_override("separation", 6)
	column.add_child(settings_row)
	week_picker = OptionButton.new()
	week_picker.add_item("本週午餐")
	week_picker.add_item("下週午餐")
	week_picker.select(clampi(week, 0, 1))
	week_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	week_picker.item_selected.connect(func(index: int):
		week = index
		_save_settings()
		last_reminder = ""
		snooze_until = 0
		_render()
	)
	settings_row.add_child(week_picker)
	settings_row.add_child(_button("網站", func(): _command("login")))
	settings_row.add_child(_button("檢查", func(): _command("refresh")))
	settings_options = VBoxContainer.new()
	column.add_child(settings_options)
	var remind_toggle := CheckButton.new()
	remind_toggle.text = "主動提醒漏訂午餐"
	remind_toggle.button_pressed = reminder_enabled
	remind_toggle.toggled.connect(func(enabled: bool):
		reminder_enabled = enabled
		last_reminder = ""
		_save_settings()
	)
	settings_options.add_child(remind_toggle)
	var lunch_toggle := CheckButton.new()
	lunch_toggle.text = "每天 11:00 告訴我今天吃什麼"
	lunch_toggle.button_pressed = lunch_enabled
	lunch_toggle.toggled.connect(func(enabled: bool):
		lunch_enabled = enabled
		_save_settings()
	)
	settings_options.add_child(lunch_toggle)
	var interval := OptionButton.new()
	for minutes in [15, 30, 60]:
		interval.add_item("漏訂每 %d 分鐘提醒一次" % minutes, minutes)
	interval.select(maxi(0, interval.get_item_index(reminder_minutes)))
	interval.item_selected.connect(func(index: int):
		reminder_minutes = interval.get_item_id(index)
		_save_settings()
	)
	settings_options.add_child(interval)
	settings_options.add_child(_button("結束桌面精靈", func(): get_tree().quit()))
	menu_controls = GridContainer.new()
	menu_controls.columns = 2
	menu_controls.add_theme_constant_override("h_separation", 8)
	menu_controls.add_theme_constant_override("v_separation", 8)
	column.add_child(menu_controls)
	for choice in [["今天吃什麼", "today"], ["這週漏訂哪天", "week"], ["提醒設定", "settings"], ["更換人物", "avatars"]]:
		var destination: String = choice[1]
		var button := _button(choice[0], func(): _show_view(destination))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_controls.add_child(button)
	menu_controls.add_child(_button("去訂便當 ↗", func(): _command("login")))
	menu_controls.add_child(_button("結束精靈", func(): get_tree().quit()))
	avatar_controls = VBoxContainer.new()
	avatar_controls.add_theme_constant_override("separation", 8)
	column.add_child(avatar_controls)
	for index in range(3):
		var variant := index
		avatar_controls.add_child(_button(["阿夜 · 熬夜工程師", "小紫 · 長髮女生", "小栗 · 短髮女生"][index], func(): _set_appearance(variant)))
	avatar_controls.add_child(_button("選自己的 PNG 圖片…", _pick_image))
	back_button = _button("想做別的事…", func(): _show_view("menu"))
	column.add_child(back_button)
	sync_label = _label("每 5 分鐘檢查 · 只檢查午餐", 12, "#8595ad")
	column.add_child(sync_label)
	pet = Control.new()
	pet.set_script(preload("res://scripts/pixel_engineer.gd"))
	pet.custom_minimum_size = Vector2(360, 224)
	add_child(pet)
	pet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pet.position = Vector2(40, 408)
	pet.size = Vector2(360, 224)
	pet.mouse_default_cursor_shape = Control.CURSOR_MOVE
	pet.tooltip_text = "點我聊天或設定 · 拖曳移動 · 右鍵收起氣泡"
	pet.gui_input.connect(_pet_input)
	_apply_appearance()
	image_picker = FileDialog.new()
	image_picker.access = FileDialog.ACCESS_FILESYSTEM
	image_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_picker.filters = PackedStringArray(["*.png ; PNG 圖片"])
	image_picker.use_native_dialog = true
	image_picker.title = "選擇桌面精靈人物"
	image_picker.file_selected.connect(_select_image)
	image_picker.canceled.connect(_update_hit_area)
	add_child(image_picker)
	# Small speech tail, drawn separately so the bubble can use flowing containers.
	bubble.resized.connect(func():
		bubble.position.y = maxf(8, 390 - bubble.size.y)
		queue_redraw()
		_update_hit_area.call_deferred()
	)
	_layout_view()
	back_button.grab_focus()

func _save_settings() -> void:
	config.set_value("reminder", "week", week)
	config.set_value("reminder", "enabled", reminder_enabled)
	config.set_value("reminder", "lunch", lunch_enabled)
	config.set_value("reminder", "minutes", reminder_minutes)
	config.set_value("pet", "appearance", appearance)
	config.set_value("pet", "image", custom_image)
	config.save("user://settings.cfg")

func _layout_view() -> void:
	days_row.visible = view == "week"
	actions_row.visible = view in ["summary", "week", "today"]
	settings_row.visible = view == "settings"
	settings_options.visible = view == "settings"
	menu_controls.visible = view == "menu"
	avatar_controls.visible = view == "avatars"
	lunch_label.visible = view == "summary" and _health() == "ok"
	detail.visible = view not in ["settings", "avatars"]
	sync_label.visible = view in ["summary", "today", "week"]
	back_button.visible = view != "menu"
	back_button.text = "想做別的事…" if view == "summary" else "← 回去選單"
	menu_controls.get_child(1).text = "這週漏訂哪天" if week == 0 else "下週漏訂哪天"
	bubble.reset_size()

func _show_view(destination: String, automatic := false) -> void:
	view = destination
	bubble.show()
	bubble_hide_at = int(Time.get_unix_time_from_system()) + 25 if automatic else 0
	_layout_view()
	_render()
	pet.queue_redraw()
	_update_hit_area()
	queue_redraw()
	if view == "menu":
		menu_controls.get_child(0).grab_focus()
	elif back_button.visible:
		back_button.grab_focus()

func _set_appearance(index: int) -> void:
	appearance = index
	custom_image = ""
	_apply_appearance()
	_save_settings()

func _apply_appearance() -> void:
	pet.appearance = appearance
	pet.custom_texture = null
	if not custom_image.is_empty() and FileAccess.file_exists(custom_image):
		var img := Image.load_from_file(custom_image)
		if img:
			pet.custom_texture = ImageTexture.create_from_image(img)
	pet.queue_redraw()

func _pick_image() -> void:
	# A native file picker may be outside the pet's mouse hit region.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
	image_picker.popup_centered_ratio(0.85)

func _select_image(path: String) -> void:
	_update_hit_area()
	if FileAccess.get_file_as_bytes(path).size() > 10 * 1024 * 1024:
		headline.text = "請選 10 MB 以內的 PNG。"
		return
	var img := Image.load_from_file(path)
	if not img or img.get_width() > 4096 or img.get_height() > 4096:
		headline.text = "請選 4096 × 4096 以內的 PNG。"
		return
	# Keep an app-owned copy so moving the original image does not break the pet.
	custom_image = "user://custom_pet.png"
	if img.save_png(custom_image) != OK:
		headline.text = "圖片儲存失敗，請再試一次。"
		return
	_apply_appearance()
	_save_settings()
	headline.text = "新人物來陪你上班了！"

func _draw() -> void:
	if is_instance_valid(bubble) and bubble.visible:
		var y := bubble.position.y + bubble.size.y
		draw_colored_polygon(PackedVector2Array([Vector2(91, y - 2), Vector2(119, y - 2), Vector2(107, y + 15)]), Color("526078"))
		draw_colored_polygon(PackedVector2Array([Vector2(95, y - 3), Vector2(115, y - 3), Vector2(107, y + 10)]), Color("1e293e"))

func _pet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if bubble.visible:
				_snooze()
			else:
				_show_view("menu")
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_start = DisplayServer.mouse_get_position()
				dragging = false
			elif not dragging:
				_show_view("menu")
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not dragging and Vector2(DisplayServer.mouse_get_position() - pointer_start).length() > 6:
			dragging = true
			DisplayServer.window_start_drag()

func _update_hit_area() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var points := PackedVector2Array([Vector2(40, 408), Vector2(400, 408), Vector2(400, 632), Vector2(40, 632)])
	if bubble.visible:
		var split := maxf(408, bubble.position.y + bubble.size.y + 18)
		var top := maxf(0, bubble.position.y - 4)
		points = PackedVector2Array([Vector2(10, top), Vector2(430, top), Vector2(430, split), Vector2(400, split), Vector2(400, 636), Vector2(40, 636), Vector2(40, split), Vector2(10, split)])
	DisplayServer.window_set_mouse_passthrough(points)

func _command(action: String) -> void:
	if demo:
		detail.text = "展示模式不會查詢真實訂單。正式啟動請移除 --demo。"
		return
	if data_dir.is_empty():
		_start_helper()
		return
	var path := data_dir.path_join("command.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"id": str(Time.get_unix_time_from_system()) + str(Time.get_ticks_usec()), "action": action}))
		file.close()
		if DirAccess.rename_absolute(path + ".tmp", path) != OK:
			detail.text = "無法送出檢查，請重新啟動精靈。"
		else:
			detail.text = "正在原本的瀏覽器開啟訂餐頁…" if action == "login" else "正在請瀏覽器同步午餐…"

func _poll() -> void:
	if demo:
		if state.is_empty():
			var sample: Array = []
			for index in range(5):
				sample.append({"date": "2026-10-%02d" % (5 + index), "weekday": "一二三四五"[index], "status": "missing" if index in [1, 3] else "ordered"})
			state = {"status": "ok", "today": "2026-10-05", "today_lunch": [{"content": "[範例餐廳] 蔥鹽豬里肌便當 × 1", "location": "總部"}], "weeks": [sample, sample]}
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
			state = {"status": "setup", "message": "請先執行安裝腳本，並在 Chrome／Edge 載入便當同步擴充功能。"}
			_render()
	var now := int(Time.get_unix_time_from_system())
	if bubble_hide_at > 0 and now >= bubble_hide_at and view in ["summary", "today"]:
		_snooze()
	if snooze_until > 0 and now >= snooze_until:
		snooze_until = 0
		last_reminder = ""
		_render()
	# Only fresh real data can produce the daily lunch announcement.
	var local := Time.get_datetime_dict_from_unix_time(now + 28800)
	var today := str(state.get("today", ""))
	if not demo and lunch_enabled and _health() == "ok" and local.hour >= 11 and local.hour < 14 and today != lunch_notified_day:
		if view not in ["menu", "settings", "avatars"]:
			lunch_notified_day = today
			first_notice_pending = false
			_show_view("today", true)
	if first_notice_pending and _health() == "ok" and view not in ["menu", "settings", "avatars"]:
		first_notice_pending = false
		if reminder_enabled or lunch_enabled:
			_show_view("summary" if reminder_enabled else "today", true)
		else:
			_snooze()

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
	if view == "menu":
		headline.text = "想要我幫你做什麼？"
		detail.text = "午餐、提醒，還是幫我換個造型？"
		return
	if view == "settings":
		headline.text = "提醒怎麼安排？"
		return
	if view == "avatars":
		headline.text = "今天換誰陪你加班？"
		return
	var health := _health()
	lunch_label.visible = view == "summary" and health == "ok"
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
		detail.text = "%s星期%s午餐還沒訂！" % ["這週" if week == 0 else "下週", "、".join(missing)]
		var key := str(week) + JSON.stringify(days)
		if key != last_reminder and snooze_until == 0 and reminder_enabled:
			bubble.show()
			last_reminder = key
			if view == "summary":
				bubble_hide_at = int(Time.get_unix_time_from_system()) + 25
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
	lunch_label.text = _today_text()
	lunch_label.tooltip_text = lunch_label.text
	if view == "today":
		headline.text = "今天午餐吃什麼？"
		detail.text = _today_text()
	detail.tooltip_text = detail.text
	if demo:
		sync_label.text = "展示模式 · 範例資料，非真實訂單"
	else:
		var checked := str(state.get("checked_at", ""))
		sync_label.text = "台北時間 %s 更新 · 每 5 分鐘檢查" % checked.substr(11, 5)

func _snooze() -> void:
	snooze_until = int(Time.get_unix_time_from_system()) + reminder_minutes * 60
	bubble_hide_at = 0
	view = "summary"
	bubble.hide()
	_layout_view()
	_update_hit_area()
	queue_redraw()

func _today_text() -> String:
	var lunches: Array = state.get("today_lunch", [])
	var descriptions: Array[String] = []
	for meal in lunches:
		descriptions.append(str(meal.get("content", "")) + "\n取餐地點：" + str(meal.get("location", "待確認")))
	if not descriptions.is_empty():
		return "今天午餐：\n" + "\n".join(descriptions)
	var weeks: Array = state.get("weeks", [])
	if not weeks.is_empty():
		for day in weeks[0]:
			if str(day.get("date", "")) == str(state.get("today", "")):
				if day.get("status") == "missing":
					return "今天午餐還沒訂喔！"
	return "今天沒有可確認的午餐預約，先到網站看看。"

func _capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/preview.png")
	get_tree().quit()
