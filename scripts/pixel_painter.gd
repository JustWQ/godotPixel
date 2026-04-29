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
var pick_image_button: Button
var recommend_palette_button: Button
var compose_sheet_button: Button
var current_reference_image_path: String = REFERENCE_IMAGE_PATH
var analyze_pixels_button: Button
var color_limit_label: Label
var image_color_limit_spinbox: SpinBox
var image_color_limit_max_button: Button
var merge_tolerance_label: Label
var image_merge_tolerance_spinbox: SpinBox
var language_toggle_button: Button
var frames_toggle_button: Button
var offset_toggle_button: Button
var suppress_image_color_limit_signal: bool = false
var suppress_merge_tolerance_signal: bool = false
var image_merge_tolerance_percent: int = 0
var current_language: String = LANG_ZH
var sprite_sheet_file_dialog: FileDialog
var frame_split_window: Window
var frame_rows_label: Label
var frame_rows_spinbox: SpinBox
var frame_cols_label: Label
var frame_cols_spinbox: SpinBox
var frame_apply_grid_button: Button
var frame_crop_button: Button
var frame_preview_texture_rect: TextureRect
var frame_grid_overlay: Control
var frame_selection_overlay: ColorRect
var frame_preview_bar: PanelContainer
var frame_preview_scroll: ScrollContainer
var frame_preview_hbox: HBoxContainer
var frame_offset_target_frame_index: int = -1
var frame_offset_mode_active: bool = false
var frame_offset_pixels: Vector2i = Vector2i.ZERO
var frame_offset_dragging: bool = false
var frame_offset_drag_start_mouse: Vector2 = Vector2.ZERO
var frame_offset_drag_start_pixels: Vector2i = Vector2i.ZERO
var sprite_sheet_image: Image
var sprite_sheet_texture: ImageTexture
var frame_rects: Array[Rect2i] = []
var frame_split_rows: int = 3
var frame_split_cols: int = 3
var editing_frame_index: int = -1
var selected_preview_frame_index: int = -1
var frame_selection_rect: Rect2i = Rect2i()
var is_dragging_frame_selection: bool = false
var frame_drag_start_local: Vector2 = Vector2.ZERO
var ui_texts: Dictionary = {
	LANG_ZH: {
		"size": "画布:",
		"palette": "调色板:",
		"clear": "清空",
		"export_png": "导出PNG",
		"export_cfg": "导出配置",
		"import_cfg": "导入配置",
		"pick_image": "选择图片像素化",
		"recommend": "推荐调色板",
		"compose_sheet": "生成整图",
		"analyze": "分析图像像素",
		"limit": "限色:",
		"limit_max": "最大",
		"tolerance": "宽容度:",
		"lang_toggle": "EN",
		"frames_toggle": "帧",
		"offset_toggle": "偏",
		"offset_apply_toggle": "应用偏移",
		"dialog_title": "选择参考图片",
		"sheet_dialog_title": "选择序列帧图片",
		"frame_window_title": "帧分割窗口",
		"rows": "行:",
		"cols": "列:",
		"apply_grid": "应用网格切割",
		"crop_image": "裁剪图片",
		"start_hint": "像素画工具已启动。左键上色，右键擦除，中键拖动画布，滚轮缩放，数字键 1-9 选色，C 清空，E 或按钮导出 PNG。"
	},
	LANG_EN: {
		"size": "Canvas:",
		"palette": "Palette:",
		"clear": "Clear",
		"export_png": "ExportPNG",
		"export_cfg": "SaveCfg",
		"import_cfg": "LoadCfg",
		"pick_image": "PickImage",
		"recommend": "BestPal",
		"compose_sheet": "Compose",
		"analyze": "Analyze",
		"limit": "Limit:",
		"limit_max": "Max",
		"tolerance": "Tolerance:",
		"lang_toggle": "中",
		"frames_toggle": "FR",
		"offset_toggle": "OF",
		"offset_apply_toggle": "ApplyOfs",
		"dialog_title": "Select Reference Image",
		"sheet_dialog_title": "Select Sprite Sheet",
		"frame_window_title": "Frame Split",
		"rows": "Rows:",
		"cols": "Cols:",
		"apply_grid": "Apply Grid",
		"crop_image": "Crop Image",
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
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			frame_offset_dragging = false
			return
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
				if frame_offset_mode_active:
					if _mouse_to_cell(mouse_event.position).x >= 0:
						frame_offset_dragging = true
						frame_offset_drag_start_mouse = mouse_event.position
						frame_offset_drag_start_pixels = frame_offset_pixels
					return
				if _try_select_palette(mouse_event.position):
					queue_redraw()
					return
				_try_paint(mouse_event.position, selected_color_idx)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				if frame_offset_mode_active:
					return
				_try_paint(mouse_event.position, -1)
	elif event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if motion_event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			canvas_pan += motion_event.relative
			queue_redraw()
		elif frame_offset_mode_active and frame_offset_dragging and (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var scaled_cell_size: float = float(cell_size) * canvas_zoom
			if scaled_cell_size > 0.0:
				var delta: Vector2 = motion_event.position - frame_offset_drag_start_mouse
				var delta_cell_x: int = int(round(delta.x / scaled_cell_size))
				var delta_cell_y: int = int(round(delta.y / scaled_cell_size))
				frame_offset_pixels.x = clampi(frame_offset_drag_start_pixels.x + delta_cell_x, -grid_width, grid_width)
				frame_offset_pixels.y = clampi(frame_offset_drag_start_pixels.y + delta_cell_y, -grid_height, grid_height)
				queue_redraw()
		elif motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if frame_offset_mode_active:
				return
			_try_paint(motion_event.position, selected_color_idx)
		elif motion_event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			if frame_offset_mode_active:
				return
			_try_paint(motion_event.position, -1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_LEFT:
			_select_preview_frame_by_offset(-1)
		elif key_event.keycode == KEY_RIGHT:
			_select_preview_frame_by_offset(1)
		elif key_event.keycode == KEY_C:
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

	pick_image_button = Button.new()
	pick_image_button.pressed.connect(_on_pick_image_pressed)
	hbox.add_child(pick_image_button)

	recommend_palette_button = Button.new()
	recommend_palette_button.pressed.connect(_on_recommend_palette_pressed)
	hbox.add_child(recommend_palette_button)

	compose_sheet_button = Button.new()
	compose_sheet_button.pressed.connect(_on_compose_sheet_pressed)
	hbox.add_child(compose_sheet_button)

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

	image_color_limit_max_button = Button.new()
	image_color_limit_max_button.pressed.connect(_on_image_color_limit_max_pressed)
	hbox.add_child(image_color_limit_max_button)
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
	_setup_sprite_sheet_file_dialog(toolbar_layer)
	_setup_frame_split_window(toolbar_layer)
	_setup_frame_preview_bar(toolbar_layer)
	_setup_language_toggle_ui(toolbar_layer)
	_refresh_toolbar_ui()


func _setup_language_toggle_ui(parent_layer: CanvasLayer) -> void:
	language_toggle_button = Button.new()
	language_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	language_toggle_button.offset_left = -126
	language_toggle_button.offset_top = 8
	language_toggle_button.offset_right = -92
	language_toggle_button.offset_bottom = 36
	language_toggle_button.custom_minimum_size = Vector2(34, 28)
	language_toggle_button.clip_text = true
	language_toggle_button.pressed.connect(_on_language_toggle_pressed)
	parent_layer.add_child(language_toggle_button)

	frames_toggle_button = Button.new()
	frames_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	frames_toggle_button.offset_left = -84
	frames_toggle_button.offset_top = 8
	frames_toggle_button.offset_right = -50
	frames_toggle_button.offset_bottom = 36
	frames_toggle_button.custom_minimum_size = Vector2(34, 28)
	frames_toggle_button.clip_text = true
	frames_toggle_button.pressed.connect(_on_frames_toggle_pressed)
	parent_layer.add_child(frames_toggle_button)

	offset_toggle_button = Button.new()
	offset_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_toggle_button.offset_left = -42
	offset_toggle_button.offset_top = 8
	offset_toggle_button.offset_right = -8
	offset_toggle_button.offset_bottom = 36
	offset_toggle_button.custom_minimum_size = Vector2(34, 28)
	offset_toggle_button.clip_text = true
	offset_toggle_button.pressed.connect(_on_offset_toggle_pressed)
	parent_layer.add_child(offset_toggle_button)


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

	if frame_offset_mode_active:
		var overlay_origin: Vector2 = draw_origin + Vector2(float(frame_offset_pixels.x) * scaled_cell_size, float(frame_offset_pixels.y) * scaled_cell_size)
		var overlay_rect := Rect2(overlay_origin, canvas_size)
		draw_rect(overlay_rect, Color(0.2, 1.0, 0.25, 0.22), true)
		var overlay_line_width: float = maxf(1.0, canvas_zoom * 0.7)
		for oy in range(grid_height + 1):
			var y_pos := overlay_origin.y + oy * scaled_cell_size
			draw_line(
				Vector2(overlay_origin.x, y_pos),
				Vector2(overlay_origin.x + grid_width * scaled_cell_size, y_pos),
				Color(0.2, 1.0, 0.35, 0.85),
				overlay_line_width
			)
		for ox in range(grid_width + 1):
			var x_pos := overlay_origin.x + ox * scaled_cell_size
			draw_line(
				Vector2(x_pos, overlay_origin.y),
				Vector2(x_pos, overlay_origin.y + grid_height * scaled_cell_size),
				Color(0.2, 1.0, 0.35, 0.85),
				overlay_line_width
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


func _on_compose_sheet_pressed() -> void:
	_export_composed_sheet_png()


func _on_analyze_image_pixels_pressed() -> void:
	_analyze_reference_image_pixels(false)


func _on_image_color_limit_changed(value: float) -> void:
	if suppress_image_color_limit_signal:
		return
	_normalize_color_limit_spinbox_value()
	if image_pixel_palette_full.is_empty():
		return
	var clamped_limit: int = clampi(int(value), 1, image_pixel_palette_full.size())
	if clamped_limit != int(value):
		suppress_image_color_limit_signal = true
		image_color_limit_spinbox.value = clamped_limit
		suppress_image_color_limit_signal = false
	_apply_image_pixel_palette_limit(clamped_limit, true)


func _on_image_color_limit_max_pressed() -> void:
	if image_color_limit_spinbox == null:
		return
	if image_color_limit_spinbox.max_value < 1:
		return
	var max_value: int = int(image_color_limit_spinbox.max_value)
	image_color_limit_spinbox.value = max_value
	_apply_image_pixel_palette_limit(max_value, true)


func _on_image_merge_tolerance_changed(value: float) -> void:
	if suppress_merge_tolerance_signal:
		return
	var clamped_value: int = clampi(int(value), 0, 100)
	if clamped_value != int(value):
		suppress_merge_tolerance_signal = true
		image_merge_tolerance_spinbox.value = clamped_value
		suppress_merge_tolerance_signal = false
	image_merge_tolerance_percent = clamped_value
	if _has_active_source_image():
		_analyze_reference_image_pixels(true)


func _on_language_toggle_pressed() -> void:
	if current_language == LANG_ZH:
		current_language = LANG_EN
	else:
		current_language = LANG_ZH
	_apply_ui_language()


func _on_frames_toggle_pressed() -> void:
	if sprite_sheet_file_dialog == null:
		push_error("序列帧文件选择框未初始化。")
		return
	sprite_sheet_file_dialog.popup_centered_ratio(0.7)


func _on_offset_toggle_pressed() -> void:
	if not frame_offset_mode_active:
		if not _has_selected_frame_source():
			push_error("请先在底部预览中左键选中一个帧。")
			return
		frame_offset_target_frame_index = selected_preview_frame_index
		frame_offset_pixels = Vector2i.ZERO
		frame_offset_dragging = false
		frame_offset_mode_active = true
		_update_offset_toggle_button_text()
		queue_redraw()
		return
	_apply_frame_offset_to_target_frame()
	frame_offset_mode_active = false
	frame_offset_dragging = false
	frame_offset_pixels = Vector2i.ZERO
	_update_offset_toggle_button_text()
	queue_redraw()


func _on_sprite_sheet_selected(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("序列帧加载失败，文件不存在: %s" % path)
		return
	var image := Image.new()
	var load_result: int = image.load(path)
	if load_result != OK:
		push_error("序列帧加载失败，错误码: %s" % str(load_result))
		return
	sprite_sheet_image = image
	sprite_sheet_texture = ImageTexture.create_from_image(sprite_sheet_image)
	frame_split_rows = 3
	frame_split_cols = 3
	frame_offset_mode_active = false
	frame_offset_pixels = Vector2i.ZERO
	frame_offset_target_frame_index = -1
	_update_offset_toggle_button_text()
	_apply_grid_split_to_frames()
	_open_frame_split_window(-1)


func _on_frame_grid_apply_pressed() -> void:
	frame_split_rows = clampi(int(frame_rows_spinbox.value), 1, 128)
	frame_split_cols = clampi(int(frame_cols_spinbox.value), 1, 128)
	_apply_grid_split_to_frames()
	_sync_frame_selection_with_editing_frame()


func _apply_frame_offset_to_target_frame() -> void:
	if sprite_sheet_image == null:
		return
	if frame_offset_target_frame_index < 0 or frame_offset_target_frame_index >= frame_rects.size():
		return
	var rect: Rect2i = frame_rects[frame_offset_target_frame_index]
	var src_img: Image = sprite_sheet_image.get_region(rect)
	var out_img: Image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	out_img.fill(Color(0, 0, 0, 0))
	var dx: int = int(round(float(frame_offset_pixels.x) * float(rect.size.x) / maxf(1.0, float(grid_width))))
	var dy: int = int(round(float(frame_offset_pixels.y) * float(rect.size.y) / maxf(1.0, float(grid_height))))
	# "Shift canvas" semantics: moving green canvas right/down samples from
	# right/down area of old content, so visible content appears left/up.
	for y in range(out_img.get_height()):
		for x in range(out_img.get_width()):
			var src_x: int = x + dx
			var src_y: int = y + dy
			if src_x < 0 or src_y < 0 or src_x >= src_img.get_width() or src_y >= src_img.get_height():
				continue
			out_img.set_pixel(x, y, src_img.get_pixel(src_x, src_y))

	for y in range(rect.size.y):
		for x in range(rect.size.x):
			sprite_sheet_image.set_pixel(rect.position.x + x, rect.position.y + y, out_img.get_pixel(x, y))

	sprite_sheet_texture = ImageTexture.create_from_image(sprite_sheet_image)
	if frame_preview_texture_rect != null:
		frame_preview_texture_rect.texture = sprite_sheet_texture
	_refresh_frame_preview_strip()
	_load_frame_to_canvas(frame_offset_target_frame_index)


func _on_frame_preview_gui_input(event: InputEvent) -> void:
	if sprite_sheet_image == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			is_dragging_frame_selection = true
			frame_drag_start_local = mb.position
			_update_frame_selection_from_drag(frame_drag_start_local, frame_drag_start_local)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if is_dragging_frame_selection:
				is_dragging_frame_selection = false
				_update_frame_selection_from_drag(frame_drag_start_local, mb.position)
				if editing_frame_index >= 0 and editing_frame_index < frame_rects.size():
					frame_rects[editing_frame_index] = frame_selection_rect
					_refresh_frame_preview_strip()
			return
	elif event is InputEventMouseMotion and is_dragging_frame_selection:
		var mm := event as InputEventMouseMotion
		_update_frame_selection_from_drag(frame_drag_start_local, mm.position)


func _on_frame_crop_button_pressed() -> void:
	if sprite_sheet_image == null:
		push_error("请先选择序列帧图片。")
		return
	if frame_selection_rect.size.x <= 0 or frame_selection_rect.size.y <= 0:
		var img_w: int = sprite_sheet_image.get_width()
		var img_h: int = sprite_sheet_image.get_height()
		var margin_x: int = maxi(1, int(round(float(img_w) * 0.1)))
		var margin_y: int = maxi(1, int(round(float(img_h) * 0.1)))
		var start_x: int = clampi(margin_x, 0, img_w - 1)
		var start_y: int = clampi(margin_y, 0, img_h - 1)
		var end_x: int = clampi(img_w - margin_x, start_x + 1, img_w)
		var end_y: int = clampi(img_h - margin_y, start_y + 1, img_h)
		frame_selection_rect = Rect2i(start_x, start_y, end_x - start_x, end_y - start_y)
		_update_frame_selection_overlay()
		return

	var crop_rect: Rect2i = frame_selection_rect
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		push_error("裁剪失败，选区无效。")
		return

	sprite_sheet_image = sprite_sheet_image.get_region(crop_rect)
	sprite_sheet_texture = ImageTexture.create_from_image(sprite_sheet_image)
	if frame_preview_texture_rect != null:
		frame_preview_texture_rect.texture = sprite_sheet_texture
	frame_selection_rect = Rect2i()
	editing_frame_index = -1
	frame_selection_overlay.visible = false
	_apply_grid_split_to_frames()
	_refresh_frame_grid_overlay()


func _on_frame_thumb_gui_input(event: InputEvent, frame_index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		selected_preview_frame_index = frame_index
		if frame_offset_mode_active:
			frame_offset_target_frame_index = frame_index
			frame_offset_pixels = Vector2i.ZERO
		# Switching selected frame should immediately rebuild image-pixel analysis data,
		# so "limit colors" works without requiring a tolerance tweak first.
		_analyze_reference_image_pixels(false)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_load_frame_to_canvas(frame_index)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_refresh_frame_preview_strip()
			_open_frame_split_window(frame_index)


func _select_preview_frame_by_offset(step: int) -> void:
	if step == 0:
		return
	if frame_rects.is_empty():
		return
	var current_idx: int = selected_preview_frame_index
	if current_idx < 0 or current_idx >= frame_rects.size():
		current_idx = 0 if step > 0 else frame_rects.size() - 1
	else:
		current_idx = (current_idx + step + frame_rects.size()) % frame_rects.size()
	selected_preview_frame_index = current_idx
	if frame_offset_mode_active:
		frame_offset_target_frame_index = current_idx
		frame_offset_pixels = Vector2i.ZERO
	_analyze_reference_image_pixels(false)
	_load_frame_to_canvas(current_idx)


func _on_frame_split_window_close_requested() -> void:
	if frame_split_window != null:
		frame_split_window.hide()


func _on_frame_preview_resized() -> void:
	_refresh_frame_grid_overlay()
	_update_frame_selection_overlay()


func _on_frame_grid_value_changed(_value: float) -> void:
	frame_split_rows = clampi(int(frame_rows_spinbox.value), 1, 128)
	frame_split_cols = clampi(int(frame_cols_spinbox.value), 1, 128)
	_refresh_frame_grid_overlay()


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


func _export_composed_sheet_png() -> void:
	if sprite_sheet_image == null or frame_rects.is_empty():
		push_error("生成整图失败，请先导入并切出预览帧。")
		return

	var frame_count: int = frame_rects.size()
	var cell_w: int = 1
	var cell_h: int = 1
	for rect_any in frame_rects:
		var rect: Rect2i = rect_any as Rect2i
		cell_w = max(cell_w, rect.size.x)
		cell_h = max(cell_h, rect.size.y)

	var cols: int = maxi(1, int(ceili(sqrt(float(frame_count)))))
	var rows: int = int(ceili(float(frame_count) / float(cols)))
	var out_w: int = cols * cell_w
	var out_h: int = rows * cell_h

	var out_img: Image = Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	out_img.fill(Color(0, 0, 0, 0))
	for i in range(frame_count):
		var src_rect: Rect2i = frame_rects[i]
		var src_img: Image = sprite_sheet_image.get_region(src_rect)
		var col: int = i % cols
		var row: int = i / cols
		var dst_x0: int = col * cell_w
		var dst_y0: int = row * cell_h
		for y in range(src_img.get_height()):
			for x in range(src_img.get_width()):
				out_img.set_pixel(dst_x0 + x, dst_y0 + y, src_img.get_pixel(x, y))

	_ensure_output_dir()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var save_path := "%s/frame_sheet_%s.png" % [OUTPUT_DIR, stamp]
	var result: int = out_img.save_png(save_path)
	if result == OK:
		print("整图生成成功: %s (frames=%d, grid=%dx%d, cell=%dx%d)" % [save_path, frame_count, cols, rows, cell_w, cell_h])
	else:
		push_error("整图生成失败，错误码: %s" % str(result))


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


func _setup_sprite_sheet_file_dialog(parent_node: Node) -> void:
	sprite_sheet_file_dialog = FileDialog.new()
	sprite_sheet_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	sprite_sheet_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	sprite_sheet_file_dialog.use_native_dialog = true
	sprite_sheet_file_dialog.file_selected.connect(_on_sprite_sheet_selected)
	parent_node.add_child(sprite_sheet_file_dialog)
	_update_sprite_sheet_dialog_text()


func _setup_frame_split_window(parent_node: Node) -> void:
	frame_split_window = Window.new()
	frame_split_window.unresizable = false
	frame_split_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	frame_split_window.size = Vector2i(620, 480)
	frame_split_window.close_requested.connect(_on_frame_split_window_close_requested)
	parent_node.add_child(frame_split_window)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	frame_split_window.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)

	frame_rows_label = Label.new()
	frame_rows_label.name = "RowsLabel"
	top.add_child(frame_rows_label)

	frame_rows_spinbox = SpinBox.new()
	frame_rows_spinbox.min_value = 1
	frame_rows_spinbox.max_value = 128
	frame_rows_spinbox.step = 1
	frame_rows_spinbox.value = frame_split_rows
	frame_rows_spinbox.custom_minimum_size = Vector2(80, 0)
	frame_rows_spinbox.value_changed.connect(_on_frame_grid_value_changed)
	top.add_child(frame_rows_spinbox)

	frame_cols_label = Label.new()
	frame_cols_label.name = "ColsLabel"
	top.add_child(frame_cols_label)

	frame_cols_spinbox = SpinBox.new()
	frame_cols_spinbox.min_value = 1
	frame_cols_spinbox.max_value = 128
	frame_cols_spinbox.step = 1
	frame_cols_spinbox.value = frame_split_cols
	frame_cols_spinbox.custom_minimum_size = Vector2(80, 0)
	frame_cols_spinbox.value_changed.connect(_on_frame_grid_value_changed)
	top.add_child(frame_cols_spinbox)

	frame_apply_grid_button = Button.new()
	frame_apply_grid_button.name = "ApplyGridButton"
	frame_apply_grid_button.pressed.connect(_on_frame_grid_apply_pressed)
	top.add_child(frame_apply_grid_button)

	frame_crop_button = Button.new()
	frame_crop_button.name = "CropImageButton"
	frame_crop_button.pressed.connect(_on_frame_crop_button_pressed)
	top.add_child(frame_crop_button)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 8)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 8)
	preview_panel.add_child(preview_margin)

	frame_preview_texture_rect = TextureRect.new()
	frame_preview_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_preview_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_preview_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_preview_texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	frame_preview_texture_rect.gui_input.connect(_on_frame_preview_gui_input)
	frame_preview_texture_rect.resized.connect(_on_frame_preview_resized)
	preview_margin.add_child(frame_preview_texture_rect)

	frame_grid_overlay = Control.new()
	frame_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_preview_texture_rect.add_child(frame_grid_overlay)

	frame_selection_overlay = ColorRect.new()
	frame_selection_overlay.color = Color(0.2, 0.8, 1.0, 0.25)
	frame_selection_overlay.visible = false
	frame_selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_preview_texture_rect.add_child(frame_selection_overlay)

	_update_frame_window_text()
	frame_split_window.hide()


func _setup_frame_preview_bar(parent_node: Node) -> void:
	frame_preview_bar = PanelContainer.new()
	frame_preview_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	frame_preview_bar.offset_left = 8
	frame_preview_bar.offset_right = -8
	frame_preview_bar.offset_top = -116
	frame_preview_bar.offset_bottom = -8
	parent_node.add_child(frame_preview_bar)

	frame_preview_scroll = ScrollContainer.new()
	frame_preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	frame_preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame_preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_preview_bar.add_child(frame_preview_scroll)

	frame_preview_hbox = HBoxContainer.new()
	frame_preview_hbox.add_theme_constant_override("separation", 6)
	frame_preview_scroll.add_child(frame_preview_hbox)
	frame_preview_bar.visible = false


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
	if pick_image_button != null:
		pick_image_button.text = _ui_text("pick_image")
	if recommend_palette_button != null:
		recommend_palette_button.text = _ui_text("recommend")
	if compose_sheet_button != null:
		compose_sheet_button.text = _ui_text("compose_sheet")
	if analyze_pixels_button != null:
		analyze_pixels_button.text = _ui_text("analyze")
	if color_limit_label != null:
		color_limit_label.text = _ui_text("limit")
	if image_color_limit_max_button != null:
		image_color_limit_max_button.text = _ui_text("limit_max")
	if merge_tolerance_label != null:
		merge_tolerance_label.text = _ui_text("tolerance")
	if language_toggle_button != null:
		language_toggle_button.text = _ui_text("lang_toggle")
	if frames_toggle_button != null:
		frames_toggle_button.text = _ui_text("frames_toggle")
	_update_offset_toggle_button_text()
	_update_reference_dialog_text()
	_update_sprite_sheet_dialog_text()
	_update_frame_window_text()


func _update_offset_toggle_button_text() -> void:
	if offset_toggle_button == null:
		return
	if frame_offset_mode_active:
		offset_toggle_button.text = _ui_text("offset_apply_toggle")
	else:
		offset_toggle_button.text = _ui_text("offset_toggle")


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


func _update_sprite_sheet_dialog_text() -> void:
	if sprite_sheet_file_dialog == null:
		return
	sprite_sheet_file_dialog.title = _ui_text("sheet_dialog_title")
	if current_language == LANG_EN:
		sprite_sheet_file_dialog.filters = PackedStringArray([
			"*.png ; PNG Image",
			"*.jpg,*.jpeg ; JPEG Image",
			"*.webp ; WEBP Image"
		])
	else:
		sprite_sheet_file_dialog.filters = PackedStringArray([
			"*.png ; PNG 图片",
			"*.jpg,*.jpeg ; JPEG 图片",
			"*.webp ; WEBP 图片"
		])


func _update_frame_window_text() -> void:
	if frame_split_window == null:
		return
	frame_split_window.title = _ui_text("frame_window_title")
	if frame_rows_label != null:
		frame_rows_label.text = _ui_text("rows")
	if frame_cols_label != null:
		frame_cols_label.text = _ui_text("cols")
	if frame_apply_grid_button != null:
		frame_apply_grid_button.text = _ui_text("apply_grid")
	if frame_crop_button != null:
		frame_crop_button.text = _ui_text("crop_image")


func _open_frame_split_window(frame_index: int) -> void:
	if frame_split_window == null:
		return
	editing_frame_index = frame_index
	if frame_rows_spinbox != null:
		frame_rows_spinbox.value = frame_split_rows
	if frame_cols_spinbox != null:
		frame_cols_spinbox.value = frame_split_cols
	if frame_preview_texture_rect != null:
		frame_preview_texture_rect.texture = sprite_sheet_texture
	_set_frame_window_mode(frame_index >= 0)
	_refresh_frame_grid_overlay()
	_sync_frame_selection_with_editing_frame()
	frame_split_window.popup_centered_ratio(0.8)


func _set_frame_window_mode(only_save_current_frame: bool) -> void:
	var show_full_controls: bool = not only_save_current_frame
	if frame_rows_label != null:
		frame_rows_label.visible = show_full_controls
	if frame_rows_spinbox != null:
		frame_rows_spinbox.visible = show_full_controls
	if frame_cols_label != null:
		frame_cols_label.visible = show_full_controls
	if frame_cols_spinbox != null:
		frame_cols_spinbox.visible = show_full_controls
	if frame_apply_grid_button != null:
		frame_apply_grid_button.visible = show_full_controls
	if frame_crop_button != null:
		frame_crop_button.visible = show_full_controls


func _sync_frame_selection_with_editing_frame() -> void:
	if editing_frame_index >= 0 and editing_frame_index < frame_rects.size():
		frame_selection_rect = frame_rects[editing_frame_index]
		_update_frame_selection_overlay()
	else:
		frame_selection_overlay.visible = false


func _apply_grid_split_to_frames() -> void:
	if sprite_sheet_image == null:
		return
	frame_rects.clear()
	var w: int = sprite_sheet_image.get_width()
	var h: int = sprite_sheet_image.get_height()
	for row in range(frame_split_rows):
		for col in range(frame_split_cols):
			var x0: int = int(floor(float(col) * float(w) / float(frame_split_cols)))
			var x1: int = int(floor(float(col + 1) * float(w) / float(frame_split_cols)))
			var y0: int = int(floor(float(row) * float(h) / float(frame_split_rows)))
			var y1: int = int(floor(float(row + 1) * float(h) / float(frame_split_rows)))
			var rect := Rect2i(x0, y0, max(1, x1 - x0), max(1, y1 - y0))
			frame_rects.append(rect)
	if frame_offset_mode_active and (frame_offset_target_frame_index < 0 or frame_offset_target_frame_index >= frame_rects.size()):
		frame_offset_mode_active = false
		frame_offset_pixels = Vector2i.ZERO
		_update_offset_toggle_button_text()
	_refresh_frame_grid_overlay()
	_refresh_frame_preview_strip()


func _refresh_frame_preview_strip() -> void:
	if frame_preview_hbox == null:
		return
	for child in frame_preview_hbox.get_children():
		child.queue_free()
	if sprite_sheet_image == null or frame_rects.is_empty():
		frame_preview_bar.visible = false
		selected_preview_frame_index = -1
		return
	if selected_preview_frame_index >= frame_rects.size():
		selected_preview_frame_index = -1
	for i in range(frame_rects.size()):
		var rect: Rect2i = frame_rects[i]
		var frame_img: Image = sprite_sheet_image.get_region(rect)
		var preview_img: Image = frame_img.duplicate()
		preview_img.resize(64, 64, Image.INTERPOLATE_NEAREST)
		var texture: ImageTexture = ImageTexture.create_from_image(preview_img)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(72, 72)
		panel.add_theme_stylebox_override("panel", _build_frame_thumb_style(i == selected_preview_frame_index))
		frame_preview_hbox.add_child(panel)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 3)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_right", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
		panel.add_child(margin)
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(68, 68)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_normal = texture
		btn.tooltip_text = "Frame %d (%d,%d,%d,%d)" % [i, rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		btn.gui_input.connect(_on_frame_thumb_gui_input.bind(i))
		margin.add_child(btn)
	frame_preview_bar.visible = true


func _load_frame_to_canvas(frame_index: int) -> void:
	if sprite_sheet_image == null:
		return
	if frame_index < 0 or frame_index >= frame_rects.size():
		return
	if palette.is_empty():
		push_error("加载帧失败，当前调色板为空。")
		return
	var rect: Rect2i = frame_rects[frame_index]
	var frame_img: Image = sprite_sheet_image.get_region(rect)
	frame_img.resize(grid_width, grid_height, Image.INTERPOLATE_NEAREST)
	_quantize_image_to_pixels(frame_img, palette)
	_normalize_color_limit_spinbox_value()
	if selected_preview_frame_index != frame_index:
		selected_preview_frame_index = frame_index
	_refresh_frame_preview_strip()


func _update_frame_selection_from_drag(start_local: Vector2, end_local: Vector2) -> void:
	if sprite_sheet_image == null:
		return
	var draw_rect: Rect2 = _get_frame_preview_draw_rect()
	if draw_rect.size.x <= 0 or draw_rect.size.y <= 0:
		return
	var p0: Vector2 = _preview_to_source_point(start_local)
	var p1: Vector2 = _preview_to_source_point(end_local)
	var min_x: int = int(floor(minf(p0.x, p1.x)))
	var min_y: int = int(floor(minf(p0.y, p1.y)))
	var max_x: int = int(ceili(maxf(p0.x, p1.x)))
	var max_y: int = int(ceili(maxf(p0.y, p1.y)))
	var img_w: int = sprite_sheet_image.get_width()
	var img_h: int = sprite_sheet_image.get_height()
	min_x = clampi(min_x, 0, img_w - 1)
	min_y = clampi(min_y, 0, img_h - 1)
	max_x = clampi(max_x, min_x + 1, img_w)
	max_y = clampi(max_y, min_y + 1, img_h)
	frame_selection_rect = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)
	_update_frame_selection_overlay()


func _get_frame_preview_draw_rect() -> Rect2:
	if frame_preview_texture_rect == null or sprite_sheet_image == null:
		return Rect2(0, 0, 0, 0)
	var control_size: Vector2 = frame_preview_texture_rect.size
	var img_size: Vector2 = Vector2(sprite_sheet_image.get_width(), sprite_sheet_image.get_height())
	if img_size.x <= 0.0 or img_size.y <= 0.0 or control_size.x <= 0.0 or control_size.y <= 0.0:
		return Rect2(0, 0, 0, 0)
	var scale_factor: float = minf(control_size.x / img_size.x, control_size.y / img_size.y)
	var draw_size: Vector2 = img_size * scale_factor
	var offset: Vector2 = (control_size - draw_size) * 0.5
	return Rect2(offset, draw_size)


func _preview_to_source_point(local_pos: Vector2) -> Vector2:
	var draw_rect: Rect2 = _get_frame_preview_draw_rect()
	if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		return Vector2.ZERO
	var px: float = (local_pos.x - draw_rect.position.x) / draw_rect.size.x
	var py: float = (local_pos.y - draw_rect.position.y) / draw_rect.size.y
	px = clampf(px, 0.0, 1.0)
	py = clampf(py, 0.0, 1.0)
	return Vector2(px * float(sprite_sheet_image.get_width()), py * float(sprite_sheet_image.get_height()))


func _source_to_preview_rect(source_rect: Rect2i) -> Rect2:
	var draw_rect: Rect2 = _get_frame_preview_draw_rect()
	if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		return Rect2(0, 0, 0, 0)
	var img_w: float = float(sprite_sheet_image.get_width())
	var img_h: float = float(sprite_sheet_image.get_height())
	var p0: Vector2 = Vector2(float(source_rect.position.x) / img_w, float(source_rect.position.y) / img_h)
	var p1: Vector2 = Vector2(float(source_rect.end.x) / img_w, float(source_rect.end.y) / img_h)
	var start: Vector2 = draw_rect.position + p0 * draw_rect.size
	var end: Vector2 = draw_rect.position + p1 * draw_rect.size
	return Rect2(start, end - start)


func _update_frame_selection_overlay() -> void:
	if frame_selection_overlay == null:
		return
	if sprite_sheet_image == null or frame_selection_rect.size.x <= 0 or frame_selection_rect.size.y <= 0:
		frame_selection_overlay.visible = false
		return
	var preview_rect: Rect2 = _source_to_preview_rect(frame_selection_rect)
	frame_selection_overlay.position = preview_rect.position
	frame_selection_overlay.size = preview_rect.size
	frame_selection_overlay.visible = true


func _build_frame_thumb_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 1.0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if selected:
		style.border_color = Color(0.35, 1.0, 0.45, 1.0)
	else:
		style.border_color = Color(0.25, 0.25, 0.25, 1.0)
	return style


func _refresh_frame_grid_overlay() -> void:
	if frame_grid_overlay == null:
		return
	for child in frame_grid_overlay.get_children():
		child.queue_free()
	if sprite_sheet_image == null:
		return
	var draw_rect: Rect2 = _get_frame_preview_draw_rect()
	if draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		return
	var line_color := Color(0.25, 1.0, 0.35, 0.95)
	for col in range(1, frame_split_cols):
		var t: float = float(col) / float(frame_split_cols)
		var x: float = draw_rect.position.x + draw_rect.size.x * t
		var vline := ColorRect.new()
		vline.color = line_color
		vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vline.position = Vector2(x - 0.5, draw_rect.position.y)
		vline.size = Vector2(1.0, draw_rect.size.y)
		frame_grid_overlay.add_child(vline)
	for row in range(1, frame_split_rows):
		var t: float = float(row) / float(frame_split_rows)
		var y: float = draw_rect.position.y + draw_rect.size.y * t
		var hline := ColorRect.new()
		hline.color = line_color
		hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hline.position = Vector2(draw_rect.position.x, y - 0.5)
		hline.size = Vector2(draw_rect.size.x, 1.0)
		frame_grid_overlay.add_child(hline)


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


func _normalize_color_limit_spinbox_value() -> void:
	if image_color_limit_spinbox == null:
		return
	var min_v: int = max(1, int(image_color_limit_spinbox.min_value))
	var max_v: int = max(min_v, int(image_color_limit_spinbox.max_value))
	var cur_v: int = int(image_color_limit_spinbox.value)
	var clamped_v: int = clampi(cur_v, min_v, max_v)
	if clamped_v == cur_v:
		return
	suppress_image_color_limit_signal = true
	image_color_limit_spinbox.value = clamped_v
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
	var resized: Image = _load_active_source_resized_image(Image.INTERPOLATE_NEAREST)
	if resized == null:
		return

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
	var target_limit: int = image_pixel_palette_full.size()
	if keep_limit_value and image_color_limit_spinbox != null and image_color_limit_spinbox.editable:
		target_limit = clampi(int(image_color_limit_spinbox.value), 1, image_pixel_palette_full.size())
	_set_image_color_limit_ui(image_pixel_palette_full.size(), target_limit)
	_apply_image_pixel_palette_limit(target_limit, true)
	print("图像像素分析完成: 颜色种类=%d, 宽容度=%d, 阈值=%.4f, 来源=%s" % [
		image_pixel_palette_full.size(),
		image_merge_tolerance_percent,
		merge_threshold,
		_get_active_source_label()
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


func _has_selected_frame_source() -> bool:
	return sprite_sheet_image != null and selected_preview_frame_index >= 0 and selected_preview_frame_index < frame_rects.size()


func _has_active_source_image() -> bool:
	return _has_selected_frame_source() or FileAccess.file_exists(current_reference_image_path)


func _load_active_source_resized_image(interpolation: int) -> Image:
	if _has_selected_frame_source():
		var rect: Rect2i = frame_rects[selected_preview_frame_index]
		var frame_img: Image = sprite_sheet_image.get_region(rect)
		var resized: Image = frame_img.duplicate()
		resized.resize(grid_width, grid_height, interpolation)
		return resized
	return _load_reference_resized_image(current_reference_image_path, interpolation)


func _get_active_source_label() -> String:
	if _has_selected_frame_source():
		return "帧#%d" % selected_preview_frame_index
	return current_reference_image_path


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
	var resized: Image = _load_active_source_resized_image(Image.INTERPOLATE_BILINEAR)
	if resized == null:
		push_error("推荐失败，当前无可用来源图像。")
		return

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
	print("推荐调色板: %s (平均误差=%.6f, 来源=%s)" % [best_name, best_error, _get_active_source_label()])
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
