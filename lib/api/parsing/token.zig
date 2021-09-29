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
        comma,
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

    pub fn valueType(comptime id: Id) type {
        return std.meta.TagPayload(Value, id);
    }

    pub fn description(self: Token.Id) []const u8 {
        return switch (self) {
            .assignment => "=",
            .number_literal => "number",
            .colon => ":",
            .comma => ",",
            .fslash => "/",
            .kwd_fn => "fn",
            .kwd_let => "let",
            .left_brace => "{",
            .left_paren => "(",
            .minus => "-",
            .plus => "+",
            .right_brace => "}",
            .right_paren => ")",
            .semicolon => ";",
            .star => "*",
            .eof => "<eof>",
            else => @tagName(self)
        };
    }
};
