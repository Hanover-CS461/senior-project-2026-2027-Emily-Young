
extends CanvasLayer

## VIRELUNE - Compact Fantasy HUD
## Mage: Health + animated spell selector
## Knight: Health + animated shield indicator

const HEALTH_NAMES = [
	"health", "hp", "current_health", "current_hp"
]

const MAX_HEALTH_NAMES = [
	"max_health", "max_hp", "health_max", "maxHealth", "MAX_HEALTH"
]

const SPELL_PROPS = [
	"hud_spell_index", "current_spell", "selected_spell",
	"active_spell", "spell", "spell_index",
	"current_spell_index", "selected_spell_index", "spell_type"
]

const SHIELD_PROPS = [
	"is_blocking", "blocking", "shield_up", "shield_raised",
	"is_shielding", "shielding", "is_guarding", "guarding",
	"is_defending", "defending"
]

const STATE_PROPS = ["state", "current_state", "player_state"]

const DARK = Color(0.025, 0.035, 0.06, 0.92)
const MUTED = Color(0.55, 0.58, 0.68)
const WHITE = Color(0.92, 0.93, 1.0)

@export var margin := Vector2(14, 14)
@export var card_width: float = 245.0

@export var mage_accent := Color(0.55, 0.68, 1.0)
@export var knight_accent := Color(0.88, 0.65, 0.34)

var spell_names: Array[String] = ["FIRE", "ICE", "HEAL"]

var spell_symbols: Array[String] = ["✦", "❄", "✚"]

var spell_colors: Array[Color] = [
	Color(1.0, 0.39, 0.19),
	Color(0.35, 0.76, 1.0),
	Color(0.45, 0.95, 0.63)
]

var panels: Array = []
var animation_time: float = 0.0


func _ready() -> void:
	layer = 10

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var halves := VBoxContainer.new()
	halves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halves.add_theme_constant_override("separation", 0)
	root.add_child(halves)
	halves.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	panels.append(
		build_panel(
			halves,
			"player1",
			"MAGE",
			"M",
			mage_accent,
			true
		)
	)

	panels.append(
		build_panel(
			halves,
			"player2",
			"KNIGHT",
			"K",
			knight_accent,
			false
		)
	)


func make_style(
	bg: Color,
	border: Color,
	border_size: int = 1,
	radius: int = 8
) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_size)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	return style


func make_label(
	value: String,
	font_size: int,
	color: Color,
	bold: bool = false
) -> Label:

	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

	if bold:
		label.add_theme_color_override(
			"font_outline_color",
			Color.BLACK
		)
		label.add_theme_constant_override("outline_size", 2)

	return label


func build_panel(
	parent: Control,
	group_name: String,
	title: String,
	letter: String,
	accent: Color,
	is_mage: bool
) -> Dictionary:

	var half := Control.new()
	half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	half.size_flags_vertical = Control.SIZE_EXPAND_FILL
	half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(half)

	var frame := PanelContainer.new()
	frame.position = margin
	frame.custom_minimum_size = Vector2(card_width, 0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	frame.add_theme_stylebox_override(
		"panel",
		make_style(DARK, Color(accent.r, accent.g, accent.b, 0.65), 1, 9)
	)

	half.add_child(frame)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(content)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	content.add_child(header)

	var emblem := PanelContainer.new()
	emblem.custom_minimum_size = Vector2(28, 28)
	emblem.add_theme_stylebox_override(
		"panel",
		make_style(
			Color(accent.r, accent.g, accent.b, 0.14),
			accent, 1, 6
		)
	)
	header.add_child(emblem)

	var emblem_text := make_label(letter, 15, accent, true)
	emblem_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emblem.add_child(emblem_text)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)

	heading.add_child(make_label(title, 13, WHITE, true))

	heading.add_child(
		make_label(
			"PLAYER 01" if is_mage else "PLAYER 02",
			8,
			accent,
			true
		)
	)

	var hp_label := make_label("-- / --", 11, WHITE, true)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hp_label)

	# Health bar
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.13, 0.19, 1)
	bar_bg.set_corner_radius_all(5)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.35, 0.78, 0.57)
	fill_style.set_corner_radius_all(5)

	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", fill_style)
	content.add_child(bar)

	var info := make_label("", 9, MUTED)
	content.add_child(info)

	var chips: Array = []
	var shield_icon: Label = null

	if is_mage:
		# Miniature spell wheel
		var spell_row := HBoxContainer.new()
		spell_row.add_theme_constant_override("separation", 5)
		spell_row.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(spell_row)

		for i in range(spell_names.size()):
			var spell_card := PanelContainer.new()
			spell_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spell_card.custom_minimum_size = Vector2(0, 43)

			spell_card.add_theme_stylebox_override(
				"panel",
				make_style(
					Color(0.08, 0.10, 0.16, 1),
					Color(0.25, 0.27, 0.36, 1),
					1,
					7
				)
			)

			spell_row.add_child(spell_card)

			var spell_content := VBoxContainer.new()
			spell_content.add_theme_constant_override("separation", 0)
			spell_content.alignment = BoxContainer.ALIGNMENT_CENTER
			spell_card.add_child(spell_content)

			var symbol := make_label(
				spell_symbols[i],
				17,
				spell_colors[i],
				true
			)
			symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			spell_content.add_child(symbol)

			var spell_text := make_label(
				spell_names[i],
				8,
				MUTED,
				true
			)
			spell_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			spell_content.add_child(spell_text)

			chips.append({
				"panel": spell_card,
				"symbol": symbol,
				"text": spell_text
			})

	else:
		# Knight shield indicator
		var shield_row := HBoxContainer.new()
		shield_row.add_theme_constant_override("separation", 7)
		shield_row.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(shield_row)

		shield_icon = make_label("◈", 22, MUTED, true)
		shield_row.add_child(shield_icon)

		var shield_text := make_label(
			"SHIELD DOWN",
			10,
			MUTED,
			true
		)
		shield_row.add_child(shield_text)

		info = shield_text

	return {
		"group": group_name,
		"is_mage": is_mage,
		"player": null,
		"cache": {},
		"next_search": {},
		"warned": {},
		"bar": bar,
		"fill": fill_style,
		"hp_label": hp_label,
		"accent": accent,
		"max_seen": 0.0,
		"last_hp": -1.0,
		"flash": 0.0,
		"chips": chips,
		"info": info,
		"shield_icon": shield_icon,
		"shield_active": false
	}


func _process(delta: float) -> void:
	animation_time += delta

	for panel in panels:
		update_panel(panel, delta)

		if panel["is_mage"]:
			animate_spell_wheel(panel)
		else:
			animate_shield(panel)


func update_panel(panel: Dictionary, delta: float) -> void:
	var player: Node = panel["player"]

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(panel["group"])
		panel["player"] = player
		panel["cache"].clear()

		if player == null:
			return

	update_health(panel, player, delta)

	if panel["is_mage"]:
		update_spell(panel)
	else:
		update_shield(panel)


func update_health(
	panel: Dictionary,
	player: Node,
	delta: float
) -> void:

	var hp_ref = find_prop(panel, "hp", HEALTH_NAMES)

	if hp_ref == null:
		warn_once(panel, "hp", "No health variable found.")
		panel["hp_label"].text = "-- / --"
		return

	var hp: float = float(
		hp_ref["node"].get(hp_ref["prop"])
	)

	var max_ref = find_prop(panel, "max_hp", MAX_HEALTH_NAMES)
	var max_hp: float

	if max_ref != null:
		max_hp = float(max_ref["node"].get(max_ref["prop"]))
	else:
		panel["max_seen"] = maxf(panel["max_seen"], hp)
		max_hp = panel["max_seen"]

	max_hp = maxf(max_hp, 1.0)

	var dead: bool = bool(player.get("is_dead"))

	panel["bar"].max_value = max_hp
	panel["bar"].value = lerpf(
		panel["bar"].value,
		hp,
		minf(1.0, delta * 8.0)
	)

	if dead or hp <= 0.0:
		panel["hp_label"].text = "DEFEATED"
	else:
		panel["hp_label"].text = "%d / %d" % [
			int(ceil(hp)),
			int(round(max_hp))
		]

	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)

	if ratio > 0.55:
		panel["fill"].bg_color = Color(0.35, 0.78, 0.57)
	elif ratio > 0.25:
		panel["fill"].bg_color = Color(0.95, 0.66, 0.29)
	else:
		panel["fill"].bg_color = Color(0.88, 0.28, 0.30)

	if panel["last_hp"] >= 0.0 and hp < panel["last_hp"] - 0.01:
		panel["flash"] = 1.0

	panel["last_hp"] = hp
	panel["flash"] = maxf(0.0, panel["flash"] - delta * 3.0)

	panel["hp_label"].modulate = Color.WHITE.lerp(
		Color(1.0, 0.55, 0.55),
		panel["flash"]
	)


func update_spell(panel: Dictionary) -> void:
	var ref = find_prop(panel, "spell", SPELL_PROPS)

	if ref == null:
		warn_once(
			panel,
			"spell",
			"Mage spell not found. Check the Arduino controller reference."
		)
		panel["info"].text = "Spell selection unavailable"
		set_spell_selection(panel, -1)
		return

	var value = ref["node"].get(ref["prop"])
	var index: int = -1

	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		index = int(value)

	elif typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		var wanted: String = str(value).to_lower()

		for i in range(spell_names.size()):
			if spell_names[i].to_lower() == wanted:
				index = i
				break

	if index >= 0 and index < spell_names.size():
		set_spell_selection(panel, index)
		panel["info"].text = "ARCANE ATTUNEMENT"
	else:
		set_spell_selection(panel, -1)
		panel["info"].text = "Spell: " + str(value)


func set_spell_selection(panel: Dictionary, selected: int) -> void:
	for i in range(panel["chips"].size()):
		var chip: Dictionary = panel["chips"][i]
		var color: Color = spell_colors[i]

		if i == selected:
			chip["panel"].add_theme_stylebox_override(
				"panel",
				make_style(
					Color(color.r, color.g, color.b, 0.18),
					color,
					2,
					7
				)
			)

			chip["symbol"].add_theme_color_override(
				"font_color", color
			)
			chip["text"].add_theme_color_override(
				"font_color", color
			)

		else:
			chip["panel"].add_theme_stylebox_override(
				"panel",
				make_style(
					Color(0.08, 0.10, 0.16, 1),
					Color(0.25, 0.27, 0.36, 1),
					1,
					7
				)
			)

			chip["symbol"].add_theme_color_override(
				"font_color", color.darkened(0.35)
			)
			chip["text"].add_theme_color_override(
				"font_color", MUTED
			)


func animate_spell_wheel(panel: Dictionary) -> void:
	for i in range(panel["chips"].size()):
		var chip: Dictionary = panel["chips"][i]
		var selected: bool = false

		var color: Color = spell_colors[i]
		var current_color: Color = chip["symbol"].get_theme_color(
			"font_color"
		)

		selected = current_color.is_equal_approx(color)

		if selected:
			var pulse: float = 1.0 + sin(animation_time * 4.0) * 0.035
			chip["panel"].scale = Vector2(pulse, pulse)
			chip["symbol"].modulate.a = 0.8 + (
				sin(animation_time * 4.0) + 1.0
			) * 0.1
		else:
			chip["panel"].scale = Vector2.ONE
			chip["symbol"].modulate.a = 0.8


func update_shield(panel: Dictionary) -> void:
	var ref = find_prop(panel, "shield", SHIELD_PROPS)

	if ref != null:
		var up: bool = bool(ref["node"].get(ref["prop"]))
		panel["shield_active"] = up

		if up:
			panel["info"].text = "SHIELD ACTIVE"
			panel["info"].add_theme_color_override(
				"font_color", Color(0.45, 0.8, 1.0)
			)
		else:
			panel["info"].text = "SHIELD DOWN"
			panel["info"].add_theme_color_override(
				"font_color", MUTED
			)
		return

	var state_ref = find_prop(panel, "state", STATE_PROPS)

	if state_ref != null:
		var state_value = str(
			state_ref["node"].get(state_ref["prop"])
		).to_lower()

		var up: bool = (
			state_value.contains("shield")
			or state_value.contains("block")
			or state_value.contains("guard")
		)

		panel["shield_active"] = up
		panel["info"].text = "SHIELD ACTIVE" if up else "SHIELD DOWN"
	else:
		panel["info"].text = "SHIELD STATUS UNKNOWN"


func animate_shield(panel: Dictionary) -> void:
	var icon: Label = panel["shield_icon"]

	if icon == null:
		return

	if panel["shield_active"]:
		var pulse: float = 0.8 + (
			sin(animation_time * 5.0) + 1.0
		) * 0.1

		icon.add_theme_color_override(
			"font_color",
			Color(0.45, 0.8, 1.0, pulse)
		)
		icon.scale = Vector2.ONE * (
			1.0 + sin(animation_time * 5.0) * 0.05
		)
	else:
		icon.add_theme_color_override("font_color", MUTED)
		icon.scale = Vector2.ONE


func find_prop(panel: Dictionary, key: String, names: Array):
	var cached = panel["cache"].get(key)

	if cached != null and is_instance_valid(cached["node"]):
		return cached

	var now: int = Time.get_ticks_msec()

	if panel["next_search"].get(key, 0) > now:
		return null

	panel["next_search"][key] = now + 1000

	var player: Node = panel["player"]
	var candidates: Array = [player]

	candidates.append_array(
		player.find_children("*", "", true, false)
	)

	if "arduino" in player:
		var controller = player.get("arduino")

		if controller != null:
			candidates.append(controller)

	for candidate in candidates:
		for prop in names:
			if prop in candidate:
				var found := {
					"node": candidate,
					"prop": prop
				}

				panel["cache"][key] = found
				return found

	return null


func warn_once(
	panel: Dictionary,
	key: String,
	message: String
) -> void:

	if panel["warned"].has(key):
		return

	panel["warned"][key] = true
	push_warning("player_hud: " + message)
