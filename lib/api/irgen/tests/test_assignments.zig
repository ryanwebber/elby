const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const runner = @import("runner.zig");

test "assignment ir generation" {
    const expectedIR =
        \\S0 := int(5)
        \\S1 := int(3)
        \\S2 := int(2)
        \\S3 := S1 * S2
        \\S4 := int(1)
        \\S5 := int(0)
        \\S6 := S4 + S5
        \\S7 := S3 / S6
        \\S8 := S0 - S7
        \\L120 := S8
        \\S9 := int(5)
        \\S10 := int(3)
        \\S11 := S10 * L120
        \\S12 := int(1)
        \\S13 := int(0)
        \\S14 := S12 + S13
        \\S15 := S11 / S14
        \\S16 := S9 - S15
        \\L121 := S16
        \\
        ;

    try runner.expectIR(std.testing.allocator, expectedIR, &.{
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
                                                        .int = 2
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
            },
            &.{
                .assignment = &.{
                    .identifier = &.{
                        .name = "y"
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
                                                .identifier = &.{
                                                    .name = "x"
                                                },
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
            },
        }
    });
}
