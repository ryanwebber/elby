const std = @import("std");
const Token = @import("token.zig").Token;
const SystemError = @import("../error.zig").SystemError;
const SyntaxError = @import("syntax_error.zig").SyntaxError;

pub const Deviation = struct {
    const Self = @This();

    factoryFn: fn(self: *Self) SystemError!SyntaxError,

    pub fn makeSyntaxError(self: *Self) SystemError!SyntaxError {
        return self.factoryFn(self);
    }
};

pub fn static(after: *Token, msg: []const u8) Deviation {
    return StaticDeviation.init(after, msg).deviation;
}

pub const StaticDeviation = struct {
    deviation: Deviation,
    msg: []const u8,
    after: *Token,

    const Self = @This();

    pub fn init(after: *Token, msg: []const u8) Self {
        return .{
            .deviation = .{
                .factoryFn = makeSyntaxError
            },
            .msg = msg,
            .after = after,
        };
    }

    pub fn makeSyntaxError(deviation: *Deviation) SystemError!SyntaxError {
        const self = @fieldParentPtr(Self, "deviation", deviation);
        return SyntaxError.init(self.after);
    }
};

test {
    _ = static;
    try @import("std").testing.expect(true);
}
