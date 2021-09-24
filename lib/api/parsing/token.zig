const std = @import("std");
const types = @import("../types.zig");

pub const Token = struct {
    type: Value,
    range: []const u8,
    line: usize,
    offset: usize,

    pub const Id = std.meta.TagType(Value);
    pub const Value = union(enum) {
        identifier: []const u8,
        assignment,
        number_literal: types.Numeric,
        plus,
        minus,
        star,
        fslash,
        semicolon,
        left_paren,
        right_paren,
        left_brace,
        right_brace,
        kwd_let,
        kwd_fn,
        eof,
    };

    // TODO: Is there a better way to do this?
    pub fn valueType(comptime id: Id) type {
        return std.meta.TagPayload(Value, id);
    }

    pub fn description(self: Token.Id) []const u8 {
        return switch (self) {
            .assignment => "=",
            .number_literal => "number",
            .plus => "+",
            .minus => "-",
            .star => "*",
            .fslash => "/",
            .semicolon => ";",
            .left_paren => "(",
            .right_paren => ")",
            .left_brace => "{",
            .right_brace => "}",
            .kwd_let => "let",
            .kwd_fn => "fn",
            .eof => "<eof>",
            else => @tagName(self)
        };
    }
};
