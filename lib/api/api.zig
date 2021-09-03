const std = @import("std");
const scanner = @import("tokenizer/scanner.zig");
const tokenizer = @import("tokenizer/tokenizer.zig");

pub fn hello() []const u8 {
    return "Hello world!";
}

test {
    std.testing.refAllDecls(@This());
}
