extends Node2D

@onready var grid = $board

# UI containers built in code
var captured_by_white_container: HBoxContainer
var captured_by_black_container: HBoxContainer
var white_clock_label: Label
var black_clock_label: Label
var status_label: Label
var move_label: Label
var undo_btn: Button
var options_popup: PopupMenu = null
var gear_button: Button = null

# Layout references for clock swapping
var game_layout: VBoxContainer
var top_clock_row: HBoxContainer
var bottom_clock_row: HBoxContainer
var top_clock_panel: PanelContainer
var bottom_clock_panel: PanelContainer
var board_frame: PanelContainer
var board_bg: Control

# Preload main menu scene
const START_MENU = preload("uid://4qjf3irw75er")

# Piece textures
const BLACK_BISOP = preload("uid://vge74iyt7gow")
const BLACK_ELEPHANT = preload("uid://ct626x616nd7b")
const BLACK_FOOTMAN = preload("uid://bdt5vhwaiem4t")
const BLACK_KING = preload("uid://dvoft8u8p0cfq")
const BLACK_KNIGHT = preload("uid://dvpxcqgyf1f2t")
const BLACK_MINISTER = preload("uid://mb44aa10it8d")
const WHITE_BISOP = preload("uid://6i6k1vbe5uyi")
const WHITE_ELEPHANTE = preload("uid://dfmgqil8kbwsv")
const WHITE_FOOTMAN = preload("uid://drlkibi2oj66m")
const WHITE_KING = preload("uid://bysisk7as82ok")
const WHITE_KNIGHT = preload("uid://cns8wjmekem7g")
const WHITE_MINISTER = preload("uid://dw0whg4i6vksp")

# Audio
const piece_move_audio = preload("uid://cfag17x5qhpjb")
const piece_capture_audio = preload("uid://bu3h1wvjlsq7e")

const BOARD_SIZE := 8
const TILE_SIZE := 62

enum PieceType { KING, MINISTER, ELEPHANT, BISOP, KNIGHT, FOOTMAN }
enum PieceColor { WHITE, BLACK }

const COLOR_LIGHT := Color(0.93, 0.88, 0.72)
const COLOR_DARK := Color(0.46, 0.59, 0.34)
const COLOR_SELECTED := Color(0.86, 0.83, 0.36)
const COLOR_LAST_MOVE := Color(0.75, 0.8, 0.45)
const COLOR_MOVE_DOT := Color(0.1, 0.1, 0.1, 0.35)
const COLOR_CAPTURE := Color(0.75, 0.2, 0.2, 0.45)
const COLOR_CHECK := Color(1.0, 0.2, 0.2, 0.6)

var squares := []
var square_base_color := []
var board_state := []

var selected_pos := Vector2i(-1, -1)
var legal_moves := []
var current_turn: int = PieceColor.WHITE
var last_move := [Vector2i(-1, -1), Vector2i(-1, -1)]
var game_over := false

var bot: ChessBot = null
var vs_bot := true
var bot_color: int = PieceColor.BLACK
var player_color: int = PieceColor.WHITE
var awaiting_bot := false

# Online (LAN P2P) state
var online_mode := false
var top_player_label: Label
var bottom_player_label: Label
var _online_result_reported := false

var clock_enabled := false
var white_time := 0.0
var black_time := 0.0

var move_audio_player: AudioStreamPlayer
var capture_audio_player: AudioStreamPlayer

var move_history := []
var redo_history := []

var king_in_check_pos := Vector2i(-1, -1)

# Threading and flip
var bot_thread: Thread = null
var board_flipped := false


func _ready():
	# Audio players
	move_audio_player = AudioStreamPlayer.new()
	move_audio_player.stream = piece_move_audio
	add_child(move_audio_player)

	capture_audio_player = AudioStreamPlayer.new()
	capture_audio_player.stream = piece_capture_audio
	add_child(capture_audio_player)

	# UI and game
	_build_ui()
	create_board()
	_add_coordinate_labels()
	setup_pieces()
	_setup_game_from_settings()

	# Determine player color
	if vs_bot:
		player_color = opposite(bot_color)
	elif online_mode:
		player_color = GameSettings.local_player_color
	else:
		player_color = PieceColor.WHITE

	# Swap clock rows so player's clock is always at the bottom
	_update_clock_positions()

	# Flip the board if player is black
	board_flipped = (player_color == PieceColor.BLACK)
	refresh_board_orientation()

	if status_label:
		status_label.add_theme_color_override("font_color", Color(0.97, 0.83, 0.53, 1))

# UI construction (clock rows stored for swapping)
func _build_ui() -> void:
	var parent := grid.get_parent()
	var grid_index := grid.get_index()

	# The in-game UI is Control-based and anchored to the viewport, so a
	# legacy Camera2D would shift the whole layout. Remove it if present.
	var cam := get_node_or_null("Camera2D")
	if cam:
		cam.queue_free()

	# Paint a themed background instead of the default gray clear color.
	_build_background(parent)

	game_layout = VBoxContainer.new()
	game_layout.name = "GameLayout"
	game_layout.add_theme_constant_override("separation", 12)
	game_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layout.offset_left = 18
	game_layout.offset_right = -18
	game_layout.offset_top = 16
	game_layout.offset_bottom = -16

	# Status label
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	game_layout.add_child(status_label)

	# Top clock card (opponent by default – will be swapped if needed)
	top_clock_panel = PanelContainer.new()
	top_clock_panel.name = "TopClockPanel"
	top_clock_panel.theme_type_variation = "SettingsPanel"
	top_clock_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	top_clock_row = HBoxContainer.new()
	top_clock_row.name = "TopClockRow"
	top_clock_row.add_theme_constant_override("separation", 12)
	top_clock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_clock_panel.add_child(top_clock_row)

	top_player_label = Label.new()
	top_player_label.name = "TopPlayerLabel"
	top_player_label.add_theme_font_size_override("font_size", 18)
	top_player_label.custom_minimum_size = Vector2(140, 0)
	top_player_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_clock_row.add_child(top_player_label)

	captured_by_black_container = HBoxContainer.new()
	captured_by_black_container.name = "CapturedByBlack"
	captured_by_black_container.add_theme_constant_override("separation", 2)
	captured_by_black_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_clock_row.add_child(captured_by_black_container)

	black_clock_label = Label.new()
	black_clock_label.name = "BlackClockLabel"
	black_clock_label.add_theme_font_size_override("font_size", 26)
	black_clock_label.add_theme_color_override("font_color", Color(0.97, 0.83, 0.53, 1))
	black_clock_label.custom_minimum_size = Vector2(90, 0)
	black_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	black_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_clock_row.add_child(black_clock_label)

	game_layout.add_child(top_clock_panel)

	# Board, framed in a themed panel so it reads as a real board
	parent.add_child(game_layout)
	parent.move_child(game_layout, grid_index)
	if board_bg:
		parent.move_child(board_bg, 0)

	board_frame = PanelContainer.new()
	board_frame.name = "BoardFrame"
	board_frame.theme_type_variation = "MenuPanel"
	board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.get_parent().remove_child(grid)
	board_frame.add_child(grid)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game_layout.add_child(board_frame)

	# Bottom clock card (player by default)
	bottom_clock_panel = PanelContainer.new()
	bottom_clock_panel.name = "BottomClockPanel"
	bottom_clock_panel.theme_type_variation = "SettingsPanel"
	bottom_clock_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	bottom_clock_row = HBoxContainer.new()
	bottom_clock_row.name = "BottomClockRow"
	bottom_clock_row.add_theme_constant_override("separation", 12)
	bottom_clock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_clock_panel.add_child(bottom_clock_row)

	bottom_player_label = Label.new()
	bottom_player_label.name = "BottomPlayerLabel"
	bottom_player_label.add_theme_font_size_override("font_size", 18)
	bottom_player_label.custom_minimum_size = Vector2(140, 0)
	bottom_player_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_clock_row.add_child(bottom_player_label)

	captured_by_white_container = HBoxContainer.new()
	captured_by_white_container.name = "CapturedByWhite"
	captured_by_white_container.add_theme_constant_override("separation", 2)
	captured_by_white_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_clock_row.add_child(captured_by_white_container)

	white_clock_label = Label.new()
	white_clock_label.name = "WhiteClockLabel"
	white_clock_label.add_theme_font_size_override("font_size", 26)
	white_clock_label.add_theme_color_override("font_color", Color(0.97, 0.83, 0.53, 1))
	white_clock_label.custom_minimum_size = Vector2(90, 0)
	white_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	white_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_clock_row.add_child(white_clock_label)

	game_layout.add_child(bottom_clock_panel)

	# Spacer pushes the action bar toward the bottom of the screen
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_layout.add_child(spacer)

	# Undo / Redo / Options action bar
	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.name = "ActionBar"
	buttons_hbox.add_theme_constant_override("separation", 10)

	undo_btn = Button.new()
	undo_btn.text = "UNDO"
	undo_btn.theme_type_variation = "SecondaryButton"
	undo_btn.add_theme_font_size_override("font_size", 16)
	undo_btn.custom_minimum_size = Vector2(0, 56)
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_btn.pressed.connect(_on_undo_pressed)
	buttons_hbox.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text = "REDO"
	redo_btn.theme_type_variation = "SecondaryButton"
	redo_btn.add_theme_font_size_override("font_size", 16)
	redo_btn.custom_minimum_size = Vector2(0, 56)
	redo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redo_btn.pressed.connect(_on_redo_pressed)
	buttons_hbox.add_child(redo_btn)

	gear_button = Button.new()
	gear_button.text = "MENU"
	gear_button.theme_type_variation = "SecondaryButton"
	gear_button.add_theme_font_size_override("font_size", 16)
	gear_button.custom_minimum_size = Vector2(0, 56)
	gear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_button.pressed.connect(_on_gear_pressed)
	buttons_hbox.add_child(gear_button)

	game_layout.add_child(buttons_hbox)

	# Popup menu for options (attached to the menu button)
	options_popup = PopupMenu.new()
	options_popup.name = "OptionsPopup"

	# Make items larger and touch-friendly
	options_popup.add_theme_font_size_override("font_size", 20)
	options_popup.add_theme_constant_override("item_start_padding", 20)
	options_popup.add_theme_constant_override("item_end_padding", 20)
	options_popup.add_theme_constant_override("item_top_padding", 12)
	options_popup.add_theme_constant_override("item_bottom_padding", 12)
	options_popup.add_theme_constant_override("h_separation", 16)
	options_popup.add_theme_constant_override("v_separation", 8)

	options_popup.add_item("Flip Board", 0)
	options_popup.add_item("Resign", 1)
	options_popup.add_separator()
	options_popup.add_item("Main Menu", 2)
	options_popup.id_pressed.connect(_on_option_chosen)
	gear_button.add_child(options_popup)

	# Move scroll
	var move_scroll := ScrollContainer.new()
	move_scroll.name = "MoveScroll"
	move_scroll.custom_minimum_size = Vector2(0, 30)
	move_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	move_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	move_label = Label.new()
	move_label.name = "MoveLabel"
	move_label.add_theme_font_size_override("font_size", 16)
	move_label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.78, 1))
	move_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	move_label.size_flags_horizontal = Control.SIZE_EXPAND
	move_scroll.add_child(move_label)
	game_layout.add_child(move_scroll)


func _build_background(parent: Node) -> void:
	board_bg = Control.new()
	board_bg.name = "BoardBackground"
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(board_bg)

	var base := ColorRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.055, 0.062, 0.09, 1.0)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_bg.add_child(base)

	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	glow.offset_bottom = 320.0
	glow.color = Color(0.35, 0.27, 0.14, 0.16)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_bg.add_child(glow)

	var floor_glow := ColorRect.new()
	floor_glow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	floor_glow.offset_top = -340.0
	floor_glow.color = Color(0.12, 0.16, 0.22, 0.5)
	floor_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_bg.add_child(floor_glow)


func _make_button_style(hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8) if not hover else Color(0.3, 0.3, 0.3, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


# Clock position swap (based on player color and flip)
func _update_clock_positions() -> void:
	# Default order (player is white):
	#   status (0), top_clock_row (black) (1), board (2), bottom_clock_row (white) (3), buttons (4), move_scroll (5)
	#
	# If player is black, we want:
	#   status (0), white row (1), board (2), black row (3), buttons (4), move_scroll (5)

	# Child order of game_layout:
	#   0 status, 1 top_clock_panel, 2 grid, 3 bottom_clock_panel,
	#   4 spacer, 5 action bar, 6 move scroll
	# top_clock_panel holds the opponent's card (black by default) and
	# bottom_clock_panel holds the player's card (white by default).
	if player_color == PieceColor.BLACK:
		# Opponent is white -> put the white card on top, black at the bottom
		game_layout.move_child(bottom_clock_panel, 1)
		game_layout.move_child(board_frame, 2)
		game_layout.move_child(top_clock_panel, 3)
	else:
		# Player is white -> default order is already correct
		game_layout.move_child(top_clock_panel, 1)
		game_layout.move_child(board_frame, 2)
		game_layout.move_child(bottom_clock_panel, 3)


# Options callbacks
func _on_gear_pressed() -> void:
	var btn_pos = gear_button.global_position
	var btn_size = gear_button.size
	options_popup.position = Vector2(btn_pos.x, btn_pos.y + btn_size.y)
	options_popup.popup()


func _on_option_chosen(id: int) -> void:
	match id:
		0:   # Flip Board
			board_flipped = not board_flipped
			refresh_board_orientation()
		1:   # Resign – show resignation confirmation
			_show_resign_popup()
		2:   # Main Menu – show confirmation first
			_show_main_menu_confirmation()


func _show_main_menu_confirmation() -> void:
	var popup := ConfirmationDialog.new()
	popup.title = "Main Menu"
	popup.dialog_text = "Are you sure you want to return to the main menu?\nThe current game will be lost."
	popup.get_ok_button().text = "Yes"
	popup.get_cancel_button().text = "Cancel"
	popup.confirmed.connect(_on_main_menu_confirmed)
	popup.canceled.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)
	add_child(popup)
	popup.popup_centered()


func _on_main_menu_confirmed() -> void:
	if bot_thread and bot_thread.is_alive():
		bot_thread.wait_to_finish()
	if online_mode:
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://board/start_menu.tscn")

func _show_resign_popup() -> void:
	var popup := ConfirmationDialog.new()
	popup.title = "Resign"
	popup.dialog_text = "Are you sure you want to resign?"
	popup.get_ok_button().text = "Resign"
	popup.get_cancel_button().text = "Cancel"
	popup.confirmed.connect(_on_resign_confirmed)
	popup.canceled.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)
	add_child(popup)
	popup.popup_centered()


func _on_resign_confirmed() -> void:
	if not game_over:
		game_over = true
		var winner = "Black" if current_turn == PieceColor.WHITE else "White"
		_set_status("You resigned. %s wins." % winner)
		_glow_status_red()

		if online_mode:
			NetworkManager.send_resign()
			_report_online_result("loss")

		# Highlight the resigning player's king in red
		var my_king_pos = find_king(board_state, player_color)
		if my_king_pos != Vector2i(-1, -1):
			king_in_check_pos = my_king_pos
			refresh_square_colors()
	_show_post_game_options()


func _show_post_game_options() -> void:
	var popup := ConfirmationDialog.new()
	popup.title = "Game Over"
	popup.dialog_text = "What would you like to do?"

	# Remove the standard OK/Cancel buttons – we only want our own
	popup.get_ok_button().visible = false
	popup.get_cancel_button().visible = false

	if not online_mode:
		popup.add_button("Restart", true, "restart")
	popup.add_button("Main Menu", true, "main_menu")
	popup.custom_action.connect(func(action: String):
		match action:
			"restart":
				_restart_game()
			"main_menu":
				if bot_thread and bot_thread.is_alive():
					bot_thread.wait_to_finish()
				if online_mode:
					NetworkManager.disconnect_game()
				get_tree().change_scene_to_file("res://board/start_menu.tscn")
		popup.queue_free()
	)
	popup.canceled.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)
	add_child(popup)
	popup.popup_centered()


func _restart_game() -> void:
	# Kill bot thread if running
	if bot_thread and bot_thread.is_alive():
		bot_thread.wait_to_finish()
	# Reload the same scene
	get_tree().reload_current_scene()


# Game setup
func _setup_game_from_settings() -> void:
	vs_bot = (GameSettings.mode == GameSettings.Mode.VS_BOT)
	online_mode = (GameSettings.mode == GameSettings.Mode.ONLINE)
	bot_color = GameSettings.bot_color
	if vs_bot:
		bot = ChessBot.new(self, bot_color, GameSettings.difficulty)
	if online_mode:
		player_color = GameSettings.local_player_color
		NetworkManager.move_received.connect(_on_network_move_received)
		NetworkManager.opponent_resigned.connect(_on_opponent_resigned)
		NetworkManager.player_disconnected.connect(_on_opponent_disconnected)
	clock_enabled = GameSettings.time_control_seconds > 0
	white_time = float(GameSettings.time_control_seconds)
	black_time = float(GameSettings.time_control_seconds)
	_update_clock_labels()
	_update_player_labels()
	if vs_bot and current_turn == bot_color:
		_start_bot_turn()


func _update_player_labels() -> void:
	if not is_instance_valid(top_player_label) or not is_instance_valid(bottom_player_label):
		return
	# top_player_label always belongs to Black's clock row, bottom_player_label
	# always belongs to White's clock row — the rows themselves get swapped
	# top/bottom on screen depending on player_color, so these stay correct.
	var white_text := "White"
	var black_text := "Black"
	if online_mode:
		var my_text = "%s (%d)" % [ProfileManager.player_name, ProfileManager.elo]
		var opp_text = "%s (%d)" % [GameSettings.opponent_name, GameSettings.opponent_elo]
		if player_color == PieceColor.WHITE:
			white_text = my_text
			black_text = opp_text
		else:
			black_text = my_text
			white_text = opp_text
	elif vs_bot:
		var diff_names = ["Bot (Easy)", "Bot (Medium)", "Bot (Hard)"]
		var bot_text = diff_names[GameSettings.difficulty]
		if player_color == PieceColor.WHITE:
			white_text = ProfileManager.player_name
			black_text = bot_text
		else:
			black_text = ProfileManager.player_name
			white_text = bot_text
	top_player_label.text = black_text
	bottom_player_label.text = white_text


# Board creation & coordinates
func create_board():
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var square = ColorRect.new()
			square.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
			var col = COLOR_LIGHT if (x + y) % 2 == 0 else COLOR_DARK
			square.color = col
			square.mouse_filter = Control.MOUSE_FILTER_STOP
			square.gui_input.connect(_on_square_gui_input.bind(Vector2i(x, y)))
			grid.add_child(square)
			squares.append(square)
			square_base_color.append(col)


func _add_coordinate_labels() -> void:
	for x in range(BOARD_SIZE):
		var file_letter := char(97 + x)
		var square = squares[7 * BOARD_SIZE + x]
		var label := Label.new()
		label.text = file_letter
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(TILE_SIZE - 14, TILE_SIZE - 16)
		label.add_theme_color_override("font_color", _label_color_for_square(x, 7))
		square.add_child(label)
	for y in range(BOARD_SIZE):
		var rank_number := str(BOARD_SIZE - y)
		var square = squares[y * BOARD_SIZE + 0]
		var label := Label.new()
		label.text = rank_number
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(4, 2)
		label.add_theme_color_override("font_color", _label_color_for_square(0, y))
		square.add_child(label)


func _label_color_for_square(x: int, y: int) -> Color:
	return COLOR_DARK if (x + y) % 2 == 0 else COLOR_LIGHT


# Piece setup & helpers
func setup_pieces():
	board_state.clear()
	for y in range(BOARD_SIZE):
		var row = []
		for x in range(BOARD_SIZE):
			row.append(null)
		board_state.append(row)
	var back_rank = [
		PieceType.ELEPHANT, PieceType.KNIGHT, PieceType.BISOP, PieceType.MINISTER,
		PieceType.KING, PieceType.BISOP, PieceType.KNIGHT, PieceType.ELEPHANT
	]
	for x in range(BOARD_SIZE):
		place_piece(back_rank[x], PieceColor.BLACK, Vector2i(x, 0))
		place_piece(PieceType.FOOTMAN, PieceColor.BLACK, Vector2i(x, 1))
		place_piece(PieceType.FOOTMAN, PieceColor.WHITE, Vector2i(x, 6))
		place_piece(back_rank[x], PieceColor.WHITE, Vector2i(x, 7))


func get_texture(type: int, color: int) -> Texture2D:
	if color == PieceColor.WHITE:
		match type:
			PieceType.KING: return WHITE_KING
			PieceType.MINISTER: return WHITE_MINISTER
			PieceType.ELEPHANT: return WHITE_ELEPHANTE
			PieceType.BISOP: return WHITE_BISOP
			PieceType.KNIGHT: return WHITE_KNIGHT
			PieceType.FOOTMAN: return WHITE_FOOTMAN
	else:
		match type:
			PieceType.KING: return BLACK_KING
			PieceType.MINISTER: return BLACK_MINISTER
			PieceType.ELEPHANT: return BLACK_ELEPHANT
			PieceType.BISOP: return BLACK_BISOP
			PieceType.KNIGHT: return BLACK_KNIGHT
			PieceType.FOOTMAN: return BLACK_FOOTMAN
	return null


func place_piece(type: int, color: int, pos: Vector2i):
	var tex_rect = TextureRect.new()
	tex_rect.texture = get_texture(type, color)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var square = squares[pos.y * BOARD_SIZE + pos.x]
	square.add_child(tex_rect)
	board_state[pos.y][pos.x] = {
		"type": type,
		"color": color,
		"node": tex_rect,
		"moved": false
	}


# Input handling (with board flip mapping)
func _on_square_gui_input(event: InputEvent, pos: Vector2i):
	if game_over or awaiting_bot:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(_visual_to_board(pos))


func _handle_click(pos: Vector2i):
	if vs_bot and current_turn == bot_color:
		return
	if online_mode and current_turn != player_color:
		return
	if selected_pos != Vector2i(-1, -1):
		if pos in legal_moves:
			var moved_from = selected_pos
			move_piece(selected_pos, pos)
			if online_mode:
				NetworkManager.send_move(moved_from, pos)
			clear_selection()
			switch_turn()
			return
		clear_selection()
	var piece = board_state[pos.y][pos.x]
	if piece != null and piece.color == current_turn:
		select_square(pos)


func select_square(pos: Vector2i):
	selected_pos = pos
	var piece = board_state[pos.y][pos.x]
	legal_moves = get_legal_moves(board_state, pos, piece)
	highlight_selection()


func clear_selection():
	selected_pos = Vector2i(-1, -1)
	legal_moves = []
	refresh_square_colors()


func highlight_selection():
	refresh_square_colors()
	var visual_sel = _board_to_visual(selected_pos)
	squares[visual_sel.y * BOARD_SIZE + visual_sel.x].color = COLOR_SELECTED
	for m in legal_moves:
		var vis_m = _board_to_visual(m)
		var sq = squares[vis_m.y * BOARD_SIZE + vis_m.x]
		if board_state[m.y][m.x] != null:
			sq.color = COLOR_CAPTURE
		else:
			sq.color = sq.color.lerp(COLOR_MOVE_DOT, 0.5)


func refresh_square_colors():
	for i in range(squares.size()):
		squares[i].color = square_base_color[i]

	if last_move[0] != Vector2i(-1, -1):
		var vis_from = _board_to_visual(last_move[0])
		var vis_to = _board_to_visual(last_move[1])
		squares[vis_from.y * BOARD_SIZE + vis_from.x].color = COLOR_LAST_MOVE
		squares[vis_to.y * BOARD_SIZE + vis_to.x].color = COLOR_LAST_MOVE

	if king_in_check_pos != Vector2i(-1, -1):
		var vis_king = _board_to_visual(king_in_check_pos)
		squares[vis_king.y * BOARD_SIZE + vis_king.x].color = COLOR_CHECK


# Board flipping helpers
func _visual_to_board(vis_pos: Vector2i) -> Vector2i:
	if board_flipped:
		return Vector2i(BOARD_SIZE - 1 - vis_pos.x, BOARD_SIZE - 1 - vis_pos.y)
	return vis_pos

func _board_to_visual(board_pos: Vector2i) -> Vector2i:
	if board_flipped:
		return Vector2i(BOARD_SIZE - 1 - board_pos.x, BOARD_SIZE - 1 - board_pos.y)
	return board_pos

func refresh_board_orientation() -> void:
	# Re‑parent all pieces to correct visual squares
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var sq = squares[y * BOARD_SIZE + x]
			for child in sq.get_children():
				if child is TextureRect:
					sq.remove_child(child)

	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var piece = board_state[y][x]
			if piece != null:
				var visual_pos = _board_to_visual(Vector2i(x, y))
				var square = squares[visual_pos.y * BOARD_SIZE + visual_pos.x]
				square.add_child(piece.node)

	refresh_square_colors()


# Move execution and undo/redo
func _perform_move(from: Vector2i, to: Vector2i) -> void:
	var piece = board_state[from.y][from.x]

	if piece.type == PieceType.KING and abs(to.x - from.x) == 2:
		var rook_from_x = 7 if to.x > from.x else 0
		var rook_to_x = to.x - 1 if to.x > from.x else to.x + 1
		var rook = board_state[from.y][rook_from_x]
		board_state[from.y][rook_from_x] = null
		board_state[from.y][rook_to_x] = rook
		rook.moved = true
		reposition_node(rook.node, Vector2i(rook_to_x, from.y))

	var captured = board_state[to.y][to.x]
	if captured != null:
		capture_audio_player.play()
		_add_captured_piece(captured.type, captured.color)
		captured.node.get_parent().remove_child(captured.node)
	else:
		move_audio_player.play()

	board_state[to.y][to.x] = piece
	board_state[from.y][from.x] = null
	piece.moved = true
	reposition_node(piece.node, to)

	if piece.type == PieceType.FOOTMAN and (to.y == 0 or to.y == 7):
		piece.type = PieceType.MINISTER
		piece.node.texture = get_texture(PieceType.MINISTER, piece.color)


func move_piece(from: Vector2i, to: Vector2i):
	var record = _make_undo_record(from, to)
	_perform_move(from, to)
	move_history.append(record)
	redo_history.clear()
	last_move = [from, to]


func reposition_node(node: TextureRect, pos: Vector2i):
	var visual_pos = _board_to_visual(pos)
	var square = squares[visual_pos.y * BOARD_SIZE + visual_pos.x]
	if node.get_parent():
		node.get_parent().remove_child(node)
	square.add_child(node)


func switch_turn():
	current_turn = PieceColor.BLACK if current_turn == PieceColor.WHITE else PieceColor.WHITE
	refresh_square_colors()
	check_game_end()
	_update_move_display()

	if not game_over and vs_bot and current_turn == bot_color:
		_start_bot_turn()


# Bot turn via thread
func _start_bot_turn() -> void:
	awaiting_bot = true

	var board_copy := []
	for row in board_state:
		var new_row := []
		for p in row:
			new_row.append(p.duplicate(true) if p != null else null)
		board_copy.append(new_row)

# Time management
	var time_limit_ms: int = 0   # declare outside if/else
	if clock_enabled:
		var time_left: float = white_time if bot_color == PieceColor.WHITE else black_time
		time_limit_ms = int( min(time_left * 1000.0 * 0.05, 2000.0) )
		time_limit_ms = max(time_limit_ms, 100)
	# else: time_limit_ms stays 0 (no limit)

	bot_thread = Thread.new()
	bot_thread.start(_bot_thread_worker.bind(board_copy, time_limit_ms))


func _bot_thread_worker(board_copy: Array, time_limit_ms: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return ChessBot.choose_move_static(
		board_copy,
		bot_color,
		opposite(bot_color),
		bot.max_depth,
		bot.randomness,
		rng,
		time_limit_ms
	)


func _check_bot_thread() -> void:
	if not awaiting_bot or bot_thread == null:
		return

	if not bot_thread.is_alive():
		var move_dict = bot_thread.wait_to_finish()
		bot_thread = null
		awaiting_bot = false

		if move_dict.is_empty():
			return

		move_piece(move_dict.from, move_dict.to)
		switch_turn()


# Online opponent events (LAN P2P)
func _on_network_move_received(from: Vector2i, to: Vector2i) -> void:
	if game_over:
		return
	move_piece(from, to)
	switch_turn()


func _on_opponent_resigned() -> void:
	if game_over:
		return
	game_over = true
	_set_status("Opponent resigned. You win!")
	_glow_status_red()
	_report_online_result("win")
	_show_post_game_options()


func _on_opponent_disconnected() -> void:
	if game_over:
		return
	game_over = true
	_set_status("Opponent disconnected.")
	_show_post_game_options()


func _report_online_result(result: String) -> void:
	if not online_mode or _online_result_reported:
		return
	_online_result_reported = true
	var change = ProfileManager.record_game(GameSettings.opponent_name, GameSettings.opponent_elo, result, "online")
	var sign_str = "+" if change >= 0 else ""
	var current_text = status_label.text if status_label else ""
	_set_status("%s  (%s%d elo, now %d)" % [current_text, sign_str, change, ProfileManager.elo])


# Process (clocks + bot polling)
func _process(delta: float) -> void:
	if clock_enabled and not game_over:
		if current_turn == PieceColor.WHITE:
			white_time = max(0.0, white_time - delta)
			if white_time == 0.0:
				game_over = true
				_set_status("White ran out of time! Black wins.")
				_report_online_result("win" if player_color == PieceColor.BLACK else "loss")
		else:
			black_time = max(0.0, black_time - delta)
			if black_time == 0.0:
				game_over = true
				_set_status("Black ran out of time! White wins.")
				_report_online_result("win" if player_color == PieceColor.WHITE else "loss")
		_update_clock_labels()

	_check_bot_thread()


# UI updates
func _update_clock_labels() -> void:
	if white_clock_label:
		white_clock_label.text = _format_time(white_time)
	if black_clock_label:
		black_clock_label.text = _format_time(black_time)


func _format_time(t: float) -> String:
	if not clock_enabled:
		return "--:--"
	var total := int(ceil(t))
	var m := total / 60
	var s := total % 60
	return "%02d:%02d" % [m, s]


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
	else:
		print(text)


func _glow_status_red() -> void:
	if not status_label:
		return
	# Safely kill existing tween
	if status_label.has_meta("glow_tween"):
		var existing_tween = status_label.get_meta("glow_tween")
		if existing_tween:
			existing_tween.kill()

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(status_label, "modulate", Color(1, 0.3, 0.3, 1), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(status_label, "modulate", Color.RED, 0.6).set_trans(Tween.TRANS_SINE)
	status_label.set_meta("glow_tween", tween)


# Check / game end
func check_game_end():
	var any_moves = has_any_legal_move(board_state, current_turn)
	var in_check = is_king_in_check(board_state, current_turn)
	king_in_check_pos = Vector2i(-1, -1)

	if not any_moves:
		game_over = true
		if in_check:
			var winner_color = opposite(current_turn)
			var winner = "Black" if winner_color == PieceColor.BLACK else "White"
			_set_status("Checkmate! %s wins." % winner)
			_glow_status_red()
			_report_online_result("win" if winner_color == player_color else "loss")
		else:
			_set_status("Stalemate! Draw.")
			_report_online_result("draw")
	else:
		if in_check:
			king_in_check_pos = find_king(board_state, current_turn)
			_set_status("")
		else:
			_set_status("")
			if status_label:
				status_label.add_theme_color_override("font_color", Color.WHITE)
				if status_label.has_meta("glow_tween"):
					var tween = status_label.get_meta("glow_tween")
					if tween:
						tween.kill()
						status_label.set_meta("glow_tween", null)

	refresh_square_colors()


# Move generation
func get_legal_moves(board: Array, pos: Vector2i, piece: Dictionary) -> Array:
	var pseudo = get_pseudo_moves(board, pos, piece, false)
	var result = []
	for m in pseudo:
		var sim = simulate_move(board, pos, m)
		if not is_king_in_check(sim, piece.color):
			result.append(m)
	if piece.type == PieceType.KING and not piece.moved:
		result.append_array(get_castle_moves(board, pos, piece))
	return result

func get_castle_moves(board: Array, pos: Vector2i, piece: Dictionary) -> Array:
	var moves = []
	if is_king_in_check(board, piece.color):
		return moves
	var y = pos.y
	var rook_k = board[y][7]
	if rook_k != null and rook_k.type == PieceType.ELEPHANT and not rook_k.moved:
		if board[y][5] == null and board[y][6] == null:
			if not is_square_attacked(board, Vector2i(5, y), opposite(piece.color)) \
			and not is_square_attacked(board, Vector2i(6, y), opposite(piece.color)):
				moves.append(Vector2i(6, y))
	var rook_q = board[y][0]
	if rook_q != null and rook_q.type == PieceType.ELEPHANT and not rook_q.moved:
		if board[y][1] == null and board[y][2] == null and board[y][3] == null:
			if not is_square_attacked(board, Vector2i(3, y), opposite(piece.color)) \
			and not is_square_attacked(board, Vector2i(2, y), opposite(piece.color)):
				moves.append(Vector2i(2, y))
	return moves

func get_pseudo_moves(board: Array, pos: Vector2i, piece: Dictionary, attack_only: bool) -> Array:
	match piece.type:
		PieceType.FOOTMAN:
			return get_pawn_moves(board, pos, piece, attack_only)
		PieceType.KNIGHT:
			return get_knight_moves(board, pos, piece)
		PieceType.BISOP:
			return get_sliding_moves(board, pos, piece, [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
		PieceType.ELEPHANT:
			return get_sliding_moves(board, pos, piece, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)])
		PieceType.MINISTER:
			return get_sliding_moves(board, pos, piece, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
		PieceType.KING:
			return get_king_moves(board, pos, piece)
	return []

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func get_pawn_moves(board: Array, pos: Vector2i, piece: Dictionary, attack_only: bool) -> Array:
	var moves = []
	var dir = -1 if piece.color == PieceColor.WHITE else 1
	var start_row = 6 if piece.color == PieceColor.WHITE else 1
	if not attack_only:
		var one = Vector2i(pos.x, pos.y + dir)
		if in_bounds(one) and board[one.y][one.x] == null:
			moves.append(one)
			var two = Vector2i(pos.x, pos.y + dir * 2)
			if pos.y == start_row and board[two.y][two.x] == null:
				moves.append(two)
	for dx in [-1, 1]:
		var diag = Vector2i(pos.x + dx, pos.y + dir)
		if in_bounds(diag):
			var target = board[diag.y][diag.x]
			if attack_only:
				moves.append(diag)
			elif target != null and target.color != piece.color:
				moves.append(diag)
	return moves

func get_knight_moves(board: Array, pos: Vector2i, piece: Dictionary) -> Array:
	var offsets = [
		Vector2i(1,2), Vector2i(2,1), Vector2i(2,-1), Vector2i(1,-2),
		Vector2i(-1,-2), Vector2i(-2,-1), Vector2i(-2,1), Vector2i(-1,2)
	]
	var moves = []
	for o in offsets:
		var p = pos + o
		if in_bounds(p):
			var target = board[p.y][p.x]
			if target == null or target.color != piece.color:
				moves.append(p)
	return moves

func get_king_moves(board: Array, pos: Vector2i, piece: Dictionary) -> Array:
	var moves = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var p = pos + Vector2i(dx, dy)
			if in_bounds(p):
				var target = board[p.y][p.x]
				if target == null or target.color != piece.color:
					moves.append(p)
	return moves

func get_sliding_moves(board: Array, pos: Vector2i, piece: Dictionary, directions: Array) -> Array:
	var moves = []
	for dir in directions:
		var p = pos + dir
		while in_bounds(p):
			var target = board[p.y][p.x]
			if target == null:
				moves.append(p)
			else:
				if target.color != piece.color:
					moves.append(p)
				break
			p += dir
	return moves

# Check / checkmate detection
func opposite(color: int) -> int:
	return PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE

func is_square_attacked(board: Array, pos: Vector2i, by_color: int) -> bool:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p = board[y][x]
			if p != null and p.color == by_color:
				var moves = get_pseudo_moves(board, Vector2i(x, y), p, true)
				if pos in moves:
					return true
	return false

func find_king(board: Array, color: int) -> Vector2i:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p = board[y][x]
			if p != null and p.type == PieceType.KING and p.color == color:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func is_king_in_check(board: Array, color: int) -> bool:
	var king_pos = find_king(board, color)
	if king_pos == Vector2i(-1, -1):
		return false
	return is_square_attacked(board, king_pos, opposite(color))

func has_any_legal_move(board: Array, color: int) -> bool:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var p = board[y][x]
			if p != null and p.color == color:
				if get_legal_moves(board, Vector2i(x, y), p).size() > 0:
					return true
	return false

func simulate_move(board: Array, from: Vector2i, to: Vector2i) -> Array:
	var copy = []
	for y in range(BOARD_SIZE):
		var row = []
		for x in range(BOARD_SIZE):
			var p = board[y][x]
			row.append(p if p == null else p.duplicate())
		copy.append(row)
	copy[to.y][to.x] = copy[from.y][from.x]
	copy[from.y][from.x] = null
	return copy


# Undo/redo (with bot move restart)
func _make_undo_record(from: Vector2i, to: Vector2i) -> Dictionary:
	var piece = board_state[from.y][from.x]
	var captured = board_state[to.y][to.x]
	var record := {
		"from": from,
		"to": to,
		"piece": piece,
		"captured": captured,
		"was_moved": piece.moved,
		"turn": current_turn
	}
	if piece.type == PieceType.KING and abs(to.x - from.x) == 2:
		var rook_from_x = 7 if to.x > from.x else 0
		var rook_to_x = to.x - 1 if to.x > from.x else to.x + 1
		record["rook_from"] = Vector2i(rook_from_x, from.y)
		record["rook_to"] = Vector2i(rook_to_x, from.y)
		record["rook_piece"] = board_state[from.y][rook_from_x]
	if piece.type == PieceType.FOOTMAN and (to.y == 0 or to.y == 7):
		record["promoted"] = true
		record["original_type"] = PieceType.FOOTMAN
		record["new_type"] = PieceType.MINISTER
	return record

func undo_last_move() -> void:
	if move_history.is_empty() or game_over:
		return
	if vs_bot and move_history.size() >= 2:
		var last = move_history[-1]
		var prev = move_history[-2]
		if prev.turn != bot_color and last.turn == bot_color:
			var bot_rec = move_history.pop_back()
			_undo_single(bot_rec)
			var player_rec = move_history.pop_back()
			_undo_single(player_rec)
			redo_history.append(bot_rec)
			redo_history.append(player_rec)
		else:
			var rec = move_history.pop_back()
			_undo_single(rec)
			redo_history.append(rec)
	else:
		var rec = move_history.pop_back()
		_undo_single(rec)
		redo_history.append(rec)

	clear_selection()
	refresh_square_colors()
	check_game_end()
	_update_move_display()

	# If it's now the bot's turn, start it (except if game over)
	if not game_over and vs_bot and current_turn == bot_color:
		_start_bot_turn()

func _undo_single(record: Dictionary) -> void:
	var piece = record.piece
	var from = record.from
	var to = record.to
	board_state[from.y][from.x] = piece
	board_state[to.y][to.x] = null
	reposition_node(piece.node, from)
	piece.moved = record.was_moved

	if record.captured != null:
		board_state[to.y][to.x] = record.captured
		var visual_to = _board_to_visual(to)
		var square = squares[visual_to.y * BOARD_SIZE + visual_to.x]
		square.add_child(record.captured.node)
		_remove_captured_icon(record.captured.type, record.captured.color)

	if record.has("rook_from"):
		var rook = record.rook_piece
		board_state[record.rook_from.y][record.rook_from.x] = rook
		board_state[record.rook_to.y][record.rook_to.x] = null
		reposition_node(rook.node, record.rook_from)
		rook.moved = false

	if record.has("promoted") and record.promoted:
		piece.type = record.original_type
		piece.node.texture = get_texture(record.original_type, piece.color)

	current_turn = record.turn
	if record.captured != null:
		capture_audio_player.play()
	else:
		move_audio_player.play()

func redo_last_move() -> void:
	if redo_history.is_empty():
		return
	var record = redo_history.pop_back()
	_perform_move(record.from, record.to)
	move_history.append(record)
	current_turn = PieceColor.BLACK if record.piece.color == PieceColor.WHITE else PieceColor.WHITE

	if vs_bot and not redo_history.is_empty():
		var next = redo_history.back()
		if next.piece.color == bot_color:
			record = redo_history.pop_back()
			_perform_move(record.from, record.to)
			move_history.append(record)
			current_turn = PieceColor.BLACK if record.piece.color == PieceColor.WHITE else PieceColor.WHITE

	refresh_square_colors()
	check_game_end()
	_update_move_display()
	if not game_over and vs_bot and current_turn == bot_color and redo_history.is_empty():
		_start_bot_turn()

func _remove_captured_icon(type: int, color: int) -> void:
	var container = captured_by_black_container if color == PieceColor.WHITE else captured_by_white_container
	for i in range(container.get_child_count() - 1, -1, -1):
		var child = container.get_child(i)
		if child is TextureRect and child.texture == get_texture(type, color):
			child.queue_free()
			return

func _on_undo_pressed() -> void:
	if awaiting_bot or game_over or online_mode:
		return
	undo_last_move()

func _on_redo_pressed() -> void:
	if awaiting_bot or game_over or online_mode:
		return
	redo_last_move()

func _pos_to_alg(pos: Vector2i) -> String:
	var file := char(97 + pos.x)
	var rank := str(BOARD_SIZE - pos.y)
	return file + rank

func _update_move_display() -> void:
	if not is_instance_valid(move_label):
		return
	var reversed := move_history.duplicate()
	reversed.reverse()
	var text := ""
	for rec in reversed:
		text += _pos_to_alg(rec.to) + " "
	move_label.text = text.strip_edges()

# Captured pieces UI
# Captured pieces UI
func _add_captured_piece(type: int, color: int) -> void:
	var icon = TextureRect.new()
	icon.texture = get_texture(type, color)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if color == PieceColor.WHITE:
		captured_by_black_container.add_child(icon)
	else:
		captured_by_white_container.add_child(icon)
