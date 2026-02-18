extends Node
class_name EnemyAI

const ENEMY_TEAM: int = 1
const LANE_LEFT: int = 0
const LANE_RIGHT: int = 1

const DEFAULT_DECK_CARD_PATHS: Array[String] = [
	"res://data/cards/iron_vanguard.tres",
	"res://data/cards/ember_archer.tres",
	"res://data/cards/stone_colossus.tres",
	"res://data/cards/gear_swarm.tres",
	"res://data/cards/dusk_duelist.tres",
	"res://data/cards/spark_slinger.tres",
	"res://data/cards/frost_guardian.tres",
	"res://data/cards/river_raiders.tres",
]

@export var min_play_interval: float = 2.0
@export var max_play_interval: float = 5.0
@export var top_deploy_min: float = 0.08
@export var top_deploy_max: float = 0.38
@export var river_top: float = 0.43
@export var river_bottom: float = 0.57

@onready var deck_system: DeckSystem = $DeckSystem
@onready var elixir_system: ElixirSystem = $ElixirSystem

var _rng := RandomNumberGenerator.new()
var _next_play_timer: float = 0.0
var _is_active: bool = true
var _world: Node2D = null

func _ready() -> void:
	_rng.randomize()
	elixir_system.configure(10.0, 5.0)
	_ensure_deck_initialized()
	_schedule_next_play()

func setup(world: Node2D) -> void:
	_world = world

func set_active(active: bool) -> void:
	_is_active = active

func _process(delta: float) -> void:
	if not _is_active:
		return
	if _world == null:
		return

	_next_play_timer -= delta
	if _next_play_timer > 0.0:
		return

	_try_play_random_affordable_card()
	_schedule_next_play()

func _ensure_deck_initialized() -> void:
	if deck_system.hand.size() > 0 or deck_system.draw_pile.size() > 0:
		return

	var default_deck: Array[CardData] = []
	for path in DEFAULT_DECK_CARD_PATHS:
		var resource := load(path)
		if resource is CardData:
			default_deck.append(resource)

	if default_deck.size() > 0:
		deck_system.initialize_deck(default_deck)

func _schedule_next_play() -> void:
	var min_interval := minf(min_play_interval, max_play_interval)
	var max_interval := maxf(min_play_interval, max_play_interval)
	_next_play_timer = _rng.randf_range(min_interval, max_interval)

func _try_play_random_affordable_card() -> void:
	var hand := deck_system.get_hand()
	if hand.is_empty():
		return

	var affordable_indexes: Array[int] = []
	for i in hand.size():
		var card := hand[i]
		if card != null and elixir_system.can_afford(card.cost):
			affordable_indexes.append(i)

	if affordable_indexes.is_empty():
		return

	var selected_index := affordable_indexes[_rng.randi_range(0, affordable_indexes.size() - 1)]
	var selected_card := hand[selected_index]
	if selected_card == null:
		return

	var unit_scene := load(selected_card.unit_scene_path)
	if not (unit_scene is PackedScene):
		return

	var lane := _rng.randi_range(LANE_LEFT, LANE_RIGHT)
	var spawn_position := _enemy_spawn_position_for_lane(lane)
	if not _is_valid_enemy_position(spawn_position):
		return

	var unit_instance := (unit_scene as PackedScene).instantiate()
	if not (unit_instance is Node2D):
		if unit_instance != null:
			unit_instance.queue_free()
		return

	if not elixir_system.spend(selected_card.cost):
		unit_instance.queue_free()
		return
	var played_card := deck_system.play_card(selected_index)
	if played_card == null:
		elixir_system.add_elixir(float(selected_card.cost))
		unit_instance.queue_free()
		return

	_world.add_child(unit_instance)
	var unit := unit_instance as Node2D
	unit.global_position = spawn_position
	unit.set("team", ENEMY_TEAM)
	unit.set("lane", lane)
	if unit.has_method("_snap_to_lane"):
		unit.call("_snap_to_lane")

func _enemy_spawn_position_for_lane(lane: int) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var lane_x := viewport_size.x * 0.3 if lane == LANE_LEFT else viewport_size.x * 0.7
	var lane_y := viewport_size.y * _rng.randf_range(top_deploy_min, top_deploy_max)
	return Vector2(lane_x, lane_y)

func _is_valid_enemy_position(position: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	if position.y >= viewport_size.y * 0.5:
		return false

	var top_river := viewport_size.y * river_top
	var bottom_river := viewport_size.y * river_bottom
	if position.y >= top_river and position.y <= bottom_river:
		return false

	return true
