extends Control

const Policy = preload("res://scripts/reminder_policy.gd")
const Atelier = preload("res://scripts/atelier.gd")
const COLORS = {"ordered": "a8ceb7", "missing": "e8bc82", "closed": "a29aaa", "unknown": "a8a8b4", "past": "787583"}
const WORDS = {"ordered": "已訂好", "missing": "還沒訂", "closed": "已截止", "unknown": "待確認", "past": "已過"}
var data_dir := ""
var demo := false
var state: Dictionary = {}
var config := ConfigFile.new()
var view := "summary"
var week := 0
var appearance := 0
var custom_image := ""
var reminder_enabled := true
var lunch_enabled := true
var quiet_reminders := false
var reduced_motion := false
var text_speed := 26.0
var snooze_until := 0
var last_slot := ""
var lunch_notified_day := ""
var bubble_hide_at := 0
var last_content := ""
var last_health := ""
var clock_override := -1
var pointer_start := Vector2i.ZERO
var dragging := false
var character_count := 0.0
var type_pause := 0.0
var bubble: PanelContainer
var speaker: Label
var headline: Label
var detail: Label
var sync_label: Label
var page_box: VBoxContainer
var actions_row: HBoxContainer
var menu_controls: GridContainer
var settings_options: VBoxContainer
var avatar_controls: VBoxContainer
var days_row: VBoxContainer
var day_labels: Array[Label] = []
var back_button: Button
var close_button: Button
var pet: Control
var image_picker: FileDialog
var import_target := "character"
var import_sheet := false
var page_scroll: ScrollContainer

func _now() -> int:
	if clock_override >= 0:
		return clock_override
	if demo:
		return int(Time.get_unix_time_from_datetime_string("2026-10-05T08:30:00")) - 28800
	return int(Time.get_unix_time_from_system())

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
	week = clampi(int(config.get_value("reminder", "week", 0)), 0, 1)
	reminder_enabled = config.get_value("reminder", "enabled", true)
	lunch_enabled = config.get_value("reminder", "lunch", true)
	quiet_reminders = config.get_value("reminder", "quiet", false)
	last_slot = str(config.get_value("reminder", "last_slot", ""))
	lunch_notified_day = str(config.get_value("reminder", "lunch_day", ""))
	appearance = clampi(int(config.get_value("pet", "appearance", 0)), 0, 1)
	custom_image = str(config.get_value("pet", "image", ""))
	text_speed = clampf(float(config.get_value("dialogue", "speed", 26)), 12, 60)
	reduced_motion = config.get_value("scene", "reduced_motion", false)
	_build_ui()
	if not demo and data_dir.is_empty():
		_start_helper()
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect()
		get_window().position = usable.end - get_window().size - Vector2i(20, 20)
	_poll()
	var timer := Timer.new()
	timer.wait_time = 2
	timer.timeout.connect(_poll)
	add_child(timer)
	timer.start()
	_update_hit_area.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _style(bg: String, border: String, radius := 5) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(bg)
	box.border_color = Color(border)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func _label(value: String, px := 16, color := "c6c0b8") -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Color(color))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("211d21" if primary else "e4dccb"))
	button.add_theme_stylebox_override("normal", _style("d9b779" if primary else "292731", "d9b779" if primary else "4b4650"))
	button.add_theme_stylebox_override("hover", _style("f1d599" if primary else "3e3740", "e1c18a"))
	button.add_theme_stylebox_override("pressed", _style("b59463", "efcf92"))
	button.add_theme_stylebox_override("focus", _style("00000000", "f3dda5"))
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/buddy.otf")
	ui_theme.default_font_size = 16
	theme = ui_theme
	pet = Control.new()
	pet.set_script(Atelier)
	pet.position = Vector2(16, 398)
	pet.size = Vector2(488, 310)
	pet.clip_contents = true
	pet.layout = config.get_value("scene", "layout", {})
	add_child(pet)
	pet.gui_input.connect(_pet_input)
	pet.layout_changed.connect(_save_settings)
	pet.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pet.tooltip_text = "點我聊天 · 拖曳搬動辦公室 · 右鍵收起對話"
	_apply_appearance()
	bubble = PanelContainer.new()
	bubble.position = Vector2(20, 16)
	bubble.size.x = 480
	bubble.custom_minimum_size.x = 480
	bubble.add_theme_stylebox_override("panel", _style("201f29f5", "a38b62", 6))
	add_child(bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.minimum_size_changed.connect(func(): bubble.reset_size.call_deferred())
	bubble.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	speaker = _label("", 13, "ddbc82")
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(speaker)
	close_button = _button("×", func(): get_tree().quit())
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.custom_minimum_size = Vector2(32, 30)
	close_button.tooltip_text = "結束精靈"
	header.add_child(close_button)
	headline = _label("", 21, "f1e8d7")
	headline.mouse_filter = Control.MOUSE_FILTER_STOP
	headline.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	headline.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_finish_typing()
	)
	column.add_child(headline)
	detail = _label("", 14, "ada7b1")
	column.add_child(detail)
	page_scroll = ScrollContainer.new()
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(page_scroll)
	page_box = VBoxContainer.new()
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 8)
	page_scroll.add_child(page_box)
	actions_row = HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 8)
	column.add_child(actions_row)
	back_button = _button("聊點別的", func(): _show_view("menu"))
	column.add_child(back_button)
	sync_label = _label("", 11, "898491")
	column.add_child(sync_label)
	bubble.resized.connect(func():
		bubble.position.y = maxf(10, 379 - bubble.size.y)
		queue_redraw()
		_update_hit_area.call_deferred()
	)
	image_picker = FileDialog.new()
	image_picker.access = FileDialog.ACCESS_FILESYSTEM
	image_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_picker.filters = PackedStringArray(["*.png ; PNG 圖片"])
	image_picker.use_native_dialog = true
	image_picker.file_selected.connect(_select_image)
	image_picker.canceled.connect(_update_hit_area)
	add_child(image_picker)
	_show_view("summary")

func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _show_view(destination: String, automatic := false) -> void:
	view = destination
	bubble.show()
	pet.set_talking(true)
	bubble_hide_at = _now() + 25 if automatic else 0
	pet.editing = view == "decorate"
	pet.queue_redraw()
	_clear(page_box)
	_clear(actions_row)
	page_scroll.visible = view in ["menu", "week", "settings", "avatars", "decorate"]
	page_scroll.custom_minimum_size.y = {"menu": 134, "week": 135, "avatars": 124}.get(view, 0)
	back_button.visible = view not in ["menu", "summary"]
	back_button.text = "聊點別的" if view in ["summary", "today"] else "← 回去聊天"
	sync_label.visible = view in ["week", "settings"]
	if view == "menu":
		menu_controls = GridContainer.new()
		menu_controls.columns = 2
		menu_controls.add_theme_constant_override("h_separation", 8)
		menu_controls.add_theme_constant_override("v_separation", 8)
		page_box.add_child(menu_controls)
		for choice in [["今天吃什麼", "today"], ["看看這週", "week"], ["提醒設定", "settings"], ["換位同事", "avatars"], ["布置辦公桌", "decorate"]]:
			var target: String = choice[1]
			menu_controls.add_child(_button(choice[0], func(): _show_view(target)))
		menu_controls.add_child(_button("先去訂便當 ↗", func(): _command("login")))
	elif view == "week":
		var picker := OptionButton.new()
		picker.add_item("本週午餐")
		picker.add_item("下週午餐")
		picker.select(week)
		picker.item_selected.connect(func(index: int):
			week = index
			_save_settings()
			_render()
		)
		page_box.add_child(picker)
		days_row = VBoxContainer.new()
		page_box.add_child(days_row)
		day_labels.clear()
		for i in range(5):
			var label := _label("", 16)
			days_row.add_child(label)
			day_labels.append(label)
	elif view == "settings":
		_build_settings()
	elif view == "avatars":
		avatar_controls = VBoxContainer.new()
		page_box.add_child(avatar_controls)
		for index in range(2):
			var variant := index
			avatar_controls.add_child(_button(["亞修 · 盔甲裡也是打工人", "莉亞 · 下班再去討伐魔王"][index], func(): _set_appearance(variant)))
		avatar_controls.add_child(_button("使用自己的 PNG 人物…", func(): _pick_image("character")))
	elif view == "decorate":
		_build_editor()
	if view in ["summary", "today", "week"]:
		actions_row.add_child(_button("去訂便當 ↗", func(): _command("login"), true))
		actions_row.add_child(_button("嗯，知道了", _acknowledge))
	_render()
	bubble.reset_size.call_deferred()
	_update_hit_area.call_deferred()
	queue_redraw()
	if view == "menu":
		menu_controls.get_child(0).grab_focus()
	elif back_button.visible:
		back_button.grab_focus()
	elif actions_row.get_child_count() > 0:
		actions_row.get_child(0).grab_focus()

func _toggle(parent: Node, value: String, enabled: bool, callback: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = value
	toggle.button_pressed = enabled
	toggle.toggled.connect(callback)
	parent.add_child(toggle)

func _build_settings() -> void:
	settings_options = VBoxContainer.new()
	settings_options.add_theme_constant_override("separation", 6)
	page_box.add_child(settings_options)
	page_scroll.custom_minimum_size.y = 158
	_toggle(settings_options, "早上提醒我訂午餐", reminder_enabled, func(value: bool):
		reminder_enabled = value
		_save_settings()
	)
	var schedule := OptionButton.new()
	schedule.add_item("08:00、08:30、08:50 提醒")
	schedule.add_item("輕聲提醒一次 · 08:30")
	schedule.select(1 if quiet_reminders else 0)
	schedule.item_selected.connect(func(index: int):
		quiet_reminders = index == 1
		_save_settings()
	)
	settings_options.add_child(schedule)
	settings_options.add_child(_label("週一～五 · 台北時間 · 當天 09:00 截止", 13, "ddbc82"))
	_toggle(settings_options, "11:00 告訴我今天吃什麼", lunch_enabled, func(value: bool):
		lunch_enabled = value
		_save_settings()
	)
	_toggle(settings_options, "減少動態（暫停角色與場景動畫）", reduced_motion, func(value: bool):
		reduced_motion = value
		pet.reduced_motion = value
		pet.apply()
		_save_settings()
	)
	var speed := OptionButton.new()
	for choice in ["慢慢說", "平常語速", "說快一點"]:
		speed.add_item(choice)
	speed.select(0 if text_speed < 20 else 2 if text_speed > 35 else 1)
	speed.item_selected.connect(func(index: int):
		text_speed = [16.0, 26.0, 48.0][index]
		_save_settings()
	)
	settings_options.add_child(speed)
	var tools_row := HBoxContainer.new()
	settings_options.add_child(tools_row)
	tools_row.add_child(_button("同步午餐", func(): _command("refresh")))
	tools_row.add_child(_button("開啟訂餐頁 ↗", func(): _command("login")))

func _build_editor() -> void:
	page_scroll.custom_minimum_size.y = 186
	var picker := OptionButton.new()
	var keys: Array = Atelier.CATALOG.keys()
	for key in keys:
		picker.add_item(Atelier.CATALOG[key].label)
	picker.select(keys.find(pet.selected))
	picker.item_selected.connect(func(index: int):
		pet.selected = keys[index]
		_show_view("decorate")
	)
	page_box.add_child(picker)
	var options: Dictionary = pet.layout.get(pet.selected, {})
	_toggle(page_box, "顯示這個物件", not options.get("hidden", false), func(value: bool): pet.change(pet.selected, "hidden", not value))
	var tint := OptionButton.new()
	for choice in ["原色 · 暖光", "冷色 · 月光", "復古 · 琥珀"]:
		tint.add_item(choice)
	tint.select(int(options.get("tint", 0)))
	tint.item_selected.connect(func(index: int): pet.change(pet.selected, "tint", index))
	page_box.add_child(tint)
	var moves := HBoxContainer.new()
	page_box.add_child(moves)
	for move in [["←", Vector2(-4, 0)], ["↑", Vector2(0, -4)], ["↓", Vector2(0, 4)], ["→", Vector2(4, 0)]]:
		var delta: Vector2 = move[1]
		moves.add_child(_button(move[0], func(): pet.move_selected(delta)))
	var size_row := HBoxContainer.new()
	page_box.add_child(size_row)
	for item in [["縮小", -0.05], ["放大", 0.05]]:
		var change: float = item[1]
		size_row.add_child(_button(item[0], func(): pet.change(pet.selected, "scale", clampf(float(pet.layout.get(pet.selected, {}).get("scale", 1.0)) + change, 0.5, 1.3))))
	page_box.add_child(_button("換成自己的 PNG 物件…", func(): _pick_image(pet.selected)))
	if pet.selected != "character":
		page_box.add_child(_button("匯入 2 × 2 四幀動畫 PNG…", func(): _pick_image(pet.selected, true)))
	page_box.add_child(_button("恢復這個物件", func():
		pet.layout.erase(pet.selected)
		if pet.selected == "character":
			custom_image = ""
		_apply_appearance()
		_save_settings()
		_show_view("decorate")
	))

func _save_settings() -> void:
	config.set_value("reminder", "week", week)
	config.set_value("reminder", "enabled", reminder_enabled)
	config.set_value("reminder", "lunch", lunch_enabled)
	config.set_value("reminder", "quiet", quiet_reminders)
	config.set_value("reminder", "last_slot", last_slot)
	config.set_value("reminder", "lunch_day", lunch_notified_day)
	config.set_value("pet", "appearance", appearance)
	config.set_value("pet", "image", custom_image)
	config.set_value("scene", "layout", pet.layout)
	config.set_value("scene", "reduced_motion", reduced_motion)
	config.set_value("dialogue", "speed", text_speed)
	if not demo:
		config.save("user://settings.cfg")

func _set_appearance(index: int) -> void:
	appearance = clampi(index, 0, 1)
	custom_image = ""
	pet.layout.erase("character")
	_apply_appearance()
	_save_settings()
	_render()

func _apply_appearance() -> void:
	pet.appearance = appearance
	pet.reduced_motion = reduced_motion
	pet.custom_texture = null
	if not custom_image.is_empty() and FileAccess.file_exists(custom_image):
		var img := Image.load_from_file(custom_image)
		if img:
			pet.custom_texture = ImageTexture.create_from_image(img)
	pet.apply()

func _pick_image(target: String = "character", sheet := false) -> void:
	import_target = target
	import_sheet = sheet
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
	image_picker.title = "選擇四幀動畫（2 × 2 等分）" if sheet else "選擇透明 PNG"
	image_picker.popup_centered_ratio(0.85)

func _select_image(path: String) -> void:
	_update_hit_area()
	if FileAccess.get_file_as_bytes(path).size() > 10 * 1024 * 1024:
		_say("圖片有點大，請選 10 MB 以內的 PNG。")
		return
	var img := Image.load_from_file(path)
	if not img or img.get_width() > 4096 or img.get_height() > 4096:
		_say("請選 4096 × 4096 以內的 PNG。")
		return
	if import_sheet and (img.get_width() % 2 != 0 or img.get_height() % 2 != 0):
		_say("動畫圖需要能平均分成 2 × 2 格喔。")
		return
	var destination := "user://custom_%s.png" % import_target
	if img.save_png(destination) != OK:
		_say("圖片沒存好，再試一次吧。")
		return
	if import_target == "character":
		custom_image = destination
	else:
		var options: Dictionary = pet.layout.get(import_target, {}).duplicate()
		options.image = destination
		options.sheet = import_sheet
		pet.layout[import_target] = options
	_apply_appearance()
	_save_settings()
	_say("好了，這樣看起來更像你的位子了。")

func _say(text: String) -> void:
	if headline.text == text:
		return
	headline.text = text
	headline.visible_characters = 0
	character_count = 0
	type_pause = 0
	bubble.reset_size.call_deferred()

func _process(delta: float) -> void:
	if not is_instance_valid(headline) or headline.visible_characters < 0 or not bubble.visible:
		return
	if type_pause > 0:
		type_pause -= delta
		return
	character_count += delta * text_speed
	var count := mini(int(character_count), headline.text.length())
	if count > headline.visible_characters:
		headline.visible_characters = count
		if count > 0 and headline.text[count - 1] in "，。！？…":
			type_pause = 0.16
	if count >= headline.text.length():
		headline.visible_characters = -1

func _finish_typing() -> void:
	headline.visible_characters = -1
	character_count = headline.text.length()

func _acknowledge() -> void:
	if headline.visible_characters >= 0:
		_finish_typing()
	else:
		_snooze()

func _snooze() -> void:
	snooze_until = _now() + 10 * 60
	bubble_hide_at = 0
	bubble.hide()
	pet.set_talking(false)
	pet.editing = false
	view = "summary"
	_update_hit_area()
	queue_redraw()

func _pet_input(event: InputEvent) -> void:
	if pet.editing:
		return
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
				if bubble.visible and headline.visible_characters >= 0:
					_finish_typing()
				else:
					_show_view("menu")
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not dragging and Vector2(DisplayServer.mouse_get_position() - pointer_start).length() > 6:
			dragging = true
			DisplayServer.window_start_drag()

func _update_hit_area() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var top := maxf(0, bubble.position.y - 3) if bubble.visible else 398.0
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(14, top), Vector2(506, top), Vector2(506, 710), Vector2(14, 710)]))

func _draw() -> void:
	if is_instance_valid(bubble) and bubble.visible:
		var y := bubble.position.y + bubble.size.y
		draw_colored_polygon(PackedVector2Array([Vector2(99, y - 1), Vector2(121, y - 1), Vector2(110, y + 12)]), Color("a38b62"))
		draw_colored_polygon(PackedVector2Array([Vector2(101, y - 2), Vector2(119, y - 2), Vector2(110, y + 10)]), Color("201f29"))

func _command(action: String) -> void:
	if demo:
		_say("現在是展示模式。正式啟動後，我再幫你看真實午餐。")
		return
	if data_dir.is_empty():
		_start_helper()
		return
	var path := data_dir.path_join("command.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"id": str(Time.get_unix_time_from_system()) + str(Time.get_ticks_usec()), "action": action}))
		file.close()
		if DirAccess.rename_absolute(path + ".tmp", path) == OK:
			_say("幫你打開訂餐頁了。訂好了再回來聊。" if action == "login" else "我去看一下，等我一下喔。")
		else:
			_say("連線有點不順，重開精靈再試一下。")

func _health() -> String:
	if demo or state.get("status") != "ok":
		return str(state.get("status", "unknown"))
	var checked := str(state.get("checked_at", ""))
	var timestamp := Time.get_unix_time_from_datetime_string(checked.left(19)) - 28800
	if _now() - timestamp > 900 or timestamp - _now() > 60 or str(state.get("today", "")) != Policy.date_key(_now()):
		return "stale"
	return "ok"

func _days(index: int) -> Array:
	var weeks: Array = state.get("weeks", [])
	return weeks[index] if weeks.size() > index and weeks[index] is Array else []

func _poll() -> void:
	if demo and state.is_empty():
		var sample: Array = []
		var next_week: Array = []
		for i in range(5):
			sample.append({"date": "2026-10-%02d" % (5 + i), "weekday": "一二三四五"[i], "status": "missing" if i in [1, 3] else "ordered"})
			next_week.append({"date": "2026-10-%02d" % (12 + i), "weekday": "一二三四五"[i], "status": "missing" if i in [0, 2] else "ordered"})
		state = {"status": "ok", "today": "2026-10-05", "today_lunch": [{"content": "蔥鹽豬里肌便當", "location": "總部"}], "weeks": [sample, next_week]}
		_render()
	elif not demo and not data_dir.is_empty() and FileAccess.file_exists(data_dir.path_join("state.json")):
		var content := FileAccess.get_file_as_string(data_dir.path_join("state.json"))
		var parsed: Variant = JSON.parse_string(content)
		if parsed is Dictionary:
			state = parsed
			if content != last_content:
				last_content = content
				_render()
	var health := _health()
	# Include the office cutoff in the render key, even if no new server data arrives.
	var render_key := health + ":" + str(Policy.local_clock(_now()).hour)
	if render_key != last_health:
		last_health = render_key
		_render()
	if bubble_hide_at > 0 and _now() >= bubble_hide_at:
		_snooze()
	_check_notices()

func _check_notices() -> void:
	if demo or _health() != "ok" or view in ["menu", "settings", "avatars", "decorate", "week"] or _now() < snooze_until:
		return
	var slot := Policy.reminder_slot(_now(), quiet_reminders)
	if reminder_enabled and not slot.is_empty() and slot != last_slot and not Policy.missing_days(_days(0), _now()).is_empty():
		last_slot = slot
		_save_settings()
		_show_view("summary", true)
		return
	var local := Policy.local_clock(_now())
	var today := Policy.date_key(_now())
	if lunch_enabled and local.weekday not in [0, 6] and local.hour >= 11 and local.hour < 14 and today != lunch_notified_day:
		lunch_notified_day = today
		_save_settings()
		_show_view("today", true)

func _render() -> void:
	speaker.text = ("亞修" if appearance == 0 else "莉亞") + "  /  你的異世界同事" + (" · 範例" if demo else "")
	detail.text = ""
	detail.visible = false
	sync_label.text = "展示模式 · 以下為範例午餐" if demo else "台北時間 %s 更新" % str(state.get("checked_at", "—")).substr(11, 5)
	if view == "menu":
		_say("怎麼啦？要聊午餐，還是換個心情？")
		return
	if view == "settings":
		_say("早上我提醒你，忙完也要吃飯。")
		return
	if view == "avatars":
		_say("今天誰坐你隔壁？")
		return
	if view == "decorate":
		_say("這個位子，照你喜歡的樣子吧。")
		pet.tooltip_text = "拖曳移動選取的物件 · 選單向下捲動可替換圖片"
		return
	var health := _health()
	if health != "ok":
		_say("我還看不到午餐資料，先連上再聊。")
		detail.text = "資料有點舊了，到提醒設定按「同步午餐」吧。" if health == "stale" else str(state.get("message", "在平常的瀏覽器載入訂餐同步擴充功能，就能陪你顧午餐。"))
		detail.visible = true
		if view == "week":
			for i in range(day_labels.size()):
				day_labels[i].text = "週%s                     待確認" % "一二三四五"[i]
		return
	if view == "today":
		_say(_today_text())
	elif view == "week":
		_say("一起看看，這週還有哪天沒安排。" if week == 0 else "下週的午餐，也可以先安排好。")
		var days := _days(week)
		for i in range(day_labels.size()):
			if i >= days.size():
				day_labels[i].text = "週%s                     待確認" % "一二三四五"[i]
				continue
			var status := Policy.display_status(days[i], _now())
			day_labels[i].text = "週%s    %s      %s" % [days[i].get("weekday", ""), str(days[i].get("date", "")).substr(5).replace("-", "/"), WORDS.get(status, "待確認")]
			day_labels[i].add_theme_color_override("font_color", Color(COLORS.get(status, COLORS.unknown)))
	else:
		var local := Policy.local_clock(_now())
		if local.hour >= 9:
			_say(_today_text())
		else:
			_say(Policy.message(_days(0), _now(), int(local.hour) == 8 and int(local.minute) >= 50))

func _today_text() -> String:
	var meals: Array = state.get("today_lunch", [])
	var descriptions: Array[String] = []
	for meal in meals:
		descriptions.append(str(meal.get("content", "")) + "，到" + str(meal.get("location", "取餐處")) + "拿。")
	if not descriptions.is_empty():
		return "今天吃" + "\n".join(descriptions) + "\n忙完這段，記得好好吃飯。"
	for day in _days(0):
		if str(day.get("date", "")) == Policy.date_key(_now()):
			if Policy.display_status(day, _now()) == "closed":
				return "今天 9 點截止了，這餐沒訂到。中午找點喜歡的吃吧，別餓著。"
			if day.get("status") == "missing":
				return "今天還沒訂午餐喔，記得 9 點前訂。我陪你一起記。"
	return "今天還查不到確定的午餐。先看一下網站，別讓自己餓著。"

func _capture() -> void:
	_finish_typing()
	await get_tree().create_timer(0.5).timeout
	for frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/preview.png")
	get_tree().quit()
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
