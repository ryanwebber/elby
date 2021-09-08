const std = @import("std");
const ast = @import("../ast.zig");
const Parse = @import("../parser.zig").Parse;

const Error = error {
    ParseError
};

pub fn expectEqualAst(allocator: *std.mem.Allocator, expected: *const ast.Program, parse: *const Parse) !void {

    switch (parse.result) {
        .fail => |errors| {
            var buf: [256]u8 = undefined;

            std.debug.print("\n\n============================================================\n", .{});
            std.debug.print("Got parse failure with errors:\n", .{});
            for (errors) |err| {
                std.debug.print("  Syntax Error: {s}\n", .{ try err.format(&buf) });
            }
            std.debug.print("\n============================================================\n", .{});

            return Error.ParseError;
        },
        .ok => |actual| {
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
    }
}
