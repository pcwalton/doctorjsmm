f = function() {
    x = this;
}

var obj = { f: f };
f();
obj.f();

