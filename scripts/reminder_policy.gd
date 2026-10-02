extends RefCounted
## All inputs use UTC epoch seconds; the office day is always Asia/Taipei.
const OFFSET := 28800
const CUTOFF := 9 * 60
const SLOTS := [480, 510, 530]

static func local_clock(now: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(now + OFFSET)

static func date_key(now: int) -> String:
	return Time.get_date_string_from_unix_time(now + OFFSET)

static func display_status(day: Dictionary, now: int) -> String:
	var status := str(day.get("status", "unknown"))
	if status == "missing" and str(day.get("date", "")) == date_key(now):
		var local := local_clock(now)
		if int(local.hour) * 60 + int(local.minute) >= CUTOFF:
			return "closed"
	return status

static func missing_days(days: Array, now: int) -> Array[String]:
	var result: Array[String] = []
	for day in days:
		if str(day.get("date", "")) >= date_key(now) and display_status(day, now) == "missing":
			result.append(str(day.get("weekday", "")))
	return result

static func reminder_slot(now: int, quiet: bool = false) -> String:
	var local := local_clock(now)
	if int(local.weekday) in [0, 6]:
		return ""
	var minutes := int(local.hour) * 60 + int(local.minute)
	if minutes < 480 or minutes >= CUTOFF:
		return ""
	var selected := -1
	for slot in ([510] if quiet else SLOTS):
		if minutes >= slot:
			selected = slot
	return "" if selected < 0 else date_key(now) + ":" + str(selected)

static func message(days: Array, now: int, urgent := false) -> String:
	var missing := missing_days(days, now)
	if missing.is_empty():
		return "午餐有著落了。你先忙，我陪你。"
	var today_missing := false
	for day in days:
		if str(day.get("date", "")) == date_key(now) and display_status(day, now) == "missing":
			today_missing = true
	if urgent and today_missing:
		return "欸，快 9 點了！今天便當還沒訂，先訂一下再忙吧。"
	if today_missing:
		return "早啊，今天便當還沒訂喔。記得 9 點前訂，我先幫你顧著。"
	return "對了，星期%s的午餐還沒訂。趁現在有空，一起訂好吧。" % "、".join(missing)
