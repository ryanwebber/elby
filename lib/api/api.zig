const std = @import("std");

pub fn hello() []const u8 {
    return "Hello world!";
}

test {
    _ = @import("parsing/index.zig");
    _ = @import("irgen/index.zig");
    _ = @import("codegen/target.zig");
    _ = @import("pipeline.zig");
}
