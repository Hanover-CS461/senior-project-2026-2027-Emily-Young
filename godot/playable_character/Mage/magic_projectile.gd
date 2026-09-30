extends MeshInstance3D


@export var speed = 12.0
@export var damage = 20


var target_position = Vector3.ZERO
var spell_name = "Fireball"


@onready var hit_area = $Area3D


# ==========================================
# SET TARGET
# ==========================================

func set_target(target: Vector3):

	target_position = target


# ==========================================
# SET SPELL
# ==========================================

func set_spell(spell: String):

	spell_name = spell

	print("Projectile spell: ", spell_name)

	if spell_name == "Fireball":

		scale = Vector3(1.2, 1.2, 1.2)

	elif spell_name == "Ice":

		scale = Vector3(1.0, 1.0, 1.0)

	elif spell_name == "Lightning":

		scale = Vector3(1.4, 1.4, 1.4)


# ==========================================
# MOVE PROJECTILE
# ==========================================

func _physics_process(delta):

	var distance = global_position.distance_to(
		target_position
	)


	# ==========================================
	# REACHED TARGET
	# ==========================================

	if distance <= 0.05:

		global_position = target_position

		print(
			"Projectile reached target: ",
			spell_name
		)

		queue_free()

		return


	# ==========================================
	# MOVE TOWARD TARGET
	# ==========================================

	var direction = global_position.direction_to(
		target_position
	)

	var movement = speed * delta

	# Never move past the target.

	if movement >= distance:

		global_position = target_position

	else:

		global_position += direction * movement


	# ==========================================
	# CHECK ENEMY COLLISION
	# ==========================================

	var bodies = hit_area.get_overlapping_bodies()

	for body in bodies:

		if body.is_in_group("enemies"):

			if body.has_method("take_damage"):

				body.take_damage(damage)

				print(
					"Mage ",
					spell_name,
					" hits enemy!"
				)

				queue_free()

				return
