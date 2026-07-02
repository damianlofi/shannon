module Shannon_Switching_Game

export Vertex, Edge, GameGraph, GameState, new_game, valid_moves, make_move!, check_winner, random_graph, short_strategy, cut_strategy, MaximallyDistantTrees, Augment, weighted_short, weighted_cut, play_gui

include("Datenstrukturen.jl")
include("Funktionen.jl")
include("Visualisierung.jl")
include("Gewinnstrategien.jl")
include("Weightedstrategien.jl")

function __init__()
    println("Shannon-Switching Game gestartet!")
end

end