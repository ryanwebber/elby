const std = @import("std");
const scanner = @import("tokenizer/scanner.zig");
const tokenizer = @import("tokenizer/tokenizer.zig");
const parser = @import("parser/parser.zig");
const parsers = @import("parser/types.zig").Parsers;

pub fn hello() []const u8 {
    return "Hello world!";
}

test {
    std.testing.refAllDecls(@This());
}
