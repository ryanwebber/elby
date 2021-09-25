const std = @import("std");
const ast = @import("../ast.zig");
const utils = @import("../../testing/utils.zig");

const Parser = @import("../parser.zig").Parser;

test "parse mixed expression" {
    const source = "fn main() { let x = 5 - 3 * 2.15 / (0x1 + 0); }";
    try utils.expectAst(std.testing.allocator, source, &.{
        .identifier = &.{
            .name = "main",
        },
        .body = &.{
            &.{
                .assignment = &.{
                    .identifier = &.{
                        .name = "x"
                    },
                    .expression = &.{
                        .binary_expression = .{
                            .lhs = &.{
                                .number_literal = &.{
                                    .value = .{
                                        .int = 5
                                    }
                                }
                            },
                            .op = ast.BinOp.op_minus,
                            .rhs = &.{
                                .binary_expression = .{
                                    .lhs = &.{
                                        .binary_expression = .{
                                            .lhs = &.{
                                                .number_literal = &.{
                                                    .value = .{
                                                        .int = 3
                                                    }
                                                }
                                            },
                                            .op = ast.BinOp.op_mul,
                                            .rhs = &.{
                                                .number_literal = &.{
                                                    .value = .{
                                                        .float = 2.15
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    .op = ast.BinOp.op_div,
                                    .rhs = &.{
                                        .binary_expression = .{
                                            .lhs = &.{
                                                .number_literal = &.{
                                                    .value = .{
                                                        .int = 1
                                                    }
                                                }
                                            },
                                            .op = ast.BinOp.op_plus,
                                            .rhs = &.{
                                                .number_literal = &.{
                                                    .value = .{
                                                        .int = 0
                                                    }
                                                }
                                            }
                                        }
                                    },
                                }
                            }
                        }
                    }
                }
            }
        }
    });
}
