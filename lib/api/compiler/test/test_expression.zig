const std = @import("std");
const ast = @import("../ast.zig");
const runner = @import("runner.zig");

test "parse number" {
    const allocator = std.testing.allocator;
    const source = "let x = 82";
    const program = try runner.parse(allocator, source);
    defer { allocator.destroy(program); }

    try runner.expectEqualAst(allocator, &.{
        .identifier = .{
            .name = "x"
        },
        .expression = .{
            .number_literal = .{
                .value = 82
            }
        }
    }, program);
}
