DoctorJS--
----------

DoctorJS-- is a simple static analysis tool for JavaScript, written in
CoffeeScript. It uses a cut-down version of Brian Hackett's type inference
algorithm, which is now part of the SpiderMonkey JavaScript engine (used in
Firefox). Its output is in Exuberant Ctags format.

DoctorJS-- is neither as precise nor as sophisticated (nor, right now, as
complete) as its big brother [DoctorJS](http://github.com/mozilla/doctorjs),
but on the plus side it's designed to be small, clean, and easy to hack.

To get started, run `make` and then use `bin/jsctags path/to/file.js`. Output
is written to a `tags` file in the current directory.

Have fun!

Prerequisites:

* node.js. Tested with version 0.4.11.
* `npm`. Tested with version 1.0.27.

Files of interest:

* `lib/dom.coffee` — You can add new functions and properties to the global
  object here.
* `lib/infer.coffee` — Defines the abstract interpreter that performs the type
  inference. You can add more interpreter functionality here.
* `lib/absvalue.coffee` — Contains documentation for the abstract value
  representation; you'll almost certainly want to read this if you're modifying
  DoctorJS--.

Major known issues:

* Source file locations aren't tracked. (This is a limitation in `parse-js`.)
* Prototype chains aren't handled.
* Array element types aren't tracked.
* Array expando properties won't be handled correctly.
* RegExp methods and expando properties won't be handled correctly.
* Dynamically-computed properties are handled in a bad way.
* `for in` is missing in the interpreter.

Thanks:

* Brian Hackett for the type inference algorithm.
* Marijn Haverbeke and Mihai Bazon for the `parse-js` module from UglifyJS.

