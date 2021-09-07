const std = @import("std");
const ast = @import("ast.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const SyntaxError = @import("syntax_error.zig").SyntaxError;
const Context = @import("combinators.zig").Context;
const ErrorAccumulator = @import("combinators.zig").ErrorAccumulator;

const parseProgram = @import("grammar.zig").parser;

pub fn Parse(comptime AST: type) type {

    const Result = union(enum) {
        ok: AST,
        fail: []const SyntaxError
    };

    return struct {
        allocator: *std.mem.Allocator,
        result: Result,

        const Self = @This();

        pub fn init(allocator: *std.mem.Allocator, result: Result) Self {
            return .{
                .allocator = allocator,
                .result = result,
            };
        }

        pub fn deinit(_: *Self) void {
            // TODO
        }
    };
}

pub const Parser = struct {
    pub fn parse(allocator: *std.mem.Allocator, source: []const u8) !Parse(*ast.Program) {
        var tokenizer = try Tokenizer.tokenize(allocator, source);
        var iterator = tokenizer.iterator();
        var err_accumulator = ErrorAccumulator.init(allocator);

        defer {
            // Free all tokens, all we want is the ast
            tokenizer.deinit();

            // Free error accumulator, we either empty it or drop errors
            err_accumulator.deinit();
        }

        var context: Context = .{
            .allocator = allocator,
            .iterator =  &iterator,
            .errorHandler = &err_accumulator
        };

        const parser_result = try parseProgram(&context);
        switch (parser_result) {
            .value => |value| {
                var ast_root = try allocator.create(ast.Program);
                ast_root.* = value;

                return Parse(*ast.Program).init(allocator, .{
                    .ok = ast_root,
                });
            },
            else => {
                return Parse(*ast.Program).init(allocator, .{
                    .fail = err_accumulator.errors.toOwnedSlice(),
                });
            }
        }
    }
};
