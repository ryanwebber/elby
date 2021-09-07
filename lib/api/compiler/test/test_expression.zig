const std = @import("std");
const ast = @import("../ast.zig");
const runner = @import("runner.zig");

test "parse number" {
    const allocator = std.testing.allocator;
    const source = "82";
    const program = try runner.expectAst(allocator, source);
    defer { allocator.destroy(program); }
    _ = program;
}
