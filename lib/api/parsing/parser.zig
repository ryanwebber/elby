const std = @import("std");
const ast = @import("ast.zig");
const TokenIterator = @import("tokenizer.zig").TokenIterator;
const SyntaxError = @import("syntax_error.zig").SyntaxError;
const Context = @import("combinators.zig").Context;
const Parser = @import("combinators.zig").Parser;
const ErrorAccumulator = @import("combinators.zig").ErrorAccumulator;
const Result = @import("../result.zig").Result;

const grammar = @import("grammar.zig");

pub fn Parse(comptime Value: type) type {
    return struct {
        allocator: *std.heap.ArenaAllocator,
        result: ResultType,

        const Self = @This();
        const ResultType = Result(Value, []const SyntaxError);

        pub fn init(allocator: *std.heap.ArenaAllocator, result: ResultType) Self {
            return .{
                .allocator = allocator,
                .result = result,
            };
        }
    };
}

pub fn ParseBuilder(comptime Value: type, parser: Parser(Value)) type {
    return struct {

        pub const ValueType = Value;

        pub fn parse(arena: *std.heap.ArenaAllocator, iterator: *TokenIterator) !Parse(Value) {
            const allocator = &arena.allocator();

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

            const parser_result = try parser.parse(&context);
            switch (parser_result) {
                .value => |value| {
                    return Parse(Value).init(arena, .{
                        .ok = value,
                    });
                },
                else => {
                    return Parse(Value).init(arena, .{
                        .fail = err_accumulator.errors.toOwnedSlice(),
                    });
                }
            }
        }
    };
}

pub const ProgramParser = ParseBuilder(*ast.Program, grammar.parser);
