#
# doctorjsmm/lib/absvalue.coffee
#
# Copyright (c) 2011 Mozilla Foundation
#

#
# An abstract object. Corresponds to a TypeObject in SpiderMonkey TI.
#

class ObjectValue
    constructor: (context, @props, @proto) ->
        @props ?= {}
        @proto = context.objectProto if @proto is undefined

    toString: (path) ->
        path ?= []  # For cycle detection.
        return "(cycle)" if this in path
        path = path.slice(0)
        path.push this

        strs = []
        for propName, value of @props
            strs.push propName + ": " + value.toString path
        return "{ " + strs.join(", ") + " }"


#
# An abstract value. Corresponds to a TypeSet in SpiderMonkey TI.
#

class Value
    # Creates a new abstract value. |types| is a list of types; see the
    # comments for |add| below for how these are specified. |astNode| is
    # optional and represents the AST node that this value originates from.
    constructor: (types, @astNode) ->
        @constraints = []
        @types = {}
        if types?
            @add type for type in types

    _updateConstraints: (type) ->
        constraint.newType type for constraint in @constraints

    # Adds a type to the set for this abstract value.
    #
    # * Primitive types are given as a string; e.g. 'number', 'string',
    #   'boolean', 'null', 'undefined'.
    #
    # * Function types are given as [ 'function', node ]. If the function is
    #   actually present in the source text (i.e. not an external reference or
    #   native function), the |node| is an AST node. The node is expected to
    #   have these properties:
    #   - |argValues|, an array of Values representing the function arguments;
    #   - |retValue|, a Value representing the function return type;
    #   - |thisValue|, a Value representing the |this| binding in the
    #     function.
    #
    # * Object types are given as [ 'function', ObjectValue ].
    add: (type) ->
        if typeof(type) == 'string'
            modified = !(type of @types)
            @types[type] = true
        else if type[0] == 'function'
            @types.function ?= []

            # Check to see whether we already have the function in this type
            # set.
            modified = !(type[1] in @types.function)

            @types.function.push type[1] if modified
        else if type[0] == 'object'
            @types.object ?= []

            # Check to see whether we already have the object in this type set.
            modified = !(type[1] in @types.object)

            @types.object.push type[1] if modified    

        @_updateConstraints type if modified

    addConstraint: (constraint) ->
        return if constraint in @constraints
        constraint.newType type for type in @getTypes()
        @constraints.push constraint

    # When the interpreter expects a Value (as opposed to a Reference), it
    # calls deref(). In this case, we simply return ourselves.
    deref: () ->
        return this

    # Returns the types that this value can take on as a list.
    getTypes: () ->
        list = []
        for kind, subkinds of @types
            if subkinds == true     # Primitive type.
                list.push kind
            else                    # Nonprimitive type.
                list.push [ kind, subkind ] for subkind in subkinds
        return list

    toString: (path) ->
        strs = []
        for kind, subkinds of @types
            if subkinds == true         # Primitive type.
                strs.push kind
            else if kind == 'function'
                for node in subkinds
                    args = arg.toString path for arg in node.argValues
                    args = args.join ", "
                    retValue = node.retValue.toString path
                    strs.push retValue + " function(" + args + ")"
            else if kind == 'object'
                for obj in subkinds
                    strs.push obj.toString path

        return "unknown" if !strs.length
        strs.sort()
        return strs.join " | "


#
# Execution contexts.
#
# The execution context models the JavaScript environment in which the
# script executes. The default execution context is devoid of any properties.
# Usually you will want to use a subclass (e.g. DOMExecContext) which defines
# more properties.
#

class ExecContext
    constructor: ->
        @objectProtoObject = new ObjectValue this, {}, null
        @objectProto = new Value [ [ 'object', @objectProtoObject ] ]
        @globalObject = new ObjectValue this
        @global = new Value [ [ 'object', @globalObject ] ]


exports.ExecContext = ExecContext
exports.ObjectValue = ObjectValue
exports.Value = Value

