const std = @import("std");
const SyntaxError = @import("parsing/syntax_error.zig").SyntaxError;

pub fn reportSyntaxErrors(errors: []const SyntaxError, writer: anytype) !void {

    try writer.print("============================================================\n", .{});
    try writer.print("Got errors:\n", .{});

    for (errors) |err| {
        try writer.print("  Syntax Error: ", .{});
        try err.format(writer);
        try writer.print("\n", .{});
    }

    try writer.print("============================================================\n", .{});
}
