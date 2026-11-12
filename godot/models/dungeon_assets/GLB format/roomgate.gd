
extends Node3D
## Entrance gate for Virelune combat rooms.
## Starts open, closes when either player enters, and reopens
## after every enemy in the assigned group is defeated.

@export var enemy_group: StringName = &"room_1_enemies"
@export var detection_area: NodePath

@export var open_height: float = 2.2
@export var move_time: float = 1.2

var closed_y: float = 0.0
var is_open: bool = true
var fight_started: bool = false
var cleared: bool = false
var check_timer: float = 0.0

var tween: Tween
var detection: Area3D = null


func _ready() -> void:
	closed_y = position.y

	# Entrance starts open.
	position.y = closed_y + open_height
	is_open = true

	find_detection_area()

	if detection == null:
		push_error(
			"Entrance Gate: Detection Area not found. "
			+ "Make sure it is an Area3D with a CollisionShape3D."
		)
		return

	if not detection.monitoring:
		detection.monitoring = true

	if not detection.body_entered.is_connected(
		_on_detection_body_entered
	):
		detection.body_entered.connect(
			_on_detection_body_entered
		)

	print(
		"Entrance Gate: Detection area connected: ",
		detection.get_path()
	)


func find_detection_area() -> void:
	detection = null

	# 1. Try the Inspector-assigned NodePath.
	if not detection_area.is_empty():
		detection = get_node_or_null(
			detection_area
		) as Area3D

	if detection != null:
		return

	# 2. Search inside the gate.
	detection = find_child(
		"DetectionArea", true, false
	) as Area3D

	if detection == null:
		detection = find_child(
			"detection_area", true, false
		) as Area3D

	if detection != null:
		return

	# 3. Search siblings under the gate's parent.
	if get_parent() != null:
		detection = get_parent().find_child(
			"DetectionArea", true, false
		) as Area3D

		if detection == null:
			detection = get_parent().find_child(
				"detection_area", true, false
			) as Area3D

		if detection != null:
			return

	# 4. Search all nodes in the current scene.
	var scene := get_tree().current_scene

	if scene != null:
		detection = scene.find_child(
			"DetectionArea", true, false
		) as Area3D

		if detection == null:
			detection = scene.find_child(
				"detection_area", true, false
			) as Area3D


func _on_detection_body_entered(body: Node3D) -> void:
	if cleared or fight_started:
		return

	if not body.is_in_group("player1") and not body.is_in_group("player2"):
		return

	if group_cleared():
		cleared = true
		print("Entrance Gate: Encounter already cleared.")
		return

	fight_started = true

	print("Entrance Gate: Player entered. Closing gate!")

	set_open(false)


func _physics_process(delta: float) -> void:
	if cleared or not fight_started:
		return

	check_timer -= delta

	if check_timer > 0.0:
		return

	check_timer = 0.3

	if group_cleared():
		cleared = true

		print("Entrance Gate: All enemies defeated. Opening gate!")

		set_open(true)


func group_cleared() -> bool:
	if enemy_group == &"":
		return false

	var enemies := get_tree().get_nodes_in_group(
		enemy_group
	)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.get("is_dead") == true:
			continue

		if enemy.get("is_dying") == true:
			continue

		return false

	return true


func set_open(open: bool) -> void:
	if is_open == open:
		return

	is_open = open

	if tween != null and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	var target_y := closed_y + (
		open_height if open else 0.0
	)

	tween.tween_property(
		self,
		"position:y",
		target_y,
		move_time
	)
