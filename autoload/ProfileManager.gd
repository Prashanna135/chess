extends Node
# Autoload this script as "ProfileManager" (Project Settings -> Autoload)
#
# Fully local profile: no backend. Name, Elo, and match history are saved
# to user:// on this device only. In an online game, both devices apply the
# same Elo formula against each other's pre-game rating, so results stay
# consistent between the two local histories even without a shared server.

const SAVE_PATH := "user://profile.json"
const STARTING_ELO := 1200
const K_FACTOR := 32

var player_name: String = ""
var elo: int = STARTING_ELO
var history: Array = []   # [{opponent, opponent_elo, result, elo_change, mode, date}, ...]


func _ready() -> void:
	load_profile()
	if player_name == "":
		player_name = "Player%d" % (randi() % 9000 + 1000)
		save_profile()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	player_name = data.get("name", player_name)
	elo = data.get("elo", elo)
	history = data.get("history", [])


func save_profile() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"name": player_name, "elo": elo, "history": history}))
	f.close()


func set_player_name(new_name: String) -> void:
	var trimmed = new_name.strip_edges()
	if trimmed != "":
		player_name = trimmed
		save_profile()


# result must be "win", "loss", or "draw". Returns the elo delta applied.
func record_game(opponent_name: String, opponent_elo: int, result: String, mode: String = "online") -> int:
	var score: float
	match result:
		"win": score = 1.0
		"loss": score = 0.0
		_: score = 0.5

	var expected = 1.0 / (1.0 + pow(10.0, float(opponent_elo - elo) / 400.0))
	var change = int(round(K_FACTOR * (score - expected)))
	elo += change

	history.push_front({
		"opponent": opponent_name,
		"opponent_elo": opponent_elo,
		"result": result,
		"elo_change": change,
		"mode": mode,
		"date": Time.get_datetime_string_from_system(),
	})
	if history.size() > 200:
		history.resize(200)

	save_profile()
	return change


func get_profile_dict() -> Dictionary:
	return {"name": player_name, "elo": elo}
