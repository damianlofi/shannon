#spielbare Visualisierung

using Gtk4
using GtkObservables
using Cairo
using Colors
using Graphics: width, height

"""
    filled_segment!(ctx, x1, y1, x2, y2, halfwidth, color)

Zeichnet eine "Linie" von `(x1,y1)` nach `(x2,y2)` als gefülltes schmales
Rechteck der Breite `2*halfwidth`. In dieser Umgebung rendert `stroke()`
nichts sichtbares (getestet), `fill()` dagegen zuverlässig -- deshalb bauen
wir alle linienartigen Elemente aus gefüllten Polygonen statt aus
gezogenen Pfaden.
"""
function filled_segment!(ctx, x1, y1, x2, y2, halfwidth, color)
    dx, dy = x2 - x1, y2 - y1
    len = hypot(dx, dy)
    nx, ny = -dy / len * halfwidth, dx / len * halfwidth
    move_to(ctx, x1 + nx, y1 + ny)
    line_to(ctx, x2 + nx, y2 + ny)
    line_to(ctx, x2 - nx, y2 - ny)
    line_to(ctx, x1 - nx, y1 - ny)
    close_path(ctx)
    set_source(ctx, color)
    fill(ctx)
end

"""
    filled_circle!(ctx, x, y, r, fillcolor; outline=colorant"black", outline_width=0.005)

Zeichnet einen Knoten als zwei konzentrische gefüllte Kreise: ein etwas
größerer in `outline`-Farbe darunter, ein kleinerer in `fillcolor` darüber.
Simuliert einen Kreis mit Rand, ohne `stroke()` zu benötigen.
"""
function filled_circle!(ctx, x, y, r, fillcolor; outline=colorant"black", outline_width=0.005)
    arc(ctx, x, y, r, 0, 2pi)
    set_source(ctx, outline)
    fill(ctx)
    arc(ctx, x, y, r - outline_width, 0, 2pi)
    set_source(ctx, fillcolor)
    fill(ctx)
end

"""
    draw_centered_text!(ctx, txt, x, y)

Zeichnet `txt` zentriert um `(x,y)`.
"""
function draw_centered_text!(ctx, txt::AbstractString, x, y)
    ext = text_extents(ctx, txt)
    move_to(ctx, x - (ext[3] / 2 + ext[1]), y - (ext[4] / 2 + ext[2]))
    show_text(ctx, txt)
end

"""
    layout_positions(g)

Berechnet für jeden Knoten eine Position in `[0,1]×[0,1]`, rein anhand der
Graphtopologie. `s` liegt links, `t` rechts, alle übrigen Knoten werden
abwechselnd oberhalb und unterhalb der Mittelachse verteilt dazwischen.
Einfache heuristische Anordnung, kein allgemeiner Graph-Layout-Algorithmus.
"""
function layout_positions(g::GameGraph)::Dict{Int,Tuple{Float64,Float64}}
    pos = Dict{Int,Tuple{Float64,Float64}}()
    pos[g.s.id] = (0.08, 0.5)
    pos[g.t.id] = (0.92, 0.5)
    others = [v for v in g.vertices if !(v == g.s) && !(v == g.t)]
    k = length(others)
    for (i, v) in enumerate(others)
        frac = k <= 1 ? 0.5 : (i - 1) / (k - 1)
        x = 0.08 + 0.84 * frac
        y = isodd(i) ? 0.5 - 0.32 : 0.5 + 0.32
        pos[v.id] = (x, y)
    end
    return pos
end

"""
    segment_distance(px, py, x1, y1, x2, y2)

Abstand des Punktes `(px,py)` zur Strecke von `(x1,y1)` nach `(x2,y2)`.
"""
function segment_distance(px, py, x1, y1, x2, y2)
    dx, dy = x2 - x1, y2 - y1
    len2 = dx^2 + dy^2
    t = clamp(((px - x1) * dx + (py - y1) * dy) / len2, 0.0, 1.0)
    cx, cy = x1 + t * dx, y1 + t * dy
    return hypot(px - cx, py - cy)
end

"""
    edge_at_position(g, pos, x, y; tol=0.05)

Gibt die Kante aus `g` zurück, die dem Punkt `(x,y)` am nächsten liegt,
sofern der Abstand unter `tol` liegt; sonst `nothing`.
"""
function edge_at_position(g::GameGraph, pos, x, y; tol=0.05)
    best = nothing
    bestd = tol
    for e in g.edges
        (x1, y1) = pos[e.u.id]
        (x2, y2) = pos[e.v.id]
        d = segment_distance(x, y, x1, y1, x2, y2)
        if d < bestd
            bestd = d
            best = e
        end
    end
    return best
end

"""
    clone_graph(g)

Erzeugt eine unabhängige Kopie von `g` mit frischen `Vertex`/`Edge`-Objekten,
deren Kanten alle auf `:neutral` zurückgesetzt sind. Notwendig, weil `Edge`
`mutable` ist: `make_move!` verändert Kanten direkt, daher würde ein neues
Spiel auf demselben `GameGraph`-Objekt noch die Zustände der vorherigen
Partie tragen.
"""
function clone_graph(g::GameGraph)::GameGraph
    vertexcopy(v::Vertex) = Vertex(v.id)
    edgecopy(e::Edge) = Edge(e.id, vertexcopy(e.u), vertexcopy(e.v), e.weight, :neutral)
    return GameGraph(map(vertexcopy, g.vertices), map(edgecopy, g.edges), vertexcopy(g.s), vertexcopy(g.t))
end

"""
    example_diamond()

Der Beispielgraph aus Abbildung 1 der Aufgabenstellung: vier Knoten
(`s`, `a`, `b`, `t`) und fünf Kanten.
"""
function example_diamond()::GameGraph
    s = Vertex(1)
    a = Vertex(2)
    b = Vertex(3)
    t = Vertex(4)
    edges = [
        Edge(1, s, a, 0.0, :neutral),
        Edge(2, s, b, 0.0, :neutral),
        Edge(3, a, t, 0.0, :neutral),
        Edge(4, b, t, 0.0, :neutral),
        Edge(5, a, b, 0.0, :neutral),
    ]
    return GameGraph([s, a, b, t], edges, s, t)
end

"""
    example_bridge()

Ein einfacher Pfad `s`-`m`-`t` mit nur zwei Kanten. Ein klassisches
Cut-Spiel: egal welche Kante Short zuerst beansprucht, Cut entfernt die
andere und gewinnt.
"""
function example_bridge()::GameGraph
    s = Vertex(1)
    m = Vertex(2)
    t = Vertex(3)
    edges = [Edge(1, s, m, 0.0, :neutral), Edge(2, m, t, 0.0, :neutral)]
    return GameGraph([s, m, t], edges, s, t)
end

"""
    example_cycle(n=6)

Ein Kreis mit `n` Knoten, `s` und `t` liegen sich gegenüber. Enthält zwar
zwei kantendisjunkte `s`-`t`-Wege, ist aber trotzdem KEIN garantiertes
Short-Spiel: die beiden Wege haben keinerlei Redundanz (bloße Pfade, keine
Bäume), daher kann Cut mit einem einzigen Zug (Entfernen einer beliebigen
Kante) den Kreis so aufbrechen, dass nur noch ein einziger `s`-`t`-Weg ohne
Ersatzkante übrig bleibt. Rechnerisch: der Graph mit verschmolzenem `s`,`t`
hat 5 Knoten (braucht 2·4=8 Kanten für zwei disjunkte Spannbäume), besitzt
aber nur 6 Kanten -- ein Short-Spiel im Sinne von Lehmans Kriterium ist
damit unmöglich. Trotzdem als eigenständiges Beispiel nützlich (kleiner,
sparsamer Graph zum Testen der Spiellogik).
"""
function example_cycle(n::Int=6)::GameGraph
    n >= 3 || throw(ArgumentError("Ein Kreis benötigt mindestens 3 Knoten."))
    vertices = [Vertex(i) for i in 1:n]
    edges = [Edge(i, vertices[i], vertices[i == n ? 1 : i + 1], 0.0, :neutral) for i in 1:n]
    return GameGraph(vertices, edges, vertices[1], vertices[n ÷ 2 + 1])
end

function status_text(state::GameState)::String
    if state.winner !== nothing
        winner = state.winner == :short ? "Short" : "Cut"
        return "Spiel beendet — Gewinner: $winner"
    end
    player = state.current_player == :short ? "Short" : "Cut"
    return "Am Zug: $player"
end

"""
    play_gui(g::GameGraph=random_graph(6, 8))

Der Graph ist spielbar (Klick auf eine neutrale Kante = Zug), und eine
Symbolleiste bietet: neuen Zufallsgraphen, Neustart mit demselben Graphen,
das Beispiel aus Abbildung 1, einen Gewichtet-Schalter sowie Buttons, um
Short/Cut über `short_strategy`/`cut_strategy` ziehen zu lassen.
"""
function play_gui(g::GameGraph=random_graph(6, 8))
    template = Ref(g)
    state = new_game(clone_graph(template[]))

    win = GtkWindow("Shannon-Switching-Spiel", 600, 520)
    vbox = GtkBox(:v)

    # Zeile 1: Graph erzeugen/laden
    row1 = GtkBox(:h)
    cb_weighted = GtkCheckButton("gewichtet")
    spn_n = GtkSpinButton(2:40)
    set_gtk_property!(spn_n, "value", 6)
    spn_m = GtkSpinButton(1:200)
    set_gtk_property!(spn_m, "value", 8)
    btn_random = GtkButton("Neues zufälliges Spiel")
    btn_restart = GtkButton("Neues Spiel (gleicher Graph)")
    for w in (cb_weighted, GtkLabel("n:"), spn_n, GtkLabel("m:"), spn_m, btn_random, btn_restart)
        push!(row1, w)
    end
    push!(vbox, row1)

    # Zeile 2: Beispielgraphen und Computerstrategien
    row2 = GtkBox(:h)
    btn_diamond = GtkButton("Beispiel: Diamant")
    btn_bridge = GtkButton("Beispiel: Brücke")
    btn_cycle = GtkButton("Beispiel: Kreis")
    btn_short_ki = GtkButton("Short (KI) zieht")
    btn_cut_ki = GtkButton("Cut (KI) zieht")
    for w in (btn_diamond, btn_bridge, btn_cycle, btn_short_ki, btn_cut_ki)
        push!(row2, w)
    end
    push!(vbox, row2)

    statuslabel = GtkLabel(status_text(state))
    push!(vbox, statuslabel)

    cnvs = canvas(UserUnit)
    Gtk4.vexpand(widget(cnvs), true)
    push!(vbox, cnvs)
    push!(win, vbox)

    hover = Ref{Union{Edge,Nothing}}(nothing)

    function refresh!()
        Gtk4.label(statuslabel, status_text(state))
        Gtk4.draw(widget(cnvs))
    end

    function load_graph!(newgraph::GameGraph)
        template[] = newgraph
        state = new_game(clone_graph(newgraph))
        hover[] = nothing
        refresh!()
    end

    draw(cnvs) do widget
        fill!(widget, colorant"white")

        # Ein zentriertes Quadrat innerhalb des Canvas als Zeichenfläche
        # verwenden, statt den vollen (ggf. nicht-quadratischen) Canvas auf
        # das 0..1-Koordinatenquadrat abzubilden -- sonst würde die Zeichnung
        # bei jedem Resize non-uniform gestreckt/gestaucht.
        w, h = width(widget), height(widget)
        side = min(w, h)
        x0, y0 = (w - side) / 2, (h - side) / 2
        set_coordinates(widget, BoundingBox(x0, x0 + side, y0, y0 + side), BoundingBox(0, 1, 0, 1))
        ctx = getgc(widget)
        pos = layout_positions(state.graph)
        weighted = any(e -> e.weight != 0.0, state.graph.edges)

        for e in state.graph.edges
            x1, y1 = pos[e.u.id]
            x2, y2 = pos[e.v.id]

            color = if e.state == :short
                colorant"royalblue"
            elseif e.state == :cut
                colorant"firebrick"
            elseif e === hover[] && state.winner === nothing
                colorant"green"
            else
                colorant"gray40"
            end
            filled_segment!(ctx, x1, y1, x2, y2, 0.005, color)

            if weighted
                mx, my = (x1 + x2) / 2, (y1 + y2) / 2
                set_source(ctx, colorant"black")
                select_font_face(ctx, "sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
                set_font_size(ctx, 0.03)
                draw_centered_text!(ctx, string(round(e.weight, digits=1)), mx, my - 0.02)
            end
        end

        for v in state.graph.vertices
            x, y = pos[v.id]
            color = (v == state.graph.s || v == state.graph.t) ? colorant"orange" : colorant"lightskyblue"
            filled_circle!(ctx, x, y, 0.035, color)

            label = v == state.graph.s ? "s" : v == state.graph.t ? "t" : string(v.id)
            set_source(ctx, colorant"black")
            select_font_face(ctx, "sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
            set_font_size(ctx, 0.04)
            draw_centered_text!(ctx, label, x, y)
        end
    end

    on(cnvs.mouse.motion) do btn
        pos = layout_positions(state.graph)
        x, y = Float64(btn.position.x), Float64(btn.position.y)
        e = edge_at_position(state.graph, pos, x, y)
        if e !== hover[]
            hover[] = e
            Gtk4.draw(widget(cnvs))
        end
    end

    on(cnvs.mouse.buttonpress) do btn
        btn.button == 1 || return
        state.winner === nothing || return
        pos = layout_positions(state.graph)
        x, y = Float64(btn.position.x), Float64(btn.position.y)
        e = edge_at_position(state.graph, pos, x, y)
        if e !== nothing && e.state == :neutral
            make_move!(state, e)
            refresh!()
        end
    end

    signal_connect(btn_random, "clicked") do _
        weighted = get_gtk_property(cb_weighted, "active", Bool)
        n = get_gtk_property(spn_n, "value", Int)
        m = get_gtk_property(spn_m, "value", Int)
        load_graph!(random_graph(n, m; weighted=weighted))
    end

    signal_connect(btn_restart, "clicked") do _
        state = new_game(clone_graph(template[]))
        hover[] = nothing
        refresh!()
    end

    signal_connect(btn_diamond, "clicked") do _
        load_graph!(example_diamond())
    end

    signal_connect(btn_bridge, "clicked") do _
        load_graph!(example_bridge())
    end

    signal_connect(btn_cycle, "clicked") do _
        load_graph!(example_cycle(6))
    end

    function ki_move!(strategy, playersym, name)
        if state.winner !== nothing
            Gtk4.label(statuslabel, "Spiel ist bereits beendet.")
            return
        end
        if state.current_player != playersym
            Gtk4.label(statuslabel, "$name ist nicht am Zug.")
            return
        end
        try
            e = strategy(state)
            make_move!(state, e)
            refresh!()
        catch err
            Gtk4.label(statuslabel, "$name-Strategie hat einen Fehler geworfen: $(sprint(showerror, err))")
        end
    end

    signal_connect(btn_short_ki, "clicked") do _
        ki_move!(short_strategy, :short, "Short")
    end

    signal_connect(btn_cut_ki, "clicked") do _
        ki_move!(cut_strategy, :cut, "Cut")
    end

    return win
end
