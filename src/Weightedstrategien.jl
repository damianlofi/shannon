#Gewichtetes Spiel – Strategiewettbewerb

const TEAM_NAME::String = "Die drei ???" # Tragen Sie hier Ihren Teamnamen ein

"""
    weighted_short

Die Funktion gibt den besten Zug zu einem gegebenen Spielzustand im weighted Spiel aus, welchen Short ausführen kann
# Beispiel
````julia
julia> new_game(GameGraph([Vertex(1), Vertex(2)], [Edge(1,Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)))
GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)), :short, Tuple{Symbol, Edge}[], nothing)
````
"""
#Laufzeit: O(n+m) für die Tiefensuche nach einem s-t-Weg; im Fall ohne
#gefundenen Weg zusätzlich O(m log m) für die Sortierung der Kantengewichte
#(m=|Kanten|, n=|Knoten|)
function weighted_short(state::GameState)::Edge
    gamegraph=state.graph
    G1=Vector{Edge}() #alle neutralen und short kanten
    for edge in state.graph.edges
        if edge.state== :short || edge.state== :neutral
            push!(G1, edge)
        end
    end

    #Tiefensuche st-Weg
    stack=[gamegraph.s] #Knoten
    A_t_edge=Vector{Edge}() #Kantenmenge
    A_t_vertex=[gamegraph.s] #Knotenmenge
    while length(stack)>0
        node=pop!(stack)

        #Abbruchbedingung
        if node.id==gamegraph.t.id
            #erste Kante auf st-Weg
            for edge in A_t_edge
                if edge.state==:neutral
                    return edge
                end
            end
        end
    

        #neue Knoten adden
        for edge in G1
            if edge.u==node && !(edge.v in A_t_vertex) #nur, wenn Knoten noch nicht besucht worden ist
                push!(stack, edge.v)
                push!(A_t_edge, edge)
                push!(A_t_vertex, edge.v)
            end
            if edge.v==node && !(edge.u in A_t_vertex)
                push!(stack, edge.u)
                push!(A_t_edge, edge)
                push!(A_t_vertex, edge.u)
            end
        end
    end

    #kein st-Weg gefunden (dann hat eigentlich cut gewonnen)
    weights_edges= Dict{Float64, Edge}()
    neutral_edges = [e for e in state.graph.edges if e.state == :neutral]
    for edge in neutral_edges
        w=edge.weight
        weights_edges[w]=edge
    end

    weights=Vector{Float64}()
    for (k,v) in weights_edges
        push!(weights, k)
    end

    cheap=sort!(weights)[1]
    return weights_edges[cheap] #günstigste neutrale Kante

end

"""
    weighted_cut

Die Funktion gibt den besten Zug zu einem gegebenen Spielzustand im weighted Spiel aus, welchen Cut ausführen kann
# Beispiel
````julia
julia> new_game(GameGraph([Vertex(1), Vertex(2)], [Edge(1,Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)))
GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)), :short, Tuple{Symbol, Edge}[], nothing)
````
"""
#Laufzeit: O(n+m) für die Breitensuche ab t; der Fallback (günstigste
#neutrale Kante) kostet zusätzlich O(m) (m=|Kanten|, n=|Knoten|)
function weighted_cut(state::GameState)::Edge
    gamegraph=state.graph
    G1=Vector{Edge}() #alle neutralen und short kanten
    for edge in state.graph.edges
        if edge.state== :short || edge.state== :neutral
            push!(G1, edge)
        end
    end
    #Breitensuche auf G1
    queue=[gamegraph.t]
    wc_edge=Vector{Edge}()
    wc_vertex=[gamegraph.t]
    while length(queue)>0
        node=popfirst!(queue)
        #=Abbruchbedingung
        if node.id=gamegraph.t.id
            return :short
        end=#

        #neue Knoten adden
        for edge in G1
            if edge.u==node && !(edge.v in wc_vertex)
                push!(queue, edge.v)
                push!(wc_edge, edge)
                push!(wc_vertex, edge.v)
            end
            if edge.v==node && !(edge.u in wc_vertex)
                push!(queue, edge.u)
                push!(wc_edge, edge)
                push!(wc_vertex, edge.u)
            end
        end
    end

    for edge in wc_edge
        if edge.state==:neutral
            return edge 
        end
    end

    #wenn keine neutrale Kante in wc_edge liegt:
    #günstigste neutrale Kante wählen
    neutral_edges = [e for e in state.graph.edges if e.state == :neutral]
    return neutral_edges[argmin(e -> e.weight, neutral_edges)]

end