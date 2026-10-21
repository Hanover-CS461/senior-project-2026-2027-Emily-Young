class_name HeroBackdrop
extends Control

@export var knight_color: Color = Color("d9b36c")
@export var mage_color: Color = Color("8fb4ff")
@export var ring_color: Color = Color("b07a3a")
@export var glow_color: Color = Color("ffb35a")
@export var rotation_speed: float = 0.04
@export var show_labels: bool = true

const KNIGHT_PARTS := [
	[-0.15, 0.78, 0.15, 0.78, 0.19, 0.3, 0.09, 0.24, 0, 0.3, -0.09, 0.24, -0.19, 0.3],
	[-0.1, 0.42, -0.01, 0.42, -0.01, 0.05, -0.02, 0, -0.12, 0, -0.11, 0.05],
	[0.01, 0.42, 0.1, 0.42, 0.11, 0.05, 0.12, 0, 0.02, 0, 0.01, 0.05],
	[-0.21, 0.72, -0.13, 0.74, -0.15, 0.52, -0.22, 0.52],
	[0.13, 0.74, 0.21, 0.72, 0.22, 0.52, 0.15, 0.52],
	[-0.12, 0.8, 0.12, 0.8, 0.1, 0.56, 0.12, 0.42, -0.12, 0.42, -0.1, 0.56],
	[-0.22, 0.79, -0.11, 0.84, -0.11, 0.72, -0.21, 0.71],
	[0.11, 0.84, 0.22, 0.79, 0.21, 0.71, 0.11, 0.72],
	[-0.27, 0.76, -0.15, 0.68, -0.14, 0.52, -0.27, 0.36, -0.4, 0.52, -0.39, 0.68],
	[-0.065, 0.84, 0.065, 0.84, 0.07, 0.92, 0.05, 0.99, 0, 1.01, -0.05, 0.99, -0.07, 0.92],
	[-0.015, 1.0, 0.015, 1.0, 0.025, 0.88, 0, 0.8, -0.025, 0.88],
	[0.215, 0.52, 0.235, 0.52, 0.232, 0.02, 0.225, -0.02, 0.218, 0.02],
	[0.18, 0.54, 0.27, 0.54, 0.27, 0.5, 0.18, 0.5]
]

const KNIGHT_STYLES := [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 2, 3]

const MAGE_PARTS := [
	[-0.1, 0.72, 0.1, 0.72, 0.26, 0.2, 0.3, 0.04, -0.3, 0.06, -0.26, 0.2],
	[-0.12, 0.7, 0.12, 0.7, 0.19, 0.35, 0.22, 0, 0.12, 0.04, 0.05, 0, -0.03, 0.05, -0.12, 0, -0.22, 0.01, -0.18, 0.35],
	[-0.05, 0.72, 0.05, 0.72, 0.06, 0.8, 0, 0.84, -0.06, 0.8],
	[0.11, 0.68, 0.17, 0.66, 0.3, 0.52, 0.27, 0.47],
	[-0.11, 0.68, -0.17, 0.66, -0.19, 0.48, -0.14, 0.46],
	[0.285, 1.02, 0.3, 1.02, 0.3, 0, 0.285, 0],
	[-0.14, 0.8, 0.14, 0.8, 0.12, 0.84, -0.12, 0.84],
	[-0.09, 0.84, 0.09, 0.84, 0.02, 1.14]
]

const MAGE_STYLES := [0, 1, 0, 0, 0, 3, 1, 1]

const FILLS := [
	Color(0.045, 0.05, 0.075),
	Color(0.09, 0.10, 0.14),
	Color(0.62, 0.67, 0.74),
	Color(0.42, 0.30, 0.16)
]

var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _center() -> Vector2:
	return Vector2(size.x * 0.70, size.y * 0.52)


func _r() -> float:
	return minf(size.x * 0.30, size.y * 0.42)


func _ground() -> float:
	return _center().y + _r() * 0.62


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _arch(
	cx: float,
	ground: float,
	width: float,
	height: float,
	segments: int = 14
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(cx - width, ground))
	points.append(Vector2(cx - width, ground - height))

	for i in range(1, segments):
		var angle: float = PI + PI * float(i) / float(segments)
		points.append(
			Vector2(
				cx + cos(angle) * width,
				ground - height + sin(angle) * width
			)
		)

	points.append(Vector2(cx + width, ground - height))
	points.append(Vector2(cx + width, ground))

	return points


func _scaled_about(
	points: PackedVector2Array,
	focal: Vector2,
	factor: float
) -> PackedVector2Array:
	var result := PackedVector2Array()

	for point in points:
		result.append(focal + (point - focal) * factor)

	return result


func _poly(
	points: PackedVector2Array,
	fill: Color,
	rim: Color = Color(0, 0, 0, 0),
	rim_width: float = 1.5
) -> void:
	if points.size() < 3:
		return

	draw_colored_polygon(points, fill)

	if rim.a > 0.0:
		var loop := points.duplicate()
		loop.append(points[0])
		draw_polyline(loop, rim, rim_width, true)


func _hero(
	data: Array,
	styles: Array,
	origin: Vector2,
	hero_scale: float,
	rim: Color
) -> void:
	for i in range(data.size()):
		var flat: Array = data[i]
		var points := PackedVector2Array()

		for k in range(0, flat.size(), 2):
			points.append(
				origin
				+ Vector2(float(flat[k]), -float(flat[k + 1])) * hero_scale
			)

		var style_index: int = int(styles[i])
		_poly(
			points,
			FILLS[style_index],
			_with_alpha(rim, 0.55),
			1.5
		)


func _flame(position: Vector2, height: float, phase: float) -> void:
	var flicker: float = (
		1.0
		+ 0.12 * sin(_t * 7.0 + phase)
		+ 0.06 * sin(_t * 12.3 + phase * 2.0)
	)
	var width: float = height * 0.32

	_poly(
		PackedVector2Array([
			position + Vector2(-width, 0),
			position + Vector2(-width * 0.7, -height * 0.5 * flicker),
			position + Vector2(0, -height * flicker),
			position + Vector2(width * 0.7, -height * 0.5 * flicker),
			position + Vector2(width, 0)
		]),
		Color(1.0, 0.45, 0.12, 0.9)
	)

	_poly(
		PackedVector2Array([
			position + Vector2(-width * 0.5, 0),
			position + Vector2(0, -height * 0.65 * flicker),
			position + Vector2(width * 0.5, 0)
		]),
		Color(1.0, 0.85, 0.4, 0.95)
	)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var center := _center()
	var radius := _r()
	var ground := _ground()
	var gx: float = center.x
	var pulse: float = 0.8 + 0.2 * sin(_t * 0.9)
	var ring_center := Vector2(gx, ground - radius * 0.5)

	var strong := _with_alpha(ring_color, 0.7)
	var soft := _with_alpha(ring_color, 0.3)

	# Rotating rune ring.
	draw_arc(ring_center, radius * 0.95, 0.0, TAU, 96, strong, 3.0, true)
	draw_arc(ring_center, radius * 1.01, 0.0, TAU, 96, soft, 1.5, true)
	draw_arc(ring_center, radius * 0.78, 0.0, TAU, 96, soft, 2.0, true)

	var rotation: float = _t * rotation_speed

	for i in range(72):
		var angle: float = rotation + TAU * float(i) / 72.0
		var direction := Vector2(cos(angle), sin(angle))
		var is_long_tick: bool = i % 6 == 0

		draw_line(
			ring_center + direction * radius * 1.04,
			ring_center + direction * radius * (1.11 if is_long_tick else 1.08),
			strong if is_long_tick else soft,
			2.0 if is_long_tick else 1.5
		)

	for i in range(12):
		var angle: float = -rotation * 0.7 + TAU * float(i) / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var point := ring_center + direction * radius * 0.87
		var detail: int = (i * 37 + 11) % 7

		draw_line(
			point - direction * 8.0,
			point + direction * 8.0,
			strong,
			2.0
		)

		if detail % 2 == 0:
			draw_line(
				point - tangent * 6.0,
				point + tangent * 6.0,
				strong,
				2.0
			)

		if detail > 2:
			draw_line(
				point + direction * 8.0,
				point + direction * 8.0 + tangent * 7.0,
				strong,
				2.0
			)

		if detail > 4:
			draw_line(
				point - direction * 8.0,
				point - direction * 8.0 - tangent * 7.0,
				strong,
				2.0
			)

	# Gate glow on the floor.
	var gate_width: float = radius * 0.34
	var gate_height: float = radius * 0.70

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(gx - gate_width, ground),
			Vector2(gx + gate_width, ground),
			Vector2(gx + gate_width * 2.6, ground + radius * 0.5),
			Vector2(gx - gate_width * 2.6, ground + radius * 0.5)
		]),
		_with_alpha(glow_color, 0.10 * pulse)
	)

	# Gate frame and opening.
	var frame := _arch(
		gx,
		ground,
		gate_width + radius * 0.09,
		gate_height
	)
	_poly(
		frame,
		Color(0.10, 0.11, 0.15),
		_with_alpha(ring_color, 0.9),
		2.5
	)

	var opening := _arch(gx, ground, gate_width, gate_height)
	_poly(opening, Color(0.06, 0.03, 0.02))

	var focal := Vector2(gx, ground - gate_height * 0.35)

	for k in range(7):
		var factor: float = 1.0 - float(k) * 0.12
		var glow := _with_alpha(
			glow_color,
			(0.12 + 0.07 * float(k)) * pulse
		)
		draw_colored_polygon(_scaled_about(opening, focal, factor), glow)

	for i in range(6):
		var y: float = (
			ground
			- radius * 0.02
			- float(i) * radius * 0.035 * (1.0 + float(i) * 0.12)
		)
		var half_width: float = gate_width * (0.95 - float(i) * 0.13)

		draw_line(
			Vector2(gx - half_width, y),
			Vector2(gx + half_width, y),
			Color(1.0, 0.85, 0.5, 0.35 - float(i) * 0.04),
			2.0
		)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(gx, ground - gate_height - gate_width - radius * 0.13),
			Vector2(gx + radius * 0.05, ground - gate_height - gate_width - radius * 0.07),
			Vector2(gx, ground - gate_height - gate_width - radius * 0.01),
			Vector2(gx - radius * 0.05, ground - gate_height - gate_width - radius * 0.07)
		]),
		ring_color
	)

	# Torches and their light.
	for side: float in [-1.0, 1.0]:
		var torch_x: float = gx + side * radius * 1.12

		draw_rect(
			Rect2(torch_x - 4.0, ground - radius * 0.5, 8.0, radius * 0.5),
			Color(0.14, 0.12, 0.1)
		)
		draw_rect(
			Rect2(torch_x - 9.0, ground - radius * 0.54, 18.0, 8.0),
			_with_alpha(ring_color, 0.9)
		)

		_flame(
			Vector2(torch_x, ground - radius * 0.54),
			radius * 0.13,
			side * 1.7
		)

		for glow_data in [[0.2, 0.025], [0.14, 0.035], [0.08, 0.05]]:
			draw_circle(
				Vector2(torch_x, ground - radius * 0.62),
				radius * float(glow_data[0]),
				_with_alpha(glow_color, float(glow_data[1]) * pulse)
			)

	# Hero silhouettes and ground shadows.
	var hero_scale: float = radius * 0.62
	var knight_position := Vector2(gx - radius * 0.66, ground)
	var mage_position := Vector2(gx + radius * 0.66, ground)

	_poly(
		_ellipse(
			knight_position + Vector2(0, 4),
			hero_scale * 0.34,
			hero_scale * 0.05
		),
		Color(0, 0, 0, 0.45)
	)

	_poly(
		_ellipse(
			mage_position + Vector2(0, 4),
			hero_scale * 0.34,
			hero_scale * 0.05
		),
		Color(0, 0, 0, 0.45)
	)

	_hero(
		KNIGHT_PARTS,
		KNIGHT_STYLES,
		knight_position,
		hero_scale,
		knight_color
	)
	_hero(
		MAGE_PARTS,
		MAGE_STYLES,
		mage_position,
		hero_scale,
		mage_color
	)

	# Knight shield emblem.
	var shield_center := knight_position + Vector2(-0.27, -0.58) * hero_scale

	draw_line(
		shield_center + Vector2(0, -0.14) * hero_scale,
		shield_center + Vector2(0, 0.13) * hero_scale,
		_with_alpha(knight_color, 0.9),
		2.0
	)
	draw_line(
		shield_center + Vector2(-0.09, -0.02) * hero_scale,
		shield_center + Vector2(0.09, -0.02) * hero_scale,
		_with_alpha(knight_color, 0.9),
		2.0
	)

	# Mage orb and casting spark.
	var orb := mage_position + Vector2(0.2925, -1.07) * hero_scale
	var spark := mage_position + Vector2(-0.17, -0.45) * hero_scale
	var orb_pulse: float = 0.95 + 0.05 * sin(_t * 1.3)

	for glow_data in [[0.12, 0.10], [0.08, 0.2], [0.05, 0.9]]:
		draw_circle(
			orb,
			hero_scale * float(glow_data[0]) * orb_pulse,
			_with_alpha(mage_color, float(glow_data[1]))
		)

	for glow_data in [[0.07, 0.12], [0.035, 0.85]]:
		draw_circle(
			spark,
			hero_scale * float(glow_data[0]),
			_with_alpha(mage_color, float(glow_data[1]))
		)

	# Role emblems.
	_emblem(
		knight_position + Vector2(0, -hero_scale * 1.36),
		hero_scale * 0.1,
		"knight",
		knight_color
	)
	_emblem(
		mage_position + Vector2(0, -hero_scale * 1.36),
		hero_scale * 0.1,
		"mage",
		mage_color
	)

	if show_labels:
		var font: Font = ThemeDB.fallback_font

		draw_string(
			font,
			knight_position + Vector2(-80, hero_scale * 0.17),
			"THE KNIGHT",
			HORIZONTAL_ALIGNMENT_CENTER,
			160.0,
			15,
			_with_alpha(knight_color, 0.95)
		)
		draw_string(
			font,
			mage_position + Vector2(-80, hero_scale * 0.17),
			"THE MAGE",
			HORIZONTAL_ALIGNMENT_CENTER,
			160.0,
			15,
			_with_alpha(mage_color, 0.95)
		)


func _ellipse(
	center: Vector2,
	radius_x: float,
	radius_y: float
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for i in range(20):
		var angle: float = TAU * float(i) / 20.0
		points.append(
			center
			+ Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		)

	return points


func _emblem(
	center: Vector2,
	radius: float,
	role: String,
	color: Color
) -> void:
	draw_circle(center, radius, Color(0.07, 0.08, 0.11, 0.9))
	draw_arc(center, radius, 0.0, TAU, 32, color, 2.0, true)

	var points := PackedVector2Array()

	if role == "knight":
		points = PackedVector2Array([
			Vector2(-0.62, -0.7),
			Vector2(0.62, -0.7),
			Vector2(0.62, 0.1),
			Vector2(0, 0.85),
			Vector2(-0.62, 0.1)
		])
	else:
		points = PackedVector2Array([
			Vector2(0, -0.9),
			Vector2(0.2, -0.2),
			Vector2(0.9, 0),
			Vector2(0.2, 0.2),
			Vector2(0, 0.9),
			Vector2(-0.2, 0.2),
			Vector2(-0.9, 0),
			Vector2(-0.2, -0.2)
		])

	var scaled_points := PackedVector2Array()

	for point in points:
		scaled_points.append(center + point * radius * 0.58)

	draw_colored_polygon(scaled_points, _with_alpha(color, 0.9))
