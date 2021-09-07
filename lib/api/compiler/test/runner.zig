const std = @import("std");
const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;

const Error = error {
    ParseError
};

pub fn expectAst(allocator: *std.mem.Allocator, source: []const u8) !*ast.Program {
    const parse = try Parser.parse(allocator, source);
    switch (parse.result) {
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
