const std = @import("std");
const ast = @import("ast.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const SyntaxError = @import("syntax_error.zig").SyntaxError;
const Context = @import("combinators.zig").Context;
const ErrorAccumulator = @import("combinators.zig").ErrorAccumulator;

const grammarRoot = @import("grammar.zig").parser;

pub const Parse = struct {
    allocator: *std.heap.ArenaAllocator,
    result: Result,

    const Self = @This();
    const Result = union(enum) {
        ok: *ast.Program,
        fail: []const SyntaxError
    };

    pub fn init(allocator: *std.heap.ArenaAllocator, result: Result) Self {
        return .{
            .allocator = allocator,
            .result = result,
        };
    }
};

pub const Parser = struct {
    pub fn parse(arena: *std.heap.ArenaAllocator, source: []const u8) !Parse {
        const allocator = &arena.allocator;
        var tokenizer = try Tokenizer.tokenize(allocator, source);
        var iterator = tokenizer.iterator();
        var err_accumulator = ErrorAccumulator.init(allocator);

        defer {
            // Free all tokens, all we want is the ast
            tokenizer.deinit();

            // Free error accumulator, we either return an owned slice or ignore any errors
            err_accumulator.deinit();
        }

        var context: Context = .{
            .allocator = allocator,
            .iterator =  &iterator,
            .errorHandler = &err_accumulator
        };

        const parser_result = try grammarRoot.parse(&context);
        switch (parser_result) {
            .value => |value| {
                return Parse.init(arena, .{
                    .ok = value,
                });
            },
            else => {
                return Parse.init(arena, .{
                    .fail = err_accumulator.errors.toOwnedSlice(),
                });
            }
        }
    }
};
