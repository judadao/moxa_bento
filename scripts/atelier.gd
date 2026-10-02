extends Control
## Independent sprite objects. Frame animation belongs to each object, never a baked room.
signal layout_changed
const CATALOG = {
	"window": {"file": "window_front", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(302, 4, 156, 158), "z": 0, "label": "背景窗景"},
	"chair": {"file": "chair_front", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(166, 29, 164, 267), "z": 1, "label": "辦公椅"},
	"character": {"file": "knight_front", "frames": 8, "grid": Vector2i(4, 2), "rect": Rect2(145, 0, 192, 307), "z": 2, "label": "同事"},
	"desk": {"file": "desk_front", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(22, 162, 444, 138), "z": 3, "label": "書桌"},
	"monitor": {"file": "monitor_back", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(67, 59, 139, 120), "z": 4, "label": "左側電腦"},
	"keyboard": {"file": "keyboard_front", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(186, 156, 109, 18), "z": 4, "label": "鍵盤"},
	"lamp": {"file": "lamp_front", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(359, 85, 56, 96), "z": 5, "label": "桌燈"},
	"coffee": {"file": "coffee_front", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(319, 138, 34, 44), "z": 5, "label": "咖啡"},
	"plant": {"file": "plant_front", "frames": 4, "grid": Vector2i(2, 2), "rect": Rect2(407, 120, 42, 60), "z": 5, "label": "盆栽"},
}
var objects: Dictionary = {}
var layout: Dictionary = {}
var appearance := 0
var custom_texture: Texture2D
var editing := false
var selected := "desk"
var reduced_motion := false
var players: Array[AnimationPlayer] = []
var drag_object := false
var last_pointer := Vector2.ZERO
var bounds_cache: Dictionary = {}
var talking := false
var metrics: Dictionary = {}
var light_material := ShaderMaterial.new()
var turn_generation := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light_material.shader = preload("res://scripts/office_light.gdshader")
	if FileAccess.file_exists("res://assets/atelier/metrics.json"):
		metrics = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atelier/metrics.json"))
	for key in CATALOG:
		var sprite := Sprite2D.new()
		sprite.name = key
		sprite.centered = false
		sprite.z_index = CATALOG[key].z
		if key != "window":
			sprite.material = light_material
		add_child(sprite)
		sprite.frame_changed.connect(_align_frame.bind(sprite))
		objects[key] = sprite
	apply()

func _texture(file: String) -> Texture2D:
	var path := "res://assets/atelier/" + file + ".png"
	return load(path) if ResourceLoader.exists(path) else null

func apply() -> void:
	if objects.is_empty():
		return
	for player in players:
		player.stop()
		player.queue_free()
	players.clear()
	for key in CATALOG:
		var spec: Dictionary = CATALOG[key]
		var options: Dictionary = layout.get(key, {})
		var sprite: Sprite2D = objects[key]
		var character_file := ("knight" if appearance == 0 else "female") + ("_talk" if talking else "_front")
		var tex: Texture2D = _texture(character_file if key == "character" else spec.file)
		var grid: Vector2i = spec.grid
		var count: int = spec.frames
		if key == "character" and custom_texture:
			tex = custom_texture
			grid = Vector2i.ONE
			count = 1
		elif FileAccess.file_exists(str(options.get("image", ""))):
			var img := Image.load_from_file(str(options.image))
			if img:
				tex = ImageTexture.create_from_image(img)
				grid = Vector2i(2, 2) if options.get("sheet", false) else Vector2i.ONE
				count = 4 if options.get("sheet", false) else 1
		sprite.texture = tex
		sprite.hframes = grid.x
		sprite.vframes = grid.y
		sprite.frame = 0
		_align_frame(sprite)
		sprite.visible = not options.get("hidden", false)
		var base: Rect2 = spec.rect
		var offset := Vector2(float(options.get("x", 0)), float(options.get("y", 0)))
		sprite.position = base.position + offset
		if tex:
			var bounds := _content_bounds(tex, grid)
			var factor: float = minf(base.size.x / bounds.size.x, base.size.y / bounds.size.y) * float(options.get("scale", 1.0))
			sprite.scale = Vector2.ONE * factor
			sprite.position += Vector2((base.size.x - bounds.size.x * factor) / 2.0, base.size.y - bounds.size.y * factor) - bounds.position * factor
		sprite.modulate = [Color.WHITE, Color("b5cadf"), Color("deb88d")][clampi(int(options.get("tint", 0)), 0, 2)]
		_animate(sprite, count, key == "character" and talking and count == 8)
	_update_lights()
	queue_redraw()

func _update_lights() -> void:
	for pair in [["monitor", "cool_source", "cool_energy", 0.22], ["lamp", "warm_source", "warm_energy", 0.32]]:
		var options: Dictionary = layout.get(pair[0], {})
		var base: Rect2 = CATALOG[pair[0]].rect
		var source := global_position + base.get_center() + Vector2(float(options.get("x", 0)), float(options.get("y", 0)))
		light_material.set_shader_parameter(pair[1], source)
		light_material.set_shader_parameter(pair[2], 0.0 if options.get("hidden", false) else pair[3])

func _align_frame(sprite: Sprite2D) -> void:
	sprite.offset = Vector2.ZERO
	if not sprite.texture:
		return
	var file := sprite.texture.resource_path.get_file().get_basename()
	if metrics.has(file) and metrics[file].has("offsets"):
		var offsets: Array = metrics[file].offsets
		if sprite.frame < offsets.size():
			sprite.offset = Vector2(offsets[sprite.frame][0], offsets[sprite.frame][1])

func _content_bounds(tex: Texture2D, grid: Vector2i) -> Rect2:
	var key := str(tex.get_rid()) + str(grid)
	if bounds_cache.has(key):
		return bounds_cache[key]
	var file := tex.resource_path.get_file().get_basename()
	if metrics.has(file):
		var b: Array = metrics[file].bounds
		return Rect2(b[0], b[1], b[2], b[3])
	var img := tex.get_image()
	var cell := Vector2i(img.get_size()) / grid
	var bounds := Rect2i()
	for y in range(grid.y):
		for x in range(grid.x):
			var used := img.get_region(Rect2i(Vector2i(x, y) * cell, cell)).get_used_rect()
			bounds = used if bounds.size == Vector2i.ZERO else bounds.merge(used)
	if bounds.size == Vector2i.ZERO:
		bounds = Rect2i(Vector2i.ZERO, cell)
	bounds_cache[key] = Rect2(bounds)
	return Rect2(bounds)

func set_talking(value: bool) -> void:
	if talking != value:
		talking = value
		turn_generation += 1
		if not value and not reduced_motion and not custom_texture:
			_return_to_work(turn_generation)
		else:
			apply()

func _return_to_work(generation: int) -> void:
	for player in players:
		if player.has_animation("turn"):
			player.animation_set_next("turn", "")
			player.play("turn", -1, -1.0, true)
	await get_tree().create_timer(0.36).timeout
	if generation == turn_generation and not talking:
		apply()

func _animate(sprite: Sprite2D, count: int, conversation := false) -> void:
	var player := AnimationPlayer.new()
	add_child(player)
	players.append(player)
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = count * (0.18 if count == 8 else 0.36)
	clip.loop_mode = Animation.LOOP_LINEAR
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath(str(get_path_to(sprite)) + ":frame"))
	clip.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for frame in range(count):
			clip.track_insert_key(track, frame * clip.length / count, frame)
	library.add_animation("work", clip)
	var reset := Animation.new()
	var reset_track := reset.add_track(Animation.TYPE_VALUE)
	reset.track_set_path(reset_track, NodePath(str(get_path_to(sprite)) + ":frame"))
	reset.track_insert_key(reset_track, 0, 0)
	library.add_animation("RESET", reset)
	if conversation:
		# Turn toward the user once, then hold a frontal talking loop.
		var turn := Animation.new()
		turn.length = 0.36
		var tt := turn.add_track(Animation.TYPE_VALUE)
		turn.track_set_path(tt, NodePath(str(get_path_to(sprite)) + ":frame"))
		turn.value_track_set_update_mode(tt, Animation.UPDATE_DISCRETE)
		for frame in range(3):
			turn.track_insert_key(tt, frame * 0.12, frame)
		library.add_animation("turn", turn)
		var talk := Animation.new()
		talk.length = 1.08
		talk.loop_mode = Animation.LOOP_LINEAR
		var ct := talk.add_track(Animation.TYPE_VALUE)
		talk.track_set_path(ct, NodePath(str(get_path_to(sprite)) + ":frame"))
		talk.value_track_set_update_mode(ct, Animation.UPDATE_DISCRETE)
		for frame in range(6):
			talk.track_insert_key(ct, frame * 0.18, frame + 2)
		library.add_animation("talk", talk)
	player.add_animation_library("", library)
	if conversation:
		player.animation_set_next("turn", "talk")
	player.play("turn" if conversation else "work")
	if reduced_motion and conversation:
		sprite.frame = 2
	player.active = not reduced_motion and sprite.visible

func change(key: String, property: String, value: Variant) -> void:
	var options: Dictionary = layout.get(key, {}).duplicate()
	options[property] = value
	layout[key] = options
	apply()
	layout_changed.emit()

func move_selected(delta: Vector2) -> void:
	var options: Dictionary = layout.get(selected, {}).duplicate()
	options.x = clampf(float(options.get("x", 0)) + delta.x, -CATALOG[selected].rect.position.x, 488 - CATALOG[selected].rect.end.x)
	options.y = clampf(float(options.get("y", 0)) + delta.y, -CATALOG[selected].rect.position.y, 310 - CATALOG[selected].rect.end.y)
	layout[selected] = options
	apply()
	layout_changed.emit()

func _gui_input(event: InputEvent) -> void:
	if not editing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_object = event.pressed
		last_pointer = event.position
		accept_event()
	elif event is InputEventMouseMotion and drag_object:
		move_selected(event.position - last_pointer)
		last_pointer = event.position
		accept_event()

func _draw() -> void:
	# Layered soft contact shadow; the desktop outside the diorama stays transparent.
	for i in range(6):
		draw_style_box(_shadow(0.03 + i * 0.008), Rect2(35 + i * 7, 284 + i, 420 - i * 14, 23 - i * 2))
	if editing and objects.has(selected):
		var sprite: Sprite2D = objects[selected]
		if sprite.texture:
			var bounds := _content_bounds(sprite.texture, Vector2i(sprite.hframes, sprite.vframes))
			draw_rect(Rect2(sprite.position + bounds.position * sprite.scale, bounds.size * sprite.scale), Color("e1bd76"), false, 1)

func _shadow(alpha: float) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(0.03, 0.025, 0.05, alpha)
	result.set_corner_radius_all(20)
	return result
