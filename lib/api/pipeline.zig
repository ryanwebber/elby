const std = @import("std");
const errors = @import("error.zig");
const types = @import("types.zig");
const parsing = @import("parsing/parser.zig");
const ir = @import("irgen/compiler.zig");

const Module = @import("module.zig").Module;
const Scheme = @import("irgen/scheme.zig").Scheme;
const SyntaxError = @import("parsing/syntax_error.zig").SyntaxError;
const Tokenizer = @import("parsing/tokenizer.zig").Tokenizer;
const Context = @import("codegen/context.zig").Context;
const Target = @import("codegen/target.zig").Target;

const SystemError = errors.SystemError;

pub const PipelineResult = union(enum) {
    success,
    syntaxError: []const SyntaxError,
};

pub fn Pipeline(comptime TargetType: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        context: *Context,

        const Self = @This();

        pub fn init(allocator: *std.mem.Allocator, context: *Context) Self {
            return .{
                .arena = std.heap.ArenaAllocator.init(allocator),
                .context = context,
            };
        }

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }

        pub fn compileModule(self: *Self, module: *const Module, options: *TargetType.OptionsType) !PipelineResult {
            var target = TargetType.init(self.context);
            defer { target.deinit(); }

            var allocator = &self.arena.allocator;

            var tokenizer = try Tokenizer.tokenize(allocator, module.source);
            const parser = parsing.ProgramParser;
            const parse = try parser.parse(&self.arena, &tokenizer.iterator());
            const program = switch (parse.result) {
                .fail => |errors| {
                    return PipelineResult {
                        .syntaxError = errors,
                    };
                },
                .ok => |program| program,
            };

            const typeRegistry = types.TypeRegistry.init(TargetType.config.types);
            var scheme = try ir.compileScheme(allocator, program, &typeRegistry, TargetType.config.externs);
            defer { scheme.deinit(); }

            try target.generator.compileScheme(&scheme, options);
            return PipelineResult.success;
        }
    };
}

test {

    const source =
        \\fn main() {
        \\    let x: intish = 5 - 3 * 2 / (0x1 + 0);
        \\    let y: intish = x * x;
        \\    let z: intish = 0;
        \\    if (x == y) {
        \\      foo(abc: 9, def: x + y);
        \\    } else if (x == z) {
        \\      foo(abc: 9, def: x + z);
        \\    } else {
        \\      foo(abc: 9, def: 0);
        \\    }
        \\
        \\    let q: intish = 5;
        \\}
        \\
        \\fn foo(abc: intish, def: intish) {
        \\    let sum: intish = abc + def;
        \\    bar(a: sum + sum, b: def);
        \\}
        \\
        \\fn bar(a: intish, b: intish) {
        \\    let c: intish = a * b;
        \\}
        ;

    var allocator = std.testing.allocator;

    const module = Module {
        .identifier = .anonymous,
        .source = source
    };

    const TestTarget = Target(struct {
        const Self = @This();

        pub const Options = struct {};

        pub fn init(_: *Context) Self {
            return .{};
        }

        pub fn deinit(_: *Self) void {
        }

        pub fn compileScheme(_: *Self, _: *const Scheme, _: *const Options) !void {
        }
    }, &.{
        .name = "test",
        .types = &.{
            .{
                .name = "intish",
                .value = .{
                    .numeric = .{
                        .type = .int,
                        .size = 1
                    }
                }
            },
        },
        .externs = &.{},
    });

    var context = Context.init(allocator);
    defer { context.deinit(); }

    var pipeline = Pipeline(TestTarget).init(allocator, &context);
    defer { pipeline.deinit(); }

    var options: TestTarget.OptionsType = .{};
    const result = try pipeline.compileModule(&module, &options);
    switch (result) {
        .syntaxError => |errs| {
            return @import("testing/utils.zig").reportSyntaxErrors(errs);
        },
        else => {}
    }

    try std.testing.expectEqual(PipelineResult.success, result);
}
