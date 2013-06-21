###
#
#   src/visualizer.coffee :: exports Vamonos.Visualizer
#
#   Controls widgets, runs algorithm, and maintains state for the visualization.
#
#   Constructor Arguments:
#
#       widgets:        An array of Vamanos.Widget objects. These set up the
#                       stash and breakpoints, display variables and control
#                       the visualizer.
#
#       algorithm:      The algorithm itself, coded as a javascript function
#                       that takes a visualizer as input and calls the
#                       visualizer's line(n) method at places corresponding
#                       to pseudocode lines.
#
#       maxFrames:      The maximum number of frames that the line method will
#                       generate before throwing an error. Default is 250.
#
#       autoStart:      Should the visualizer start in display mode? Defaults
#                       to false.
#
###


###*
# The test project
#
# @project tester
# @title The Tester
# @icon http://a.img
# @url http://one.url
# @url http://two.url
# @author admo
# @contributor davglass
# @contributor entropy
###


###*
# Just a test
#
# @class Visualizer
# @constructor
# @param options {Object} asdfasdf
#   @param options.widgets {Array} list of widgets
#   @param options.algorithm {Function} callback
#   @param options.maxFrames {Number} something
#   @param options.autoStart {Boolean} whether to auto start
###

class Visualizer

    constructor: ({@widgets, @maxFrames, algorithm, autoStart}) ->
        @maxFrames         ?= 250
        autoStart          ?= false

        @currentFrameNumber = 0
        @breakpoints        = {}

        @stash = new Vamonos.DataStructure.Stash()

        @_prepareAlgorithm(algorithm)

        @tellWidgets("setup", @)

        if autoStart
            @runAlgorithm() 
        else
            @editMode() 

    # stash manipulation encapsulation methods
    registerVariable: (name) ->
        @stash[name] ?= undefined

    setVariable: (name, value, isInput = false) ->
        @stash[name] = value
        Vamonos.insertSet(name, @stash._inputVars) if isInput
        return value # for chaining

    getVariable: (name) ->
        @stash[name]

    getBreakpoints: (proc) ->
        @breakpoints[proc] ?= []
        return @breakpoints[proc]

    setBreakpoint: (b, proc) ->
        @breakpoints[proc] ?= []
        Vamonos.insertSet(b, @breakpoints[proc])

    removeBreakpoint: (b, proc) ->
        @breakpoints[proc] ?= []
        @breakpoints[proc].splice(@breakpoints[proc].indexOf(b), 1)


    _prepareAlgorithm: (algorithm) -> switch typeof algorithm
        when 'function'
            @stash._inputVars.push("main")
            @stash._subroutine
                name: "main"
                procedure: algorithm
                visualizer: @

        when 'object'
            for procedureName, obj of algorithm
                @stash._inputVars.push(procedureName)
                @stash._subroutine
                    procedureName : procedureName
                    argNames      : obj.argNames
                    procedure     : obj.procedure
                    localVarNames : obj.localVarNames
                    visualizer    : @


    ###
    #   Visualizer.line(number)
    #
    #   marks an expression in the javascript algorithm simulation (passed
    #   in to constructor as 'algorithm') as corresponding to a particular
    #   line in the pseudocode.
    #
    #   n=0 is reserved for taking a snapshot of the variables before/after
    #   entire algorithm execution
    ###
    line: (n) ->
        # if context changed since last call of line(), tell the stash's
        # call stack what the last line was.
        if @prevLine? and @stash._context isnt @prevLine.context and @stash._callStack.length > 0
            calls = (s for s in @stash._callStack when s.context is @prevLine.context)
            s.line = @prevLine.n for s in calls when not s.line?

        if @takeSnapshot(n, @stash._context.proc)
            throw "too many frames" if @currentFrameNumber >= @maxFrames

            newFrame              = Vamonos.clone(@stash)
            newFrame._nextLine    = { n, context: @stash._context }
            newFrame._prevLine    = @prevLine
            newFrame._frameNumber = ++@currentFrameNumber
            @frames.push(newFrame)
        
        @prevLine = { n, context: @stash._context }
        throw "too many lines" if ++@numCallsToLine > 10000

    takeSnapshot: (n, proc) ->
        return true if n is 0
        return n in @breakpoints[proc] if @breakpoints[proc]?.length > 0
        return @diff(@frames[@frames.length-1], @stash, @stash._watchVars) if @stash._watchVars?
        return false
        
    # this is somewhat hacky, comparing stringifications
    diff: (left, right, vars) ->
        tleft = {}
        tright = {}
        for v in vars
            tleft[v]  = left[v]
            tright[v] = right[v]
        return JSON.stringify(tleft) isnt JSON.stringify(tright)

    trigger: (event, options...) -> switch event
        when "runAlgorithm" then @runAlgorithm()
        when "editMode"     then @editMode()
        when "nextFrame"    then @nextFrame()
        when "prevFrame"    then @prevFrame()
        when "jumpFrame"    then @jumpFrame(options...)


    tellWidgets: (event, options...) ->
        for widget in @widgets
            widget.event(event, options...)

    ###
    #   Visualizer.runAlgorithm()
    #
    #   Initializes the frame and stash arrays, runs the algorithm, and
    #   activates widgets.
    ###
    runAlgorithm: ->
        return if @mode is "display"

        @frames             = []
        @currentFrameNumber = 0
        @prevLine           = 0
        @numCallsToLine     = 0

        @stash._initialize()
        @tellWidgets("editStop") if @mode is "edit"

        try
            # there's always a "before" & "after" snapshot
            @line(0)
            throw "no main function" unless @stash.main?
            @stash.main()
            @line(0)
        catch err
            switch err
                when "too many frames"
                    alert("Too many frames. You may have an infinite loop, or you may " +
                          "want to consider setting fewer breakpoints. " +
                          "Visualization has been truncated to the first " +
                          "#{@maxFrames} frames.")
                when "too many lines"
                    alert("Your algorithm has executed for over 10000 instructions. " +
                          "You may have an infinite loop. " +
                          "Visualization has been truncated.")
                else
                    throw err


        @currentFrameNumber = 0
        f._numFrames = @frames.length for f in @frames

        @mode = "display"
        @tellWidgets("displayStart")
        @nextFrame()


    editMode: ->
        return if @mode is "edit"
        @tellWidgets("displayStop") if @mode is "display"
        @mode = "edit"
        @tellWidgets("editStart")

    ###
    #   Frame controls - move frame and send message to widgets.
    #
    #   Frame numbers are 1-indexed.
    ###
    nextFrame: ->
        @goToFrame(@currentFrameNumber + 1, "next")

    prevFrame: ->
        @goToFrame(@currentFrameNumber - 1, "prev")

    jumpFrame: (n) ->
        @goToFrame(n, "jump")

    goToFrame: (n, type) ->
        return unless @mode is "display" and 1 <= n <= @frames.length
        @currentFrameNumber = n
        @tellWidgets("render", @frames[@currentFrameNumber-1], type)


Vamonos.export { Visualizer }
