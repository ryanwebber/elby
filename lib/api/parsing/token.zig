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
        number_literal: types.Numeric,
        assignment,
        colon,
        fslash,
        kwd_fn,
        kwd_let,
        left_brace,
        left_paren,
        minus,
        plus,
        right_brace,
        right_paren,
        semicolon,
        star,
        eof,

        pub fn description(self: *const Value) []const u8 {
            return Token.description(self.*);
        }
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
