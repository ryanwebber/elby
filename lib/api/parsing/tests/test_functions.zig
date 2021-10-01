const std = @import("std");
const ast = @import("../ast.zig");
const utils = @import("../../testing/utils.zig");

const Parser = @import("../parser.zig").Parser;

test "parse mixed expression" {
    const source =
        \\fn main(a: b) -> c {
        \\  return a;
        \\}
        \\
        ;

    try utils.expectAst(std.testing.allocator, source, &.{
        .functions = &.{
            &.{
                .identifier = &.{
                    .name = "main",
                },
                .paramlist = &.{
                    .parameters = &.{
                        &.{
                            .identifier = &.{
                                .name = "a",
                            },
                            .type = &.{
                                .name = "b"
                            }
                        },
                    }
                },
                .returnType = &.{
                    .name = "c",
                },
                .body = &.{
                    &.{
                        .ret = &.{
                            .identifier = &.{
                                .name = "a"
                            }
                        },
                    },
                }
            }
        }
    });
}
