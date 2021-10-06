const std = @import("std");

pub const Context = struct {
    allocator: *std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(_: *Self) void {
    }
};
