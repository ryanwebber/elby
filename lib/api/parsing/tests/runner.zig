const std = @import("std");
const ast = @import("../ast.zig");
const Parse = @import("../parser.zig").Parse;
const Parser = @import("../parser.zig").Parser;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const Error = error {
    ParseError
};

pub fn expectAst(allocator: *std.mem.Allocator, source: []const u8, expected: *const ast.Program) !void {
    var tokenizer = try Tokenizer.tokenize(allocator, source);
    defer { tokenizer.deinit(); }

    try std.testing.expect(tokenizer.err == null);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer { arena.deinit(); }

    var parse = try Parser.parse(&arena, &tokenizer.iterator());

    switch (parse.result) {
        .fail => |errors| {
            var buf: [256]u8 = undefined;
            var writer = std.io.fixedBufferStream(&buf);

            std.debug.print("\n\n============================================================\n", .{});
            std.debug.print("Got parse failure with errors:\n", .{});
            for (errors) |err| {
                try err.format(writer.writer());
                std.debug.print("  Syntax Error: {s}\n", .{ writer.getWritten() });
            }
            std.debug.print("============================================================\n\n", .{});

            try std.testing.expectEqual(std.meta.TagType(@TypeOf(parse.result)).ok, parse.result);
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
