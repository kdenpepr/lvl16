extends Node
class_name DeckSystem

const HAND_SIZE: int = 4

@export var starting_deck: Array[CardData] = []

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []

func _ready() -> void:
	if starting_deck.size() > 0:
		initialize_deck(starting_deck)

func initialize_deck(deck_cards: Array[CardData]) -> void:
	draw_pile = deck_cards.duplicate()
	hand.clear()

	if draw_pile.size() == 0:
		return

	while hand.size() < HAND_SIZE and draw_pile.size() > 0:
		hand.append(draw_pile.pop_front())

func get_hand() -> Array[CardData]:
	return hand.duplicate()

func can_play_card(hand_index: int) -> bool:
	return hand_index >= 0 and hand_index < hand.size()

func play_card(hand_index: int) -> CardData:
	if not can_play_card(hand_index):
		return null

	var played_card := hand[hand_index]
	hand.remove_at(hand_index)
	draw_pile.append(played_card)

	if draw_pile.size() > 0:
		hand.append(draw_pile.pop_front())

	return played_card
