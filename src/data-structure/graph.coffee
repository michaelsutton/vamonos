class Graph
    constructor: ({vertices, edges, directed}) ->
        
        @vertices  = Vamonos.arrayify(vertices)
        @_type     = 'graph'
        @directed ?= yes
        @_adjHash  = {}
        
        @edges = for e in Vamonos.arrayify(edges)
            {source, target} = e
            e.source = @vertex(source)
            e.target = @vertex(target)
            @_adjHash[source] ?= {}
            @_adjHash[source][target] = e 
            e

        v._type = 'vertex' for v in @vertices
        e._type = 'edge'   for e in @edges

    edge: (s, t) ->
        [s,t] = (@_idify(v) for v in [s,t])
        @_adjHash[s][t]

    vertex: (id_str) ->
        @vertices.filter(({id}) -> id is id_str)[0]

    eachVertex: (f) ->
        f(v) for v in @vertices

    neighbors: (v) ->
        v = @_idify(v)
        @vertex(target) for target, edge of @_adjHash[v]

    eachNeighbor: (v, f) ->
        f(neighbor) for neighbor in @neighbors(v)

    outgoingEdges: (v) ->
        v = @_idify(v)
        @edges.filter(({source}) -> source.id is v)

    incomingEdges: (v) ->
        v = @_idify(v)
        @edges.filter(({target}) -> target.id is v)

    _idify: (v) ->
        return v if typeof v is 'string'
        v.id

    clone: () ->
        r = new Vamonos.DataStructure.Graph
            vertices: Vamonos.clone(@vertices)
            directed: @directed
            edges: []
        Vamonos.mixin(r, this, Vamonos.clone)


Vamonos.export { DataStructure: { Graph } }
