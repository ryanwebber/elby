const std = @import("std");
const tokenizer = @import("tokenizer/tokenizer.zig");

pub fn hello() []const u8 {
    return "Hello world!";
}

test {
    std.testing.refAllDecls(@This());
}
