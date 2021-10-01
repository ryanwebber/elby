const std = @import("std");
const ast = @import("../parsing/ast.zig");
const types = @import("../types.zig");
const grammar = @import("../parsing/grammar.zig");
const compiler = @import("../irgen/compiler.zig");
const interpreter = @import("../irgen/interpreter/interpreter.zig");
const Parser = @import("../parsing/combinators.zig").Parser;
const ParseBuilder = @import("../parsing/parser.zig").ParseBuilder;
const Tokenizer = @import("../parsing/tokenizer.zig").Tokenizer;
const Context = @import("../irgen/compiler.zig").Context;
const Instruction = @import("../irgen/instruction.zig").Instruction;
const FunctionPrototype = @import("../irgen/function.zig").FunctionPrototype;
const PrototypeRegistry = @import("../irgen/function.zig").PrototypeRegistry;
const SyntaxError = @import("../parsing/syntax_error.zig").SyntaxError;
const Error = error {
    ParseError, FunctionNotFound
};

const testTypes: []const types.Type = &.{
    types.Types.void,
    .{
        .name = "int",
        .value = .{
            .numeric = .{
                .type = .int,
                .size = 1,
            }
        }
    },
};

pub fn toProgramAst(arena: *std.heap.ArenaAllocator, source: []const u8) !*ast.Program {
    return toOwnedAst(*ast.Program, grammar.parser, arena, source);
}

pub fn reportSyntaxErrors(errors: []const SyntaxError) anyerror {

    var buf: [256]u8 = undefined;
    var writer = std.io.fixedBufferStream(&buf);

    std.debug.print("\n\n============================================================\n", .{});
    std.debug.print("Got parse failure with errors:\n", .{});

    for (errors) |err| {
        try err.format(writer.writer());
        std.debug.print("  Syntax Error: {s}\n", .{ writer.getWritten() });
        writer.reset();
    }

    std.debug.print("============================================================\n\n", .{});
    try std.testing.expect(false);
    unreachable;
}

pub fn toOwnedAst(comptime Value: type, comptime parser: Parser(Value), arena: *std.heap.ArenaAllocator, source: []const u8) !Value {
    var tokenizer = try Tokenizer.tokenize(&arena.allocator, source);

    if (tokenizer.err) |err| {
        return reportSyntaxErrors(&.{ err });
    }

    var parse = try ParseBuilder(Value, parser).parse(arena, &tokenizer.iterator());

    switch (parse.result) {
        .fail => |errors| {
            return reportSyntaxErrors(errors);
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

pub fn evaluateIR(allocator: *std.mem.Allocator, source: []const u8) !interpreter.IntType {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer { arena.deinit(); }

    const program = try toProgramAst(&arena, source);

    const typeRegistry = types.TypeRegistry.init(interpreter.SimpleInterpreter.supportedTypes);
    defer { typeRegistry.deinit(); }

    var scheme = try compiler.compileScheme(allocator, program, &typeRegistry);
    defer { scheme.deinit(); }

    var interpreterInstance = try interpreter.SimpleInterpreter.init(allocator, &scheme);
    defer { interpreterInstance.deinit(); }

    return try interpreterInstance.evaluate();
}

pub fn expectIR(allocator: *std.mem.Allocator, source: []const u8, functionID: []const u8, expectedIR: []const u8) !void {

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer { arena.deinit(); }

    const program = try toProgramAst(&arena, source);


    const typeRegistry = types.TypeRegistry.init(testTypes);
    defer { typeRegistry.deinit(); }

    var scheme = try compiler.compileScheme(allocator, program, &typeRegistry);
    defer { scheme.deinit(); }

    const targetFunction = scheme.functions.mapping.get(functionID) orelse {
        return Error.FunctionNotFound;
    };

    var actualIR = std.ArrayList(u8).init(std.testing.allocator);
    var stream = actualIR.writer();
    defer { actualIR.deinit(); }

    for (targetFunction.body.instructions) |*instr| {
        try instr.format(&stream);
        try stream.print("\n", .{});
    }

    try std.testing.expectEqualStrings(expectedIR, actualIR.items);
}
