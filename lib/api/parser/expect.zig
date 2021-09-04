const std = @import("std");
const Parser = @import("parser.zig").Parser;

pub fn Expect(comptime Value: type) type {
    return struct {
        parser: Parser(Value),
        wrapped: *Parser(Value),

        const Self = @This();

        pub fn init(wrapped: *Parser(Value),) Self {
            return .{
                .parser = .{
                    .parseFn = parse,
                },
                .wrapped = wrapped
            };
        }

        pub fn parse(
            parser: *Parser(Value),
            allocator: *std.mem.Allocator,
            iterator: *TokenIterator,
            errhandler: *ErrorAccumulator
        ) SystemError!Value {
            const self = @fieldParentPtr(Self, "parser", parser);
            const result = try self.wrapped.parse(allocator, iterator, errhandler);

            switch (result) {
                err => |err| {
                    errhandler.push(err);
                },
                else => {}
            }

            return result;
        }
    };
}

test "sanity check" {
    _ = Expect(u8);
    try std.testing.expect(true);
}
