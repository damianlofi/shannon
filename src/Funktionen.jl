"""
    new_game

Die Funktion startet das Spiel, indem sie aus einen Graphen den neutralen 1. Spielstand macht
# Beispiel
````julia
julia> new_game(GameGraph([Vertex(1), Vertex(2)], [Edge(1,Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)))
GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)), :short, Tuple{Symbol, Edge}[], nothing)
````
"""
#Laufzeit: O(1)
function new_game(g::GameGraph)::GameState
    return(GameState(g, :short, Vector{Tuple{Symbol, Edge}}(), nothing))
end

"""
    valid_moves

Die Funktion gibt alle möglichen Züge für den jeweiligen Spieler zurück
# Beispiel
````julia
julia> state=GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)), :short, Tuple{Symbol, Edge}[], nothing)
julia> valid_moves(state)
1-element Vector{Edge}:
 Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
````
"""
#Laufzeit: O(m) mit m=|state.graph.edges| (einmaliges Durchlaufen aller Kanten)
function valid_moves(state::GameState)::Vector{Edge}
    neutraledges=Vector{Edge}()
    for edge in state.graph.edges
        if edge.state== :neutral 
            push!(neutraledges, edge)
        end
    end
    return(neutraledges)
end

"""
    make_move!

Die Funktion führt einen Spielzug aus (Kante beanspruchen) und aktualisiert dabei den Zustand vom Spiel
# Beispiel
````julia
julia> edge=Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
julia> state=GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], edge, Vertex(1), Vertex(2)), :short, Tuple{Symbol, Edge}[], nothing)
julia> make_move!(state, edge)
julia> state
GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :short)], Vertex(1), Vertex(2)), :cut, Tuple{Symbol, Edge}[(:short, Edge(1, Vertex(1), Vertex(2), 0.0, :short))], :short)
````
"""
#Laufzeit: O(n+m) mit n=|Knoten|, m=|Kanten| -- dominiert vom Aufruf von
#check_winner (valid_moves allein ist O(m))
function make_move!(state::GameState, e::Edge)::Nothing
    #=for edge in state.graph.edges
        if e==edge
            e=edge
        end
    end=#
    if e in valid_moves(state)
        #println("make_move ausgeführt")
        player= state.current_player

        e.state= player #Kantenzustand
        push!(state.history, (player, e)) #history aktualisieren
        
        #aktiven Spieler wechseln
        if player == :short
            state.current_player= :cut
        else
            state.current_player= :short
        end

        #Gewinnbedingung prüfen
        state.winner=check_winner(state)
        nothing
    end
end

"""
    check_winner

Die Funktion schaut nach jedem Zug, ob ein Spieler bereits Gewonnen (d.h. einen s-t-Weg hat)
# Beispiel
````julia
julia> state=GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :short)], Vertex(1), Vertex(2)), :cut, Tuple{Symbol, Edge}[(:short, Edge(1, Vertex(1), Vertex(2), 0.0, :short))], :short)
julia> check_winner(state)
:short
````
"""
#Laufzeit: O(n+m) mit n=|Knoten|, m=|Kanten| -- zwei Breitensuchen
#(je einmal höchstens alle Knoten/Kanten besucht)
function check_winner(state::GameState)::Union{Symbol, Nothing}
    #hat short gewonnen?
    beansprucht=Vector{Edge}()
    for (symbol,edge) in state.history
        if symbol== :short
            push!(beansprucht, edge)
        end
    end

    #Breitensuche
    gamegraph=state.graph
    queue=[gamegraph.s]
    short_winner_vertex=[gamegraph.s]
    while length(queue)>0
        node=popfirst!(queue)
        #Abbruchbedingung
        if node.id==gamegraph.t.id
            return :short
        end
        #neue Knoten adden
        for edge in beansprucht
            if edge.u==node && !(edge.v in short_winner_vertex)
                push!(queue, edge.v)
                push!(short_winner_vertex, edge.v)
            end
            if edge.v==node && !(edge.u in short_winner_vertex)
                push!(queue, edge.u)
                push!(short_winner_vertex, edge.u)
            end
        end
    end
    #hier hat short nicht gewonnen

    #hat cut gewonnen?
    frei=beansprucht #alle :cut und :neutral kanten
    for edge in state.graph.edges
        if edge.state==:neutral
            push!(frei, edge)
        end
    end

    gamegraph=state.graph
    queue=[gamegraph.s]
    cut_winner_vertex=[gamegraph.s]
    while length(queue)>0
        node=popfirst!(queue)
        #Abbruchbedingung
        if node.id==gamegraph.t.id
            return nothing
        end
        #neue Knoten adden
        for edge in frei
            if edge.u==node && !(edge.v in cut_winner_vertex)
                push!(queue, edge.v)
                push!(cut_winner_vertex, edge.v)
            end
            if edge.v==node && !(edge.u in cut_winner_vertex)
                push!(queue, edge.u)
                push!(cut_winner_vertex, edge.u)
            end
        end
    end
    #hier hat cut gewonnen
    return :cut    
    
end

"""
    valid_moves

Die Funktion erzeugt einen zufälligen Graphen mit n Knoten und m Kanten
# Beispiel
````julia
julia> random_graph(3,2)
GameGraph(Vertex[Vertex(1), Vertex(2), Vertex(3)], 
Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral), Edge(2, Vertex(3), Vertex(2), 0.0, :neutral)], 
Vertex(1), Vertex(3))
````
"""
#Laufzeit: O(n) für das Spannbaum-Grundgerüst, danach bis zu m-(n-1) weitere
#Kanten, deren Duplikatsprüfung jeweils O(m) kostet -- damit im schlechtesten
#Fall O(n+m²). Für m nahe der Maximalkantenzahl n(n-1)/2 kann die
#Zufallssuche nach einem noch freien Knotenpaar zusätzlich mehrere Versuche
#brauchen, bleibt aber für die in diesem Projekt üblichen Graphgrößen unkritisch.
function random_graph(n::Int, m::Int; weighted=false)::GameGraph
    #Knoten bauen
    vertices=Vector{Vertex}()
    for i=1:n
        push!(vertices, Vertex(i))
    end
    #kanten bauen
    edges=[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)]
    Zshkomponente=[Vertex(1), Vertex(2)]
    for i=3:n
        push!(edges, Edge(i-1, Vertex(i), rand(Zshkomponente), 0.0, :neutral))
        push!(Zshkomponente, Vertex(i))
    end
    j=n
    #maximale Kantenzahl eines einfachen Graphen mit n Knoten -- das Spiel
    #wird laut Aufgabenstellung auf einfachen Graphen gespielt, also ohne
    #Parallelkanten
    max_edges = n*(n-1) ÷ 2
    m = min(m, max_edges)
    while length(edges)<m
        u=rand(Zshkomponente)
        Zshkomponente2=copy(Zshkomponente)
        filter!(!=(u),Zshkomponente2)
        v=rand(Zshkomponente2)
        if !any(e -> (e.u==u && e.v==v) || (e.u==v && e.v==u), edges)
            push!(edges, Edge(j, u, v, 0.0, :neutral))
            j+=1
        end
    end

    #gewichteter fall
    if weighted==true
        for edge in edges
            edge.weight=float(rand(1:10))
        end
    end
    return GameGraph(vertices, edges, Vertex(1), Vertex(n))
end
