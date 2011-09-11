[ fs, util ] = [ require('fs'), require('util') ]
optimist = require 'optimist'
parse_js = require '../lib/parse-js.js'
ctags = require '../lib/ctags.js'
dom = require '../lib/dom.js'
infer = require '../lib/infer.js'

argv = optimist.argv

# FIXME: Hopelessly Unix-specific.
src = fs.readFileSync(argv._[0]).toString()
ast = parse_js.parse src
console.warn line for line in util.inspect(ast, false, null).split("\n")

execContext = new dom.DOMExecContext
interp = new infer.Interpreter execContext
interp.interpret ast

tags = new ctags.Tags
tags.add execContext.globalObject
tagsFD = fs.openSync "tags", 'w'
try
    tags.write tagsFD
finally
    fs.closeSync tagsFD

