const std = @import("std");

pub const SystemError = error {
    InvalidState
} || std.mem.Allocator.Error;
