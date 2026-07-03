# ------------------------------------------------------------
# Optimale Short-Strategie für das klassische Shannon-Spiel
# Kompatibel mit:
#
# struct Vertex
#     id::Int
# end
#
# mutable struct Edge
#     id::Int
#     u::Vertex
#     v::Vertex
#     weight::Float64
#     state::Symbol
# end
#
# struct GameGraph
#     vertices::Vector{Vertex}
#     edges::Vector{Edge}
#     s::Vertex
#     t::Vertex
# end
#
# mutable struct GameState
#     graph::GameGraph
#     current_player::Symbol
#     history::Vector{Tuple{Symbol, Edge}}
#     winner::Union{Symbol, Nothing}
# end
# ------------------------------------------------------------


# ---------- Union-Find für Zusammenhang / Kontraktion ----------

struct _DSU
    parent::Dict{Int, Int}
    rank::Dict{Int, Int}
end

function _DSU(xs)
    parent = Dict{Int, Int}()
    rank = Dict{Int, Int}()

    for x in xs
        parent[x] = x
        rank[x] = 0
    end

    return _DSU(parent, rank)
end

function _find!(d::_DSU, x::Int)::Int
    if d.parent[x] != x
        d.parent[x] = _find!(d, d.parent[x])
    end
    return d.parent[x]
end

function _union!(d::_DSU, a::Int, b::Int)::Bool
    ra = _find!(d, a)
    rb = _find!(d, b)

    if ra == rb
        return false
    end

    if d.rank[ra] < d.rank[rb]
        ra, rb = rb, ra
    end

    d.parent[rb] = ra

    if d.rank[ra] == d.rank[rb]
        d.rank[ra] += 1
    end

    return true
end


# ---------- Interne Arbeitskante ----------
# Wir arbeiten nach Kontraktion von Short-Kanten nicht mehr direkt
# auf Vertex-Objekten, sondern auf Komponenten-IDs.

struct _WorkEdge
    id::Int
    u::Int
    v::Int
    original::Union{Edge, Nothing}
end

Base.:(==)(a::_WorkEdge, b::_WorkEdge) = a.id == b.id
Base.hash(e::_WorkEdge, h::UInt) = hash((:_WorkEdge, e.id), h)

_is_real_neutral(e::_WorkEdge)::Bool =
    e.original !== nothing && e.original.state == :neutral


# ---------- Letzten Cut-Zug finden ----------

function _last_cut_edge(state::GameState)::Union{Edge, Nothing}
    for i in length(state.history):-1:1
        player, edge = state.history[i]
        if player == :cut
            return edge
        end
    end
    return nothing
end

function _virtual_edge_id(g::GameGraph)::Int
    min_id = 0
    for e in g.edges
        min_id = min(min_id, e.id)
    end
    return min_id - 1
end


# ---------- Arbeitsgraph für Short bauen ----------
#
# Short-Kanten werden kontrahiert.
# Neutrale Kanten bleiben verfügbar.
# Die zuletzt von Cut entfernte Kante wird zusätzlich eingefügt,
# damit wir prüfen können, welchen Baum Cut beschädigt hat.
# Falls es noch keinen Cut-Zug gab, wird die virtuelle Kante (s,t) eingefügt.

function _short_work_graph(
    state::GameState,
    last_cut::Union{Edge, Nothing},
)
    g = state.graph

    dsu = _DSU([v.id for v in g.vertices])

    # Short-Kanten sind sicher und werden daher kontrahiert.
    for e in g.edges
        if e.state == :short
            _union!(dsu, e.u.id, e.v.id)
        end
    end

    comp = Dict{Int, Int}()
    for v in g.vertices
        comp[v.id] = _find!(dsu, v.id)
    end

    work_vertices = collect(Set(values(comp)))
    work_edges = _WorkEdge[]
    damaged_edge = nothing

    for e in g.edges
        is_last_cut = last_cut !== nothing && e.id == last_cut.id

        if e.state == :neutral || is_last_cut
            u = comp[e.u.id]
            v = comp[e.v.id]

            # Self-loops nach Kontraktion sind für Spannbäume irrelevant.
            if u == v
                continue
            end

            we = _WorkEdge(e.id, u, v, e)
            push!(work_edges, we)

            if is_last_cut
                damaged_edge = we
            end
        end
    end

    # Erster Short-Zug: virtuellen Cut auf (s,t) simulieren.
    if last_cut === nothing
        u = comp[g.s.id]
        v = comp[g.t.id]

        if u != v
            damaged_edge = _WorkEdge(_virtual_edge_id(g), u, v, nothing)
            push!(work_edges, damaged_edge)
        end
    end

    return work_vertices, work_edges, damaged_edge
end


# ---------- Spannbaum berechnen ----------

function _spanning_tree(
    vertices::Vector{Int},
    edges::Vector{_WorkEdge};
    forced_ids::Set{Int}=Set{Int}(),
    forbidden_ids::Set{Int}=Set{Int}(),
)::Union{Set{_WorkEdge}, Nothing}

    target_size = max(length(vertices) - 1, 0)
    dsu = _DSU(vertices)
    tree = Set{_WorkEdge}()

    # Erzwungene Kanten zuerst einbauen.
    for e in edges
        if e.id in forced_ids
            if e.id in forbidden_ids
                return nothing
            end

            if !_union!(dsu, e.u, e.v)
                return nothing
            end

            push!(tree, e)
        end
    end

    # Danach beliebig auffüllen.
    for e in edges
        if e.id in forced_ids || e.id in forbidden_ids
            continue
        end

        if _union!(dsu, e.u, e.v)
            push!(tree, e)
            if length(tree) == target_size
                break
            end
        end
    end

    if length(tree) == target_size
        return tree
    else
        return nothing
    end
end


# ---------- Fundamentalkreis ----------
#
# Für eine Nicht-Baumkante e und einen Baum T:
# FC(e,T) = die Baumkanten auf dem eindeutigen Pfad zwischen e.u und e.v.

function _tree_adjacency(tree::Set{_WorkEdge})
    adj = Dict{Int, Vector{Tuple{Int, _WorkEdge}}}()

    for e in tree
        push!(get!(adj, e.u, Tuple{Int, _WorkEdge}[]), (e.v, e))
        push!(get!(adj, e.v, Tuple{Int, _WorkEdge}[]), (e.u, e))
    end

    return adj
end

function _fundamental_cycle(
    chord::_WorkEdge,
    tree::Set{_WorkEdge},
)::Vector{_WorkEdge}

    adj = _tree_adjacency(tree)

    start = chord.u
    goal = chord.v

    parent_vertex = Dict{Int, Int}()
    parent_edge = Dict{Int, _WorkEdge}()

    seen = Set{Int}([start])
    queue = [start]
    head = 1

    while head <= length(queue)
        x = queue[head]
        head += 1

        if x == goal
            break
        end

        for (y, e) in get(adj, x, Tuple{Int, _WorkEdge}[])
            if !(y in seen)
                push!(seen, y)
                parent_vertex[y] = x
                parent_edge[y] = e
                push!(queue, y)
            end
        end
    end

    if !(goal in seen)
        return _WorkEdge[]
    end

    path = _WorkEdge[]
    x = goal

    while x != start
        e = parent_edge[x]
        push!(path, e)
        x = parent_vertex[x]
    end

    reverse!(path)
    return path
end


# ---------- Kishi-Kajitani-Augmentierung ----------
#
# Versucht, zwei Spannbäume weiter voneinander zu entfernen.
# Am Ende teilen sie im Idealfall keine neutralen Kanten mehr.

function _augment!(
    T1::Set{_WorkEdge},
    T2::Set{_WorkEdge},
    e::_WorkEdge,
)::Bool

    parent = Dict{_WorkEdge, _WorkEdge}()

    F = Set(_fundamental_cycle(e, T1))
    visited = Set(F)

    k = 1

    while !isempty(F)
        Talt = isodd(k) ? T2 : T1

        hit = nothing
        for f in F
            if f in Talt
                hit = f
                break
            end
        end

        if hit !== nothing
            chain = _WorkEdge[hit]
            x = hit

            while haskey(parent, x)
                x = parent[x]
                pushfirst!(chain, x)
            end

            # Tauschregel aus Algorithmus 4:
            # T1 bekommt e und die geraden Kettenpositionen,
            # verliert die ungeraden.
            # T2 macht das Umgekehrte.
            push!(T1, e)

            for (i, c) in enumerate(chain)
                if iseven(i)
                    push!(T1, c)
                    delete!(T2, c)
                else
                    delete!(T1, c)
                    push!(T2, c)
                end
            end

            return true
        end

        Fnext = Set{_WorkEdge}()

        for g in F
            for fp in _fundamental_cycle(g, Talt)
                if !(fp in visited)
                    push!(Fnext, fp)
                    push!(visited, fp)
                    parent[fp] = g
                end
            end
        end

        F = Fnext
        k += 1
    end

    return false
end

function _maximally_distant_trees!(
    T1::Set{_WorkEdge},
    T2::Set{_WorkEdge},
    edges::Vector{_WorkEdge},
)
    changed = true

    while changed
        changed = false

        for e in edges
            if !(e in T1) && !(e in T2)
                if _augment!(T1, T2, e)
                    changed = true
                end
            end
        end
    end

    return T1, T2
end

function _no_shared_neutral_edges(
    T1::Set{_WorkEdge},
    T2::Set{_WorkEdge},
)::Bool

    for e in intersect(T1, T2)
        if _is_real_neutral(e)
            return false
        end
    end

    return true
end


# ---------- Reparaturkante finden ----------

function _component_after_removing(
    tree::Set{_WorkEdge},
    removed::_WorkEdge,
    start::Int,
)::Set{Int}

    adj = _tree_adjacency(tree)

    seen = Set{Int}([start])
    queue = [start]
    head = 1

    while head <= length(queue)
        x = queue[head]
        head += 1

        for (y, e) in get(adj, x, Tuple{Int, _WorkEdge}[])
            if e == removed
                continue
            end

            if !(y in seen)
                push!(seen, y)
                push!(queue, y)
            end
        end
    end

    return seen
end

function _crosses_cut(e::_WorkEdge, side::Set{Int})::Bool
    return (e.u in side) != (e.v in side)
end

function _repair_edge(
    other_tree::Set{_WorkEdge},
    side::Set{Int},
)::Union{Edge, Nothing}

    for e in other_tree
        if _crosses_cut(e, side) && _is_real_neutral(e)
            return e.original
        end
    end

    return nothing
end


# ---------- Fallback: neutrale Kante auf einem s-t-Pfad ----------

function _st_path_edges(state::GameState)::Vector{Edge}
    g = state.graph

    adj = Dict{Int, Vector{Tuple{Int, Edge}}}()

    for e in g.edges
        if e.state != :cut
            push!(get!(adj, e.u.id, Tuple{Int, Edge}[]), (e.v.id, e))
            push!(get!(adj, e.v.id, Tuple{Int, Edge}[]), (e.u.id, e))
        end
    end

    start = g.s.id
    goal = g.t.id

    parent_vertex = Dict{Int, Int}()
    parent_edge = Dict{Int, Edge}()

    seen = Set{Int}([start])
    queue = [start]
    head = 1

    while head <= length(queue)
        x = queue[head]
        head += 1

        if x == goal
            break
        end

        for (y, e) in get(adj, x, Tuple{Int, Edge}[])
            if !(y in seen)
                push!(seen, y)
                parent_vertex[y] = x
                parent_edge[y] = e
                push!(queue, y)
            end
        end
    end

    if !(goal in seen)
        return Edge[]
    end

    path = Edge[]
    x = goal

    while x != start
        e = parent_edge[x]
        push!(path, e)
        x = parent_vertex[x]
    end

    reverse!(path)
    return path
end

function _fallback_short_move(state::GameState)::Edge
    moves = valid_moves(state)

    if isempty(moves)
        error("short_strategy wurde aufgerufen, obwohl es keine gültigen Züge gibt.")
    end

    path = _st_path_edges(state)

    for e in path
        if e.state == :neutral
            return e
        end
    end

    # Wenn kein s-t-Pfad existiert oder der gefundene Pfad schon komplett Short gehört:
    # irgendeinen gültigen Zug zurückgeben.
    return moves[1]
end


# ---------- Öffentliche Strategie ----------

function short_strategy(state::GameState)::Edge
    moves = valid_moves(state)

    if isempty(moves)
        error("short_strategy wurde aufgerufen, obwohl es keine gültigen Züge gibt.")
    end

    last_cut = _last_cut_edge(state)

    vertices, edges, damaged = _short_work_graph(state, last_cut)

    if damaged === nothing
        return _fallback_short_move(state)
    end

    forced_T1 = Set{Int}()
    forbidden_T2 = Set{Int}()

    # Beim ersten Zug ist damaged die virtuelle Kante (s,t).
    # Wir zwingen sie in T1 und verbieten sie in T2.
    if damaged.original === nothing
        push!(forced_T1, damaged.id)
        push!(forbidden_T2, damaged.id)
    end

    T1 = _spanning_tree(vertices, edges; forced_ids=forced_T1)
    T2 = _spanning_tree(vertices, edges; forbidden_ids=forbidden_T2)

    if T1 === nothing || T2 === nothing
        return _fallback_short_move(state)
    end

    _maximally_distant_trees!(T1, T2, edges)

    # Wenn die Bäume noch eine neutrale Kante gemeinsam haben,
    # ist die Gewinnstrategie nicht zertifiziert.
    if !_no_shared_neutral_edges(T1, T2)
        return _fallback_short_move(state)
    end

    # Fall 1: Cut hat T1 beschädigt.
    if damaged in T1
        side = _component_after_removing(T1, damaged, damaged.u)
        b = _repair_edge(T2, side)

        if b !== nothing
            return b
        end
    end

    # Fall 2: Cut hat T2 beschädigt.
    if damaged in T2
        side = _component_after_removing(T2, damaged, damaged.u)
        b = _repair_edge(T1, side)

        if b !== nothing
            return b
        end
    end

    # Fall 3: Der Cut-Zug lag in keinem der beiden Bäume.
    return _fallback_short_move(state)
end
