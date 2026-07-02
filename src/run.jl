include("Shannon_Switching_Game.jl")
using .Shannon_Switching_Game



#akute Tests in der Konsole

#=println(random_graph(3,6))
edge1=Edge(1, Vertex(1), Vertex(2), 0.0, :neutral)
edge2 = Edge(2, Vertex(3), Vertex(2), 0.0, :neutral)
edge3=Edge(3, Vertex(2), Vertex(1), 0.0, :neutral)
edge6=Edge(6, Vertex(1), Vertex(2), 0.0, :neutral)


r_graph=GameGraph(Vertex[Vertex(1), Vertex(2), Vertex(3)], Edge[edge1, edge2, edge3, Edge(4, Vertex(3), Vertex(2), 0.0, :neutral), Edge(5, Vertex(2), Vertex(1), 0.0, :neutral), edge6], Vertex(1), Vertex(3))
r_state=new_game(r_graph)
=#
#valid_moves(r_state)
#make_move!(r_state, edge2) #short wählt Kante mit id 2
#println(check_winner(r_state))
#make_move!(r_state, edge1) #cut wählt Kante mit id 1
#println(r_state)
#short_strategy(r_state)
#make_move!(r_state, edge3)
#println(r_state)

#=s1=short_strategy(r_state)
println(s1)
make_move!(r_state,s1)
println(r_state)
make_move!(r_state, edge6)
println(r_state)
make_move!(r_state, short_strategy(r_state))
println(r_state)=#

t_graph=GameGraph([Vertex(1), Vertex(2), Vertex(3)], [Edge(1,Vertex(1), Vertex(2), 5.0, :neutral), Edge(2,Vertex(2), Vertex(3), 4.0, :neutral)],Vertex(1),Vertex(3))
t_state=GameState(GameGraph(Vertex[Vertex(1), Vertex(2), Vertex(3)], Edge[Edge(1, Vertex(1), Vertex(2), 5.0, :short), Edge(2, Vertex(2), Vertex(3), 4.0, :neutral)], Vertex(1), Vertex(3)), :cut, Tuple{Symbol, Edge}[(:short, Edge(1, Vertex(1), Vertex(2), 5.0, :short))], nothing)
println(weighted_cut(t_state))
make_move!(t_state, weighted_cut(t_state))
println(t_state)


