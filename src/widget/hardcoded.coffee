class Hardcoded

    constructor: (@args) ->
        @args ?= {}

    event: (event, options...) -> switch event
        when "setup"
            [@stash, visualizer] = options
            for name, value of @args
                if name is "breakpoints"
                    @setBreakpoints(value)
                else
                    @stash[name] = value 
                    @stash._inputVars.push name

        when "editStop"
            # put things in stash again
            for name, value of @vars
                @stash[name] = value 

    setBreakpoints: (breakpoints) ->
        for context, points of breakpoints
            @stash._breakpoints[context] ?= []
            Vamonos.insertSet(b, @stash._breakpoints[context]) for b in points

Vamonos.export { Widget: { Hardcoded } }
