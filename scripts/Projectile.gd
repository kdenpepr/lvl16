extends Area2D
class_name Projectile

@export var speed: float = 520.0
@export var max_lifetime: float = 3.0

var _team: int = -1
var _damage: float = 0.0
var _target: Node2D = null
var _lifetime: float = 0.0

func configure(team: int, damage: float, target: Node2D) -> void:
	_team = team
	_damage = damage
	_target = target

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= max_lifetime:
		queue_free()
		return

	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()
	if distance <= speed * delta:
		_apply_hit(_target)
		queue_free()
		return

	var direction := to_target / maxf(distance, 0.001)
	global_position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	if body is Node2D:
		_apply_hit(body as Node2D)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is Node2D:
		_apply_hit(area as Node2D)
		queue_free()

func _apply_hit(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("get"):
		var node_team := node.get("team")
		if typeof(node_team) == TYPE_INT and int(node_team) == _team:
			return

	if node.has_method("apply_damage"):
		node.apply_damage(_damage)
	elif node.has_method("take_damage"):
		node.take_damage(_damage)
