#_require ../common.coffee

class Queue

    constructor: ({container, @varName}) ->
        @$container = Common.jqueryify(container)

    event: (event, options...) -> switch event

        when "setup"
            [@stash, visualizer] = options

        when "editStop"
            @stash[@varName] = null


Common.VamonosExport { Widget: { Queue } }