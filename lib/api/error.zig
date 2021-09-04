const std = @import("std");
const Token = @import("tokenizer/token.zig").Token;

pub const SystemError = error {
} || std.mem.Allocator.Error;

pub const SyntaxError = struct {
    line: usize,
    offset: usize,

    const Self = @This();

    pub fn init(token: *Token, source: []const u8) Self {
        return .{
            .line = token.line,
            .offset = @ptrToInt(token.range.ptr) - @ptrToInt(source.ptr),
        };
    }
};

pub const LazySyntaxError = struct {
    const Self = @This();
    factoryFn: fn(self: *Self) SystemError!SyntaxError,

    pub fn makeSyntaxError(self: *Self) SystemError!SyntaxError {
        return self.factoryFn(self);
    }
};

pub const ErrorAccumulator = struct {
    allocator: *std.mem.Allocator,
    errors: std.ArrayList(LazySyntaxError),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .errors = std.ArrayList(LazySyntaxError).init(allocator),
        };
    }

    pub fn push(self: *Self, err: LazySyntaxError) !void {
        try self.errors.append(err);
    }
};
