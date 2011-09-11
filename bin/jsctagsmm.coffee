#
# doctorjsmm/bin/jsctagsmm.coffee
#
# Copyright (c) 2011 Mozilla Foundation
#

[ fs, util ] = [ require('fs'), require('util') ]
optimist = require 'optimist'
parse_js = require '../lib/parse-js.js'
ctags = require '../lib/ctags.js'
dom = require '../lib/dom.js'
infer = require '../lib/infer.js'

optimist.usage "usage: $0 [options] file.js"
optimist.describe "dump", "dump the AST (for debugging)"
optimist.boolean "dump"
argv = optimist.argv

unless argv._[0]?
	optimist.showHelp()
	process.exit 1

src = fs.readFileSync(argv._[0]).toString()
ast = parse_js.parse src
if argv.dump
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

