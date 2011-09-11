id = function(x) { return x; }
f = function() {
    id(x);
    var x = 3;
    id(x);
}
f()

