extends Node
class_name ElixirSystem

signal elixir_changed(current_elixir: float, max_elixir: float)

@export var max_elixir: float = 10.0
@export var starting_elixir: float = 5.0
@export var regen_amount: float = 1.0
@export var regen_interval: float = 2.8

var current_elixir: float = 0.0
var _regen_timer: float = 0.0

func _ready() -> void:
	max_elixir = maxf(max_elixir, 0.0)
	current_elixir = clampf(starting_elixir, 0.0, max_elixir)
	_regen_timer = 0.0
	_emit_changed()

func _process(delta: float) -> void:
	if regen_interval <= 0.0 or regen_amount <= 0.0:
		return
	if current_elixir >= max_elixir:
		_regen_timer = 0.0
		return

	_regen_timer += delta
	while _regen_timer >= regen_interval:
		_regen_timer -= regen_interval
		add_elixir(regen_amount)
		if current_elixir >= max_elixir:
			_regen_timer = 0.0
			break

func can_afford(cost: int) -> bool:
	return current_elixir >= float(cost)

func spend(cost: int) -> bool:
	if cost <= 0:
		return true
	if not can_afford(cost):
		return false

	current_elixir = maxf(0.0, current_elixir - float(cost))
	_emit_changed()
	return true

func add_elixir(amount: float) -> void:
	if amount <= 0.0:
		return
	var previous := current_elixir
	current_elixir = clampf(current_elixir + amount, 0.0, max_elixir)
	if not is_equal_approx(previous, current_elixir):
		_emit_changed()

func configure(next_max_elixir: float, next_starting_elixir: float) -> void:
	max_elixir = maxf(next_max_elixir, 0.0)
	starting_elixir = clampf(next_starting_elixir, 0.0, max_elixir)
	current_elixir = starting_elixir
	_regen_timer = 0.0
	_emit_changed()

func _emit_changed() -> void:
	elixir_changed.emit(current_elixir, max_elixir)
