extends RefCounted
class_name ChessBot

# Configuration
var max_depth: int = 4
var randomness: float = 0.0
var color: int

# Matches ChessBot.new(game_node, bot_color, difficulty)
func _init(_game: Node = null, bot_color_param: int = PieceColor.BLACK, difficulty: int = 1) -> void:
	color = bot_color_param
	match difficulty:
		0: # Easy
			max_depth = 2
			randomness = 0.35
		1: # Medium
			max_depth = 3
			randomness = 0.08
		2: # Hard
			max_depth = 5
			randomness = 0.0
		_:
			max_depth = 3
			randomness = 0.08

# Constants
const MATE_SCORE := 100000.0
const INF := 1e9
const CHECKMATE_THRESHOLD := MATE_SCORE - 100.0

enum PieceType { KING, MINISTER, ELEPHANT, BISOP, KNIGHT, FOOTMAN }
enum PieceColor { WHITE, BLACK }
const BOARD_SIZE := 8

const PIECE_VALUES = {
	PieceType.KING:     0,
	PieceType.MINISTER: 900,
	PieceType.ELEPHANT: 500,
	PieceType.BISOP:    325,
	PieceType.KNIGHT:   320,
	PieceType.FOOTMAN:  100,
}

# Tapered piece‑square tables (midgame / endgame)
const PAWN_MG = [
	0,0,0,0,0,0,0,0,
	50,50,50,50,50,50,50,50,
	10,10,20,30,30,20,10,10,
	5,5,10,25,25,10,5,5,
	0,0,0,20,20,0,0,0,
	5,-5,-10,0,0,-10,-5,5,
	5,10,10,-20,-20,10,10,5,
	0,0,0,0,0,0,0,0,
]
const PAWN_EG = [
	0,0,0,0,0,0,0,0,
	70,70,70,70,70,70,70,70,
	30,30,40,50,50,40,30,30,
	20,20,30,45,45,30,20,20,
	10,10,20,35,35,20,10,10,
	0,0,10,20,20,10,0,0,
	0,0,0,-10,-10,0,0,0,
	0,0,0,0,0,0,0,0,
]
const KNIGHT_MG = [
	-50,-40,-30,-30,-30,-30,-40,-50,
	-40,-20,0,0,0,0,-20,-40,
	-30,0,10,15,15,10,0,-30,
	-30,5,15,20,20,15,5,-30,
	-30,0,15,20,20,15,0,-30,
	-30,5,10,15,15,10,5,-30,
	-40,-20,0,5,5,0,-20,-40,
	-50,-40,-30,-30,-30,-30,-40,-50,
]
const KNIGHT_EG = [
	-40,-30,-20,-20,-20,-20,-30,-40,
	-30,-15,0,0,0,0,-15,-30,
	-20,0,10,12,12,10,0,-20,
	-20,5,12,15,15,12,5,-20,
	-20,0,12,15,15,12,0,-20,
	-20,5,10,12,12,10,5,-20,
	-30,-15,0,5,5,0,-15,-30,
	-40,-30,-20,-20,-20,-20,-30,-40,
]
const BISHOP_MG = [
	-20,-10,-10,-10,-10,-10,-10,-20,
	-10,0,0,0,0,0,0,-10,
	-10,0,5,10,10,5,0,-10,
	-10,5,5,10,10,5,5,-10,
	-10,0,10,10,10,10,0,-10,
	-10,10,10,10,10,10,10,-10,
	-10,5,0,0,0,0,5,-10,
	-20,-10,-10,-10,-10,-10,-10,-20,
]
const BISHOP_EG = [
	-15,-10,-10,-10,-10,-10,-10,-15,
	-10,0,0,0,0,0,0,-10,
	-10,0,5,5,5,5,0,-10,
	-10,5,5,5,5,5,5,-10,
	-10,0,5,5,5,5,0,-10,
	-10,5,5,5,5,5,5,-10,
	-10,0,5,0,0,0,0,-10,
	-15,-10,-10,-10,-10,-10,-10,-15,
]
const ROOK_MG = [
	0,0,0,0,0,0,0,0,
	5,10,10,10,10,10,10,5,
	-5,0,0,0,0,0,0,-5,
	-5,0,0,0,0,0,0,-5,
	-5,0,0,0,0,0,0,-5,
	-5,0,0,0,0,0,0,-5,
	-5,0,0,0,0,0,0,-5,
	0,0,0,5,5,0,0,0,
]
const ROOK_EG = [
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
]
const QUEEN_MG = [
	-20,-10,-10,-5,-5,-10,-10,-20,
	-10,0,0,0,0,0,0,-10,
	-10,0,5,5,5,5,0,-10,
	-5,0,5,5,5,5,0,-5,
	0,0,5,5,5,5,0,-5,
	-10,5,5,5,5,5,0,-10,
	-10,0,5,0,0,0,0,-10,
	-20,-10,-10,-5,-5,-10,-10,-20,
]
const QUEEN_EG = [
	-20,-10,-10,-5,-5,-10,-10,-20,
	-10,0,0,0,0,0,0,-10,
	-10,0,5,5,5,5,0,-10,
	-5,0,5,5,5,5,0,-5,
	0,0,5,5,5,5,0,-5,
	-10,5,5,5,5,5,0,-10,
	-10,0,5,0,0,0,0,-10,
	-20,-10,-10,-5,-5,-10,-10,-20,
]
const KING_MG = [
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-30,-40,-40,-50,-50,-40,-40,-30,
	-20,-30,-30,-40,-40,-30,-30,-20,
	-10,-20,-20,-20,-20,-20,-20,-10,
	20,20,0,0,0,0,20,20,
	20,30,10,0,0,10,30,20,
]
const KING_EG = [
	-50,-40,-30,-20,-20,-30,-40,-50,
	-30,-20,-10,0,0,-10,-20,-30,
	-30,-10,20,30,30,20,-10,-30,
	-30,-10,30,40,40,30,-10,-30,
	-30,-10,30,40,40,30,-10,-30,
	-30,-10,20,30,30,20,-10,-30,
	-30,-30,0,0,0,0,-30,-30,
	-50,-30,-30,-30,-30,-30,-30,-50,
]

const MG_TABLES = [KING_MG, QUEEN_MG, ROOK_MG, BISHOP_MG, KNIGHT_MG, PAWN_MG]
const EG_TABLES = [KING_EG, QUEEN_EG, ROOK_EG, BISHOP_EG, KNIGHT_EG, PAWN_EG]

# Zobrist random numbers
static var zobrist_piece: Array = []
static var zobrist_side: int

static func _static_init():
	if zobrist_piece.is_empty():
		var rng = RandomNumberGenerator.new()
		rng.seed = 123456
		zobrist_piece.resize(BOARD_SIZE)
		for y in BOARD_SIZE:
			zobrist_piece[y] = []
			zobrist_piece[y].resize(BOARD_SIZE)
			for x in BOARD_SIZE:
				zobrist_piece[y][x] = {}
				for type in range(6):
					for col in range(2):
						zobrist_piece[y][x][type * 2 + col] = rng.randi()
		zobrist_side = rng.randi()

# Lightweight piece & board helpers
class LightPiece:
	var type: int
	var color: int
	var moved: bool
	func _init(t: int, c: int, m: bool = false):
		type = t; color = c; moved = m

static func _make_light_board(full_board: Array) -> Array:
	var light = []
	for y in BOARD_SIZE:
		var row = []
		light.append(row)
		for x in BOARD_SIZE:
			var p = full_board[y][x]
			if p == null:
				row.append(null)
			else:
				row.append(LightPiece.new(p.type, p.color, p.get("moved", false)))
	return light

static func _apply_move(board: Array, from: Vector2i, to: Vector2i, move_flags: int = 0) -> Dictionary:
	var piece = board[from.y][from.x]
	var captured = board[to.y][to.x]
	board[to.y][to.x] = piece
	board[from.y][from.x] = null
	var undo = {"from": from, "to": to, "piece": piece, "captured": captured, "was_moved": piece.moved}
	piece.moved = true
	if piece.type == PieceType.KING and abs(to.x - from.x) == 2:
		var rook_from_x = 7 if to.x > from.x else 0
		var rook_to_x = to.x - 1 if to.x > from.x else to.x + 1
		var rook = board[from.y][rook_from_x]
		board[from.y][rook_to_x] = rook
		board[from.y][rook_from_x] = null
		rook.moved = true
		undo["rook_from"] = Vector2i(rook_from_x, from.y)
		undo["rook_to"] = Vector2i(rook_to_x, from.y)
		undo["rook"] = rook
	if piece.type == PieceType.FOOTMAN and (to.y == 0 or to.y == 7):
		piece.type = PieceType.MINISTER
		undo["promoted"] = true
	return undo

static func _undo_move(board: Array, undo: Dictionary):
	var piece = undo.piece
	board[undo.from.y][undo.from.x] = piece
	board[undo.to.y][undo.to.x] = undo.captured
	piece.moved = undo.was_moved
	if undo.has("rook"):
		var rook = undo.rook
		board[undo.rook_from.y][undo.rook_from.x] = rook
		board[undo.rook_to.y][undo.rook_to.x] = null
		rook.moved = false
	if undo.has("promoted"):
		piece.type = PieceType.FOOTMAN

static func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < BOARD_SIZE and p.y >= 0 and p.y < BOARD_SIZE

static func _pseudo_moves(board: Array, pos: Vector2i, piece: LightPiece, attack_only: bool = false) -> Array:
	match piece.type:
		PieceType.FOOTMAN: return _pawn_moves(board, pos, piece, attack_only)
		PieceType.KNIGHT: return _knight_moves(board, pos, piece)
		PieceType.BISOP: return _sliding_moves(board, pos, piece, [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
		PieceType.ELEPHANT: return _sliding_moves(board, pos, piece, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)])
		PieceType.MINISTER: return _sliding_moves(board, pos, piece, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
		PieceType.KING: return _king_moves(board, pos, piece)
	return []

static func _pawn_moves(board: Array, pos: Vector2i, piece: LightPiece, attack_only: bool) -> Array:
	var moves = []
	var dir = -1 if piece.color == PieceColor.WHITE else 1
	var start_row = 6 if piece.color == PieceColor.WHITE else 1
	if not attack_only:
		var one = pos + Vector2i(0, dir)
		if in_bounds(one) and board[one.y][one.x] == null:
			moves.append(one)
			var two = pos + Vector2i(0, dir*2)
			if pos.y == start_row and board[two.y][two.x] == null:
				moves.append(two)
	for dx in [-1, 1]:
		var diag = pos + Vector2i(dx, dir)
		if in_bounds(diag):
			var target = board[diag.y][diag.x]
			if attack_only or (target != null and target.color != piece.color):
				moves.append(diag)
	return moves

static func _knight_moves(board: Array, pos: Vector2i, piece: LightPiece) -> Array:
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

static func _king_moves(board: Array, pos: Vector2i, piece: LightPiece) -> Array:
	var moves = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var p = pos + Vector2i(dx, dy)
			if in_bounds(p):
				var target = board[p.y][p.x]
				if target == null or target.color != piece.color:
					moves.append(p)
	return moves

static func _sliding_moves(board: Array, pos: Vector2i, piece: LightPiece, dirs: Array) -> Array:
	var moves = []
	for d in dirs:
		var p = pos + d
		while in_bounds(p):
			var target = board[p.y][p.x]
			if target == null:
				moves.append(p)
			else:
				if target.color != piece.color:
					moves.append(p)
				break
			p += d
	return moves

static func _castling_moves(board: Array, pos: Vector2i, piece: LightPiece) -> Array:
	var moves = []
	if piece.moved: return moves
	if _is_in_check(board, piece.color): return moves
	var y = pos.y
	var rook = board[y][7]
	if rook != null and rook.type == PieceType.ELEPHANT and rook.color == piece.color and not rook.moved:
		if board[y][5] == null and board[y][6] == null:
			if not _is_square_attacked(board, Vector2i(5, y), 1 - piece.color) and not _is_square_attacked(board, Vector2i(6, y), 1 - piece.color):
				moves.append(Vector2i(6, y))
	rook = board[y][0]
	if rook != null and rook.type == PieceType.ELEPHANT and rook.color == piece.color and not rook.moved:
		if board[y][1] == null and board[y][2] == null and board[y][3] == null:
			if not _is_square_attacked(board, Vector2i(3, y), 1 - piece.color) and not _is_square_attacked(board, Vector2i(2, y), 1 - piece.color):
				moves.append(Vector2i(2, y))
	return moves

static func _get_legal_moves(board: Array, pos: Vector2i, piece: LightPiece) -> Array:
	var pseudo = _pseudo_moves(board, pos, piece, false)
	pseudo.append_array(_castling_moves(board, pos, piece))
	var legal = []
	for m in pseudo:
		var undo = _apply_move(board, pos, m)
		if not _is_in_check(board, piece.color):
			legal.append(m)
		_undo_move(board, undo)
	return legal

static func _find_king(board: Array, color: int) -> Vector2i:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.type == PieceType.KING and p.color == color:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

static func _is_square_attacked(board: Array, pos: Vector2i, by_color: int) -> bool:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.color == by_color:
				var moves = _pseudo_moves(board, Vector2i(x,y), p, true)
				if pos in moves:
					return true
	return false

static func _is_in_check(board: Array, color: int) -> bool:
	var king_pos = _find_king(board, color)
	if king_pos.x == -1: return true
	return _is_square_attacked(board, king_pos, 1 - color)

# Evaluation
static func _evaluate(board: Array, side: int) -> float:
	var mg_score = 0
	var eg_score = 0
	var mg_material = 0
	var eg_material = 0
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p == null: continue
			var col = 1 if p.color == side else -1
			var type = p.type
			if type != PieceType.KING:
				mg_material += col * PIECE_VALUES[type]
				eg_material += col * PIECE_VALUES[type]
			var row = y if p.color == PieceColor.WHITE else 7 - y
			var idx = row * BOARD_SIZE + x
			mg_score += col * MG_TABLES[type][idx]
			eg_score += col * EG_TABLES[type][idx]
	var total_mat = 0
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.type != PieceType.KING:
				total_mat += PIECE_VALUES[p.type]
	var phase = clamp((8000 - total_mat) / 8000.0, 0.0, 1.0)
	return (mg_score + mg_material) * (1.0 - phase) + (eg_score + eg_material) * phase

# Transposition table (Dictionary-based)
static func _store_tt(tt: Dictionary, hash: int, depth: int, score: float, flag: int, best_move: Vector2i):
	tt[hash] = {
		"depth": depth,
		"score": score,
		"flag": flag,
		"best_move": best_move
	}

static func _lookup_tt(tt: Dictionary, hash: int, depth: int, alpha: float, beta: float):
	if tt.has(hash):
		var entry = tt[hash]
		if entry.depth >= depth:
			match entry.flag:
				0: return {"score": entry.score}
				1: alpha = max(alpha, entry.score)
				2: beta = min(beta, entry.score)
			if alpha >= beta:
				return {"score": entry.score}
	return {"alpha": alpha, "beta": beta}

# Move ordering — captures (MVV-LVA) > killers > history
static var killer_moves: Array = []          # killer_moves[ply] = [Vector2i, Vector2i]
static var history_table: Dictionary = {}    # "fx,fy->tx,ty" -> score

static func _move_score(board: Array, move: Dictionary) -> int:
	var captured = board[move.to.y][move.to.x]
	if captured == null:
		return 0
	var attacker = board[move.from.y][move.from.x]
	return PIECE_VALUES[captured.type] * 10 - PIECE_VALUES[attacker.type]

static func _history_key(m: Dictionary) -> String:
	return "%d,%d->%d,%d" % [m.from.x, m.from.y, m.to.x, m.to.y]

static func _sort_moves(board: Array, moves: Array, ply: int = 0) -> Array[Dictionary]:
	var scored := []
	var killers = []
	if ply < killer_moves.size() and killer_moves[ply] != null:
		killers = killer_moves[ply]
	for m in moves:
		var sc := 0
		var captured = board[m.to.y][m.to.x]
		if captured != null:
			sc = _move_score(board, m) + 1000000
		elif killers.has(m.to):
			sc = 900000
		else:
			sc = history_table.get(_history_key(m), 0)
		scored.append({"move": m, "score": sc})
	scored.sort_custom(func(a, b): return a.score > b.score)

	var result: Array[Dictionary] = []
	for x in scored:
		result.append(x.move)
	return result

static func _record_killer(m: Dictionary, ply: int, depth: int) -> void:
	if ply >= killer_moves.size():
		killer_moves.resize(ply + 1)
	if killer_moves[ply] == null:
		killer_moves[ply] = []
	var slot: Array = killer_moves[ply]
	if not slot.has(m.to):
		slot.push_front(m.to)
		if slot.size() > 2:
			slot.resize(2)
		killer_moves[ply] = slot
	var key = _history_key(m)
	history_table[key] = history_table.get(key, 0) + depth * depth

# Zobrist hashing
static func _zobrist_hash(board: Array, side: int) -> int:
	var hash = 0
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null:
				var key = p.type * 2 + p.color
				hash ^= zobrist_piece[y][x][key]
	if side == PieceColor.BLACK:
		hash ^= zobrist_side
	return hash

# Quiescence search — extends capture sequences only, so we
# don't blunder at the horizon without paying a full extra ply everywhere
static func _quiescence(
	board: Array,
	side: int,
	alpha: float,
	beta: float,
	start_time: int,
	time_limit_ms: int,
) -> float:
	node_count += 1
	if node_count % 512 == 0:
		if time_limit_ms > 0 and Time.get_ticks_msec() - start_time >= time_limit_ms:
			return 0.0

	var stand_pat = _evaluate(board, side)
	if stand_pat >= beta:
		return beta
	if alpha < stand_pat:
		alpha = stand_pat

	var captures: Array[Dictionary] = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.color == side:
				var pos = Vector2i(x, y)
				for m in _get_legal_moves(board, pos, p):
					if board[m.y][m.x] != null:
						captures.append({"from": pos, "to": m})

	if captures.is_empty():
		return alpha

	captures = _sort_moves(board, captures, 0)

	for m in captures:
		var undo = _apply_move(board, m.from, m.to)
		var score = -_quiescence(board, 1 - side, -beta, -alpha, start_time, time_limit_ms)
		_undo_move(board, undo)

		if score >= beta:
			return beta
		if score > alpha:
			alpha = score

	return alpha

# Main iterative deepening search
static var node_count: int

static func choose_move_static(
	full_board: Array,
	color: int,
	opponent_color: int,
	max_depth: int,
	randomness: float,
	rng: RandomNumberGenerator,
	time_limit_ms: int = 0,
) -> Dictionary:
	_static_init()
	var board = _make_light_board(full_board)
	var all_moves: Array[Dictionary] = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.color == color:
				var pos = Vector2i(x, y)
				for m in _get_legal_moves(board, pos, p):
					all_moves.append({"from": pos, "to": m})

	if all_moves.is_empty():
		return {}

	if rng.randf() < randomness:
		return all_moves[rng.randi() % all_moves.size()]

	# Reset ordering heuristics for this move's search
	killer_moves.clear()
	history_table.clear()

	var best_move_dict = all_moves[0]
	var best_score = -INF
	var start_time = Time.get_ticks_msec()
	# Stop LAUNCHING a new depth once this fraction of the budget is used —
	# leaves headroom so an in-progress depth doesn't blow the hard limit.
	var soft_limit = int(time_limit_ms * 0.55) if time_limit_ms > 0 else 0
	var tt = {}

	for depth in range(1, max_depth + 1):
		node_count = 0
		var current_best_move = best_move_dict
		var alpha = -INF
		var beta = INF
		var aborted = false

		all_moves = _sort_moves(board, all_moves, 0)

		for m in all_moves:
			var undo = _apply_move(board, m.from, m.to)
			var score = -_negamax(board, depth - 1, opponent_color, -beta, -alpha, start_time, time_limit_ms, tt, 0)
			_undo_move(board, undo)

			if time_limit_ms > 0 and Time.get_ticks_msec() - start_time >= time_limit_ms:
				aborted = true
				break

			if score > alpha:
				alpha = score
				current_best_move = m
			var hash = _zobrist_hash(board, color)
			_store_tt(tt, hash, depth, score, 0 if score > best_score else 1, m.to)

		# Only trust a depth's result if it completed the whole root move loop.
		# A partial pass can report a "best" move that just happened to be
		# searched before the clock ran out, not the actual best move.
		if not aborted:
			best_score = alpha
			best_move_dict = current_best_move
		else:
			break

		var elapsed = Time.get_ticks_msec() - start_time
		if time_limit_ms > 0 and elapsed >= soft_limit:
			break
		if best_score > CHECKMATE_THRESHOLD:
			break

	return best_move_dict

static func _negamax(
	board: Array,
	depth: int,
	side: int,
	alpha: float,
	beta: float,
	start_time: int,
	time_limit_ms: int,
	tt: Dictionary,
	ply: int,
) -> float:
	node_count += 1
	if node_count % 512 == 0:
		if time_limit_ms > 0 and Time.get_ticks_msec() - start_time >= time_limit_ms:
			return 0.0

	var alpha_orig = alpha

	var hash = _zobrist_hash(board, side)
	var lookup = _lookup_tt(tt, hash, depth, alpha, beta)
	if lookup.has("score"):
		return lookup.score
	alpha = lookup.alpha
	beta = lookup.beta

	if depth == 0:
		return _quiescence(board, side, alpha, beta, start_time, time_limit_ms)

	var moves: Array[Dictionary] = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p = board[y][x]
			if p != null and p.color == side:
				var pos = Vector2i(x, y)
				for m in _get_legal_moves(board, pos, p):
					moves.append({"from": pos, "to": m})

	if moves.is_empty():
		if _is_in_check(board, side):
			return -(MATE_SCORE - float(ply))
		return 0.0

	moves = _sort_moves(board, moves, ply)

	var best = -INF
	var best_move = Vector2i(-1, -1)
	for m in moves:
		var undo = _apply_move(board, m.from, m.to)
		var was_quiet = (undo.captured == null)
		var score = -_negamax(board, depth - 1, 1 - side, -beta, -alpha, start_time, time_limit_ms, tt, ply + 1)
		_undo_move(board, undo)

		if score > best:
			best = score
			best_move = m.to
		alpha = max(alpha, score)
		if alpha >= beta:
			# Quiet-move cutoff -> record as killer / bump history
			if was_quiet:
				_record_killer(m, ply, depth)
			break

	var flag = 0
	if best <= alpha_orig: flag = 2
	elif best >= beta: flag = 1
	else: flag = 0
	_store_tt(tt, hash, depth, best, flag, best_move)

	return best
