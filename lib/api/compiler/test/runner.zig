const std = @import("std");
const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;

const Error = error {
    ParseError
};

pub fn parse(allocator: *std.mem.Allocator, source: []const u8) !*ast.Program {
    const result_parse = try Parser.parse(allocator, source);
    switch (result_parse.result) {
        .ok => |program| {
            return program;
        },
        .fail => |errors| {
            defer { allocator.free(errors); }

            var buf: [256]u8 = undefined;

            std.debug.print("\n\n============================================================\n", .{});
            std.debug.print("Got parse failure with errors:\n", .{});
            for (errors) |err| {
                std.debug.print("  Syntax Error: {s}\n", .{ try err.format(&buf) });
            }
            std.debug.print("\n============================================================\n", .{});

            return Error.ParseError;
        }
    }
}

pub fn expectEqualAst(expected: *const ast.Program, actual: *const ast.Program) !void {
    const Utils = struct {
        fn expectEqualIdentifiers(lhs: *const ast.Identifier, rhs: *const ast.Identifier) !void {
            try std.testing.expectEqualStrings(lhs.name, rhs.name);
        }

        fn expectEqualNumberLiterals(lhs: *const ast.NumberLiteral, rhs: *const ast.NumberLiteral) !void {
            try std.testing.expectEqual(lhs.value, rhs.value);
        }

        fn expectEqualExpressions(lhs: *const ast.Expression, rhs: *const ast.Expression) !void {
            switch (lhs.*) {
                .number_literal => {
                    try std.testing.expectEqual(ast.Expression.number_literal, rhs.*);
                    try expectEqualNumberLiterals(&lhs.number_literal, &rhs.number_literal);
                },
            }
        }

        fn expectEqualDefinitions(lhs: *const ast.Definition, rhs: *const ast.Program) !void {
            try expectEqualIdentifiers(&lhs.identifier, &rhs.identifier);
            try expectEqualExpressions(&lhs.expression, &rhs.expression);
        }

        fn expectEqualProgram(lhs: *const ast.Program, rhs: *const ast.Program) !void {
            try expectEqualDefinitions(lhs, rhs);
        }
    };

    try Utils.expectEqualProgram(expected, actual);
}
