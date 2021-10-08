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

pub fn StageResult(comptime ValueType: type) type {
    return union(enum) {
        ok: ValueType,
        syntaxError: []const SyntaxError,

        const Self = @This();

        fn erase(self: *const Self) StageResult(void) {
            switch (self.*) {
                .ok => {
                    return StageResult(void).ok;
                },
                .syntaxError => |errs| {
                    return StageResult(void) {
                        .syntaxError = errs,
                    };
                }
            }
        }
    };
}

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

        pub fn compile(self: *Self, module: *const Module) !StageResult(Scheme) {
            var allocator = &self.arena.allocator;
            var tokenizer = try Tokenizer.tokenize(allocator, module.source);
            const parser = parsing.ProgramParser;
            const parse = try parser.parse(&self.arena, &tokenizer.iterator());
            const program = switch (parse.result) {
                .fail => |errors| {
                    return StageResult(Scheme) {
                        .syntaxError = errors,
                    };
                },
                .ok => |program| program,
            };

            const typeRegistry = types.TypeRegistry.init(TargetType.config.types);
            const scheme = try ir.compileScheme(allocator, program, &typeRegistry, TargetType.config.externs);
            return StageResult(Scheme) {
                .ok = scheme,
            };
        }

        pub fn generate(self: *Self, scheme: *const Scheme, options: *TargetType.OptionsType) !StageResult(void) {
            var target = TargetType.init(self.context);
            defer { target.deinit(); }

            try target.generator.compileScheme(scheme, options);
            return StageResult(void).ok;
        }

        pub fn compileAndGenerate(self: *Self, module: *const Module, options: *TargetType.OptionsType) !StageResult(void) {
            var compilationResult = try self.compile(module);
            switch (compilationResult) {
                .ok => |*scheme| {
                    defer { scheme.deinit(); }
                    return try self.generate(scheme, options);
                },
                else => {}
            }

            return compilationResult.erase();
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
    const result = try pipeline.compileAndGenerate(&module, &options);
    switch (result) {
        .syntaxError => |errs| {
            return @import("testing/utils.zig").reportSyntaxErrors(errs);
        },
        else => {}
    }

    try std.testing.expectEqual(StageResult(void).ok, result);
}
