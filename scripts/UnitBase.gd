extends Node2D

@export var max_hp: float = 70.0
@export var hp: float = 70.0
@export var speed: float = 120.0
@export_enum("PLAYER", "ENEMY") var team: int = 0
@export_enum("LEFT", "RIGHT") var lane: int = 0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 0.9
@export var damage: float = 10.0
@export var uses_projectile: bool = false
@export var projectile_scene: PackedScene = preload("res://scenes/units/Projectile.tscn")

var _cooldown_remaining: float = 0.0
var _is_dead: bool = false
var _hit_flash_tween: Tween = null

func _ready() -> void:
	hp = clampf(hp, 0.0, max_hp)
	add_to_group("units")
	_snap_to_lane()
	_update_team_visuals()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	var target := _select_target_in_range()
	if target != null:
		try_attack(target)
		return

	_move_forward(delta)

func _move_forward(delta: float) -> void:
	global_position.x = _lane_x()
	global_position.y += _forward_direction() * speed * delta

func _forward_direction() -> float:
	return -1.0 if team == 0 else 1.0

func _lane_x() -> float:
	return 576.0 if lane == 0 else 1344.0

func _snap_to_lane() -> void:
	global_position.x = _lane_x()

func can_attack(target: Node2D) -> bool:
	if target == null or _cooldown_remaining > 0.0 or not is_alive():
		return false
	return global_position.distance_to(target.global_position) <= attack_range

func try_attack(target: Node2D) -> bool:
	if not can_attack(target):
		return false

	if uses_projectile and projectile_scene != null:
		_spawn_projectile(target)
	else:
		if target.has_method("apply_damage"):
			target.apply_damage(damage)
		elif target.has_method("take_damage"):
			target.take_damage(damage)
		else:
			return false

	_cooldown_remaining = attack_cooldown
	return true

func _spawn_projectile(target: Node2D) -> void:
	var projectile_instance := projectile_scene.instantiate()
	if not (projectile_instance is Projectile):
		return

	var projectile := projectile_instance as Projectile
	var parent := get_tree().current_scene if get_tree().current_scene != null else self
	parent.add_child(projectile)
	projectile.global_position = global_position + Vector2(0.0, -10.0)
	projectile.configure(team, damage, target)

func _select_target_in_range() -> Node2D:
	var unit_target := _nearest_enemy_in_range(get_tree().get_nodes_in_group("units"))
	if unit_target != null:
		return unit_target
	return _nearest_enemy_in_range(get_tree().get_nodes_in_group("towers"))

func _nearest_enemy_in_range(candidates: Array[Node]) -> Node2D:
	var best_target: Node2D = null
	var best_distance := INF

	for node in candidates:
		if node == self:
			continue
		if not (node is Node2D):
			continue
		if not _is_enemy(node):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue

		var node_2d := node as Node2D
		var distance := global_position.distance_to(node_2d.global_position)
		if distance > attack_range:
			continue
		if distance < best_distance:
			best_distance = distance
			best_target = node_2d

	return best_target

func _is_enemy(node: Node) -> bool:
	if not node.has_method("get"):
		return false
	var node_team := node.get("team")
	if typeof(node_team) != TYPE_INT:
		return false
	return int(node_team) != team

func apply_damage(amount: float) -> void:
	if _is_dead:
		return
	hp = maxf(0.0, hp - maxf(0.0, amount))
	_play_hit_feedback()
	if hp <= 0.0:
		_die()

func is_alive() -> bool:
	return not _is_dead and hp > 0.0

func _die() -> void:
	_is_dead = true
	queue_free()

func _play_hit_feedback() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()
	modulate = Color(1.0, 0.6, 0.6, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.10)

func _update_team_visuals() -> void:
	var body := get_node_or_null("Body") as Polygon2D
	if body == null:
		return
	body.color = Color(0.4, 0.75, 1.0, 1.0) if team == 0 else Color(1.0, 0.5, 0.5, 1.0)
