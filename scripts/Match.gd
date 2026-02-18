extends Control

const PLAYER_TEAM: int = 0
const LANE_LEFT: int = 0
const LANE_RIGHT: int = 1

@export var match_duration_seconds: float = 180.0

@onready var world: Node2D = $World
@onready var hand_ui = $HandUI
@onready var enemy_ai: EnemyAI = $EnemyAI
@onready var timer_label: Label = $TimerLabel

@onready var player_towers: Array[Node] = [
	$World/PlayerTowerLeft,
	$World/PlayerTowerRight,
]

@onready var enemy_towers: Array[Node] = [
	$World/EnemyTowerLeft,
	$World/EnemyTowerRight,
]

@onready var ghost_preview: ColorRect = $GhostPreview
@onready var result_overlay: ColorRect = $ResultOverlay
@onready var result_label: Label = $ResultOverlay/Panel/VBox/ResultLabel
@onready var back_to_menu_button: Button = $ResultOverlay/Panel/VBox/BackToMenuButton

var _match_finished: bool = false
var _placement_active: bool = false
var _selected_card: CardData = null
var _selected_hand_index: int = -1
var _time_remaining: float = 0.0

func _ready() -> void:
	result_overlay.visible = false
	ghost_preview.visible = false
	_time_remaining = maxf(0.0, match_duration_seconds)
	_update_timer_label()

	back_to_menu_button.pressed.connect(_on_back_to_menu_button_pressed)
	hand_ui.card_selected.connect(_on_card_selected)
	enemy_ai.setup(world)
	enemy_ai.set_active(true)

func _process(delta: float) -> void:
	if _match_finished:
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	_update_timer_label()
	if _time_remaining <= 0.0:
		_end_match_by_tower_hp()
		return

	if _are_all_destroyed(enemy_towers):
		_end_match(true)
		return
	if _are_all_destroyed(player_towers):
		_end_match(false)
		return

	if _placement_active:
		_update_ghost_preview()

func _unhandled_input(event: InputEvent) -> void:
	if _match_finished:
		return
	if not _placement_active:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_placement_mode()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement_mode()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_selected_card(mouse_event.position)

func _on_card_selected(hand_index: int, card: CardData) -> void:
	if _match_finished:
		return
	_selected_hand_index = hand_index
	_selected_card = card
	_placement_active = true
	ghost_preview.visible = true
	_update_ghost_preview()

func _try_place_selected_card(mouse_position: Vector2) -> void:
	if _selected_card == null:
		_cancel_placement_mode()
		return
	if not _is_valid_placement_position(mouse_position):
		return
	if not hand_ui.can_play_card(_selected_hand_index):
		_cancel_placement_mode()
		return

	var unit_scene := load(_selected_card.unit_scene_path)
	if not (unit_scene is PackedScene):
		push_error("Card unit_scene_path is not a valid PackedScene: %s" % _selected_card.unit_scene_path)
		_cancel_placement_mode()
		return

	var played_card := hand_ui.play_card_from_hand(_selected_hand_index)
	if played_card == null:
		_cancel_placement_mode()
		return

	var spawned_unit := (unit_scene as PackedScene).instantiate()
	if not (spawned_unit is Node2D):
		if spawned_unit != null:
			spawned_unit.queue_free()
		_cancel_placement_mode()
		return

	var lane := _lane_from_x(mouse_position.x)
	world.add_child(spawned_unit)
	var unit_node := spawned_unit as Node2D
	unit_node.global_position = mouse_position
	unit_node.set("team", PLAYER_TEAM)
	unit_node.set("lane", lane)
	if unit_node.has_method("_snap_to_lane"):
		unit_node.call("_snap_to_lane")

	_cancel_placement_mode()

func _update_ghost_preview() -> void:
	var mouse_position := get_global_mouse_position()
	ghost_preview.global_position = mouse_position - (ghost_preview.size * 0.5)
	ghost_preview.color = Color(0.2, 0.85, 0.35, 0.45) if _is_valid_placement_position(mouse_position) else Color(0.95, 0.2, 0.2, 0.45)

func _is_valid_placement_position(position: Vector2) -> bool:
	var viewport_size := get_viewport_rect().size
	if position.y < viewport_size.y * 0.5:
		return false

	var river_top := viewport_size.y * 0.43
	var river_bottom := viewport_size.y * 0.57
	if position.y >= river_top and position.y <= river_bottom:
		return false

	return true

func _lane_from_x(x_position: float) -> int:
	return LANE_LEFT if x_position < get_viewport_rect().size.x * 0.5 else LANE_RIGHT

func _cancel_placement_mode() -> void:
	_placement_active = false
	_selected_hand_index = -1
	_selected_card = null
	ghost_preview.visible = false

func _are_all_destroyed(towers: Array[Node]) -> bool:
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		if tower.has_method("is_alive") and tower.is_alive():
			return false
	return true

func _total_tower_hp(towers: Array[Node]) -> float:
	var total_hp := 0.0
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		var tower_hp := tower.get("hp")
		if typeof(tower_hp) == TYPE_FLOAT or typeof(tower_hp) == TYPE_INT:
			total_hp += float(tower_hp)
	return total_hp

func _end_match_by_tower_hp() -> void:
	var player_hp_total := _total_tower_hp(player_towers)
	var enemy_hp_total := _total_tower_hp(enemy_towers)
	var player_won := player_hp_total >= enemy_hp_total
	_end_match(player_won)

func _end_match(player_won: bool) -> void:
	_match_finished = true
	enemy_ai.set_active(false)
	_cancel_placement_mode()
	result_label.text = "WIN" if player_won else "LOSE"
	result_overlay.visible = true

func _update_timer_label() -> void:
	var seconds_remaining := int(ceil(_time_remaining))
	var minutes := seconds_remaining / 60
	var seconds := seconds_remaining % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

func _on_back_to_menu_button_pressed() -> void:
	var result := get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	if result != OK:
		push_error("Unable to load res://scenes/MainMenu.tscn")
