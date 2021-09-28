const std = @import("std");
const ast = @import("../parsing/ast.zig");
const types = @import("../types.zig");
const grammar = @import("../parsing/grammar.zig");
const compiler = @import("../irgen/compiler.zig");
const Parser = @import("../parsing/combinators.zig").Parser;
const ParseBuilder = @import("../parsing/parser.zig").ParseBuilder;
const Tokenizer = @import("../parsing/tokenizer.zig").Tokenizer;
const Context = @import("../irgen/compiler.zig").Context;
const Instruction = @import("../irgen/instruction.zig").Instruction;
const FunctionPrototype = @import("../irgen/function.zig").FunctionPrototype;
const Error = error {
    ParseError
};

const testTypes: []const types.Type = &.{
    types.Types.void,
};

pub fn toOwnedAst(comptime Value: type, comptime parser: Parser(Value), arena: *std.heap.ArenaAllocator, source: []const u8) !Value {
    var tokenizer = try Tokenizer.tokenize(&arena.allocator, source);

    try std.testing.expect(tokenizer.err == null);

    var parse = try ParseBuilder(Value, parser).parse(arena, &tokenizer.iterator());

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
            unreachable;
        },
        .ok => |actual| {
            return actual;
        }
    }
}

pub fn expectAst(allocator: *std.mem.Allocator, source: []const u8, expected: *const ast.Program) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer { arena.deinit(); }

    const actual = try toOwnedAst(*ast.Program, grammar.parser, &arena, source);

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

pub fn expectIR(allocator: *std.mem.Allocator, source: []const u8, expectedIR: []const u8) !void {

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer { arena.deinit(); }

    const function = try toOwnedAst(*ast.Function, grammar.Function.parser, &arena, source);
    const prototype = try FunctionPrototype.init(allocator, function);
    defer { prototype.deinit(); }

    const typeRegistry = types.TypeRegistry.init(testTypes);
    defer { typeRegistry.deinit(); }

    var context = try Context.init(allocator, &prototype, &typeRegistry);
    defer { context.deinit(); }

    var destList = std.ArrayList(Instruction).init(allocator);
    defer { destList.deinit(); }

    try compiler.compileFunction(function, &destList, &context);

    var actualIR = std.ArrayList(u8).init(std.testing.allocator);
    var stream = actualIR.writer();
    defer { actualIR.deinit(); }

    for (destList.items) |*instr| {
        try instr.format(&stream);
        try stream.print("\n", .{});
    }

    try std.testing.expectEqualStrings(expectedIR, actualIR.items);
}
