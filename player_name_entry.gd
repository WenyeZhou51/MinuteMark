extends Control

@onready var name_input: LineEdit = $CenterContainer/VBoxContainer/NameInput
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var error_label: Label = $CenterContainer/VBoxContainer/ErrorLabel

func _ready() -> void:
	# Connect button
	start_button.pressed.connect(_on_start_button_pressed)
	
	# Allow pressing Enter to submit
	name_input.text_submitted.connect(_on_name_submitted)
	
	# Focus on input field
	name_input.grab_focus()
	
	# Hide error label initially
	error_label.visible = false

func _on_start_button_pressed() -> void:
	_submit_name()

func _on_name_submitted(_text: String) -> void:
	_submit_name()

func _submit_name() -> void:
	var player_name = name_input.text.strip_edges()
	
	# Validate name
	if player_name.is_empty():
		error_label.text = "Please enter a name"
		error_label.visible = true
		return
	
	if player_name.length() < 2:
		error_label.text = "Name must be at least 2 characters"
		error_label.visible = true
		return
	
	if player_name.length() > 20:
		error_label.text = "Name must be 20 characters or less"
		error_label.visible = true
		return
	
	# Save player name to LeaderboardManager (auto-capitalize)
	LeaderboardManager.set_player_name(player_name)
	
	# Go to level selection menu
	LoadingIndicator.change_scene("res://level_select_menu.tscn")
