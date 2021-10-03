const std = @import("std");
const errors = @import("error.zig");
const types = @import("types.zig");
const targets = @import("codegen/target.zig");
const parsing = @import("parsing/parser.zig");
const ir = @import("irgen/compiler.zig");
const Module = @import("module.zig").Module;
const SyntaxError = @import("parsing/syntax_error.zig").SyntaxError;
const Tokenizer = @import("parsing/tokenizer.zig").Tokenizer;

const SystemError = errors.SystemError;

const PipelineResult = union(enum) {
    success,
    syntaxError: []const SyntaxError,
};

const ModuleResolver = struct {
    arena: *std.heap.ArenaAllocator,

    const Self = @This();
    const Error = error {
        ModuleNotFound,
    } | SystemError;

    pub fn resolve(_: *Self, name: []const u8) !Error {
        return errors.fatal("Module resolver not implemented (resolving '{s}')", .{ name });
    }
};

pub fn compileSource(comptime Target: type, arena: *std.heap.ArenaAllocator, module: *const Module) !PipelineResult {
    var allocator = &arena.allocator;
    var context = targets.Context.init(allocator);
    var target = try Target.init(&context);
    defer { target.deinit(); }

    var tokenizer = try Tokenizer.tokenize(allocator, module.source);
    const parser = parsing.ProgramParser;
    const parse = try parser.parse(arena, &tokenizer.iterator());
    const program = switch (parse.result) {
        .fail => |errors| {
            return PipelineResult {
                .syntaxError = errors,
            };
        },
        .ok => |program| program,
    };

    const typeRegistry = types.TypeRegistry.init(Target.types);
    var scheme = try ir.compileScheme(allocator, program, &typeRegistry);
    defer { scheme.deinit(); }

    try target.compileScheme(&scheme);
    return PipelineResult.success;
}

// TODO: Put this test somewhere else
test {

    const source =
        \\fn main() {
        \\    let x: uint8_t = 5 - 3 * 2 / (0x1 + 0);
        \\    let y: uint8_t = x * x;
        \\    let z: uint8_t = 0;
        \\    if (x == y) {
        \\      foo(abc: 9, def: x + y);
        \\    } else if (x == z) {
        \\      foo(abc: 9, def: x + z);
        \\    } else {
        \\      foo(abc: 9, def: 0);
        \\    }
        \\
        \\    let q: uint8_t = 5;
        \\}
        \\
        \\fn foo(abc: uint8_t, def: uint8_t) {
        \\    let sum: uint8_t = abc + def;
        \\    bar(a: sum + sum, b: def);
        \\}
        \\
        \\fn bar(a: uint8_t, b: uint8_t) {
        \\    let c: uint8_t = a * b;
        \\}
        ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer { arena.deinit(); }

    const module = Module {
        .identifier = .anonymous,
        .source = source
    };

    const Target = @import("codegen/targets/c99/target.zig").Target;
    const result = try compileSource(Target, &arena, &module);
    switch (result) {
        .syntaxError => |errs| {
            return @import("testing/utils.zig").reportSyntaxErrors(errs);
        },
        else => {}
    }

    try std.testing.expectEqual(PipelineResult.success, result);

    const expectedGeneration =
        \\
        ;

    var writtenData = @import("codegen/target.zig").temp;
    _ = writtenData;
    _ = expectedGeneration;
    // try std.testing.expectEqualStrings(expectedGeneration, &writtenData);
}
