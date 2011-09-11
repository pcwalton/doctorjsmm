#
# doctorjsmm/lib/infer.coffee
#
# Copyright (c) 2011 Mozilla Foundation
#

{ ObjectValue: ObjectValue, Value: Value } = require './absvalue.js'
util = require 'util'

assert = (cond, message) -> if !cond then throw new Error message


#
# Type constraints
#

class Constraint

# Simple subset constraint; corresponds to TypeConstraintSubset.
class SubsetConstraint extends Constraint
    constructor: (@target) ->

    newType: (type) ->
        @target.add type

# Object property lookup constraint; corresponds to TypeConstraintProp.
#
# Whenever a new object appears in the type set this constraint is monitoring,
# it creates a new subset relation such that the object property value flows
# into the target type set.
class GetPropConstraint extends Constraint
    constructor: (@target, @propName) ->

    newType: (type) ->
        return unless typeof(type) == 'object' && type[0] == 'object'
        obj = type[1]
        obj.props[@propName] ?= new Value [ [ 'undefined' ] ]
        obj.props[@propName].addConstraint new SubsetConstraint @target

# Object property setting constraint; corresponds to TypeConstraintProp.
#
# As above, whenever a new object appears in the type set this constraint is
# monitoring, it creates a new subset relation such that the source type set
# flows into the object property value.
class SetPropConstraint extends Constraint
    constructor: (@source, @propName) ->

    newType: (type) ->
        return unless typeof(type) == 'object' && type[0] == 'object'
        obj = type[1]
        obj.props[@propName] ?= new Value
        @source.addConstraint new SubsetConstraint obj.props[@propName]

# Call constraint.
#
# Whenever a new function appears in the type set this constraint is
# monitoring, it creates new subset relations such that (a) the argument types
# flow into the function's arguments; (b) the return type flows out of the
# function; and (c) the |this| binding flows into the function's |this|
# binding.
class CallConstraint extends Constraint
    constructor: (@args, @retValue, @thisBinding) ->

    newType: (type) ->
        return unless typeof(type) == 'object' && type[0] == 'function'
        { argValues: fnArgs, retValue: fnRet, thisValue: fnThis } = type[1]
        assert fnArgs?, "No function arguments!"
        assert fnRet?, "No return value!"

        # Propagate the formal parameters.
        for fnArg, i in fnArgs
            if @args[i]?
                @args[i].addConstraint new SubsetConstraint fnArg
            else
                fnArg.add 'undefined'

        # Propagate the return value.
        fnRet.addConstraint new SubsetConstraint @retValue

        # Propagate the |this| binding.
        @thisBinding.addConstraint new SubsetConstraint fnThis

# Plus (+) constraint.
#
# When |number| appears in the type set this constraint is monitoring, it adds
# |number| to the type set of the result. When anything else appears, it adds
# |string| to the type set of the result.
#
# TODO: This is an overapproximation; we can do better and only add |number| to
# the type set of the result if both LHS and RHS have |number|.
class PlusConstraint extends Constraint
    constructor: (@target) ->

    newType: (type) ->
        if typeof(type) == 'string' && type == 'number'
            @target.add 'number'
        else
            @target.add 'string'


#
# Scopes
#
# Each Interpreter instance maintains a pointer to the head of a singly linked
# list of scopes consisting of bindings from variables and parameters to
# abstract values.
#

class Scope
    constructor: (context, @parent, @bindings) ->
        @parent ?= null
        @bindings ?= {}

class FunctionScope extends Scope
    constructor: (context, @parent, @bindings, @node) ->
        super context, @parent, @bindings


#
# References
#

class Reference
    addConstraint: () ->
        throw new Error "Attempt to add a constraint to a reference; did " +
            "you mean to deref()?"


class LocalReference extends Reference
    constructor: (@base) ->
        assert !(@base instanceof Reference), "Base is a reference!"

    assign: (val) ->
        val.addConstraint new SubsetConstraint @base

    deref: () ->
        return @base

class PropReference extends Reference
    constructor: (@base, @propName) ->
        assert !(@base instanceof Reference), "Base is a reference!"

    assign: (val) ->
        @base.addConstraint new SetPropConstraint val, @propName

    deref: () ->
        val = new Value
        @base.addConstraint new GetPropConstraint val, @propName
        return val


#
# Abstract interpretation
#

class Interpreter

    # Creates a new interpreter. |context| is an |ExecContext| object. The
    # optional |scope| specifies the scope for interpretation; if omitted, it
    # defaults to the global scope.
    constructor: (@context, @scope) ->
        @scope ?= new Scope @context

    #
    # Fundamental abstract operations
    #

    assign: (dest, src) ->
        if dest instanceof Reference
            dest.assign src
        else
            @error "Assignment to non-Reference"

    # Performs a |call| or |new| operation.
    call: (node) ->
        callee = @interpret node[1]

        # Populate the |this| binding.
        if node[0] == 'new'
            # TODO: Set prototype correctly.
            emptyObject = new ObjectValue @context, {}
            thisBinding = new Value [ [ 'object', emptyObject ] ]
        else if callee instanceof PropReference
            thisBinding = callee.base
        else
            thisBinding = @context.global

        callee = callee.deref()
        args = @interpret(arg).deref() for arg in node[2]
        retValue = new Value

        callee.addConstraint new CallConstraint args, retValue, thisBinding
        return retValue

    flowsTo: (dest, src) ->
        src.addConstraint new SubsetConstraint dest

    lookup: (name) ->
        scope = @scope
        until !scope? or name of scope.bindings
            scope = scope.parent

        return new LocalReference scope.bindings[name] if scope?
        return new PropReference @context.global, name

    lookupThis: (name) ->
        scope = @scope
        until !scope? or scope instanceof FunctionScope
            scope = scope.parent
        return if scope? then scope.node.thisValue else @context.global


    #
    # AST utilities
    #

    findVars: (node, list) ->
        switch node[0]
            when 'var', 'const'
                console.log "found var"
                list.push pair[0] for pair in node[1]
            when 'function', 'defun' then return

            when 'block'
                if node[1]?
                    @findVars stmt, list for stmt in node[1]
            when 'conditional'
                @findVars(node[i], list) for i in [1..3]
            when 'do'
                @findVars node[1], list
                @findVars node[2], list
            when 'for'
                for i in [1..4]
                    @findVars(node[i], list) if node[i]?
            when 'for-in'
                @findVars node[1], list
                @findVars node[3], list
                @findVars node[4], list
            when 'if'
                @findVars node[1], list
                @findVars node[2], list
                @findVars node[3], list if node[3]?
            when 'return' then @findVars node[1], list if node[1]?
            when 'stat' then @findVars node[1], list
            when 'switch'
                @findVars node[1], list
                for switchBlock in node[2]
                    @findVars switchBlock[0], list if switchBlock[0]?
                    @findVars switchBlock[1], list
            when 'throw' then @findVars node[1], list
            when 'try'
                @findVars node[1], list
                @findVars node[2], list if node[2]?  # catch
                @findVars node[3], list if node[3]?  # finally
            when 'while'
                @findVars node[1], list
                @findVars node[2], list
            when 'with'
                @findVars node[1], list
                @findVars node[2], list


    #
    # Interpretation of AST nodes
    #

    interpArray: (node) ->
        for elem in node[1]
            elem = @interpret(elem).deref()
            # TODO
        return new Value [ 'array' ]    # FIXME

    interpAssign: (node) ->
        rhs = @interpret(node[3]).deref()
        @assign @interpret(node[2]), rhs
        return rhs

    interpBinary: (node) ->
        lhs = @interpret(node[2]).deref()
        rhs = @interpret(node[3]).deref()
        result = new Value
        switch node[1]
            when '+'
                lhs.addConstraint new PlusConstraint result
                rhs.addConstraint new PlusConstraint result
            when '-', '*', '/', '%', '<<', '>>', '>>>'
                result.add 'number'
            when '<', '>', '<=', '>=', 'instanceof', 'in', '==', '!=', '===', \
                    '!=='
                result.add 'boolean'
            when '&&', '||'
                lhs.addConstraint new SubsetConstraint result
                rhs.addConstraint new SubsetConstraint result
        return result

    interpBlock: (node) ->
        if node[1]?
            @interpret stmt for stmt in node[1]

    interpBreak: (node) ->
        # no-op

    interpCall: (node) ->
        return @call node

    interpConditional: (node) ->
        @interpret node[1]
        thenValue = @interpret(node[2]).deref()
        elseValue = @interpret(node[3]).deref()

        resultValue = new Value
        thenValue.addConstraint new SubsetConstraint resultValue
        elseValue.addConstraint new SubsetConstraint resultValue
        return resultValue

    interpContinue: (node) ->
        # no-op

    interpDefun: (node) ->
        func = @interpFunction [ null, null, node[2], node[3] ]
        @assign @lookup(node[1]), func

    interpDo: (node) ->
        @interpret node[1]
        @interpret node[2]

    interpDot: (node) ->
        lhs = @interpret(node[1]).deref()
        return new PropReference lhs, node[2]

    interpFor: (node) ->
        for i in [1..4]
            @interpret node[i] if node[i]?

    interpFunction: (node) ->
        [ args, body ] = [ node[2], node[3] ]

        # Make bindings for the parameters, the return value, and |this|.
        bindings = {}
        node.argValues = []
        for arg, i in args
            bindings[arg] = node.argValues[i] = new Value
        node.retValue = new Value [ 'undefined' ]
        node.thisValue = new Value

        # Make bindings for any locals declared with |var|.
        locals = []
        @findVars stmt, locals for stmt in body
        for local in locals
            bindings[local] = new Value [ 'undefined' ]

        newScope = new FunctionScope @context, @scope, bindings, node
        sub = new Interpreter @context, newScope
        sub.interpret stmt for stmt in body

        return new Value [ [ 'function', node ] ]

    interpIf: (node) ->
        @interpret node[1]
        @interpret node[2]
        @interpret node[3] if node[3]?

    interpName: (node) ->
        return @lookupThis() if node[1] == 'this'
        return @lookup node[1]

    interpNew: (node) ->
        return @call node

    interpNum: (node) ->
        return new Value [ 'number' ], node

    interpObject: (node) ->
        props = {}
        for kvp in node[1]
            props[kvp[0]] = @interpret(kvp[1]).deref()
        obj = new ObjectValue @context, props
        return new Value [ [ 'object', obj ] ]

    interpRegexp: (node) ->
        return new Value [ [ 'RegExp' ] ]   # TODO: Should be an object.

    interpReturn: (node) ->
        scope = @scope
        until !scope? or scope instanceof FunctionScope
            scope = scope.parent

        unless scope?
            @error "|return| outside function scope"
            return

        retValue = scope.node.retValue
        if node[1]?
            @flowsTo retValue, @interpret(node[1]).deref()
        else
            retValue.add 'undefined'

    interpString: (node) ->
        return new Value [ 'string' ], node

    interpStat: (node) ->
        @interpret node[1]

    interpSub: (node) ->
        lhs = @interpret(node[1]).deref()
        rhs = @interpret node[2]
        return new PropReference lhs, '<dynamic>'   # FIXME

    interpThrow: (node) ->
        @interpret node[1]

    interpToplevel: (node) ->
        @interpret expr for expr in node[1]

    interpUnaryPostfix: (node) ->
        operand = @interpret node[2]
        result = new Value [ 'number' ]
        @assign operand, new Value [ 'number' ]

    interpUnaryPrefix: (node) ->
        operand = @interpret node[2]
        result = new Value
        switch node[1]
            when 'delete', 'void' then result.add 'undefined'
            when 'typeof' then result.add 'string'
            when '++', '--'
                @assign operand, new Value [ 'number' ]
                result.add 'number'
            when '+', '-', '~' then result.add 'number'
            when '!' then result.add 'boolean'
        return result

    interpVar: (node) ->
        for pair in node[1]
            @assign @lookup(pair[0]), @interpret(pair[1]).deref() if pair[1]?

    interpWhile: (node) ->
        @interpret node[1]
        @interpret node[2]


    # The entry point for interpretation.
    interpret: (node) ->
        op = node[0]
        op = op[0].toUpperCase() + op.slice 1
        op = op.replace /-[a-z]/g, (s) -> s[1].toUpperCase()
        return this["interp" + op] node


exports.Interpreter = Interpreter

