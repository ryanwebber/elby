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

test "parse left-associative term expression" {
    const allocator = std.testing.allocator;
    const source = "let x = 2 - 3 + 1";
    var parse = try Parser.parse(allocator, source);
    defer { parse.deinit(); }

    try runner.expectEqualAst(allocator, &.{
        .identifier = &.{
            .name = "x"
        },
        .expression = &.{
            .binary_expression = .{
                .lhs = &.{
                    .binary_expression = .{
                        .lhs = &.{
                            .number_literal = &.{
                                .value = 2
                            }
                        },
                        .op = ast.BinOp.op_minus,
                        .rhs = &.{
                            .number_literal = &.{
                                .value = 3
                            }
                        }
                    }
                },
                .op = ast.BinOp.op_plus,
                .rhs = &.{
                    .number_literal = &.{
                        .value = 1
                    }
                }
            }
        }
    }, &parse);
}
