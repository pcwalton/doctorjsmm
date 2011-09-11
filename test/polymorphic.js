foo = { f: function() { return 3; } }
bar = { f: function() { return "Hello world!"; } }
g = function(obj) {
    return obj.f();
}
g(foo);
g(bar);

