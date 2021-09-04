const std = @import("std");

const errors = @import("../error.zig");
const ErrorAccumulator = errors.ErrorAccumulator;
const LazySyntaxError = errors.LazySyntaxError;
const SystemError = errors.SystemError;
const TokenIterator = @import("../tokenizer/tokenizer.zig").TokenIterator;

pub fn ParseFn(comptime Self: type, comptime Result: type) type {
    return fn(
        self: *Self,
        allocator: *std.mem.Allocator,
        iterator: *TokenIterator,
        errhandler: *ErrorAccumulator
    ) callconv(.Inline) SystemError!Result;
}

pub fn Parser(comptime Value: type) type {
    return struct {
        const Self = @This();
        pub const Production = union(enum) {
            value: Value,
            err: LazySyntaxError,
        };

        parseFn: ParseFn(Self, Production),

        pub fn parse(
            self: *Self,
            allocator: *std.mem.Allocator,
            iterator: *TokenIterator,
            errhandler: *ErrorAccumulator
        ) SystemError!Production {
            return self.parseFn(self, allocator, iterator, errhandler);
        }
    };
}

test "sanity test" {
    _ = Parser(u8);
}
