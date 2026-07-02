using Test
using Shannon_Switching_Game

@testset "Datenstrukturen: Gleichheit" begin
    @test Vertex(1) == Vertex(1)
    @test Vertex(1) != Vertex(2)

    e1 = Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
    e1_vertauscht = Edge(1, Vertex(2), Vertex(1), 0.0, :neutral) #gleiche Kante, Endpunkte vertauscht
    e_andere_id = Edge(2, Vertex(1), Vertex(2), 0.0, :neutral)
    e_anderer_zustand = Edge(1, Vertex(1), Vertex(2), 0.0, :short)
    e_anderes_gewicht = Edge(1, Vertex(1), Vertex(2), 1.0, :neutral)

    @test e1 == e1_vertauscht
    @test e1 != e_andere_id
    @test e1 != e_anderer_zustand
    @test e1 != e_anderes_gewicht

    g1 = GameGraph([Vertex(1), Vertex(2)], [e1], Vertex(1), Vertex(2))
    g2 = GameGraph([Vertex(1), Vertex(2)], [e1_vertauscht], Vertex(1), Vertex(2))
    @test g1 == g2

    s1 = GameState(g1, :short, Tuple{Symbol,Edge}[], nothing)
    s2 = GameState(g2, :short, Tuple{Symbol,Edge}[], nothing)
    @test s1 == s2
end

@testset "new_game" begin
    g = GameGraph([Vertex(1), Vertex(2)], [Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)], Vertex(1), Vertex(2))
    state = new_game(g)
    @test state.graph == g
    @test state.current_player == :short
    @test isempty(state.history)
    @test state.winner === nothing
end

@testset "valid_moves" begin
    e1 = Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
    e2 = Edge(2, Vertex(2), Vertex(3), 0.0, :short)
    e3 = Edge(3, Vertex(1), Vertex(3), 0.0, :cut)
    g = GameGraph([Vertex(1), Vertex(2), Vertex(3)], [e1, e2, e3], Vertex(1), Vertex(3))
    state = new_game(g)
    @test valid_moves(state) == [e1]
end

@testset "make_move!" begin
    e1 = Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
    e2 = Edge(2, Vertex(2), Vertex(3), 0.0, :neutral)
    g = GameGraph([Vertex(1), Vertex(2), Vertex(3)], [e1, e2], Vertex(1), Vertex(3))
    state = new_game(g)

    make_move!(state, e1)
    @test e1.state == :short
    @test state.current_player == :cut
    @test state.history == [(:short, e1)]
    @test state.winner === nothing #noch kein s-t-Weg fuer Short

    #ungueltiger Zug (e1 ist nicht mehr neutral) -- laut Doku ein stiller No-Op
    make_move!(state, e1)
    @test state.current_player == :cut
    @test length(state.history) == 1

    make_move!(state, e2)
    @test e2.state == :cut
    @test state.current_player == :short
    @test state.winner == :cut #keine neutralen Kanten mehr, kein s-t-Weg moeglich
end

@testset "check_winner" begin
    e_short = Edge(1, Vertex(1), Vertex(2), 0.0, :short)
    g_short = GameGraph([Vertex(1), Vertex(2)], [e_short], Vertex(1), Vertex(2))
    @test check_winner(GameState(g_short, :cut, [(:short, e_short)], nothing)) == :short

    e_cut = Edge(1, Vertex(1), Vertex(2), 0.0, :cut)
    g_cut = GameGraph([Vertex(1), Vertex(2)], [e_cut], Vertex(1), Vertex(2))
    @test check_winner(GameState(g_cut, :short, [(:cut, e_cut)], nothing)) == :cut

    e_neutral = Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
    g_neutral = GameGraph([Vertex(1), Vertex(2)], [e_neutral], Vertex(1), Vertex(2))
    @test check_winner(GameState(g_neutral, :short, Tuple{Symbol,Edge}[], nothing)) === nothing
end

@testset "random_graph" begin
    for trial in 1:50
        n = rand(2:15)
        m = rand(1:40)
        g = random_graph(n, m)

        @test length(g.vertices) == n
        @test g.s == Vertex(1)
        @test g.t == Vertex(n)

        #einfacher Graph: keine Schleifen, keine Parallelkanten (siehe
        #instructions.pdf 1.1: "Das Spiel wird auf ... einfachen Graphen gespielt")
        seen = Set{Tuple{Int,Int}}()
        for e in g.edges
            @test e.u.id != e.v.id
            key = e.u.id < e.v.id ? (e.u.id, e.v.id) : (e.v.id, e.u.id)
            @test !(key in seen)
            push!(seen, key)
        end

        #zusammenhaengend: von s aus sind alle Knoten erreichbar
        visited = Set([1])
        queue = [1]
        while !isempty(queue)
            node = popfirst!(queue)
            for e in g.edges
                for (a, b) in ((e.u.id, e.v.id), (e.v.id, e.u.id))
                    if a == node && !(b in visited)
                        push!(visited, b)
                        push!(queue, b)
                    end
                end
            end
        end
        @test length(visited) == n
    end

    g_weighted = random_graph(6, 8; weighted=true)
    @test all(e -> 1.0 <= e.weight <= 10.0, g_weighted.edges)

    g_unweighted = random_graph(6, 8)
    @test all(e -> e.weight == 0.0, g_unweighted.edges)
end

@testset "weighted_short / weighted_cut liefern stets gueltige Zuege" begin
    for trial in 1:20
        n = rand(3:8)
        m = rand((n - 1):15)
        g = random_graph(n, m; weighted=true)
        state = new_game(g)
        steps = 0
        while state.winner === nothing && steps < 200
            e = state.current_player == :short ? weighted_short(state) : weighted_cut(state)
            @test e in valid_moves(state)
            make_move!(state, e)
            steps += 1
        end
        @test state.winner in (:short, :cut)
    end
end
