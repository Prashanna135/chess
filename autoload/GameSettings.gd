extends Node

# Autoload this script as "GameSettings" (Project Settings -> Autoload)

enum Mode { VS_BOT, VS_PERSON, ONLINE }
enum Difficulty { EASY, MEDIUM, HARD }

var mode: int = Mode.VS_BOT
var difficulty: int = Difficulty.MEDIUM
var time_control_seconds: int = 0   # 0 = no clock
var bot_color: int = 1              # PieceColor.BLACK — bot plays black by default

# Online multiplayer settings (set by online_menu.gd before starting the board)
var local_player_color: int = 0     # PieceColor.WHITE / BLACK — which side this device plays
var opponent_name: String = "Opponent"
var opponent_elo: int = 1200
