
extends Control

signal play_requested

@export_file("*.tscn") var play_scene_path: String = "res://main.tscn"
@export var game_title: String = "VIRELUNE"
@export var subtitle: String = "A TWO-PLAYER DUNGEON CRAWLER"
@export var backdrop_scene: PackedScene
@export var show_heroes: bool = true
@export var fade_seconds: float = 0.6

@export_group("Audio buses")
@export var music_bus_name: String = "Music"
@export var sfx_bus_name: String = "SFX"

@export_group("Panel Scrolling")
@export var panel_scroll_speed: float = 350.0
@export var panel_scroll_dead_zone: float = 0.2

@export_group("Panel text")
@export_multiline var how_to_play_text: String = "[center][b]TWO HEROES. ONE DUNGEON.[/b][/center]\n\nVirelune is a local two-player co-op dungeon adventure. Explore ancient ruins, solve environmental puzzles, overcome dangerous mechanisms, and restore the Threefold Seal.\n\n[color=#8fb4ff][b]THE MAGE — PLAYER 1[/b][/color]\nThe Mage specializes in magic and precision. Use elemental abilities and interact with magical objects to overcome obstacles. Fire, Ice, and Healing are planned abilities.\n\n[color=#d9b36c][b]THE KNIGHT — PLAYER 2[/b][/color]\nThe Knight specializes in strength and physical interaction. Operate mechanisms, confront enemies, and help clear a path through the ruins.\n\n[color=#e8c98a][b]WORK TOGETHER[/b][/color]\nSome challenges require both heroes. Coordinate your actions and discover how your abilities complement each other. Neither hero is meant to solve every challenge alone.\n\n[b]CONTROLS[/b]\nKeyboard and mouse controls are available for the current prototype. Custom Arduino-compatible controllers are being developed as part of the project. Final button assignments will be listed here once the layouts are complete.\n\n[i]Virelune is an evolving senior project. Features and controls may change during development.[/i]"

@export_multiline var credits_text: String = "[center][b]VIRELUNE[/b]\nA Computer Science Senior Project\n\n[b]DESIGN AND DEVELOPMENT[/b]\nEmily Young\n\n[b]PROJECT FOCUS[/b]\nLocal Co-op Gameplay\nEnvironmental Puzzles\nCustom Hardware Controllers\nGame Development and Interaction Design\n\n[b]TECHNOLOGY[/b]\nGodot 4\nGDScript\nArduino-Compatible Hardware\n\n[b]SPECIAL THANKS[/b]\nHanover College\nFaculty, classmates, and playtesters\n\n[i]A work in progress — 2026–2027[/i][/center]"

const SETTINGS_PATH: String = "user://virelune_settings.cfg"
const FONT_PATH: String = "res://title_screen/ui_font.ttf"

const BRONZE: Color = Color("b07a3a")
const BRONZE_DIM: Color = Color("6e4d28")
const TEXT: Color = Color("ece7da")
const TEXT_DIM: Color = Color("9fa1ad")
const FIRE: Color = Color("ff6a2a")
const MIDNIGHT: Color = Color("1b2233")
const STONE: Color = Color("2b2f3a")

var _busy: bool = false
var _opener: Control
var _cfg: ConfigFile = ConfigFile.new()
var _ctrl_status: Dictionary = {}
var _toast_tween: Tween

var _menu_nav_cooldown: float = 0.0
var _menu_nav_delay: float = 0.22
var _menu_controls: Array[Button] = []
var _panel_nav_controls: Array[Button] = []

@onready var _backdrop_holder: Control = $BackdropHolder
@onready var _hero: Control = $Hero
@onready var _embers: CPUParticles2D = $Embers
@onready var _motes: CPUParticles2D = $Motes

@onready var _title_row: HBoxContainer = $Margin/Column/TitleRow
@onready var _subtitle: Label = $Margin/Column/Subtitle
@onready var _divider: Control = $Margin/Column/Divider
@onready var _menu: VBoxContainer = $Margin/Column/Menu

@onready var _play: Button = $Margin/Column/Menu/PlayButton
@onready var _how: Button = $Margin/Column/Menu/HowButton
@onready var _controllers: Button = $Margin/Column/Menu/ControllerButton
@onready var _settings: Button = $Margin/Column/Menu/SettingsButton
@onready var _credits: Button = $Margin/Column/Menu/CreditsButton
@onready var _quit: Button = $Margin/Column/Menu/QuitButton

@onready var _footer: Label = $Footer
@onready var _hint: Label = $Hint
@onready var _toast: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/Margin/Label

@onready var _overlay: Control = $Overlay
@onready var _info_panel: Control = $Overlay/InfoPanel
@onready var _info_heading: Label = $Overlay/InfoPanel/Margin/VBox/Heading
@onready var _info_body: RichTextLabel = $Overlay/InfoPanel/Margin/VBox/Body

@onready var _ctrl_panel: Control = $Overlay/ControllersPanel
@onready var _ctrl_summary: Label = $Overlay/ControllersPanel/Margin/VBox/Summary
@onready var _ctrl_p1: Label = $Overlay/ControllersPanel/Margin/VBox/PlayerOne
@onready var _ctrl_p2: Label = $Overlay/ControllersPanel/Margin/VBox/PlayerTwo

@onready var _settings_panel: Control = $Overlay/SettingsPanel
@onready var _settings_rows: VBoxContainer = $Overlay/SettingsPanel/Margin/VBox/Rows

@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	theme = _make_theme()

	_load_settings()
	_build_title()
	_style_menu()
	_build_settings_rows()
	_setup_backdrop()

	_hero.visible = show_heroes
	_subtitle.text = subtitle
	_footer.text = "LOCAL CO-OP  •  2 PLAYERS"
	_hint.text = "Move Up/Down: Navigate     Look Up/Down: Scroll Text     Interact: Select     Esc: Back"

	_footer.add_theme_color_override("font_color", TEXT_DIM)
	_hint.add_theme_color_override("font_color", TEXT_DIM)
	_subtitle.add_theme_color_override("font_color", Color("d9c9a3"))
	_subtitle.add_theme_font_size_override("font_size", 18)

	_play.pressed.connect(_on_play)

	_how.pressed.connect(
		func() -> void:
			_show_info("HOW TO PLAY", how_to_play_text, _how)
	)

	_credits.pressed.connect(
		func() -> void:
			_show_info("CREDITS", credits_text, _credits)
	)

	_controllers.pressed.connect(
		func() -> void:
			_refresh_controllers()
			_open_panel(_ctrl_panel, _controllers)
	)

	_settings.pressed.connect(
		func() -> void:
			_open_panel(_settings_panel, _settings)
	)

	_quit.pressed.connect(
		func() -> void:
			get_tree().quit()
	)

	for panel in [_info_panel, _ctrl_panel, _settings_panel]:
		var back_button := panel.find_child("Back", true, false) as Button

		if back_button != null:
			back_button.pressed.connect(_close_panel)
		else:
			push_warning("Missing Back button in panel: " + panel.name)

	_overlay.visible = false
	_fade.modulate.a = 0.0
	_toast.visible = false

	_menu_controls = [
		_play,
		_how,
		_controllers,
		_settings,
		_credits,
		_quit
	]

	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)

	_refresh_controllers()
	_resize_particles()
	resized.connect(_resize_particles)

	set_process(true)

	_play_intro()
	_play.grab_focus()


# -------------------------------------------------------------------
# SHARED INPUT AND MENU NAVIGATION
# -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _busy:
		return

	if _menu_nav_cooldown > 0.0:
		_menu_nav_cooldown -= delta

	var mage_move: Vector2 = PlayerInput.get_move(1)
	var knight_move: Vector2 = PlayerInput.get_move(2)

	# Either player's movement stick navigates vertically.
	var vertical: float = 0.0

	if mage_move.y < -0.6 or knight_move.y < -0.6:
		vertical = -1.0
	elif mage_move.y > 0.6 or knight_move.y > 0.6:
		vertical = 1.0

	if vertical != 0.0 and _menu_nav_cooldown <= 0.0:
		if _overlay.visible:
			_move_panel_selection(int(vertical))
		else:
			_move_menu_selection(int(vertical))

		_menu_nav_cooldown = _menu_nav_delay

	# Either player's right-look analog scrolls text in open panels.
	if _overlay.visible:
		_scroll_panel_text(PlayerInput.get_look(1), delta)
		_scroll_panel_text(PlayerInput.get_look(2), delta)

	# Consume each player's interaction independently.
	var mage_interact: bool = PlayerInput.consume_interaction(1)
	var knight_interact: bool = PlayerInput.consume_interaction(2)

	if mage_interact or knight_interact:
		_activate_focused_button()


func _move_menu_selection(direction: int) -> void:
	if _menu_controls.is_empty():
		return

	var current := get_viewport().gui_get_focus_owner()
	var current_index: int = -1

	for i in range(_menu_controls.size()):
		if _menu_controls[i] == current:
			current_index = i
			break

	if current_index == -1:
		_menu_controls[0].grab_focus()
		return

	var next_index: int = (
		current_index + direction + _menu_controls.size()
	) % _menu_controls.size()

	_menu_controls[next_index].grab_focus()


func _move_panel_selection(direction: int) -> void:
	var panel := _get_active_panel()

	if panel == null:
		return

	_panel_nav_controls.clear()
	_collect_buttons(panel, _panel_nav_controls)

	if _panel_nav_controls.is_empty():
		return

	var current := get_viewport().gui_get_focus_owner()
	var current_index: int = -1

	for i in range(_panel_nav_controls.size()):
		if _panel_nav_controls[i] == current:
			current_index = i
			break

	if current_index == -1:
		_panel_nav_controls[0].grab_focus()
		return

	var next_index: int = (
		current_index + direction + _panel_nav_controls.size()
	) % _panel_nav_controls.size()

	_panel_nav_controls[next_index].grab_focus()


func _collect_buttons(node: Node, output: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button:
			var button := child as Button

			if button.visible and not button.disabled:
				output.append(button)

		_collect_buttons(child, output)


func _get_active_panel() -> Control:
	for panel in [_info_panel, _ctrl_panel, _settings_panel]:
		if panel.visible:
			return panel

	return null


func _activate_focused_button() -> void:
	var focused := get_viewport().gui_get_focus_owner()

	if focused is Button and focused.is_visible_in_tree():
		var button := focused as Button

		if not button.disabled:
			button.pressed.emit()


# -------------------------------------------------------------------
# RIGHT-ANALOG TEXT SCROLLING
# -------------------------------------------------------------------

func _scroll_panel_text(look: Vector2, delta: float) -> void:
	var panel := _get_active_panel()

	if panel == null:
		return

	if abs(look.y) < panel_scroll_dead_zone:
		return

	var scroll_amount: float = look.y * panel_scroll_speed * delta

	# The How to Play and Credits panel uses this RichTextLabel.
	if panel == _info_panel:
		var bar := _info_body.get_v_scroll_bar()
		bar.value = clampf(
			bar.value + scroll_amount,
			bar.min_value,
			bar.max_value
		)
		return

	# Other panels can use a ScrollContainer for their contents.
	var scroll_container := panel.find_child(
		"ScrollContainer",
		true,
		false
	) as ScrollContainer

	if scroll_container != null:
		var bar := scroll_container.get_v_scroll_bar()
		bar.value = clampf(
			bar.value + scroll_amount,
			bar.min_value,
			bar.max_value
		)


# -------------------------------------------------------------------
# KEYBOARD / GAMEPAD BACK NAVIGATION
# -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _overlay.visible:
			_close_panel()
			get_viewport().set_input_as_handled()


# -------------------------------------------------------------------
# CONTROLLER STATUS
# -------------------------------------------------------------------

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controllers()


func set_controller_status(
	player_index: int,
	connected: bool,
	details: String = ""
) -> void:
	_ctrl_status[player_index] = {
		"connected": connected,
		"details": details
	}

	_refresh_controllers()


func _refresh_controllers() -> void:
	var pads: Array[int] = Input.get_connected_joypads()
	var names := PackedStringArray()

	for id in pads:
		names.append("• " + Input.get_joy_name(id))

	var summary := "Standard gamepads detected: %d" % pads.size()

	if not names.is_empty():
		summary += "\n" + "\n".join(names)

	summary += "\n\nArduino serial controllers require a serial connection script."

	_ctrl_summary.text = summary
	_ctrl_p1.text = _player_line(1, "MAGE")
	_ctrl_p2.text = _player_line(2, "KNIGHT")


func _player_line(player_index: int, role: String) -> String:
	var line := "PLAYER %d — %s\n" % [player_index, role]

	if role == "MAGE":
		line += "Role: Magic and precision.\n"
		line += "Planned abilities: Fire, Ice, and Healing.\n"
	else:
		line += "Role: Strength and physical interactions.\n"
		line += "Planned abilities: Mechanisms and combat.\n"

	if not _ctrl_status.has(player_index):
		line += "Custom controller: Not linked to menu."
		return line

	var status: Dictionary = _ctrl_status[player_index]
	line += "Custom controller: "
	line += "Connected" if bool(status.get("connected", false)) else "Not detected"

	var details: String = str(status.get("details", ""))

	if not details.is_empty():
		line += "\nDetails: " + details

	return line


# -------------------------------------------------------------------
# TITLE BUILDING
# -------------------------------------------------------------------

func _build_title() -> void:
	for child in _title_row.get_children():
		_title_row.remove_child(child)
		child.queue_free()

	var count: int = game_title.length()

	for i in range(count):
		var letter := Label.new()
		letter.text = game_title.substr(i, 1)

		var blend: float = float(i) / maxf(1.0, float(count - 1))

		letter.add_theme_font_size_override("font_size", 92)
		letter.add_theme_color_override(
			"font_color",
			BRONZE.lerp(Color("f4e6c0"), blend)
		)
		letter.add_theme_color_override(
			"font_outline_color",
			Color(0.05, 0.04, 0.03, 0.95)
		)
		letter.add_theme_constant_override("outline_size", 10)
		letter.add_theme_color_override(
			"font_shadow_color",
			Color(1.0, 0.7, 0.3, 0.3)
		)
		letter.add_theme_constant_override("shadow_offset_x", 0)
		letter.add_theme_constant_override("shadow_offset_y", 0)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_title_row.add_child(letter)


func _menu_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(border, bg, 4, 0, 18, 9)
	style.border_width_left = 4
	style.shadow_size = 0
	return style


func _style_menu() -> void:
	for child in _menu.get_children():
		var button := child as Button

		if button == null:
			continue

		button.custom_minimum_size = Vector2(320, 50)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)

		button.add_theme_stylebox_override(
			"normal",
			_menu_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
		)
		button.add_theme_stylebox_override(
			"hover",
			_menu_style(Color(0.1, 0.12, 0.18, 0.78), BRONZE)
		)
		button.add_theme_stylebox_override(
			"focus",
			_menu_style(Color(0.1, 0.12, 0.18, 0.78), Color("e8c98a"))
		)
		button.add_theme_stylebox_override(
			"pressed",
			_menu_style(Color(0.14, 0.17, 0.25, 0.9), Color("e8c98a"))
		)

		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)

		button.mouse_entered.connect(_on_menu_mouse_entered.bind(button))


func _on_menu_mouse_entered(button: Button) -> void:
	button.grab_focus()


func _setup_backdrop() -> void:
	if backdrop_scene == null:
		return

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	container.add_child(viewport)

	var instance := backdrop_scene.instantiate()
	viewport.add_child(instance)

	_backdrop_holder.add_child(container)


func _resize_particles() -> void:
	if not is_instance_valid(_motes) or not is_instance_valid(_embers):
		return

	_motes.position = Vector2(size.x / 2.0, size.y + 12.0)
	_motes.emission_rect_extents = Vector2(size.x / 2.0, 4.0)

	_embers.position = Vector2(size.x * 0.4, size.y + 12.0)
	_embers.emission_rect_extents = Vector2(size.x * 0.4, 4.0)


func _play_intro() -> void:
	_subtitle.modulate.a = 0.0
	_divider.modulate.a = 0.0

	for button in _menu.get_children():
		button.modulate.a = 0.0

	await get_tree().process_frame

	var tween := create_tween().set_parallel(true)
	var letters := _title_row.get_children()

	for i in range(letters.size()):
		var letter := letters[i] as Control
		letter.modulate.a = 0.0
		letter.pivot_offset = letter.size / 2.0
		letter.scale = Vector2(0.82, 0.82)

		tween.tween_property(letter, "modulate:a", 1.0, 0.5).set_delay(0.08 * i)
		tween.tween_property(letter, "scale", Vector2.ONE, 0.5) \
			.set_delay(0.08 * i) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

	var base_delay: float = 0.08 * letters.size() + 0.1

	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.6).set_delay(base_delay)
	tween.tween_property(_divider, "modulate:a", 1.0, 0.6).set_delay(base_delay)

	var buttons := _menu.get_children()

	for i in range(buttons.size()):
		tween.tween_property(
			buttons[i],
			"modulate:a",
			1.0,
			0.4
		).set_delay(base_delay + 0.25 + 0.07 * i)


# -------------------------------------------------------------------
# MENU ACTIONS AND PANELS
# -------------------------------------------------------------------

func _on_play() -> void:
	if _busy:
		return

	if not ResourceLoader.exists(play_scene_path):
		_show_toast(
			"Cannot find %s. Set Play Scene Path on TitleScreen." % play_scene_path
		)
		return

	_busy = true
	play_requested.emit()

	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, fade_seconds)
	await tween.finished

	var error: Error = get_tree().change_scene_to_file(play_scene_path)

	if error != OK:
		_busy = false
		_fade.modulate.a = 0.0
		_show_toast("Could not open the gameplay scene.")


func _show_info(heading: String, body: String, opener: Control) -> void:
	_info_heading.text = heading
	_info_body.text = body
	_open_panel(_info_panel, opener)


func _open_panel(panel: Control, opener: Control) -> void:
	_opener = opener

	for current_panel in [_info_panel, _ctrl_panel, _settings_panel]:
		current_panel.visible = current_panel == panel

	_overlay.visible = true

	var back_button := panel.find_child("Back", true, false) as Button

	if back_button != null:
		back_button.grab_focus()


func _close_panel() -> void:
	_overlay.visible = false

	if is_instance_valid(_opener):
		_opener.grab_focus()


# -------------------------------------------------------------------
# SETTINGS
# -------------------------------------------------------------------

func _load_settings() -> void:
	var error: Error = _cfg.load(SETTINGS_PATH)

	if error != OK:
		return

	for pair in [
		["master", "Master"],
		["music", music_bus_name],
		["sfx", sfx_bus_name]
	]:
		var key: String = pair[0]
		var bus_name: String = pair[1]

		if _cfg.has_section_key("audio", key):
			_apply_bus(bus_name, float(_cfg.get_value("audio", key)))

	if _cfg.has_section_key("video", "fullscreen"):
		_apply_fullscreen(bool(_cfg.get_value("video", "fullscreen")))


func _apply_bus(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)

	if index == -1:
		return

	var safe_volume: float = clampf(linear, 0.0, 1.0)

	AudioServer.set_bus_volume_db(
		index,
		linear_to_db(maxf(safe_volume, 0.0001))
	)
	AudioServer.set_bus_mute(index, safe_volume <= 0.001)


func _apply_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _build_settings_rows() -> void:
	for pair in [
		["master", "Master", "Master volume"],
		["music", music_bus_name, "Music volume"],
		["sfx", sfx_bus_name, "Sound effects volume"]
	]:
		var key: String = pair[0]
		var bus_name: String = pair[1]
		var label_text: String = pair[2]

		var index: int = AudioServer.get_bus_index(bus_name)

		if index == -1:
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
		slider.custom_minimum_size = Vector2(240, 24)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		slider.value = (
			db_to_linear(AudioServer.get_bus_volume_db(index))
			if not AudioServer.is_bus_mute(index)
			else 0.0
		)

		var percent := Label.new()
		percent.custom_minimum_size = Vector2(48, 0)
		percent.text = "%d%%" % roundi(slider.value * 100.0)

		slider.value_changed.connect(
			func(value: float) -> void:
				_apply_bus(bus_name, value)
				percent.text = "%d%%" % roundi(value * 100.0)
				_cfg.set_value("audio", key, value)
				_cfg.save(SETTINGS_PATH)
		)

		row.add_child(label)
		row.add_child(slider)
		row.add_child(percent)
		_settings_rows.add_child(row)

	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"

	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	fullscreen.button_pressed = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)

	fullscreen.toggled.connect(
		func(enabled: bool) -> void:
			_apply_fullscreen(enabled)
			_cfg.set_value("video", "fullscreen", enabled)
			_cfg.save(SETTINGS_PATH)
	)

	_settings_rows.add_child(fullscreen)


# -------------------------------------------------------------------
# STYLE HELPERS
# -------------------------------------------------------------------

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


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
	var result := Theme.new()

	if ResourceLoader.exists(FONT_PATH):
		result.default_font = load(FONT_PATH) as Font

	result.set_color("font_color", "Label", TEXT)
	result.set_color(
		"font_outline_color",
		"Label",
		Color(0, 0, 0, 0.85)
	)
	result.set_constant("outline_size", "Label", 3)
	result.set_font_size("font_size", "Label", 16)

	result.set_stylebox(
		"panel",
		"PanelContainer",
		_panel_style(BRONZE, Color(0.078, 0.086, 0.11, 0.9))
	)

	result.set_stylebox(
		"normal",
		"Button",
		_panel_style(BRONZE_DIM, _with_alpha(MIDNIGHT, 0.92))
	)
	result.set_stylebox(
		"hover",
		"Button",
		_panel_style(BRONZE, _with_alpha(STONE, 0.95))
	)
	result.set_stylebox(
		"pressed",
		"Button",
		_panel_style(Color("e8c98a"), _with_alpha(MIDNIGHT, 1.0))
	)
	result.set_stylebox(
		"focus",
		"Button",
		_panel_style(Color("e8c98a"), _with_alpha(STONE, 0.95), 6, 3)
	)

	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color"
	]:
		result.set_color(color_name, "Button", TEXT)

	result.set_font_size("font_size", "Button", 18)
	result.set_color("default_color", "RichTextLabel", TEXT)
	result.set_font_size("normal_font_size", "RichTextLabel", 17)
	result.set_font_size("bold_font_size", "RichTextLabel", 17)
	result.set_color("font_color", "CheckButton", TEXT)

	return result


# -------------------------------------------------------------------
# TOAST NOTIFICATIONS
# -------------------------------------------------------------------

func _show_toast(message: String, color: Color = FIRE) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", color)

	_toast.add_theme_stylebox_override(
		"panel",
		_panel_style(
			color,
			Color(0.078, 0.086, 0.11, 0.92),
			8,
			2,
			22,
			10
		)
	)

	_toast.visible = true
	_toast.modulate.a = 0.0

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(
		func() -> void:
			_toast.visible = false
	)
