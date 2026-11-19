
class_name GameOverScreen
extends CanvasLayer

## Virelune two-player Game Over screen.
## GameManager controls all team-wipe and checkpoint logic.

signal respawn_requested
signal restart_requested
signal quit_requested

@export var title_text := "DEFEATED"
@export var subtitle_text := "The Sanctum claims another delver."

@export_file("*.tscn") var main_menu_scene := ""

@export var pause_game := true
@export var fade_time := 1.0

const COL_DIM := Color(0.02, 0.03, 0.05, 0.84)
const COL_PANEL := Color(0.045, 0.055, 0.085, 0.96)
const COL_BRONZE := Color(0.62, 0.42, 0.18)
const COL_BRONZE_DIM := Color(0.36, 0.25, 0.12)
const COL_CYAN := Color(0.4, 0.8, 1.0)
const COL_RED := Color(1.0, 0.36, 0.14)
const COL_TEXT := Color(0.84, 0.9, 0.96)
const COL_MUTED := Color(0.55, 0.62, 0.7)

var _root: Control
var _title: Label
var _subtitle: Label
var _stats: Label

var _btn_respawn: Button
var _btn_restart: Button
var _btn_quit: Button

var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _showing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_build_ui()
	visible = false

	print("Virelune Game Over Screen initialized.")


# ==================================================
# PUBLIC API
# ==================================================

func show_screen(
	title: String = "",
	subtitle: String = "",
	stats: String = ""
) -> void:
	if _showing:
		return

	_showing = true

	_title.text = title if title != "" else title_text
	_subtitle.text = subtitle if subtitle != "" else subtitle_text

	_stats.text = stats
	_stats.visible = stats != ""

	_btn_respawn.visible = GameManager.has_checkpoint()

	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if pause_game:
		get_tree().paused = true

	visible = true

	_set_buttons_enabled(false)

	_root.modulate.a = 0.0

	var tw := create_tween().set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	tw.tween_property(
		_root,
		"modulate:a",
		1.0,
		fade_time
	)

	tw.tween_callback(_on_fade_done)


func hide_screen() -> void:
	_showing = false
	visible = false

	if pause_game:
		get_tree().paused = false

	Input.mouse_mode = _prev_mouse_mode


# ==================================================
# CHECKPOINT RESPAWN
# ==================================================

func _on_respawn() -> void:
	if not GameManager.has_checkpoint():
		push_warning("GameOverScreen: No checkpoint is active.")
		return

	_set_buttons_enabled(false)

	print("VIRELUNE: Returning both players to checkpoint.")

	respawn_requested.emit()

	GameManager.restart_from_checkpoint()


# ==================================================
# RESTART FROM BEGINNING
# ==================================================

func _on_restart() -> void:
	_set_buttons_enabled(false)

	print("VIRELUNE: Restarting from the beginning.")

	restart_requested.emit()

	GameManager.restart_from_beginning()


# ==================================================
# QUIT
# ==================================================

func _on_quit() -> void:
	quit_requested.emit()

	hide_screen()

	if main_menu_scene != "":
		var error: Error = get_tree().change_scene_to_file(
			main_menu_scene
		)

		if error != OK:
			push_error(
				"GameOverScreen: Could not load main menu: "
				+ main_menu_scene
			)
	else:
		get_tree().quit()


# ==================================================
# BUTTON HELPERS
# ==================================================

func _on_fade_done() -> void:
	_set_buttons_enabled(true)

	if _btn_respawn.visible:
		_btn_respawn.grab_focus()
	else:
		_btn_restart.grab_focus()


func _set_buttons_enabled(on: bool) -> void:
	for b: Button in [
		_btn_respawn,
		_btn_restart,
		_btn_quit
	]:
		b.disabled = not on


# ==================================================
# UI CONSTRUCTION
# ==================================================

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = COL_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_box(COL_PANEL, COL_BRONZE, 2, 6, 44)
	)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(440, 0)
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	_title = _label("", 64, COL_RED)
	_title.add_theme_color_override(
		"font_shadow_color",
		Color(0, 0, 0, 0.7)
	)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	vb.add_child(_title)

	vb.add_child(_divider())

	_subtitle = _label("", 18, COL_MUTED)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_subtitle)

	_stats = _label("", 16, COL_TEXT)
	vb.add_child(_stats)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	vb.add_child(gap)

	_btn_respawn = _make_button("Respawn Both at Checkpoint")
	_btn_respawn.pressed.connect(_on_respawn)
	vb.add_child(_btn_respawn)

	_btn_restart = _make_button("Restart from Beginning")
	_btn_restart.pressed.connect(_on_restart)
	vb.add_child(_btn_restart)

	_btn_quit = _make_button(
		"Quit to Menu" if main_menu_scene != "" else "Quit Game"
	)
	_btn_quit.pressed.connect(_on_quit)
	vb.add_child(_btn_quit)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = COL_BRONZE
	d.custom_minimum_size = Vector2(0, 2)
	return d


func _make_button(text: String) -> Button:
	var b := Button.new()

	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_ALL

	b.add_theme_font_size_override("font_size", 20)

	b.add_theme_stylebox_override(
		"normal",
		_box(Color(0.07, 0.09, 0.13), COL_BRONZE_DIM, 2, 4, 10)
	)

	b.add_theme_stylebox_override(
		"hover",
		_box(Color(0.1, 0.14, 0.2), COL_CYAN, 2, 4, 10)
	)

	b.add_theme_stylebox_override(
		"focus",
		_box(Color(0.1, 0.14, 0.2), COL_CYAN, 2, 4, 10)
	)

	b.add_theme_stylebox_override(
		"pressed",
		_box(Color(0.05, 0.2, 0.3), COL_CYAN, 2, 4, 10)
	)

	b.add_theme_stylebox_override(
		"disabled",
		_box(Color(0.05, 0.06, 0.09), Color(0.2, 0.17, 0.12), 2, 4, 10)
	)

	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_CYAN)
	b.add_theme_color_override("font_focus_color", COL_CYAN)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override(
		"font_disabled_color",
		Color(0.35, 0.38, 0.42)
	)

	return b


func _box(
	bg: Color,
	border: Color,
	border_w: int,
	radius: int,
	margin: int
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()

	s.bg_color = bg
	s.border_color = border

	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)

	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin

	return s
