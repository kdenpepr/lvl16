extends Control

signal card_selected(hand_index: int, card: CardData)

@export var initial_elixir: float = 5.0
@export var max_elixir: float = 10.0

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

@onready var deck_system: DeckSystem = $DeckSystem
@onready var elixir_system: ElixirSystem = $ElixirSystem

@onready var card_buttons: Array[Button] = [
	$Panel/VBoxContainer/CardGrid/CardButton1,
	$Panel/VBoxContainer/CardGrid/CardButton2,
	$Panel/VBoxContainer/CardGrid/CardButton3,
	$Panel/VBoxContainer/CardGrid/CardButton4,
]

@onready var elixir_label: Label = $Panel/VBoxContainer/ElixirContainer/ElixirLabel
@onready var elixir_bar: ProgressBar = $Panel/VBoxContainer/ElixirContainer/ElixirBar

var hand_cards: Array[CardData] = []
var _displayed_elixir: float = 0.0
var _target_elixir: float = 0.0
var _bar_smoothing_speed: float = 8.0

func _ready() -> void:
	for i in card_buttons.size():
		card_buttons[i].pressed.connect(_on_card_button_pressed.bind(i))

	elixir_system.elixir_changed.connect(_on_elixir_changed)
	elixir_system.configure(max_elixir, initial_elixir)
	_target_elixir = elixir_system.current_elixir
	_displayed_elixir = _target_elixir
	set_elixir(_displayed_elixir)

	_ensure_deck_initialized()
	set_hand(deck_system.get_hand())

func _process(delta: float) -> void:
	if is_equal_approx(_displayed_elixir, _target_elixir):
		return

	_displayed_elixir = lerpf(_displayed_elixir, _target_elixir, clampf(delta * _bar_smoothing_speed, 0.0, 1.0))
	if absf(_displayed_elixir - _target_elixir) < 0.02:
		_displayed_elixir = _target_elixir
	set_elixir(_displayed_elixir)

func _ensure_deck_initialized() -> void:
	if deck_system.hand.size() > 0:
		return
	if deck_system.draw_pile.size() > 0:
		set_hand(deck_system.get_hand())
		return

	var default_deck: Array[CardData] = []
	for path in DEFAULT_DECK_CARD_PATHS:
		var resource := load(path)
		if resource is CardData:
			default_deck.append(resource)

	if default_deck.size() > 0:
		deck_system.initialize_deck(default_deck)

func set_hand(cards: Array[CardData]) -> void:
	hand_cards = cards.duplicate()
	refresh_card_buttons()

func set_elixir(value: float) -> void:
	var clamped_value := clampf(value, 0.0, max_elixir)
	elixir_bar.max_value = max_elixir
	elixir_bar.value = clamped_value
	elixir_label.text = "Elixir: %.1f / %.1f" % [clamped_value, max_elixir]

func refresh_card_buttons() -> void:
	for i in card_buttons.size():
		if i < hand_cards.size() and hand_cards[i] != null:
			var card := hand_cards[i]
			card_buttons[i].disabled = not elixir_system.can_afford(card.cost)
			card_buttons[i].text = "%s (%d)" % [card.display_name, card.cost]
		else:
			card_buttons[i].disabled = true
			card_buttons[i].text = "Empty"

func can_play_card(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand_cards.size():
		return false
	var selected_card := hand_cards[hand_index]
	if selected_card == null:
		return false
	return deck_system.can_play_card(hand_index) and elixir_system.can_afford(selected_card.cost)

func play_card_from_hand(hand_index: int) -> CardData:
	if not can_play_card(hand_index):
		return null

	var selected_card := hand_cards[hand_index]
	if selected_card == null:
		return null
	if not elixir_system.spend(selected_card.cost):
		return null

	var played_card := deck_system.play_card(hand_index)
	if played_card == null:
		elixir_system.add_elixir(float(selected_card.cost))
		return null

	set_hand(deck_system.get_hand())
	return played_card

func _on_card_button_pressed(hand_index: int) -> void:
	if not can_play_card(hand_index):
		return

	var selected_card := hand_cards[hand_index]
	if selected_card == null:
		return

	card_selected.emit(hand_index, selected_card)

func _on_elixir_changed(current_elixir: float, next_max_elixir: float) -> void:
	_target_elixir = current_elixir
	max_elixir = next_max_elixir
	if is_equal_approx(_displayed_elixir, _target_elixir):
		set_elixir(_target_elixir)
	refresh_card_buttons()
