const std = @import("std");
const ast = @import("ast.zig");
const TokenIterator = @import("tokenizer.zig").TokenIterator;
const SyntaxError = @import("syntax_error.zig").SyntaxError;
const Context = @import("combinators.zig").Context;
const ErrorAccumulator = @import("combinators.zig").ErrorAccumulator;
const Result = @import("../result.zig").Result;

const grammarRoot = @import("grammar.zig").parser;

pub const Parse = struct {
    allocator: *std.heap.ArenaAllocator,
    result: ResultType,

    const Self = @This();
    const ResultType = Result(*ast.Program, []const SyntaxError);

    pub fn init(allocator: *std.heap.ArenaAllocator, result: ResultType) Self {
        return .{
            .allocator = allocator,
            .result = result,
        };
    }
};

pub const Parser = struct {
    pub fn parse(arena: *std.heap.ArenaAllocator, iterator: *TokenIterator) !Parse {
        const allocator = &arena.allocator;

        var err_accumulator = ErrorAccumulator.init(allocator);
        defer {
            // Free error accumulator, we either return an owned slice or ignore any errors
            err_accumulator.deinit();
        }

        var context: Context = .{
            .allocator = allocator,
            .iterator =  iterator,
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
