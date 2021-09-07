const std = @import("std");
const types = @import("../types.zig");

pub const Token = struct {
    type: Value,
    range: []const u8,
    line: usize,
    offset: usize,

    // TODO: Remove and use @TagType in newer zig builds
    pub const Id = std.meta.TagType(Value);

    pub const Value = union(enum) {
        identifier,
        assignment,
        number_literal: types.Number,
        plus,
        minus,
        star,
        kwd_let,
        eof,
    };

    // TODO: Is there a better way to do this?
    pub fn valueType(comptime id: Id) type {
        return std.meta.TagPayload(Value, id);
    }

    pub fn description(self: *Token) []const u8 {
        return self.range;
    }
};
