const std = @import("std");

pub const SystemError = error {
    InvalidState,
} || std.mem.Allocator.Error;

pub fn fatal(comptime format: []const u8, args: anytype) SystemError {
    std.log.err(format, args);
    return SystemError.InvalidState;
}
