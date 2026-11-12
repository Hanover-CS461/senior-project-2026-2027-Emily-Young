
extends Node3D
## Enemy health bars for a crowded split-screen game.
##
## Regular enemies: a small bar floating above the head. It only appears after
## the enemy takes damage, stays for show_seconds, then fades.
##
## Boss (group "boss"): one screen-space bar on the split-screen seam.

@export var enemy_groups: Array[String] = ["enemies", "gate_minions", "boss_summons"]

@export var show_seconds := 4.0
@export var fade_seconds := 0.8
@export var max_distance := 9.0

@export var show_when_full := false
@export var bar_width_factor := 0.5

@export var boss_group := "boss"
@export var boss_name := "SKELETON MAGE"

@export_range(0.0, 1.0) var boss_bar_anchor_y := 0.5
@export var boss_bar_width := 460.0

const SHADER_CODE = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

instance uniform float ratio = 1.0;
instance uniform float opacity = 1.0;

uniform vec4 fill_color : source_color = vec4(0.85, 0.12, 0.12, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.05, 0.05, 0.75);
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 0.95);
uniform vec2 border = vec2(0.012, 0.16);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 c = back_color;

	if (UV.x <= ratio) {
		c = fill_color;
	}

	if (UV.x < border.x || UV.x > 1.0 - border.x || UV.y < border.y || UV.y > 1.0 - border.y) {
		c = border_color;
	}

	ALBEDO = c.rgb;
	ALPHA = c.a * opacity;
}
"""

var material: ShaderMaterial
var tracked := {}
var scan_timer := 0.0

var player1
var player2

# Boss UI
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_bar: ProgressBar
var boss_fill: StyleBoxFlat
var boss_hp_label: Label
var boss_status: Label
var boss_max_seen := 0.0


func _ready():
	var shader = Shader.new()
	shader.code = SHADER_CODE

	material = ShaderMaterial.new()
	material.shader = shader

	build_boss_ui()


func _process(delta):
	if player1 == null or not is_instance_valid(player1):
		player1 = get_tree().get_first_node_in_group("player1")

	if player2 == null or not is_instance_valid(player2):
		player2 = get_tree().get_first_node_in_group("player2")

	scan_timer -= delta

	if scan_timer <= 0:
		scan_timer = 0.3
		scan_for_enemies()

	for id in tracked.keys():
		update_enemy(id)

	update_boss(delta)


# ============================================================
# PROPERTY HELPERS
# ============================================================

func has_property(object: Object, property_name: String) -> bool:
	if object == null or not is_instance_valid(object):
		return false

	for property in object.get_property_list():
		if property["name"] == property_name:
			return true

	return false


func get_optional_property(object: Object, property_name: String):
	if has_property(object, property_name):
		return object.get(property_name)

	return null


## Rogue uses current_health for its changing HP and health for max HP.
## Other enemies can continue using health as their current HP.
func get_enemy_hp(enemy: Object) -> float:
	if has_property(enemy, "current_health"):
		return float(enemy.get("current_health"))

	if has_property(enemy, "health"):
		return float(enemy.get("health"))

	return 0.0


## Get the best available maximum-health value.
func get_enemy_max_hp(enemy: Object, fallback: float) -> float:
	var max_value = get_optional_property(enemy, "max_health")

	if max_value != null:
		return max(float(max_value), fallback)

	# For the Rogue, health is its maximum HP.
	if has_property(enemy, "current_health") and has_property(enemy, "health"):
		return max(float(enemy.get("health")), fallback)

	return max(fallback, 1.0)


func enemy_is_awake(enemy: Object) -> bool:
	# Skeleton Rogue uses is_awake.
	var awake = get_optional_property(enemy, "is_awake")

	if awake != null:
		return awake == true

	# Other enemies may use fight_started.
	awake = get_optional_property(enemy, "fight_started")

	if awake != null:
		return awake == true

	return true


func enemy_is_dead(enemy: Object) -> bool:
	return (
		get_optional_property(enemy, "is_dead") == true
		or get_optional_property(enemy, "is_dying") == true
	)


# ============================================================
# FLOATING BARS
# ============================================================

func scan_for_enemies():
	for group_name in enemy_groups:
		for enemy in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(enemy):
				continue

			var id = enemy.get_instance_id()

			if tracked.has(id):
				continue

			if enemy.is_in_group(boss_group):
				continue

			if not has_property(enemy, "health"):
				continue

			register_enemy(enemy)


func register_enemy(enemy):
	var quad = QuadMesh.new()
	quad.size = Vector2(0.5, 0.06)

	var mesh = MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Layers 1 + 2, so it shows even if a camera hides layer 1.
	mesh.layers = 3
	mesh.visible = false

	add_child(mesh)

	mesh.set_instance_shader_parameter("ratio", 1.0)
	mesh.set_instance_shader_parameter("opacity", 0.0)

	var hp = get_enemy_hp(enemy)
	var max_hp = get_enemy_max_hp(enemy, hp)

	tracked[enemy.get_instance_id()] = {
		"enemy": enemy,
		"mesh": mesh,
		"quad": quad,
		"last_hp": hp,
		"max_hp": max_hp,
		"last_hit": -100000.0,
		"top": -1.0
	}


func update_enemy(id):
	if not tracked.has(id):
		return

	var data = tracked[id]
	var enemy = data["enemy"]
	var mesh: MeshInstance3D = data["mesh"]

	if not is_instance_valid(enemy):
		if is_instance_valid(mesh):
			mesh.queue_free()

		tracked.erase(id)
		return

	var hp = get_enemy_hp(enemy)

	# Keep the maximum HP stable, using the enemy's health property
	# when it represents its maximum HP.
	data["max_hp"] = max(
		data["max_hp"],
		get_enemy_max_hp(enemy, data["max_hp"])
	)

	if hp < data["last_hp"] - 0.001:
		data["last_hit"] = Time.get_ticks_msec() / 1000.0

	data["last_hp"] = hp

	var awake = enemy_is_awake(enemy)
	var dead = enemy_is_dead(enemy)

	var alpha = 0.0

	if awake and not dead and hp > 0.0:
		var age = Time.get_ticks_msec() / 1000.0 - data["last_hit"]

		if show_when_full or age < show_seconds:
			alpha = 1.0
		elif age < show_seconds + fade_seconds:
			alpha = 1.0 - (age - show_seconds) / fade_seconds

	if alpha > 0.0 and nearest_player_distance(enemy) > max_distance:
		alpha = 0.0

	if alpha <= 0.0:
		mesh.visible = false
		return

	if data["top"] < 0.0:
		var top = compute_top(enemy)
		data["top"] = top

		var width = clamp(top * bar_width_factor, 0.4, 1.1)
		data["quad"].size = Vector2(width, width * 0.13)

	mesh.visible = true
	mesh.global_position = enemy.global_position + Vector3.UP * (data["top"] + 0.12)

	var max_hp = max(float(data["max_hp"]), 1.0)

	mesh.set_instance_shader_parameter(
		"ratio",
		clamp(hp / max_hp, 0.0, 1.0)
	)

	mesh.set_instance_shader_parameter("opacity", alpha)


## Height of the enemy's highest mesh point above its feet.
## The Rogue's Rig_Medium is a sibling of its CharacterBody3D,
## so inspect that visual model instead of only searching the body.
func compute_top(enemy) -> float:
	var visual_root: Node = enemy

	var parent = enemy.get_parent()

	if parent != null:
		var rogue_visual = parent.get_node_or_null("Rig_Medium")

		if rogue_visual != null:
			visual_root = rogue_visual

	var top = 0.0
	var found = false

	for m in visual_root.find_children("*", "MeshInstance3D", true, false):
		var box = m.get_aabb()
		var xform = m.global_transform

		for i in range(8):
			var corner = xform * box.get_endpoint(i)
			top = max(top, corner.y - enemy.global_position.y)
			found = true

	if not found or top < 0.3 or top > 5.0:
		return 1.0

	return top


func nearest_player_distance(node: Node3D) -> float:
	var best = INF

	for p in [player1, player2]:
		if p != null and is_instance_valid(p):
			best = min(best, node.global_position.distance_to(p.global_position))

	return best


# ============================================================
# BOSS BAR (screen space, on the split-screen seam)
# ============================================================

func build_boss_ui():
	var layer = CanvasLayer.new()
	layer.layer = 9
	add_child(layer)

	boss_panel = PanelContainer.new()
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 6

	boss_panel.add_theme_stylebox_override("panel", style)

	layer.add_child(boss_panel)

	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.anchor_top = boss_bar_anchor_y
	boss_panel.anchor_bottom = boss_bar_anchor_y
	boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(box)

	boss_name_label = Label.new()
	boss_name_label.text = boss_name
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 15)
	boss_name_label.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	box.add_child(boss_name_label)

	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(boss_bar_width, 18)
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var back = StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.06, 0.1, 0.95)
	back.set_corner_radius_all(4)

	boss_fill = StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.7, 0.3, 1.0)
	boss_fill.set_corner_radius_all(4)

	boss_bar.add_theme_stylebox_override("background", back)
	boss_bar.add_theme_stylebox_override("fill", boss_fill)
	box.add_child(boss_bar)

	boss_hp_label = Label.new()
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_hp_label.add_theme_font_size_override("font_size", 13)
	boss_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_hp_label.add_theme_constant_override("outline_size", 5)
	boss_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	boss_bar.add_child(boss_hp_label)
	boss_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	boss_status = Label.new()
	boss_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_status.add_theme_font_size_override("font_size", 13)
	boss_status.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	box.add_child(boss_status)


func update_boss(delta):
	var boss = get_tree().get_first_node_in_group(boss_group)

	if boss == null or not is_instance_valid(boss) or not has_property(boss, "health"):
		boss_panel.visible = false
		return

	var hp = float(boss.get("health"))
	var awake = get_optional_property(boss, "fight_started")
	var dying = enemy_is_dead(boss)

	if awake != true or dying or hp <= 0.0:
		boss_panel.visible = false
		return

	boss_panel.visible = true

	var max_value = get_optional_property(boss, "max_health")

	boss_max_seen = max(boss_max_seen, hp)
	var max_hp = boss_max_seen

	if max_value != null:
		max_hp = max(float(max_value), hp)

	max_hp = max(max_hp, 1.0)

	boss_bar.max_value = max_hp
	boss_bar.value = lerp(boss_bar.value, hp, min(1.0, delta * 6.0))

	boss_hp_label.text = "%d / %d" % [int(ceil(hp)), int(round(max_hp))]

	# Shielded while any summon is alive.
	var alive = 0
	var summons = get_optional_property(boss, "active_summons")

	if summons is Array:
		for s in summons:
			if is_instance_valid(s) and not enemy_is_dead(s):
				alive += 1

	if alive > 0:
		boss_status.text = "Shielded by %d summon%s - defeat them!" % [
			alive,
			"" if alive == 1 else "s"
		]
		boss_fill.bg_color = Color(0.45, 0.55, 0.75)
	else:
		boss_status.text = ""
		boss_fill.bg_color = Color(0.7, 0.3, 1.0)
