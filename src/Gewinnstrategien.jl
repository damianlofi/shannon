#Optimale Strategien für das klassische Spiel
"""
    short_strategy_old

Ursprüngliche Implementierung (siehe `short_strategy` weiter unten für die
korrigierte, aktuell verwendete Version). Bleibt unverändert
erhalten -- diese Version hatte zwei bekannte Probleme: einen `!=(x)`-Tippfehler
(Julias Curry-Syntax statt Negation) in einigen Zweigen, und eine A_t/B_t-
Konstruktion über zwei unabhängige Tiefensuchen, die keine echt maximal
distanten Bäume garantiert (siehe `short_strategy`-Docstring für Details).

Die Funktion gibt den besten Zug zu einem gegebenen Spielzustand aus, welchen Short ausführen kann
# Beispiel
````julia
julia> state=GameState(GameGraph(Vertex[Vertex(1), Vertex(2)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2)), :short, Tuple{Symbol, Edge}[], nothing)
julia> short_strategy_old(state)
Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
````
"""
#Laufzeit: O(n+m) mit n=|Knoten|, m=|Kanten| -- mehrere Tiefen-/Breitensuchen
#(A_t, B_t, C_s/C_t), von denen jede höchstens alle Knoten/Kanten einmal besucht
function short_strategy_old(state::GameState)::Edge
    gamegraph=state.graph
    G1=Vector{Edge}() #alle neutralen und short kanten
    for edge in state.graph.edges
        if edge.state== :short || edge.state== :neutral
            push!(G1, edge)
        end
    end

    #Tiefensuche für A_t
    stack=[gamegraph.s] #Knoten
    A_t_edge=Vector{Edge}() #Kantenmenge
    A_t_vertex=[gamegraph.s] #Knotenmenge
    while length(stack)>0
        node=pop!(stack)

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


    #Tiefensuche für B_t
    G2=copy(G1)
    function _filterfunkion(edge::Edge)
        return !(edge.state== :neutral && edge in A_t_edge)
    end
    filter!(_filterfunkion, G2)

    gamegraph=state.graph
    stack=[gamegraph.s]
    B_t_edge=Vector{Edge}() #Kantenmenge
    B_t_vertex=[gamegraph.s] #Knotenmenge
    while length(stack)>0
        node=pop!(stack)


        #neue Knoten adden
        for edge in G2
            if edge.u==node && !(edge.v in B_t_vertex)
                push!(stack, edge.v)
                push!(B_t_edge, edge)
                push!(B_t_vertex, edge.v)
            end
            if edge.v==node && !(edge.u in B_t_vertex)
                push!(stack, edge.u)
                push!(B_t_edge, edge)
                push!(B_t_vertex, edge.u)
            end
        end
    end

    if isempty(state.history)
        a=Edge(-1, gamegraph.s, gamegraph.t, 0.0, :cut)
    else
        a=state.history[length(state.history)][2]
    end

    if a in A_t_edge
        filter!(!=(a), A_t_edge)
        #Breitensuche für C_s
        gamegraph=state.graph
        queue=[gamegraph.s]
        C_s_edge=Vector{Edge}()
        C_s_vertex=[gamegraph.s]
        while length(queue)>0
            node=popfirst!(queue)
            #=Abbruchbedingung
            if node.id=gamegraph.t.id
                return :short
            end=#

            #neue Knoten adden
            for edge in A_t_edge
                if edge.u==node && !(edge.v in C_s_vertex)
                    push!(queue, edge.v)
                    push!(C_s_edge, edge)
                    push!(C_s_vertex, edge.v)
                end
                if edge.v==node && !(edge.u in C_s_vertex)
                    push!(queue, edge.u)
                    push!(C_s_edge, edge)
                    push!(C_s_vertex, edge.u)
                end
            end
        end
        #C_t ist der rest
        function _filterfunkion_C_t_edge(edge::Edge)
            return !=(edge in C_s_edge)
        end
        function _filterfunkion_C_t_vertex(vertex::Vertex)
            return !=(vertex in C_s_vertex)
        end
        C_t_edge=filter!(_filterfunkion_C_t_edge,copy(A_t_edge))
        C_t_vertex=filter!(_filterfunkion_C_t_vertex,copy(A_t_vertex))

        #Kante b auswählen
        if isempty(C_t_edge)
            for edge in A_t_edge
                if edge.state == :neutral
                    return edge 
                end
            end
        else
            for edge in B_t_edge
                if edge.state== :neutral
                    if (edge.u in C_s_vertex && edge.v in C_t_vertex) || (edge.v in C_s_vertex && edge.u in C_t_vertex)
                        return edge 
                    end
                end
            end
        end

    #Schritt 8:
    elseif a in B_t_edge
        filter!(!=(a), B_t_edge)
        #Breitensuche für C_s
        gamegraph=state.graph
        queue=[gamegraph.s]
        C_s_edge=Vector{Edge}()
        C_s_vertex=[gamegraph.s]
        while length(queue)>0
            node=popfirst!(queue)
            #=Abbruchbedingung
            if node.id=gamegraph.t.id
                return :short
            end=#

            #neue Knoten adden
            for edge in B_t_edge
                if edge.u==node && !(edge.v in C_s_vertex)
                    push!(queue, edge.v)
                    push!(C_s_edge, edge)
                    push!(C_s_vertex, edge.v)
                end
                if edge.v==node && !(edge.u in C_s_vertex)
                    push!(queue, edge.u)
                    push!(C_s_edge, edge)
                    push!(C_s_vertex, edge.u)
                end
            end
        end
        #C_t ist der rest
        function _filterfunkion_C_t_edge2(edge::Edge)
            return !=(edge in C_s_edge)
        end
        function _filterfunkion_C_t_vertex2(vertex::Vertex)
            return !=(vertex in C_s_vertex)
        end
        C_t_edge=filter!(_filterfunkion_C_t_edge2,copy(B_t_edge))
        C_t_vertex=filter!(_filterfunkion_C_t_vertex2,copy(B_t_vertex))

        #Kante b auswählen
        if isempty(C_t_edge)
            for edge in B_t_edge
                if edge.state == :neutral
                    return edge 
                end
            end
        else
            for edge in A_t_edge
                if edge.state== :neutral
                    if (edge.u in C_s_vertex && edge.v in C_t_vertex) || (edge.v in C_s_vertex && edge.u in C_t_vertex)
                        return edge 
                    end
                end
            end
        end

    #Schritt 11
    else
        for edge in A_t_edge
            if edge.state == :neutral
                return edge
            end
        end
    end
end

"""
    cut_strategy

Die Funktion gibt den besten Zug zu einem gegebenen Spielzustand aus, welchen Cut ausführen kann
# Beispiel
````julia
julia> state=GameState(GameGraph(Vertex[Vertex(1), Vertex(2), Vertex(3)], Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :short), Edge(2, Vertex(2), Vertex(3), 0.0, :neutral)], Vertex(1), Vertex(3)), :cut, Tuple{Symbol, Edge}[(:short, Edge(1, Vertex(1), Vertex(2), 0.0, :short))], nothing)
julia> cut_strategy(state)
Edge(2, Vertex(2), Vertex(3), 0.0, :neutral)
````
"""
#Laufzeit: aktuell nicht sinnvoll angebbar, da die Funktion unvollständig
#implementiert ist (kein return, verwendet ein undefiniertes A_t_edge) --
#konzeptionell (Anhang B) wäre analog zu short_strategy O(n+m) pro
#Baumkonstruktion zu erwarten, plus die Kosten von MaximallyDistantTrees
function cut_strategy(state::GameState)::Edge
    gamegraph=state.graph
    G1=Vector{Edge}() #alle neutralen und short kanten
    for edge in state.graph.edges
        if edge.state== :short || edge.state== :neutral
            push!(G1, edge)
        end
    end

    #Berechne At, Bt: zwei disjunkte s-t-Trennmengen in G′ mit Eigenschaft 2

    #(nicht richtig eine) Tiefensuche für den Spannbaum
    stack=[gamegraph.s] #Knoten
    Spannbaum_edge=Vector{Edge}() #Kantenmenge
    Spannbaum_vertex=[gamegraph.s] #Knotenmenge
    while length(stack)>0
        node=pop!(stack)

        #=Abbruchbedingung
        if node.id=gamegraph.t.id
            return :short
        end=#

        #neue Knoten adden
        for edge in G1 #gleich mehrere Kanten werden abgesucht -> nicht ganz Tiefensuche-flavoured
            if edge.u==node && !(edge.v in Spannbaum_vertex) #nur, wenn Knoten noch nicht besucht worden ist
                push!(stack, edge.v)
                push!(Spannbaum_edge, edge)
                push!(Spannbaum_vertex, edge.v)
            end
            if edge.v==node && !(edge.u in Spannbaum_vertex)
                push!(stack, edge.u)
                push!(Spannbaum_edge, edge)
                push!(Spannbaum_vertex, edge.u)
            end
        end
    end

    #Kospannbaum
    Kospannbaum=copy(G1)
    function _filterfunkion(edge::Edge)
        return !(edge.state== :neutral && edge in A_t_edge)
    end
    filter!(_filterfunkion, Kospannbaum)


    #Schritt 4
    a=state.history[length(state.history)][2]


end


#Algorithm 3 Maximal distante Spannb¨aume (Kishi-Kajitani)

"""
    MaximallyDistantTrees(G1, T1, T2)

Macht die beiden Spannbäume `T1`,`T2` von `G1` schrittweise maximal distant
(Algorithmus 3, Kishi-Kajitani, siehe Anhang A der Aufgabenstellung): Für
jede gemeinsame Sehne (eine Kante in keinem der beiden Bäume) wird versucht,
mittels `Augment` den Abstand `d(T1,T2)=|T1\\T2|` der Bäume zu erhöhen, bis
keine Verbesserung mehr möglich ist. Sind `G1` zwei kantendisjunkte
Spannbäume möglich, liefert die Funktion sie.

# Beispiel
````julia
julia> e1 = Edge(1, Vertex(1), Vertex(2), 0.0, :neutral);
julia> e2 = Edge(2, Vertex(1), Vertex(2), 0.0, :neutral);
julia> MaximallyDistantTrees([e1, e2], [e1], [e2])
(Edge[Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)], Edge[Edge(2, Vertex(1), Vertex(2), 0.0, :neutral)])
````

#Laufzeit: nicht abschließend zu beziffern, da diese Funktion auf dem
#derzeit unvollständigen `Augment`/`_FC` aufbaut (siehe dort); konzeptionell
#ist jede Augmentierung höchstens O(m) teuer (m=|G1|) und wird höchstens
#O(m) mal wiederholt, also insgesamt O(m²).
"""
function MaximallyDistantTrees(G1::Vector{Edge}, T1::Vector{Edge}, T2::Vector{Edge})::Tuple{Vector{Edge},Vector{Edge}}
    changed=true
    function _filterfunkion_MDT(edge::Edge)
        return !=(edge in T1 || edge in T2)
    end
    while changed
        changed=false
        for edge in filter!(_filterfunkion_MDT, G1)
            if Augment!(T1, T2, edge)
                changed=true
            end
        end
    end
    return (T1, T2)
end

#Algorithm 4 Augmentierung entlang einer gemeinsamen Sehne

"""
    Augment(T1, T2, edge)

Versucht, die beiden Spannbäume `T1`,`T2` entlang der gemeinsamen Sehne
`edge` einen Schritt distanter zu machen (Algorithmus 4, siehe Anhang A):
Es werden schichtweise Fundamentalkreise (`_FC`) ausgehend von `edge`
verfolgt, bis eine Kette gefunden wird, entlang derer `T1`/`T2` getauscht
werden können. Gibt zurück, ob eine solche Verbesserung gefunden und
angewendet wurde.

# Beispiel
````julia
julia> T1 = [Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)];
julia> T2 = [Edge(2, Vertex(1), Vertex(2), 0.0, :neutral)];
julia> Augment(T1, T2, Edge(3, Vertex(1), Vertex(2), 0.0, :neutral))
false
````

#Laufzeit: konzeptionell O(m) pro Aufruf (m=|T1∪T2|), da jede Kante
#höchstens einmal in eine Schicht aufgenommen wird -- die aktuelle
#Implementierung ist jedoch unvollständig (u.a. verwendet sie `par` wie ein
#Dict, obwohl es als leerer Vektor initialisiert wird) und terminiert daher
#nicht zuverlässig.
"""
function Augment(T1::Vector{Edge}, T2::Vector{Edge}, edge::Edge)::Bool
    par=[]
    L=_FC(edge,T1)
    L_prev=[]
    k=1
    while !issetequal(Set(L),Set(L_prev))
        L_prev=L
        if k%2==0
            T_alt=T1
        else
            T_alt=T2
        end
        Schnitt=intersect(L,T_alt)
        if !isempty(Schnitt)
            f=Schnitt[1]#eine Kante
            x=f
            chain=[f]
            while x in par
                x=par[x]#?????
                chain=union([x],chain)
            end
            T1=setdiff(union(T1,[edge], chain[2:2:length(chain)]), chain[1:2:length(chain)])
            T2=setdiff(union(T2, chain[1:2:length(chain)]), chain[2:2:length(chain)])
            return true
        end
        for g in L
            for f1 in setdiff(_FC(g,T_alt), L)
                L=union(L, [f1])
                par[f1]=g
            end
        end

        k+=1
    end

    return false
    
end

"""
    _FC(start, T1)

Der Fundamentalkreis FC(`start`,`T1`) der Sehne `start` bezüglich des
Spannbaums `T1` (siehe Anhang A): die Kantenmenge aus `start` selbst und dem
eindeutigen Baumpfad zwischen ihren beiden Endpunkten in `T1`.

# Beispiel
````julia
julia> T1 = [Edge(1, Vertex(1), Vertex(2), 0.0, :neutral), Edge(2, Vertex(2), Vertex(3), 0.0, :neutral)];
julia> _FC(Edge(3, Vertex(1), Vertex(3), 0.0, :neutral), T1)
3-element Vector{Edge}:
 Edge(2, Vertex(2), Vertex(3), 0.0, :neutral)
 Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
 Edge(3, Vertex(1), Vertex(3), 0.0, :neutral)
````

#Laufzeit: konzeptionell O(n+m) für die Pfadsuche in T1 (n=|Knoten|,
#m=|T1|) -- die aktuelle Implementierung ist jedoch unvollständig (die
#`while`-Bedingung fehlt, siehe `#to be done`) und daher nicht lauffähig.
"""
function _FC(start::Edge, T1:: Vector{Edge})::Vector{Edge}
    output=[start]
    currentvertex=start.v
    while #to be done (Tiefensuche?) -> Kreiskanten finden -> in der PA Eulertour?
        for edge in setdiff(T1, output)
            if edge.u==currentvertex
                currentvertex=edge.v
                push!(output, edge)
            elseif edge.v==currentvertex
                currentvertex=edge.u
                push!(output, edge)
            end
        end
    end

end
