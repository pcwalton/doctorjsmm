#
# doctorjsmm/lib/dom.coffee
#
# Copyright (c) 2011 Mozilla Foundation
#

{ ExecContext: ExecContext, Value: Value } = require './absvalue.js'

#
# An execution context that simulates the DOM.
#

class DOMExecContext extends ExecContext
    constructor: ->
        super()
        @globalObject.props.window = new Value [ [ 'object', @globalObject ] ]

exports.DOMExecContext = DOMExecContext

