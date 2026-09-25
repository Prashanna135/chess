# Chess Proj

A complete, mobile-friendly chess game built in **Godot 4** (GDScript).

Play against a real chess engine, against a friend on the same device, or
against someone on the same Wi-Fi network. Everything is laid out in code
with a single dark, gold-accented theme designed for phones.

---

## Features

### The game
- Full 8x8 chess board with all six pieces.
- Legal move generation — you can only make legal moves.
- **Castling** and **pawn promotion**.
- **Check, checkmate, and stalemate** detection.
- Captured pieces displayed on each player's card as the game goes on.
- Board coordinates (a–h / 1–8) drawn on the edge squares.

### AI opponent
A proper chess engine, not a random mover. It uses:
- Negamax search with **alpha-beta pruning**.
- **Iterative deepening** with a time budget.
- A **transposition table** to avoid re-searching the same positions.
- Killer-move and history heuristics to order moves well.
- Tapered **piece-square tables** (separate midgame and endgame values).

Three difficulty levels:

| Level  | Search depth | Randomness |
|--------|--------------|------------|
| Easy   | 2 ply        | high       |
| Medium | 3 ply        | slight     |
| Hard   | 5 ply        | none       |

Pick your side (White / Black) or hit **Random**.

### Game modes
- **Vs Bot** — play the built-in engine.
- **Vs Player** — two people, one device, taking turns.
- **Online (LAN P2P)** — direct peer-to-peer play over your local network.
  - Host a game and share a short **invite code**.
  - Or use **Quick Match**, which finds a nearby opponent automatically.
  - Optional internet mode for play over the wider web (requires port
    forwarding).

### Options and quality of life
- Optional chess clock: No Clock, Blitz (5 min), Rapid (10 min),
  Classical (30 min).
- **Undo** and **Redo** moves (local games).
- **Flip board** to view from either side.
- **Resign** with a confirmation prompt.
- Scrolling move-history strip.
- Post-game options to start another match or return to the menu.
- Local player profile: name, Elo rating, and a recent-games list — saved on
  your device, no account or server needed.

---

## Look and feel

All screens share one theme so the game feels consistent:

- Dark navy backgrounds with a warm gold glow.
- Rounded, bordered cards and panels with soft drop shadows.
- Gold primary buttons and outlined secondary buttons.
- Touch-friendly hit targets and spacing.
- Portrait layout built for phones (720 x 1280 base resolution).

---

## Controls

Everything is tap/click driven — no keyboard required.

- Tap a piece to select it, then tap a highlighted square to move.
- Move dots show legal moves; capture targets are highlighted in red.
- The **UNDO / REDO / MENU** bar sits at the bottom of the board screen.

---

## Project structure

```
board/
  board.gd            Board scene: rules, move logic, and in-game UI
  chess_bot.gd        The AI engine
  start_menu.gd       Main menu (mode, difficulty, clock, side)
  online_menu.gd      Online / LAN multiplayer lobby
  mainboard.tscn      Board scene
  start_menu.tscn     Main menu scene
  online_menu.tscn    Online menu scene

autoload/
  GameSettings.gd     Shared game settings (mode, difficulty, clock, colors)
  NetworkManager.gd   LAN peer-to-peer networking
  ProfileManager.gd   Local profile, Elo, and match history

assets/               Piece sprites, board art, and audio

main_menu_theme.tres  Shared UI theme (cards, buttons, panels, colors)
project.godot         Godot project settings
```

---

## Getting started

1. Open the project in **Godot 4**.
2. Press **Play** — the main menu is the starting scene.
3. For online play, make sure both devices are on the same Wi-Fi network or
   one is connected to the other's hotspot, then share the invite code (or
   use Quick Match).

No plugins or external services are required. Online play is direct
peer-to-peer over your local network.

---

## Requirements

- Godot 4.x
- Desktop or mobile export targets (the layout is designed for portrait
  phone screens)

---

## License

Add your preferred license here before publishing (for example, MIT for open
source, or an asset-store license for commercial distribution).
