const std = @import("std");
const ast = @import("../ast.zig");
const runner = @import("runner.zig");

const Parser = @import("../parser.zig").Parser;

test "parse mixed expression" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer { arena.deinit(); }

    const source = "fn main() { let x = 5 - 3 * 2 / (1); let a; }";
    var parse = try Parser.parse(&arena, source);

    try runner.expectEqualAst(allocator, &.{
        .identifier = &.{
            .name = "main",
        },
        .body = &.{
            &.{
                .definition = &.{
                    .identifier = &.{
                        .name = "x"
                    },
                    .expression = &.{
                        .binary_expression = .{
                            .lhs = &.{
                                .number_literal = &.{
                                    .value = 5
                                }
                            },
                            .op = ast.BinOp.op_minus,
                            .rhs = &.{
                                .binary_expression = .{
                                    .lhs = &.{
                                        .binary_expression = .{
                                            .lhs = &.{
                                                .number_literal = &.{
                                                    .value = 3
                                                }
                                            },
                                            .op = ast.BinOp.op_mul,
                                            .rhs = &.{
                                                .number_literal = &.{
                                                    .value = 2
                                                }
                                            }
                                        }
                                    },
                                    .op = ast.BinOp.op_div,
                                    .rhs = &.{
                                        .number_literal = &.{
                                            .value = 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }, &parse);
}
