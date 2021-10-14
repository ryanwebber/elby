const std = @import("std");
const ast = @import("../ast.zig");
const utils = @import("../../testing/utils.zig");

const Parser = @import("../parser.zig").Parser;

test "parse mixed expression" {
    const source = "fn main() { let x: i = 5 - 3 * 2.15 / (0x1 + 0); }";
    try utils.expectAst(std.testing.allocator, source, &.{
        .functions = &.{
            &.{
                .identifier = &.{
                    .name = "main",
                },
                .paramlist = &.{
                    .parameters = &.{}
                },
                .returnType = null,
                .body = &.{
                    &.{
                        .definition = &.{
                            .identifier = &.{
                                .name = "x"
                            },
                            .type = &.{
                                .identifier = &.{
                                    .name = "i"
                                },
                            },
                            .expression = &.{
                                .binary_expression = &.{
                                    .lhs = &.{
                                        .number_literal = &.{
                                            .value = .{
                                                .int = 5
                                            }
                                        }
                                    },
                                    .op = ast.BinOp.op_minus,
                                    .rhs = &.{
                                        .binary_expression = &.{
                                            .lhs = &.{
                                                .binary_expression = &.{
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
                                                .binary_expression = &.{
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
            }
        }
    });
}

test "parse unary expression" {
    const source = "fn main() { let x: i = -a; }";
    try utils.expectAst(std.testing.allocator, source, &.{
        .functions = &.{
            &.{
                .identifier = &.{
                    .name = "main",
                },
                .paramlist = &.{
                    .parameters = &.{}
                },
                .returnType = null,
                .body = &.{
                    &.{
                        .definition = &.{
                            .identifier = &.{
                                .name = "x"
                            },
                            .type = &.{
                                .identifier = &.{
                                    .name = "i"
                                },
                            },
                            .expression = &.{
                                .unary_expression = &.{
                                    .op = ast.UnaryOp.op_negate,
                                    .rhs = &.{
                                        .identifier = &.{
                                            .name = "a"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    });
}
