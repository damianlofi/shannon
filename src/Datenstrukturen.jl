"""
    Vertex

Die Datenstruktur eines Knotens bestehend aus seiner eindeutigen Kennung
# Beispiel
````julia
julia> Vertex(1)
Vertex(1)
````
"""
struct Vertex
    id::Int #Eindeutige Kennung des Knoten.
end

"""
    Edge

Die Datenstruktur einer Kante bestehend aus ihrer eindeutigen Kennung, ihrer Eckpunkte, ihrem Gewicht und Zustand
# Beispiel
````julia
julia> Edge(2, Vertex(1), Vertex(3), 0, :short)
Edge(2, Vertex(1), Vertex(3), 0.0, :short)
````
"""
mutable struct Edge
    id::Int #Eindeutige Kennung der Kante.
    u::Vertex #Der eine Endpunkte der ungerichteten Kante.
    v::Vertex #Der andere Endpunkte der ungerichteten Kante.
    weight::Float64 #Kantengewicht (0 für das ungewichtete Spiel). 
    state::Symbol #Zustand der Kante: :neutral, :short (beansprucht) oder :cut (entfernt).
end

"""
    GameGraph

Die Datenstruktur eines Graphen für ein Shannon-Switching-Spiel, bestehend aus allen Knoten, Kanten, Start-, sowie Endpunkt
# Beispiel
````julia
julia> GameGraph([Vertex(1), Vertex(3)], [Edge(2, Vertex(1), Vertex(3), 0, :short)], Vertex(1), Vertex(3))
GameGraph(Vertex[Vertex(1), Vertex(3)], Edge[Edge(2, Vertex(1), Vertex(3), 0.0, :short)], Vertex(1), Vertex(3))
````
"""
struct GameGraph
    vertices::Vector{Vertex} #Alle Knoten des Graphen.
    edges::Vector{Edge} #Alle Kanten des Graphen.
    s::Vertex #Quellknoten.
    t::Vertex #Zielknoten.
end

"""
    GameState

Die Datenstruktur eines Spielzuges des Shannon-Switching-Spieles bestehend aus dem zugehörigen Graph, 
Spieler, welcher an der Reihe ist, alle bisherigen Züge und dem Gewinner, falls das Spiel angeschlossen ist.
# Beispiel
````julia
julia> GameState(GameGraph(Vertex[Vertex(1), Vertex(3)], Edge[Edge(2, Vertex(1), Vertex(3), 0.0, :short)], Vertex(1), Vertex(3)), :cut, [(:short, Edge(2, Vertex(1), Vertex(3), 0.0, :short))], nothing)
GameState(GameGraph(Vertex[Vertex(1), Vertex(3)], Edge[Edge(2, Vertex(1), Vertex(3), 0.0, :short)], Vertex(1), Vertex(3)), :cut, Tuple{Symbol, Edge}[(:short, Edge(2, Vertex(1), Vertex(3), 0.0, :short))], nothing)
````
"""
mutable struct GameState
    graph::GameGraph #Der Spielgraph (mit veränderbaren Kantenzuständen).
    current_player::Symbol #Der aktuelle Spieler: :short oder :cut.
    history::Vector{Tuple{Symbol, Edge}} #Liste aller bisherigen Züge.
    winner::Union{Symbol, Nothing} #Gewinner (:short, :cut) oder nothing, falls das Spiel noch läuft
end

#Vergleichsfunktionen für unsere Structs

#Vertex vergleichen
function Base.:(==)(v1::Vertex, v2::Vertex)::Bool
    #println("vertex verglichen")
    return v1.id==v2.id
end

#Edges vergleichen
function Base.:(==)(e1::Edge, e2::Edge)::Bool
    #println("edges verglichen")
    return(e1.id==e2.id &&
    ((e1.u==e2.u &&
    e1.v==e2.v) || (e1.v==e2.u &&
    e1.u==e2.v)) &&
    e1.weight==e2.weight &&
    e1.state==e2.state)
end

#GameGraph vergleichen
function Base.:(==)(g1::GameGraph, g2::GameGraph)::Bool
    #println("graph verglichen")
    return(g1.vertices==g2.vertices &&
    g1.edges==g2.edges &&
    g1.s==g2.s &&
    g1.t==g2.t)
end

#GameState vergleichen
function Base.:(==)(g1::GameState, g2::GameState)::Bool
    #println("state verglichen")
    return(g1.graph==g2.graph &&
    g1.current_player==g2.current_player &&
    g1.history==g2.history &&
    g1.winner==g2.winner)
end

