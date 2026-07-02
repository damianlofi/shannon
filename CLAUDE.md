# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a university programming project (TU Berlin, "Computerorientierte Mathematik II", SoSe 2026) implementing
the **Shannon Switching Game** as a Julia package. Two players, Short and Cut, alternately claim/remove edges of a
graph; Short wins if his claimed edges connect `s` and `t`, Cut wins if he disconnects them. Full task description
and grading checklist are in `instructions.pdf` and `checklist.pdf` (German) at the repo root — consult these for
the precise algorithm specs (they include the pseudocode the strategy functions are supposed to implement).

The project is graded on: correct data structures, correct game logic, a playable visualization, an optimal
`short_strategy` for the unweighted game (with `cut_strategy` as optional bonus), and heuristic `weighted_short`
/ `weighted_cut` strategies submitted to an external tournament judge (`comajudge`).

## Commands

```bash
# Instantiate/resolve dependencies (Cairo, Gtk4) into Manifest.toml
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run the test suite
julia --project=. -e 'using Pkg; Pkg.test()'
# or directly:
julia --project=. test/runtests.jl

# Load the package in the REPL
julia --project=. -e 'using Shannon_Switching_Game'

# Run the ad-hoc manual scratch script (src/run.jl) — not part of the package,
# it `include`s Shannon_Switching_Game.jl directly and exercises functions by hand
julia --project=. src/run.jl
```

There is no `Manifest.toml` committed; run `Pkg.instantiate()` after cloning. `test/runtests.jl` currently only
`include`s `src/run.jl` and has no actual `@test` assertions — do not assume behavior is verified just because
"tests pass".

## Architecture

The package entry point is `src/Shannon_Switching_Game.jl`, which declares the module and `include`s the other
source files in this fixed order (later files depend on structs/functions from earlier ones):

1. `Datenstrukturen.jl` — core structs: `Vertex` (id), `Edge` (mutable: id, endpoints `u`/`v`, `weight`, `state` ∈
   `:neutral`/`:short`/`:cut`), `GameGraph` (vertices, edges, source `s`, target `t`), `GameState` (mutable: graph,
   `current_player`, move `history` as `Vector{Tuple{Symbol,Edge}}`, `winner`). Also defines `==` for all four
   structs (structural equality, not reference equality — important because `Edge` is mutable and the same logical
   edge object is looked up by value in several places).
2. `Funktionen.jl` — game engine: `new_game`, `valid_moves`, `make_move!`, `check_winner` (BFS-based, called after
   every move), and `random_graph(n, m; weighted=false)` for generating connected test graphs (vertex 1 is always
   `s`, vertex `n` is always `t`).
3. `Visualisierung.jl` — intended to hold the playable GUI/REPL visualization (per the assignment, e.g. Gtk4 +
   GtkObservables, per `Project.toml` deps). Currently a stub with no implementation.
4. `Gewinnstrategien.jl` — optimal strategies for the *unweighted* game: `short_strategy` (Algorithm 1 in
   `instructions.pdf`, §4.1: maintains two spanning trees `A_t`/`B_t` with disjoint neutral edges and repairs them
   in reaction to Cut's last move) and `cut_strategy` (Algorithm 2, the dual: two edge sets with property that
   every s-t path and every cycle intersects both). Also contains `MaximallyDistantTrees`/`Augment`/`_FC`, a
   Kishi-Kajitani algorithm (Algorithm 3/4, Appendix A) for computing the two disjoint spanning trees the
   strategies need.
5. `Weightedstrategien.jl` — the tournament-facing heuristics `weighted_short`/`weighted_cut` plus the
   `TEAM_NAME` constant, submitted externally via `comajudge submit -t your-file.jl -p Shannon`. No optimal
   polynomial strategy is known for the weighted game (that's the point of this part) — these are graded by
   round-robin tournament, not correctness tests. Submissions must run in ~2s per move or they auto-lose.

### Known incomplete/unfinished code (as of the initial commit)

Be aware when touching these — they are not finished reference implementations to preserve, they're
work-in-progress:

- `Visualisierung.jl` is an empty stub.
- `cut_strategy` in `Gewinnstrategien.jl` is unfinished: it references an undefined `A_t_edge`, has no final
  edge-selection logic, and doesn't return an `Edge`.
- `_FC` in `Gewinnstrategien.jl` has a `while` loop with no condition (`#to be done`) — calling it will not compile
  or will infinite-loop.
- `MaximallyDistantTrees`/`Augment` (Kishi-Kajitani) are drafted but untested and depend on the broken `_FC`.
- `weighted_short` picks an edge on an s-t DFS path but falls through to "cheapest neutral edge" using a
  `Dict{Float64,Edge}` keyed by weight — this silently drops edges that share a weight value; treat this as a bug
  in the heuristic, not a spec requirement (the assignment doesn't dictate a specific heuristic, only that a valid
  one exists).
- `test/runtests.jl` has no assertions; per the grading checklist ("Für alle kritischen Funktionen haben wir Tests
  geschrieben"), the data-structure/game-logic functions in `Datenstrukturen.jl`/`Funktionen.jl` need real
  `@test`/`@testset` coverage.

### Domain invariants to preserve

- `make_move!` must only ever be called with an edge from `valid_moves(state)` (i.e. `state == :neutral`); it
  silently no-ops otherwise (no error is raised — matching the existing behavior if you extend it).
- All graphs used in this project are assumed connected; per the assignment, disconnected-graph handling is
  explicitly out of scope.
- The unweighted game is the special case of the weighted game where every edge has `weight == 0.0`.
