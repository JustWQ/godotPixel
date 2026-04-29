extends Node2D

const CONFIG_PATH := "res://configs/pixel_canvas_config.json"
const REFERENCE_IMAGE_PATH := "res://configs/reference.png"
const OUTPUT_DIR := "res://output"
const IMAGE_PIXEL_PRESET_NAME := "此图像素"
const LANG_ZH := "zh"
const LANG_EN := "en"

@export var grid_width: int = 16
@export var grid_height: int = 16
@export var cell_size: int = 24
@export var palette: Array[Color] = [
	Color("000000"),
	Color("ffffff"),
	Color("ff004d"),
	Color("00e436"),
	Color("29adff"),
	Color("ffec27"),
	Color("ff77a8"),
	Color("7fdbff")
]
@export var canvas_origin: Vector2 = Vector2(16, 80)
@export var palette_origin: Vector2 = Vector2(16, 16)
@export var palette_item_size: int = 28

var selected_color_idx: int = 0
var pixels: Array[Array] = []
var canvas_size_options: Array[Vector2i] = [
	Vector2i(16, 16), Vector2i(24, 24), Vector2i(32, 32),
	Vector2i(40, 40), Vector2i(48, 48), Vector2i(64, 64)
]
var preset_palettes: Dictionary = {}
var preset_order: Array[String] = [
	"默认8色", "PICO-8", "GameBoy", "DB16", "Sweetie16",
	"EGA16", "C64", "Nord16", "Solarized16", "Dusk16",
	"Forest16", "Neon16", "Mono4", "Amber8"
]
var current_preset_name: String = "默认8色"
var size_option_button: OptionButton
var preset_option_button: OptionButton
var reference_file_dialog: FileDialog
var toolbar_layer: CanvasLayer
var size_label: Label
var preset_label: Label
var clear_button: Button
var export_button: Button
var export_config_button: Button
var import_config_button: Button
var quantize_button: Button
var pick_image_button: Button
var recommend_palette_button: Button
var current_reference_image_path: String = REFERENCE_IMAGE_PATH
var analyze_pixels_button: Button
var color_limit_label: Label
var image_color_limit_spinbox: SpinBox
var merge_tolerance_label: Label
var image_merge_tolerance_spinbox: SpinBox
var language_toggle_button: Button
var suppress_image_color_limit_signal: bool = false
var suppress_merge_tolerance_signal: bool = false
var image_merge_tolerance_percent: int = 0
var current_language: String = LANG_ZH
var ui_texts: Dictionary = {
	LANG_ZH: {
		"size": "画布:",
		"palette": "调色板:",
		"clear": "清空",
		"export_png": "导出PNG",
		"export_cfg": "导出配置",
		"import_cfg": "导入配置",
		"quantize": "参考图像素化",
		"pick_image": "选择图片像素化",
		"recommend": "推荐调色板",
		"analyze": "分析图像像素",
		"limit": "限色:",
		"tolerance": "宽容度:",
		"lang_toggle": "EN",
		"dialog_title": "选择参考图片",
		"start_hint": "像素画工具已启动。左键上色，右键擦除，中键拖动画布，滚轮缩放，数字键 1-9 选色，C 清空，E 或按钮导出 PNG。"
	},
	LANG_EN: {
		"size": "Canvas:",
		"palette": "Palette:",
		"clear": "Clear",
		"export_png": "ExportPNG",
		"export_cfg": "SaveCfg",
		"import_cfg": "LoadCfg",
		"quantize": "Quantize",
		"pick_image": "PickImage",
		"recommend": "BestPal",
		"analyze": "Analyze",
		"limit": "Limit:",
		"tolerance": "Tolerance:",
		"lang_toggle": "中",
		"dialog_title": "Select Reference Image",
		"start_hint": "Pixel painter ready. Left paint, right erase, middle drag, wheel zoom, 1-9 pick color, C clear, E export PNG."
	}
}
var image_pixel_palette_full: Array[Color] = []
var image_pixel_palette_counts: Array[int] = []
var image_pixel_source: Image
var canvas_pan: Vector2 = Vector2.ZERO
var canvas_zoom: float = 1.0
const CANVAS_ZOOM_MIN: float = 0.25
const CANVAS_ZOOM_MAX: float = 8.0


func _ready() -> void:
	_init_preset_palettes()
	_apply_preset_palette(current_preset_name)
	_setup_toolbar_ui()
	_init_pixels()
	_sync_canvas_origin()
	_apply_ui_language()
	queue_redraw()
	print(_ui_text("start_hint"))


func _draw() -> void:
	_draw_palette()
	_draw_canvas()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_canvas_at(mouse_event.position, 1.1)
				return
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_canvas_at(mouse_event.position, 1.0 / 1.1)
				return
			elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
				return

			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if _try_select_palette(mouse_event.position):
					queue_redraw()
					return
				_try_paint(mouse_event.position, selected_color_idx)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_try_paint(mouse_event.position, -1)
	elif event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if motion_event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			canvas_pan += motion_event.relative
			queue_redraw()
		elif motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_try_paint(motion_event.position, selected_color_idx)
		elif motion_event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_try_paint(motion_event.position, -1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_C:
			_clear_canvas()
		elif key_event.keycode == KEY_E:
			_export_png()
		else:
			_try_pick_palette_by_number(key_event.keycode)


func _init_pixels() -> void:
	pixels.clear()
	for y in grid_height:
		var row: Array[int] = []
		row.resize(grid_width)
		for x in grid_width:
			row[x] = -1
		pixels.append(row)


func _draw_palette() -> void:
	for i in palette.size():
		var item_pos := palette_origin + Vector2(i * (palette_item_size + 8), 0)
		var rect := Rect2(item_pos, Vector2(palette_item_size, palette_item_size))
		draw_rect(rect, palette[i], true)
		draw_rect(rect, Color(0.15, 0.15, 0.15), false, 2.0)
		if i == selected_color_idx:
			var select_rect := rect.grow(3.0)
			draw_rect(select_rect, Color.WHITE, false, 2.0)


func _setup_toolbar_ui() -> void:
	toolbar_layer = CanvasLayer.new()
	add_child(toolbar_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 8
	panel.offset_top = 8
	panel.offset_right = -8
	panel.offset_bottom = 48
	toolbar_layer.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	panel.add_child(hbox)

	size_label = Label.new()
	hbox.add_child(size_label)

	size_option_button = OptionButton.new()
	for size in canvas_size_options:
		size_option_button.add_item("%dx%d" % [size.x, size.y])
	size_option_button.item_selected.connect(_on_canvas_size_selected)
	hbox.add_child(size_option_button)

	preset_label = Label.new()
	hbox.add_child(preset_label)

	preset_option_button = OptionButton.new()
	for name in preset_order:
		if preset_palettes.has(name):
			preset_option_button.add_item(name)
	preset_option_button.item_selected.connect(_on_preset_selected)
	hbox.add_child(preset_option_button)

	clear_button = Button.new()
	clear_button.pressed.connect(_on_clear_pressed)
	hbox.add_child(clear_button)

	export_button = Button.new()
	export_button.pressed.connect(_on_export_pressed)
	hbox.add_child(export_button)

	export_config_button = Button.new()
	export_config_button.pressed.connect(_on_export_config_pressed)
	hbox.add_child(export_config_button)

	import_config_button = Button.new()
	import_config_button.pressed.connect(_on_import_config_pressed)
	hbox.add_child(import_config_button)

	quantize_button = Button.new()
	quantize_button.pressed.connect(_on_quantize_reference_pressed)
	hbox.add_child(quantize_button)

	pick_image_button = Button.new()
	pick_image_button.pressed.connect(_on_pick_image_pressed)
	hbox.add_child(pick_image_button)

	recommend_palette_button = Button.new()
	recommend_palette_button.pressed.connect(_on_recommend_palette_pressed)
	hbox.add_child(recommend_palette_button)

	analyze_pixels_button = Button.new()
	analyze_pixels_button.pressed.connect(_on_analyze_image_pixels_pressed)
	hbox.add_child(analyze_pixels_button)

	color_limit_label = Label.new()
	hbox.add_child(color_limit_label)

	image_color_limit_spinbox = SpinBox.new()
	image_color_limit_spinbox.custom_minimum_size = Vector2(80, 0)
	image_color_limit_spinbox.min_value = 1
	image_color_limit_spinbox.max_value = 1
	image_color_limit_spinbox.step = 1
	image_color_limit_spinbox.value = 1
	image_color_limit_spinbox.allow_lesser = false
	image_color_limit_spinbox.allow_greater = false
	image_color_limit_spinbox.editable = true
	image_color_limit_spinbox.value_changed.connect(_on_image_color_limit_changed)
	hbox.add_child(image_color_limit_spinbox)
	_disable_image_color_limit_ui()

	merge_tolerance_label = Label.new()
	hbox.add_child(merge_tolerance_label)

	image_merge_tolerance_spinbox = SpinBox.new()
	image_merge_tolerance_spinbox.custom_minimum_size = Vector2(90, 0)
	image_merge_tolerance_spinbox.min_value = 0
	image_merge_tolerance_spinbox.max_value = 100
	image_merge_tolerance_spinbox.step = 1
	image_merge_tolerance_spinbox.value = image_merge_tolerance_percent
	image_merge_tolerance_spinbox.allow_lesser = false
	image_merge_tolerance_spinbox.allow_greater = false
	image_merge_tolerance_spinbox.editable = true
	image_merge_tolerance_spinbox.value_changed.connect(_on_image_merge_tolerance_changed)
	hbox.add_child(image_merge_tolerance_spinbox)

	_setup_reference_file_dialog(toolbar_layer)
	_setup_language_toggle_ui(toolbar_layer)
	_refresh_toolbar_ui()


func _setup_language_toggle_ui(parent_layer: CanvasLayer) -> void:
	language_toggle_button = Button.new()
	language_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	language_toggle_button.offset_left = -42
	language_toggle_button.offset_top = 8
	language_toggle_button.offset_right = -8
	language_toggle_button.offset_bottom = 36
	language_toggle_button.custom_minimum_size = Vector2(34, 28)
	language_toggle_button.clip_text = true
	language_toggle_button.pressed.connect(_on_language_toggle_pressed)
	parent_layer.add_child(language_toggle_button)


func _draw_canvas() -> void:
	var scaled_cell_size: float = float(cell_size) * canvas_zoom
	var draw_origin: Vector2 = _get_canvas_draw_origin()
	var canvas_size := Vector2(grid_width * scaled_cell_size, grid_height * scaled_cell_size)
	draw_rect(Rect2(draw_origin, canvas_size), Color(0.08, 0.08, 0.08), true)

	for y in grid_height:
		for x in grid_width:
			var px: int = pixels[y][x]
			if px >= 0 and px < palette.size():
				var cell_rect := Rect2(
					draw_origin + Vector2(x * scaled_cell_size, y * scaled_cell_size),
					Vector2(scaled_cell_size, scaled_cell_size)
				)
				draw_rect(cell_rect, palette[px], true)

	var grid_line_width: float = maxf(1.0, canvas_zoom * 0.8)
	for y in range(grid_height + 1):
		var y_pos := draw_origin.y + y * scaled_cell_size
		draw_line(
			Vector2(draw_origin.x, y_pos),
			Vector2(draw_origin.x + grid_width * scaled_cell_size, y_pos),
			Color(0.2, 0.2, 0.2),
			grid_line_width
		)

	for x in range(grid_width + 1):
		var x_pos := draw_origin.x + x * scaled_cell_size
		draw_line(
			Vector2(x_pos, draw_origin.y),
			Vector2(x_pos, draw_origin.y + grid_height * scaled_cell_size),
			Color(0.2, 0.2, 0.2),
			grid_line_width
		)


func _try_select_palette(mouse_pos: Vector2) -> bool:
	for i in palette.size():
		var item_pos := palette_origin + Vector2(i * (palette_item_size + 8), 0)
		var rect := Rect2(item_pos, Vector2(palette_item_size, palette_item_size))
		if rect.has_point(mouse_pos):
			selected_color_idx = i
			return true
	return false


func _try_paint(mouse_pos: Vector2, color_index: int) -> void:
	var cell := _mouse_to_cell(mouse_pos)
	if cell.x < 0 or cell.y < 0:
		return
	pixels[cell.y][cell.x] = color_index
	queue_redraw()


func _mouse_to_cell(mouse_pos: Vector2) -> Vector2i:
	var scaled_cell_size: float = float(cell_size) * canvas_zoom
	if scaled_cell_size <= 0.0:
		return Vector2i(-1, -1)

	var local_pos := mouse_pos - _get_canvas_draw_origin()
	if local_pos.x < 0 or local_pos.y < 0:
		return Vector2i(-1, -1)

	var x := int(floor(local_pos.x / scaled_cell_size))
	var y := int(floor(local_pos.y / scaled_cell_size))
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _clear_canvas() -> void:
	for y in grid_height:
		for x in grid_width:
			pixels[y][x] = -1
	queue_redraw()


func _apply_canvas_size(size: Vector2i) -> void:
	grid_width = size.x
	grid_height = size.y
	_init_pixels()
	_clear_image_pixel_palette_preset()
	_sync_canvas_origin()
	_refresh_toolbar_ui()
	queue_redraw()


func _sync_canvas_origin() -> void:
	palette_origin = Vector2(16, 56)
	canvas_origin = Vector2(16, 96)
	canvas_pan = Vector2.ZERO
	canvas_zoom = 1.0


func _get_canvas_draw_origin() -> Vector2:
	return canvas_origin + canvas_pan


func _zoom_canvas_at(mouse_pos: Vector2, factor: float) -> void:
	var old_zoom: float = canvas_zoom
	canvas_zoom = clampf(canvas_zoom * factor, CANVAS_ZOOM_MIN, CANVAS_ZOOM_MAX)
	if is_equal_approx(old_zoom, canvas_zoom):
		return

	var world_before_zoom: Vector2 = (mouse_pos - _get_canvas_draw_origin()) / old_zoom
	canvas_pan = mouse_pos - canvas_origin - world_before_zoom * canvas_zoom
	queue_redraw()


func _init_preset_palettes() -> void:
	preset_palettes = {
		"默认8色": [
			Color("000000"), Color("ffffff"), Color("ff004d"), Color("00e436"),
			Color("29adff"), Color("ffec27"), Color("ff77a8"), Color("7fdbff")
		],
		"PICO-8": [
			Color("000000"), Color("1d2b53"), Color("7e2553"), Color("008751"),
			Color("ab5236"), Color("5f574f"), Color("c2c3c7"), Color("fff1e8"),
			Color("ff004d"), Color("ffa300"), Color("ffec27"), Color("00e436"),
			Color("29adff"), Color("83769c"), Color("ff77a8"), Color("ffccaa")
		],
		"GameBoy": [
			Color("0f380f"), Color("306230"), Color("8bac0f"), Color("9bbc0f")
		],
		"DB16": [
			Color("140c1c"), Color("442434"), Color("30346d"), Color("4e4a4e"),
			Color("854c30"), Color("346524"), Color("d04648"), Color("757161"),
			Color("597dce"), Color("d27d2c"), Color("8595a1"), Color("6daa2c"),
			Color("d2aa99"), Color("6dc2ca"), Color("dad45e"), Color("deeed6")
		],
		"Sweetie16": [
			Color("1a1c2c"), Color("5d275d"), Color("b13e53"), Color("ef7d57"),
			Color("ffcd75"), Color("a7f070"), Color("38b764"), Color("257179"),
			Color("29366f"), Color("3b5dc9"), Color("41a6f6"), Color("73eff7"),
			Color("f4f4f4"), Color("94b0c2"), Color("566c86"), Color("333c57")
		],
		"EGA16": [
			Color("000000"), Color("0000aa"), Color("00aa00"), Color("00aaaa"),
			Color("aa0000"), Color("aa00aa"), Color("aa5500"), Color("aaaaaa"),
			Color("555555"), Color("5555ff"), Color("55ff55"), Color("55ffff"),
			Color("ff5555"), Color("ff55ff"), Color("ffff55"), Color("ffffff")
		],
		"C64": [
			Color("000000"), Color("ffffff"), Color("813338"), Color("75cec8"),
			Color("8e3c97"), Color("56ac4d"), Color("2e2c9b"), Color("edf171"),
			Color("8e5029"), Color("553800"), Color("c46c71"), Color("4a4a4a"),
			Color("7b7b7b"), Color("a9ff9f"), Color("706deb"), Color("b2b2b2")
		],
		"Nord16": [
			Color("2e3440"), Color("3b4252"), Color("434c5e"), Color("4c566a"),
			Color("d8dee9"), Color("e5e9f0"), Color("eceff4"), Color("8fbcbb"),
			Color("88c0d0"), Color("81a1c1"), Color("5e81ac"), Color("bf616a"),
			Color("d08770"), Color("ebcb8b"), Color("a3be8c"), Color("b48ead")
		],
		"Solarized16": [
			Color("002b36"), Color("073642"), Color("586e75"), Color("657b83"),
			Color("839496"), Color("93a1a1"), Color("eee8d5"), Color("fdf6e3"),
			Color("b58900"), Color("cb4b16"), Color("dc322f"), Color("d33682"),
			Color("6c71c4"), Color("268bd2"), Color("2aa198"), Color("859900")
		],
		"Dusk16": [
			Color("120f1d"), Color("1d1833"), Color("2a2450"), Color("3b3276"),
			Color("52459b"), Color("6b63c5"), Color("8c86df"), Color("b8b6f2"),
			Color("f0b4d8"), Color("e47ca8"), Color("c15a82"), Color("8f4260"),
			Color("5f2f46"), Color("3a2031"), Color("271724"), Color("f8e8ff")
		],
		"Forest16": [
			Color("0b1a10"), Color("132b19"), Color("1d3d24"), Color("285234"),
			Color("326845"), Color("3f7e57"), Color("4f966c"), Color("67ae84"),
			Color("83c69f"), Color("a5dbbc"), Color("c7edd6"), Color("5f4b2f"),
			Color("7b623b"), Color("9b7a47"), Color("c19a5d"), Color("f0ddb1")
		],
		"Neon16": [
			Color("05070f"), Color("10142a"), Color("1a1f3d"), Color("25305c"),
			Color("2f4680"), Color("1ccad8"), Color("26f0f1"), Color("6cf7ff"),
			Color("ff2a6d"), Color("ff5f9e"), Color("ff8fc4"), Color("ffd166"),
			Color("f7f779"), Color("9cff57"), Color("b28dff"), Color("f2f2ff")
		],
		"Mono4": [
			Color("111111"), Color("555555"), Color("aaaaaa"), Color("eeeeee")
		],
		"Amber8": [
			Color("1a1000"), Color("3b2300"), Color("6a3c00"), Color("8f5400"),
			Color("b56d00"), Color("d38b1d"), Color("f0b34f"), Color("ffe2a9")
		]
	}


func _apply_preset_palette(name: String) -> void:
	if not preset_palettes.has(name):
		return
	var palette_values := preset_palettes[name] as Array
	palette.clear()
	for c in palette_values:
		palette.append(c)
	current_preset_name = name
	selected_color_idx = clampi(selected_color_idx, 0, max(palette.size() - 1, 0))
	_refresh_toolbar_ui()
	queue_redraw()


func _refresh_toolbar_ui() -> void:
	if size_option_button != null:
		var size_index := 0
		for i in canvas_size_options.size():
			var size := canvas_size_options[i]
			if size.x == grid_width and size.y == grid_height:
				size_index = i
				break
		size_option_button.select(size_index)

	if preset_option_button != null:
		_refresh_preset_option_items()
		for i in preset_option_button.item_count:
			if preset_option_button.get_item_text(i) == current_preset_name:
				preset_option_button.select(i)
				break


func _on_canvas_size_selected(index: int) -> void:
	if index < 0 or index >= canvas_size_options.size():
		return
	_apply_canvas_size(canvas_size_options[index])


func _on_preset_selected(index: int) -> void:
	if preset_option_button == null or index < 0 or index >= preset_option_button.item_count:
		return
	_apply_preset_palette(preset_option_button.get_item_text(index))


func _on_clear_pressed() -> void:
	_clear_canvas()


func _on_export_pressed() -> void:
	_export_png()


func _on_export_config_pressed() -> void:
	_export_config_json()


func _on_import_config_pressed() -> void:
	_import_config_json()


func _on_quantize_reference_pressed() -> void:
	_import_reference_and_quantize()


func _on_pick_image_pressed() -> void:
	if reference_file_dialog == null:
		push_error("文件选择框未初始化。")
		return
	reference_file_dialog.popup_centered_ratio(0.7)


func _on_reference_file_selected(path: String) -> void:
	current_reference_image_path = path
	_clear_image_pixel_palette_preset()
	_import_reference_and_quantize_from_path(path)


func _on_recommend_palette_pressed() -> void:
	_recommend_best_preset_palette()


func _on_analyze_image_pixels_pressed() -> void:
	_analyze_reference_image_pixels(false)


func _on_image_color_limit_changed(value: float) -> void:
	if suppress_image_color_limit_signal:
		return
	if image_pixel_palette_full.is_empty():
		return
	var clamped_limit: int = clampi(int(value), 1, image_pixel_palette_full.size())
	if clamped_limit != int(value):
		suppress_image_color_limit_signal = true
		image_color_limit_spinbox.value = clamped_limit
		suppress_image_color_limit_signal = false
	_apply_image_pixel_palette_limit(clamped_limit, true)


func _on_image_merge_tolerance_changed(value: float) -> void:
	if suppress_merge_tolerance_signal:
		return
	var clamped_value: int = clampi(int(value), 0, 100)
	if clamped_value != int(value):
		suppress_merge_tolerance_signal = true
		image_merge_tolerance_spinbox.value = clamped_value
		suppress_merge_tolerance_signal = false
	image_merge_tolerance_percent = clamped_value
	if FileAccess.file_exists(current_reference_image_path):
		_analyze_reference_image_pixels(true)


func _on_language_toggle_pressed() -> void:
	if current_language == LANG_ZH:
		current_language = LANG_EN
	else:
		current_language = LANG_ZH
	_apply_ui_language()


func _try_pick_palette_by_number(keycode: Key) -> void:
	var idx := -1
	match keycode:
		KEY_1:
			idx = 0
		KEY_2:
			idx = 1
		KEY_3:
			idx = 2
		KEY_4:
			idx = 3
		KEY_5:
			idx = 4
		KEY_6:
			idx = 5
		KEY_7:
			idx = 6
		KEY_8:
			idx = 7
		KEY_9:
			idx = 8
	if idx >= 0 and idx < palette.size():
		selected_color_idx = idx
		queue_redraw()


func _export_png() -> void:
	_ensure_output_dir()
	var img := Image.create(grid_width, grid_height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in grid_height:
		for x in grid_width:
			var px: int = pixels[y][x]
			if px >= 0 and px < palette.size():
				img.set_pixel(x, y, palette[px])

	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var save_path := "%s/pixel_art_%s.png" % [OUTPUT_DIR, stamp]
	var result := img.save_png(save_path)
	if result == OK:
		print("导出成功: ", save_path)
	else:
		push_error("导出失败，错误码: %s" % str(result))


func _export_config_json() -> void:
	_ensure_config_dir()
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("导出配置失败，无法写入: %s" % CONFIG_PATH)
		return

	var data := _build_config_data()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("配置导出成功: ", CONFIG_PATH)


func _import_config_json() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("导入配置失败，文件不存在: %s" % CONFIG_PATH)
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("导入配置失败，无法读取: %s" % CONFIG_PATH)
		return

	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("导入配置失败，JSON格式错误。")
		return

	_apply_config_data(parsed as Dictionary)
	print("配置导入成功: ", CONFIG_PATH)


func _build_config_data() -> Dictionary:
	var palette_hex: Array[String] = []
	for color_item in palette:
		palette_hex.append("#%s" % color_item.to_html(false))

	var pixel_rows: Array = []
	for y in grid_height:
		var row: Array[int] = []
		for x in grid_width:
			row.append(pixels[y][x])
		pixel_rows.append(row)

	return {
		"version": 1,
		"meta": {
			"tool": "godot-pixel-painter",
			"preset_name": current_preset_name
		},
		"grid": {
			"width": grid_width,
			"height": grid_height,
			"cell_size": cell_size
		},
		"palette": palette_hex,
		"pixels": pixel_rows
	}


func _apply_config_data(config: Dictionary) -> void:
	if not config.has("grid") or not config.has("palette") or not config.has("pixels"):
		push_error("导入配置失败，缺少 grid/palette/pixels 字段。")
		return

	var grid := config["grid"] as Dictionary
	var width := clampi(int(grid.get("width", grid_width)), 1, 512)
	var height := clampi(int(grid.get("height", grid_height)), 1, 512)
	var imported_cell_size := clampi(int(grid.get("cell_size", cell_size)), 4, 64)

	var imported_palette_raw := config["palette"] as Array
	var imported_palette: Array[Color] = []
	for p in imported_palette_raw:
		if p is String:
			imported_palette.append(Color.from_string(p, Color(1, 1, 1, 1)))
	if imported_palette.is_empty():
		push_error("导入配置失败，palette 为空或非法。")
		return

	grid_width = width
	grid_height = height
	cell_size = imported_cell_size
	palette = imported_palette
	selected_color_idx = clampi(selected_color_idx, 0, max(palette.size() - 1, 0))
	current_preset_name = str((config.get("meta", {}) as Dictionary).get("preset_name", "自定义"))

	_init_pixels()
	var imported_pixels: Array = config["pixels"] as Array
	var max_y: int = min(grid_height, imported_pixels.size())
	for y in range(max_y):
		if not (imported_pixels[y] is Array):
			continue
		var row: Array = imported_pixels[y] as Array
		var max_x: int = min(grid_width, row.size())
		for x in range(max_x):
			var value: int = int(row[x])
			if value < -1 or value >= palette.size():
				value = -1
			pixels[y][x] = value

	_sync_canvas_origin()
	_refresh_toolbar_ui()
	queue_redraw()


func _ensure_config_dir() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://configs")):
		return
	var error_code := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://configs"))
	if error_code != OK:
		push_error("创建配置目录失败，错误码: %s" % str(error_code))


func _ensure_output_dir() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)):
		return
	var error_code := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if error_code != OK:
		push_error("创建输出目录失败，错误码: %s" % str(error_code))


func _setup_reference_file_dialog(parent_node: Node) -> void:
	reference_file_dialog = FileDialog.new()
	reference_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	reference_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	reference_file_dialog.use_native_dialog = true
	reference_file_dialog.file_selected.connect(_on_reference_file_selected)
	parent_node.add_child(reference_file_dialog)
	_update_reference_dialog_text()


func _ui_text(key: String) -> String:
	if not ui_texts.has(current_language):
		return key
	var lang_dict: Dictionary = ui_texts[current_language] as Dictionary
	return str(lang_dict.get(key, key))


func _apply_ui_language() -> void:
	if size_label != null:
		size_label.text = _ui_text("size")
	if preset_label != null:
		preset_label.text = _ui_text("palette")
	if clear_button != null:
		clear_button.text = _ui_text("clear")
	if export_button != null:
		export_button.text = _ui_text("export_png")
	if export_config_button != null:
		export_config_button.text = _ui_text("export_cfg")
	if import_config_button != null:
		import_config_button.text = _ui_text("import_cfg")
	if quantize_button != null:
		quantize_button.text = _ui_text("quantize")
	if pick_image_button != null:
		pick_image_button.text = _ui_text("pick_image")
	if recommend_palette_button != null:
		recommend_palette_button.text = _ui_text("recommend")
	if analyze_pixels_button != null:
		analyze_pixels_button.text = _ui_text("analyze")
	if color_limit_label != null:
		color_limit_label.text = _ui_text("limit")
	if merge_tolerance_label != null:
		merge_tolerance_label.text = _ui_text("tolerance")
	if language_toggle_button != null:
		language_toggle_button.text = _ui_text("lang_toggle")
	_update_reference_dialog_text()


func _update_reference_dialog_text() -> void:
	if reference_file_dialog == null:
		return
	reference_file_dialog.title = _ui_text("dialog_title")
	if current_language == LANG_EN:
		reference_file_dialog.filters = PackedStringArray([
			"*.png ; PNG Image",
			"*.jpg,*.jpeg ; JPEG Image",
			"*.webp ; WEBP Image"
		])
	else:
		reference_file_dialog.filters = PackedStringArray([
			"*.png ; PNG 图片",
			"*.jpg,*.jpeg ; JPEG 图片",
			"*.webp ; WEBP 图片"
		])


func _refresh_preset_option_items() -> void:
	if preset_option_button == null:
		return
	preset_option_button.clear()
	for name in preset_order:
		if preset_palettes.has(name):
			preset_option_button.add_item(name)


func _disable_image_color_limit_ui() -> void:
	if image_color_limit_spinbox == null:
		return
	suppress_image_color_limit_signal = true
	image_color_limit_spinbox.min_value = 1
	image_color_limit_spinbox.max_value = 1
	image_color_limit_spinbox.value = 1
	image_color_limit_spinbox.editable = false
	suppress_image_color_limit_signal = false


func _set_image_color_limit_ui(max_colors: int, selected_value: int = -1) -> void:
	if image_color_limit_spinbox == null:
		return
	var clamped_max: int = max(1, max_colors)
	var final_value: int = clamped_max
	if selected_value >= 1:
		final_value = clampi(selected_value, 1, clamped_max)
	suppress_image_color_limit_signal = true
	image_color_limit_spinbox.min_value = 1
	image_color_limit_spinbox.max_value = clamped_max
	image_color_limit_spinbox.value = final_value
	image_color_limit_spinbox.editable = true
	suppress_image_color_limit_signal = false


func _clear_image_pixel_palette_preset() -> void:
	image_pixel_palette_full.clear()
	image_pixel_palette_counts.clear()
	image_pixel_source = null
	if preset_palettes.has(IMAGE_PIXEL_PRESET_NAME):
		preset_palettes.erase(IMAGE_PIXEL_PRESET_NAME)
	if current_preset_name == IMAGE_PIXEL_PRESET_NAME:
		_apply_preset_palette("默认8色")
	_disable_image_color_limit_ui()
	_refresh_toolbar_ui()


func _analyze_reference_image_pixels(keep_limit_value: bool) -> void:
	var resized: Image = _load_reference_resized_image(current_reference_image_path, Image.INTERPOLATE_NEAREST)
	if resized == null:
		return

	var prev_limit: int = image_pixel_palette_full.size()
	if keep_limit_value and image_color_limit_spinbox != null and image_color_limit_spinbox.editable:
		prev_limit = int(image_color_limit_spinbox.value)

	var merged_colors: Array[Color] = []
	var merged_counts: Array[int] = []
	var sum_r: Array[float] = []
	var sum_g: Array[float] = []
	var sum_b: Array[float] = []
	var merge_threshold: float = _get_image_merge_threshold()

	for y in range(grid_height):
		for x in range(grid_width):
			var c: Color = resized.get_pixel(x, y)
			if c.a < 0.1:
				continue

			var nearest: Dictionary = _find_nearest_color_index_in_colors(c, merged_colors)
			var nearest_idx: int = int(nearest.get("index", -1))
			var nearest_dist: float = float(nearest.get("distance", INF))
			if nearest_idx >= 0 and nearest_dist <= merge_threshold:
				merged_counts[nearest_idx] += 1
				sum_r[nearest_idx] += c.r
				sum_g[nearest_idx] += c.g
				sum_b[nearest_idx] += c.b
				var cnt: float = float(merged_counts[nearest_idx])
				merged_colors[nearest_idx] = Color(
					sum_r[nearest_idx] / cnt,
					sum_g[nearest_idx] / cnt,
					sum_b[nearest_idx] / cnt,
					1.0
				)
			else:
				merged_colors.append(c)
				merged_counts.append(1)
				sum_r.append(c.r)
				sum_g.append(c.g)
				sum_b.append(c.b)

	if merged_colors.is_empty():
		push_error("分析失败，参考图像有效像素为空。")
		return

	var sorted_indices: Array[int] = []
	for i in range(merged_colors.size()):
		var inserted: bool = false
		for j in range(sorted_indices.size()):
			var other_idx: int = sorted_indices[j]
			if merged_counts[i] > merged_counts[other_idx]:
				sorted_indices.insert(j, i)
				inserted = true
				break
		if not inserted:
			sorted_indices.append(i)

	image_pixel_palette_full.clear()
	image_pixel_palette_counts.clear()
	for color_idx in sorted_indices:
		image_pixel_palette_full.append(merged_colors[color_idx])
		image_pixel_palette_counts.append(merged_counts[color_idx])

	image_pixel_source = resized
	if not preset_order.has(IMAGE_PIXEL_PRESET_NAME):
		preset_order.append(IMAGE_PIXEL_PRESET_NAME)
	var target_limit: int = clampi(prev_limit, 1, image_pixel_palette_full.size())
	_set_image_color_limit_ui(image_pixel_palette_full.size(), target_limit)
	_apply_image_pixel_palette_limit(target_limit, true)
	print("图像像素分析完成: 颜色种类=%d, 宽容度=%d, 阈值=%.4f, 来源=%s" % [
		image_pixel_palette_full.size(),
		image_merge_tolerance_percent,
		merge_threshold,
		current_reference_image_path
	])


func _apply_image_pixel_palette_limit(limit: int, quantize_canvas: bool) -> void:
	if image_pixel_palette_full.is_empty():
		return
	var clamped_limit: int = clampi(limit, 1, image_pixel_palette_full.size())
	var limited_palette: Array[Color] = []
	for i in range(clamped_limit):
		limited_palette.append(image_pixel_palette_full[i])
	preset_palettes[IMAGE_PIXEL_PRESET_NAME] = limited_palette
	_apply_preset_palette(IMAGE_PIXEL_PRESET_NAME)
	if quantize_canvas and image_pixel_source != null:
		_quantize_image_to_pixels(image_pixel_source, limited_palette)


func _load_reference_resized_image(image_path: String, interpolation: int) -> Image:
	if not FileAccess.file_exists(image_path):
		push_error("读取失败，参考图不存在: %s" % image_path)
		return null
	var image := Image.new()
	var load_result: int = image.load(image_path)
	if load_result != OK:
		push_error("读取失败，无法加载参考图，错误码: %s" % str(load_result))
		return null
	var resized: Image = image.duplicate()
	resized.resize(grid_width, grid_height, interpolation)
	return resized


func _quantize_image_to_pixels(source: Image, target_palette: Array[Color]) -> void:
	if source == null or target_palette.is_empty():
		return
	_init_pixels()
	for y in range(grid_height):
		for x in range(grid_width):
			var c: Color = source.get_pixel(x, y)
			if c.a < 0.1:
				pixels[y][x] = -1
			else:
				pixels[y][x] = _find_nearest_palette_index_in_array(c, target_palette)
	queue_redraw()


func _get_image_merge_threshold() -> float:
	var t: float = clampf(float(image_merge_tolerance_percent) / 100.0, 0.0, 1.0)
	# Weighted distance max is about 3.0; use squared curve for finer low-end control.
	return 3.0 * t * t


func _find_nearest_color_index_in_colors(target: Color, color_list: Array[Color]) -> Dictionary:
	if color_list.is_empty():
		return {"index": -1, "distance": INF}
	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(color_list.size()):
		var dist: float = _color_distance_weighted(target, color_list[i])
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return {"index": best_idx, "distance": best_dist}


func _import_reference_and_quantize() -> void:
	_import_reference_and_quantize_from_path(current_reference_image_path)


func _import_reference_and_quantize_from_path(image_path: String) -> void:
	if not FileAccess.file_exists(image_path):
		push_error("像素化失败，参考图不存在: %s" % image_path)
		return
	if palette.is_empty():
		push_error("像素化失败，当前调色板为空。")
		return

	var image := Image.new()
	var load_result: int = image.load(image_path)
	if load_result != OK:
		push_error("像素化失败，读取参考图失败，错误码: %s" % str(load_result))
		return

	var resized: Image = image.duplicate()
	resized.resize(grid_width, grid_height, Image.INTERPOLATE_BILINEAR)
	_quantize_image_to_pixels(resized, palette)
	print("参考图像素化完成: ", image_path)


func _find_nearest_palette_index(target: Color) -> int:
	return _find_nearest_palette_index_in_array(target, palette)


func _find_nearest_palette_index_in_array(target: Color, palette_array: Array) -> int:
	var best_index: int = 0
	var best_dist: float = INF
	for i in range(palette_array.size()):
		var pc: Color = palette_array[i] as Color
		var dr: float = target.r - pc.r
		var dg: float = target.g - pc.g
		var db: float = target.b - pc.b
		# Green channel usually contributes more to perceived luminance.
		var dist: float = dr * dr * 0.9 + dg * dg * 1.2 + db * db * 0.9
		if dist < best_dist:
			best_dist = dist
			best_index = i
	return best_index


func _recommend_best_preset_palette() -> void:
	if not FileAccess.file_exists(current_reference_image_path):
		push_error("推荐失败，参考图不存在: %s" % current_reference_image_path)
		return

	var image := Image.new()
	var load_result: int = image.load(current_reference_image_path)
	if load_result != OK:
		push_error("推荐失败，读取参考图失败，错误码: %s" % str(load_result))
		return

	var resized: Image = image.duplicate()
	resized.resize(grid_width, grid_height, Image.INTERPOLATE_BILINEAR)

	var best_name: String = ""
	var best_error: float = INF
	var top_names: Array[String] = ["", "", ""]
	var top_errors: Array[float] = [INF, INF, INF]

	for preset_name in preset_order:
		if not preset_palettes.has(preset_name):
			continue
		var candidate_any: Variant = preset_palettes[preset_name]
		if not (candidate_any is Array):
			continue
		var candidate: Array = candidate_any as Array
		if candidate.is_empty():
			continue

		var error_value: float = _calculate_quantization_error(resized, candidate)
		_insert_top_result(preset_name, error_value, top_names, top_errors)
		if error_value < best_error:
			best_error = error_value
			best_name = preset_name

	if best_name == "":
		push_error("推荐失败，可用调色板为空。")
		return

	_apply_preset_palette(best_name)
	print("推荐调色板: %s (平均误差=%.6f)" % [best_name, best_error])
	for i in range(3):
		if top_names[i] != "":
			print("Top%d: %s (%.6f)" % [i + 1, top_names[i], top_errors[i]])


func _calculate_quantization_error(source: Image, candidate_palette: Array) -> float:
	var total_error: float = 0.0
	var count: int = 0
	for y in range(grid_height):
		for x in range(grid_width):
			var c: Color = source.get_pixel(x, y)
			if c.a < 0.1:
				continue
			var nearest_idx: int = _find_nearest_palette_index_in_array(c, candidate_palette)
			var nearest_color: Color = candidate_palette[nearest_idx] as Color
			total_error += _color_distance_weighted(c, nearest_color)
			count += 1
	if count == 0:
		return INF
	return total_error / float(count)


func _insert_top_result(name: String, error_value: float, names: Array[String], errors: Array[float]) -> void:
	for i in range(3):
		if error_value < errors[i]:
			for j in range(2, i, -1):
				errors[j] = errors[j - 1]
				names[j] = names[j - 1]
			errors[i] = error_value
			names[i] = name
			return


func _color_distance_weighted(a: Color, b: Color) -> float:
	var dr: float = a.r - b.r
	var dg: float = a.g - b.g
	var db: float = a.b - b.b
	return dr * dr * 0.9 + dg * dg * 1.2 + db * db * 0.9
