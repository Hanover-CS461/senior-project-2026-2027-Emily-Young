extends Area3D
## Projectile fired by the Skeleton Mage boss.

var direction = Vector3.FORWARD
var speed = 7.0
var damage = 15.0
var lifetime = 5.0


func _ready():

	body_entered.connect(_on_body_entered)


func _physics_process(delta):

	global_position += direction * speed * delta

	lifetime -= delta

	if lifetime <= 0:
		queue_free()


func _on_body_entered(body):

	if body.is_in_group("player1") or body.is_in_group("player2"):

		if not body.is_dead and body.has_method("take_damage"):
			body.take_damage(damage)

		queue_free()

	elif body is CharacterBody3D:

		# Other enemies (including the boss) - fly through them
		return

	else:

		# Wall / floor / prop
		queue_free()
