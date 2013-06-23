class Graph

    constructor: ({container, @varName, @defaultGraph, @vertexSetupFunc,
        @vertexUpdateFunc, @showVertices, @showEdges}) ->

        @$outer = Vamonos.jqueryify(container)
        @$inner = $("<div>", {class: "graph-inner-container"})
        @$outer.append(@$inner)

        @connections ?= []
        @nodes ?= []

        @jsPlumbInit()
        
    event: (event, options...) -> switch event
        when "setup"
            [@viz] = options
            @viz.registerVariable(key) for key of @showVertices
            for e of @showEdges
                @viz.registerVariable(v) for v in e.split(/<?->?/)
            if @defaultGraph?
                @theGraph = @viz.setVariable(@varName, Vamonos.clone(@defaultGraph), true)
            else
                @theGraph = new Vamonos.DataStructure.Graph()

        when "render"
            [frame, type] = options

            if @graphDrawn
                $elem.removeClass("changed") for $elem in @nodes.concat(@connections)
            else
                @drawGraph(frame[@varName])

            @updateVertex(v) for v in frame[@varName].vertices
            @runShowFuncs(frame)
            @previousFrame = frame

        when "displayStart"
            @displayMode()

        when "displayStop"
            @clear()

        when "editStart"
            @editMode()

        when "editStop"
            @$outer.off "click"
            @viz.setVariable(@varName, Vamonos.clone(@theGraph), true)
            @clear()


    displayMode: () ->
        @mode = "display"

    editMode: () ->
        @mode = "edit"
        @drawGraph(@theGraph)
        @$outer.on "click", (e) =>
            console.log "click handler", @theGraph
            $target = $(e.target)
            # Create and destroy vertices with shfit
            if e.shiftKey
                if $target.is(".vertex-contents")
                    vid = $target.parent().attr("id")
                    @removeNode(vid)
                else
                    vtx = 
                        id: @nextVertexId()
                        x: e.offsetX - 12
                        y: e.offsetY - 12
                    @theGraph.addVertex(vtx)
                    @makeVertex(vtx)

            # Select vertices and create and destroy edges with regular click
            else
                if not @selectedVertex?
                    if $target.is(".vertex-contents")
                        @selectedVertex = $target.parent()
                        @selectedVertex.addClass("selected")
                else
                    if $target.is(".vertex-contents")
                        if $target.parent().attr("id") is @selectedVertex.attr("id")
                            @deselect()
                            return

                        sourceId = @selectedVertex.attr("id")
                        targetId = $target.parent().attr("id")

                        if @theGraph.edge(sourceId, targetId)
                            # delete an edge
                            @theGraph.removeEdge(sourceId, targetId)
                            @removeConnection(sourceId, targetId)
                            @removeConnection(targetId, sourceId) unless @theGraph.directed
                            @deselect()
                
                        else
                            # make a new edge
                            @theGraph.addEdge(sourceId, targetId)
                            @makeConnection(sourceId, targetId)
                            @makeConnection(targetId, sourceId) unless @theGraph.directed
                            @deselect()
                    else
                        @deselect()

    deselect: () ->
        return unless @selectedVertex?
        @selectedVertex.removeClass("selected")
        @selectedVertex = undefined

    nextVertexId: () ->
        @_customVertexNum ?= 0
        return "custom-vertex-#{@_customVertexNum}"

    runShowFuncs: (frame) ->
        @runShowVertices(frame)
        @runShowEdges(frame)

    runShowVertices: (frame) ->
        for name, {show, hide} of @showVertices
            newv = frame[name]
            oldv = @previousFrame?[name] 
            if newv? and not oldv?
                show(@vertexSelector(newv))
                continue
            else if oldv? and not newv?
                hide(@vertexSelector(oldv))
            else if @varChanged(newv, oldv)
                hide(@vertexSelector(oldv))
                show(@vertexSelector(newv))

    runShowEdges: (frame) ->
        for edgeStr, {show, hide} of @showEdges
            if edgeStr.match /->/ 
                hide(c) for c in @shownConnections if @shownConnections?
                @shownConnections = []

                [source, target] = edgeStr.split /->/ 

                edges = frame[@varName].edges.filter (e) ->
                    e.source?.id == frame[source]?.id and e.target?.id == frame[target]?.id

                unless frame[@varName].directed
                    edges = edges.concat(@reverseEdge(e) for e in edges)

                return unless edges.length > 0

                for e in edges
                    for connection in @getConnections(e)
                        show(connection)
                        @shownConnections.push(connection)

    reverseEdge: (edge) ->
        source: edge.target
        target: edge.source

    getConnections: (edge) ->
        @connections.filter (e) ->
            e.sourceId == edge.source.id and e.targetId == edge.target.id

    getConnection: (sourceId, targetId) ->
        (e for e in @connections when e.sourceId is sourceId and e.targetId is targetId)[0]

    vertexSelector: (v) ->
        return unless @graphDrawn
        v = @theGraph.vertex(v) if typeof v is 'string'
        @nodes.filter(($vtx) -> $vtx.attr("id") is v.id)[0]

    vertexChanged: (newv) ->
        return true unless @previousFrame?
        oldv = @previousFrame[@varName]
            .vertices.filter((v) -> v.id is newv.id)[0]
        @varChanged(newv, oldv)

    varChanged: (newv, oldv) ->
        return false unless oldv?
        r1 = (oldv[k] == v for k, v of newv)
        r2 = (newv[k] == v for k, v of oldv)
        not r1.concat(r2).every((b) -> b)

    updateVertex: (vertex) ->
        $v = @vertexSelector(vertex)
        @vertexUpdateFunc(vertex, $v) if @vertexUpdateFunc?
        $v.addClass("changed") if @vertexChanged(vertex)

    removeNode: (vid) ->
        $vtx = @vertexSelector(vid)
        affectedEdges = @connections.filter (e) ->
            e.sourceId is vid or e.targetId is vid
        for edge in affectedEdges
            @removeConnection(edge)
        @nodes.splice(@nodes.indexOf($vtx), 1)
        $vtx.remove()
        @theGraph.removeVertex(vid)

    removeConnection: (sourceId, targetId) ->
        connection = @getConnection(sourceId, targetId)
        @jsPlumbInstance.detach(connection) 
        @connections.splice(@connections.indexOf(connection), 1)

    jsPlumbInit: () -> 
        @jsPlumbInstance = jsPlumb.getInstance 
            Connector: ["Straight", {gap: 6}]
            PaintStyle: 
                lineWidth: 2
                strokeStyle:"gray"
            Endpoint: "Blank"
            EndpointStyle:{ fillStyle:"black" }
            ConnectionOverlays: [ 
                ["PlainArrow", {location:-4, width:8, length:8}]
            ]
            Anchor: [ "Perimeter", { shape: "Circle" } ]

    makeNode: (vertex) ->
        $v = $("<div>", {class: 'vertex', id: vertex.id})
        $v.attr('id', vertex.id)
        $contents = $("<div>", class: "vertex-contents")

        if @vertexSetupFunc?
            @vertexSetupFunc(vertex, $v)
        else
            $contents.html(Vamonos.rawToTxt(vertex))

        $v.append($contents)

        pos = @$inner.position()
        $v.css("left", vertex.x)
        $v.css("top",  vertex.y)
        $v.css("position", "absolute")

        @$inner.append($v)
        @nodes.push($v)

    makeConnection: (sourceId, targetId) ->
        connection = @jsPlumbInstance.connect({ source: sourceId, target: targetId })
        @connections.push(connection)

    drawGraph: (G) ->
        @makeNode(v) for v in G.vertices
        @makeConnection(e.source.id, e.target.id) for e in G.edges
        @graphDrawn = yes

    clear: () ->
        @jsPlumbInit()
        @$inner.html("")
        @graphDrawn = no
        @connections = []
        @nodes = []
        @previousFrame = undefined

Vamonos.export { Widget: { Graph } }
