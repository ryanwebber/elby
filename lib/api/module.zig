const std = @import("std");

pub const Module = struct {
    identifier: Identifier,
    source: []const u8,

    const Identifier = union(enum) {
        anonymous,
        named: []const u8,
    };

    pub fn name(self: *const Module) []const u8 {
        return switch (self.identifier) {
            .anonymous => "[anonymous module]",
            .named => |name| name,
        };
    }
};
