
extends CanvasLayer

signal pause_opened
signal pause_closed

@export var pause_action: String = "pause"
@export var allow_gamepad_start: bool = true
@export_file("*.tscn") var main_menu_scene_path: String = "res://title_screen/title_screen.tscn"

@export_group("Audio buses")
@export var music_bus_name: String = "Music"
@export var sfx_bus_name: String = "SFX"

@export_group("Controls panel")
@export var player_one_controls: Dictionary = {}
@export var player_two_controls: Dictionary = {}

@export_multiline var controls_text: String = "[b]Controls[/b]\n\n[i]Controls will be listed here once the controllers are finalized.[/i]\n\nPause: Esc or gamepad Start."

const SETTINGS_PATH: String = "user://virelune_settings.cfg"
const FONT_PATH: String = "res://pause_menu/ui_font.ttf"

const BRONZE: Color = Color("b07a3a")
const BRONZE_DIM: Color = Color("6e4d28")
const TEXT: Color = Color("ece7da")
const TEXT_DIM: Color = Color("9fa1ad")
const GOLD: Color = Color("e8c98a")
const FIRE: Color = Color("ff6a2a")
const MIDNIGHT: Color = Color("1b2233")
const STONE: Color = Color("2b2f3a")

var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _cfg: ConfigFile = ConfigFile.new()
var _opener: Control = null
var _toast_tween: Tween = null

@onready var _root: Control = $Root
@onready var _main_panel: Control = $Root/MainPanel
@onready var _resume: Button = $Root/MainPanel/Margin/VBox/ResumeButton
@onready var _settings_btn: Button = $Root/MainPanel/Margin/VBox/SettingsButton
@onready var _controls_btn: Button = $Root/MainPanel/Margin/VBox/ControlsButton
@onready var _menu_btn: Button = $Root/MainPanel/Margin/VBox/MenuButton
@onready var _settings_panel: Control = $Root/SettingsPanel
@onready var _settings_rows: VBoxContainer = $Root/SettingsPanel/Margin/VBox/Rows
@onready var _controls_panel: Control = $Root/ControlsPanel
@onready var _controls_body: RichTextLabel = $Root/ControlsPanel/Margin/VBox/Body
@onready var _confirm_panel: Control = $Root/ConfirmPanel
@onready var _cancel_btn: Button = $Root/ConfirmPanel/Margin/VBox/Buttons/Cancel
@onready var _confirm_btn: Button = $Root/ConfirmPanel/Margin/VBox/Buttons/Confirm
@onready var _toast: PanelContainer = $Root/Toast
@onready var _toast_label: Label = $Root/Toast/Margin/Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")

	_root.theme = _make_theme()
	_root.visible = false

	_style_menu_buttons()
	_load_settings()
	_build_settings_rows()

	_resume.pressed.connect(close)
	_settings_btn.pressed.connect(func(): _open_sub(_settings_panel, _settings_btn))
	_controls_btn.pressed.connect(func():
		_controls_body.text = _build_controls_text()
		_open_sub(_controls_panel, _controls_btn)
	)
	_menu_btn.pressed.connect(func(): _open_sub(_confirm_panel, _menu_btn))

	for panel in [_settings_panel, _controls_panel]:
		var back_button: Button = panel.find_child("Back", true, false) as Button
		if back_button != null:
			back_button.pressed.connect(_back_to_main)

	_cancel_btn.pressed.connect(_back_to_main)
	_confirm_btn.pressed.connect(_return_to_main_menu)

	print("Virelune Pause Menu ready. Press Escape to pause.")


# =========================================================
# PAUSE MENU INPUT
# =========================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey

		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			print("PAUSE MENU RECEIVED ESCAPE")

			if not _root.visible:
				open()
			elif _main_panel.visible:
				close()
			else:
				_back_to_main()

			get_viewport().set_input_as_handled()


func _is_pause_event(event: InputEvent) -> bool:
	# Always detect Escape, even if the pause action is configured incorrectly.
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and (
				key_event.keycode == KEY_ESCAPE
				or key_event.physical_keycode == KEY_ESCAPE
			)
		):
			return true

	# Also allow a configured InputMap action.
	if pause_action != "" and InputMap.has_action(pause_action):
		if event.is_action_pressed(pause_action):
			return true

	# Allow gamepad Start.
	if allow_gamepad_start and event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if (
			button_event.pressed
			and button_event.button_index == JOY_BUTTON_START
		):
			return true

	return false


# =========================================================
# PUBLIC API
# =========================================================

func open() -> void:
	if _root.visible:
		return

	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	get_tree().paused = true

	_show_only(_main_panel)
	_root.visible = true
	_root.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.15)

	_resume.grab_focus()
	pause_opened.emit()


func close() -> void:
	if not _root.visible:
		return

	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode

	pause_closed.emit()


func toggle() -> void:
	if _root.visible:
		close()
	else:
		open()


func is_open() -> bool:
	return _root.visible


# =========================================================
# PANELS
# =========================================================

func _show_only(panel: Control) -> void:
	for p in [_main_panel, _settings_panel, _controls_panel, _confirm_panel]:
		p.visible = p == panel


func _open_sub(panel: Control, opener: Control) -> void:
	_opener = opener
	_show_only(panel)

	if panel == _confirm_panel:
		_cancel_btn.grab_focus()
	else:
		var back_button: Button = panel.find_child("Back", true, false) as Button
		if back_button != null:
			back_button.grab_focus()


func _back_to_main() -> void:
	_show_only(_main_panel)

	if is_instance_valid(_opener):
		_opener.grab_focus()
	else:
		_resume.grab_focus()


func _return_to_main_menu() -> void:
	if not ResourceLoader.exists(main_menu_scene_path):
		_show_toast("Cannot find %s. Check Main Menu Scene Path." % main_menu_scene_path)
		_back_to_main()
		return

	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode
	get_tree().change_scene_to_file(main_menu_scene_path)


# =========================================================
# CONTROLS PANEL
# =========================================================

func _input_hint(action: String) -> String:
	if action == "" or not InputMap.has_action(action):
		return ""

	var parts := PackedStringArray()

	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			parts.append(OS.get_keycode_string(code))
		elif event is InputEventJoypadButton:
			var button_event := event as InputEventJoypadButton
			parts.append("Pad button %d" % button_event.button_index)
		elif event is InputEventJoypadMotion:
			var motion_event := event as InputEventJoypadMotion
			parts.append("Pad axis %d" % motion_event.axis)
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			parts.append("Mouse %d" % mouse_event.button_index)

		if parts.size() >= 2:
			break

	return " / ".join(parts)


func _build_controls_text() -> String:
	var lines := PackedStringArray()
	var entries: Array = [
		["PLAYER 1 - MAGE", player_one_controls, "8fb4ff"],
		["PLAYER 2 - KNIGHT", player_two_controls, "d9b36c"]
	]

	for entry in entries:
		var title_text: String = entry[0]
		var controls: Dictionary = entry[1]
		var color_code: String = entry[2]

		if controls.is_empty():
			continue

		lines.append("[color=#%s][b]%s[/b][/color]" % [color_code, title_text])

		for label in controls:
			var hint := _input_hint(String(controls[label]))
			lines.append("    %s - %s" % [String(label), hint if hint != "" else "not set"])

		lines.append("")

	if lines.is_empty():
		return controls_text

	lines.append("Pause: Esc or gamepad Start")
	return "\n".join(lines)


# =========================================================
# STYLE
# =========================================================

func _panel_style(
	border: Color,
	bg: Color,
	radius: int = 6,
	border_width: int = 2,
	margin_h: int = 12,
	margin_v: int = 8
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 5
	return style


func _make_theme() -> Theme:
	var theme_resource := Theme.new()

	if ResourceLoader.exists(FONT_PATH):
		theme_resource.default_font = load(FONT_PATH)

	theme_resource.set_color("font_color", "Label", TEXT)
	theme_resource.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	theme_resource.set_constant("outline_size", "Label", 3)
	theme_resource.set_font_size("font_size", "Label", 16)

	theme_resource.set_stylebox(
		"panel", "PanelContainer",
		_panel_style(BRONZE, Color(0.078, 0.086, 0.11, 0.94))
	)

	theme_resource.set_stylebox("normal", "Button", _panel_style(BRONZE_DIM, MIDNIGHT))
	theme_resource.set_stylebox("hover", "Button", _panel_style(BRONZE, STONE))
	theme_resource.set_stylebox("pressed", "Button", _panel_style(GOLD, MIDNIGHT))
	theme_resource.set_stylebox("focus", "Button", _panel_style(GOLD, STONE, 6, 3))

	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme_resource.set_color(color_name, "Button", TEXT)

	theme_resource.set_font_size("font_size", "Button", 18)
	theme_resource.set_color("default_color", "RichTextLabel", TEXT)
	theme_resource.set_font_size("normal_font_size", "RichTextLabel", 17)
	theme_resource.set_font_size("bold_font_size", "RichTextLabel", 17)
	theme_resource.set_color("font_color", "CheckButton", TEXT)

	return theme_resource


func _menu_style(bg: Color, bar: Color) -> StyleBoxFlat:
	var style := _panel_style(bar, bg, 4, 0, 18, 9)
	style.border_width_left = 4
	style.shadow_size = 0
	return style


func _style_menu_buttons() -> void:
	for button in [_resume, _settings_btn, _controls_btn, _menu_btn]:
		button.custom_minimum_size = Vector2(300, 48)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 21)

		button.add_theme_stylebox_override(
			"normal", _menu_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
		)
		button.add_theme_stylebox_override(
			"hover", _menu_style(Color(0.1, 0.12, 0.18, 0.78), BRONZE)
		)
		button.add_theme_stylebox_override(
			"focus", _menu_style(Color(0.1, 0.12, 0.18, 0.78), GOLD)
		)
		button.add_theme_stylebox_override(
			"pressed", _menu_style(Color(0.14, 0.17, 0.25, 0.9), GOLD)
		)

		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.mouse_entered.connect(button.grab_focus)

	_confirm_btn.add_theme_stylebox_override(
		"normal", _panel_style(FIRE.darkened(0.3), MIDNIGHT)
	)
	_confirm_btn.add_theme_stylebox_override(
		"focus", _panel_style(FIRE, STONE, 6, 3)
	)


func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", FIRE)
	_toast.add_theme_stylebox_override(
		"panel", _panel_style(FIRE, Color(0.078, 0.086, 0.11, 0.95), 8, 2, 22, 10)
	)

	_toast.reset_size()
	_toast.visible = true
	_toast.modulate.a = 0.0

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func(): _toast.visible = false)


# =========================================================
# SETTINGS
# =========================================================

func _load_settings() -> void:
	_cfg.load(SETTINGS_PATH)

	var audio_pairs: Array = [
		["master", "Master"],
		["music", music_bus_name],
		["sfx", sfx_bus_name]
	]

	for pair in audio_pairs:
		var setting_key: String = pair[0]
		var bus_name: String = pair[1]

		if _cfg.has_section_key("audio", setting_key):
			_apply_bus(bus_name, float(_cfg.get_value("audio", setting_key)))

	if _cfg.has_section_key("video", "fullscreen"):
		_apply_fullscreen(bool(_cfg.get_value("video", "fullscreen")))


func _apply_bus(bus_name: String, linear: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(bus_index, linear <= 0.001)


func _apply_fullscreen(enabled: bool) -> void:
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)


func _build_settings_rows() -> void:
	var audio_pairs: Array = [
		["master", "Master", "Master volume"],
		["music", music_bus_name, "Music volume"],
		["sfx", sfx_bus_name, "Sound effects volume"]
	]

	for pair in audio_pairs:
		var setting_key: String = pair[0]
		var bus_name: String = pair[1]
		var label_text: String = pair[2]
		var bus_index := AudioServer.get_bus_index(bus_name)

		if bus_index == -1:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = label_text
		label.custom_minimum_size = Vector2(190, 0)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(220, 24)

		if AudioServer.is_bus_mute(bus_index):
			slider.value = 0.0
		else:
			slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))

		var percentage := Label.new()
		percentage.custom_minimum_size = Vector2(48, 0)
		percentage.text = "%d%%" % roundi(slider.value * 100.0)

		slider.value_changed.connect(
			func(value: float) -> void:
				_apply_bus(bus_name, value)
				percentage.text = "%d%%" % roundi(value * 100.0)
				_cfg.set_value("audio", setting_key, value)
				_cfg.save(SETTINGS_PATH)
		)

		row.add_child(label)
		row.add_child(slider)
		row.add_child(percentage)
		_settings_rows.add_child(row)

	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"

	var current_mode := DisplayServer.window_get_mode()
	fullscreen.button_pressed = (
		current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)

	fullscreen.toggled.connect(
		func(enabled: bool) -> void:
			_apply_fullscreen(enabled)
			_cfg.set_value("video", "fullscreen", enabled)
			_cfg.save(SETTINGS_PATH)
	)

	_settings_rows.add_child(fullscreen)
