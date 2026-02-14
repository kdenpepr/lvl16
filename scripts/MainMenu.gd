extends Control

func _on_play_button_pressed() -> void:
	var result := get_tree().change_scene_to_file("res://scenes/Match.tscn")
	if result != OK:
		push_error("Unable to load res://scenes/Match.tscn")
