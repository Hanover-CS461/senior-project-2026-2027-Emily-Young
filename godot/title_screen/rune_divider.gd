@tool
extends Control
## Thin bronze rule with a centre diamond. Fades out towards both ends.

@export var color: Color = Color("b07a3a"):
	set(value):
		color = value
		queue_redraw()
@export var length := 420.0:
	set(value):
		length = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size.y = 16.0


func _draw() -> void:
	var y := size.y / 2.0
	var l := minf(length, size.x)
	var mid := l / 2.0
	var segs := 28
	for i in segs:
		var x0 := l * i / segs
		var x1 := l * (i + 1) / segs
		var dist := absf((x0 + x1) / 2.0 - mid) / mid
		if dist < 0.06:
			continue
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(color, (1.0 - dist) * 0.9), 2.0)
	var d := 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(mid, y - d), Vector2(mid + d, y), Vector2(mid, y + d), Vector2(mid - d, y)]), color)
	for off in [-24.0, 24.0]:
		draw_circle(Vector2(mid + off, y), 2.0, Color(color, 0.8))
