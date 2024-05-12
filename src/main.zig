const std = @import("std");
const guile = @cImport({
    @cInclude("guile/3.0/libguile.h");
});

pub fn main() !void {
    guile.scm_init_guile();
    _ = guile.scm_c_primitive_load("script.scm");
    var func = guile.scm_variable_ref(guile.scm_c_lookup("simple-func"));
    var func2 = guile.scm_variable_ref(guile.scm_c_lookup("quick-test"));

    _ = guile.scm_call_0(func);
    _ = guile.scm_call_0(func2);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
