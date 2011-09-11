#
# doctorjsmm/lib/ctags.coffee
#
# Copyright (c) 2011 Mozilla Foundation
#

fs = require 'fs'

METADATA = [
    [ "!_TAG_FILE_FORMAT", 2, "extended format" ]
    [ "!_TAG_FILE_SORTED", 1, "0=unsorted, 1=sorted, 2=foldcase" ]
    [ "!_TAG_PROGRAM_AUTHOR", "Mozilla Foundation", "http://mozilla.org/" ]
    [ "!_TAG_PROGRAM_NAME", "jsctagsmm", "" ]
    [ "!_TAG_PROGRAM_URL", "http://github.com/pcwalton/doctorjsmm",
       "GitHub repository" ]
    [ "!_TAG_PROGRAM_VERSION", "0.1", "" ]
]

class Tags
    constructor: ->
        @tags = []

    # (ObjectValue, ObjectValue[], string[])
    _add: (obj, path, pathNames) ->
        return if obj in path  # Cycle detection.

        for propName, value of obj.props
            @tags.push
                NAME: propName
                KIND: if value.types.function? then "f" else "v"
                REGEX: ""   # TODO
                namespace: pathNames.join "."
                type: value.toString()

            if value.types.object?
                subpath = path.slice(0).concat(obj)
                subpathNames = pathNames.slice(0).concat(propName)

                for subobj in value.types.object
                    @_add subobj, subpath, subpathNames

    add: (globalObject) ->
        @_add globalObject, [], []
        @tags.sort (a, b) -> a.NAME >= b.NAME

    regexify: (str) ->
        str = str.replace /\//g, (ch) -> "\\" + ch
        return "/" + str + "/"

    write: (fd) ->
        for meta in METADATA
            fs.writeSync fd, "#{meta[0]}\t#{meta[1]}\t#{@regexify meta[2]}\n",
                null

        for tag in @tags
            parts = [ tag.NAME, tag.KIND, @regexify tag.REGEX ]
            for key, val of tag
                continue if key.toUpperCase() == key
                parts.push key + ":" + val  # TODO: Escape metacharacters.

            fs.writeSync fd, parts.join("\t") + "\n", null

exports.Tags = Tags

