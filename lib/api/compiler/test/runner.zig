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

pub fn expectEqualAst(allocator: *std.mem.Allocator, expected: *const ast.Program, actual: *const ast.Program) !void {

    var expected_json_container = std.ArrayList(u8).init(allocator);
    defer { expected_json_container.deinit(); }

    var actual_json_container = std.ArrayList(u8).init(allocator);
    defer { actual_json_container.deinit(); }

    const jsonOptions: std.json.StringifyOptions = .{
        .whitespace = .{
        }
    };

    // pretty-printed string equality checks are really easy to read
    try std.json.stringify(expected, jsonOptions, expected_json_container.writer());
    try std.json.stringify(actual, jsonOptions, actual_json_container.writer());

    try std.testing.expectEqualStrings(expected_json_container.items, actual_json_container.items);
}
