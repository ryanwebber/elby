const std = @import("std");

pub fn hello() []const u8 {
    return "Hello world!";
}

test {
    _ = @import("compiler/index.zig");
}
