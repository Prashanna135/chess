extends Control

@onready var vs_bot_btn: Button = $Background/MenuPanel/MainContainer/ModeSection/ModeContainer/VsBotButton
@onready var vs_person_btn: Button = $Background/MenuPanel/MainContainer/ModeSection/ModeContainer/VsPersonButton
@onready var difficulty_option: OptionButton = $Background/MenuPanel/MainContainer/SettingsPanel/SettingsGrid/DifficultySection/DifficultyOption
@onready var time_option: OptionButton = $Background/MenuPanel/MainContainer/SettingsPanel/SettingsGrid/TimeSection/TimeOption
@onready var start_button: Button = $Background/MenuPanel/MainContainer/StartButton
@onready var side_container: HBoxContainer = $Background/MenuPanel/MainContainer/SideSection/SideContainer
@onready var play_as_white_btn: Button = $Background/MenuPanel/MainContainer/SideSection/SideContainer/PlayAsWhite
@onready var play_as_black_btn: Button = $Background/MenuPanel/MainContainer/SideSection/SideContainer/PlayAsBlack
@onready var random: Button = $Background/MenuPanel/MainContainer/SideSection/SideContainer/Random
@onready var play_online_btn: Button = $Background/MenuPanel/MainContainer/PlayOnlineButton
@onready var title_label: Label = $Background/MenuPanel/MainContainer/HeaderSection/TitleLabel
@onready var subtitle_label: Label = $Background/MenuPanel/MainContainer/HeaderSection/SubtitleLabel
@onready var bg_piece_left: TextureRect = $Background/DecorLeft
@onready var bg_piece_right: TextureRect = $Background/DecorRight
@onready var board_pattern: Control = $Background/BoardPattern
@onready var top_glow: ColorRect = $Background/TopGlow
@onready var menu_panel: PanelContainer = $Background/MenuPanel

const BOARD_SCENE_PATH := "res://board/mainboard.tscn"
const ONLINE_MENU_PATH := "res://board/online_menu.tscn"

const TIME_OPTIONS = [
	{"label": "No Clock", "seconds": 0},
	{"label": "Blitz - 5 min", "seconds": 300},
	{"label": "Rapid - 10 min", "seconds": 600},
	{"label": "Classical - 30 min", "seconds": 1800},
]

var SQUARE_SIZE := 32.0
var WHITE_SQUARE := Color(0.22, 0.24, 0.28)
var DARK_SQUARE := Color(0.15, 0.17, 0.2)

var selected_mode: int = GameSettings.Mode.VS_BOT
var player_side: int = -1


func _ready() -> void:
	# Load and apply the themed resource
	var menu_theme := preload("res://main_menu_theme.tres") as Theme
	if menu_theme:
		self.theme = menu_theme

	# Chess piece decoration
	var piece_texture = preload("res://assets/chess pieces/white king.png")
	if piece_texture:
		bg_piece_left.texture = piece_texture
		bg_piece_right.texture = piece_texture
		bg_piece_left.stretch_mode = TextureRect.STRETCH_SCALE
		bg_piece_right.stretch_mode = TextureRect.STRETCH_SCALE
		bg_piece_left.visible = true
		bg_piece_right.visible = true
		bg_piece_right.scale.x = -1.0

	# Draw the checkerboard accent when the background is rendered
	board_pattern.draw.connect(_draw_board_pattern)

	# Button connections
	vs_bot_btn.toggle_mode = true
	vs_person_btn.toggle_mode = true
	vs_bot_btn.pressed.connect(func(): _set_mode(GameSettings.Mode.VS_BOT))
	vs_person_btn.pressed.connect(func(): _set_mode(GameSettings.Mode.VS_PERSON))

	difficulty_option.clear()
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium")
	difficulty_option.add_item("Hard")
	difficulty_option.selected = GameSettings.Difficulty.MEDIUM

	time_option.clear()
	for t in TIME_OPTIONS:
		time_option.add_item(t.label)
	time_option.selected = 0

	start_button.pressed.connect(_on_start_pressed)
	start_button.disabled = true

	play_as_white_btn.toggle_mode = true
	play_as_black_btn.toggle_mode = true
	play_as_white_btn.pressed.connect(func(): _on_side_selected(0))
	play_as_black_btn.pressed.connect(func(): _on_side_selected(1))

	random.pressed.connect(_on_random_side)

	if play_online_btn:
		play_online_btn.pressed.connect(_on_play_online_pressed)

	# Intro fade-in
	visible = false
	show()
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)
	tween.tween_property(menu_panel, "offset_left", -310.0, 0.5).set_delay(0.05)

	_set_mode(GameSettings.Mode.VS_BOT)


func _draw_board_pattern() -> void:
	if not board_pattern:
		return
	board_pattern.custom_minimum_size = Vector2(6.0, 6.0)
	var cols := 8
	var rows := 2
	for r in rows:
		for c in cols:
			var x := float(c) * SQUARE_SIZE
			var y := float(r) * SQUARE_SIZE + 8.0
			var col := WHITE_SQUARE if (r + c) % 2 == 0 else DARK_SQUARE
			board_pattern.draw_rect(Rect2(x, y, SQUARE_SIZE, SQUARE_SIZE), col, true)
	queue_redraw()


func _set_mode(mode: int) -> void:
	selected_mode = mode
	vs_bot_btn.button_pressed = (mode == GameSettings.Mode.VS_BOT)
	vs_person_btn.button_pressed = (mode == GameSettings.Mode.VS_PERSON)
	difficulty_option.visible = (mode == GameSettings.Mode.VS_BOT)
	side_container.visible = (mode == GameSettings.Mode.VS_BOT)

	if mode == GameSettings.Mode.VS_PERSON:
		player_side = 0
		start_button.disabled = false
	else:
		player_side = -1
		start_button.disabled = true
		play_as_white_btn.button_pressed = false
		play_as_black_btn.button_pressed = false


func _on_side_selected(side: int) -> void:
	player_side = side
	play_as_white_btn.button_pressed = (side == 0)
	play_as_black_btn.button_pressed = (side == 1)
	start_button.disabled = false

	play_as_white_btn.theme_type_variation = "WhiteSelected" if side == 0 else "SideCard"
	play_as_black_btn.theme_type_variation = "BlackSelected" if side == 1 else "SideCard"
	play_as_white_btn.queue_redraw()
	play_as_black_btn.queue_redraw()


func _on_random_side() -> void:
	var side := randi() % 2
	_on_side_selected(side)


func _on_start_pressed() -> void:
	GameSettings.mode = selected_mode
	GameSettings.difficulty = difficulty_option.selected
	GameSettings.time_control_seconds = TIME_OPTIONS[time_option.selected].seconds
	if selected_mode == GameSettings.Mode.VS_BOT:
		GameSettings.bot_color = 1 if player_side == 0 else 0
	else:
		GameSettings.bot_color = 1
	get_tree().change_scene_to_file(BOARD_SCENE_PATH)


func _on_play_online_pressed() -> void:
	get_tree().change_scene_to_file(ONLINE_MENU_PATH)
