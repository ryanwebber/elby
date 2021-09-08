const std = @import("std");
const ast = @import("../ast.zig");
const runner = @import("runner.zig");

const Parser = @import("../parser.zig").Parser;

test "parse number" {
    const allocator = std.testing.allocator;
    const source = "let x = 82";
    var parse = try Parser.parse(allocator, source);
    defer { parse.deinit(); }

    try runner.expectEqualAst(allocator, &.{
        .identifier = &.{
            .name = "x"
        },
        .expression = &.{
            .number_literal = &.{
                .value = 82
            }
        }
    }, &parse);
}

test "parse identifier" {
    const allocator = std.testing.allocator;
    const source = "let x = y";
    var parse = try Parser.parse(allocator, source);
    defer { parse.deinit(); }

    try runner.expectEqualAst(allocator, &.{
        .identifier = &.{
            .name = "x"
        },
        .expression = &.{
            .identifier = &.{
                .name = "y"
            }
        }
    }, &parse);
}
