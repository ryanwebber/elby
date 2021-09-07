const std = @import("std");

pub const SystemError = error {
} || std.mem.Allocator.Error;
