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
        arrow,
        assignment,
        bang,
        colon,
        comma,
        equality,
        fslash,
        greater_than,
        greater_than_equals,
        inequality,
        kwd_else,
        kwd_fn,
        kwd_if,
        kwd_let,
        kwd_mut,
        kwd_return,
        kwd_while,
        kwd_yield,
        left_brace,
        left_paren,
        less_than,
        less_than_equals,
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
            .arrow                  => "->",
            .assignment             => "=",
            .bang                   => "!",
            .colon                  => ":",
            .comma                  => ",",
            .eof                    => "<eof>",
            .equality               => "==",
            .fslash                 => "/",
            .greater_than           => ">",
            .greater_than_equals    => ">=",
            .identifier             => "identifier",
            .inequality             => "!=",
            .kwd_else               => "else",
            .kwd_fn                 => "fn",
            .kwd_if                 => "if",
            .kwd_let                => "let",
            .kwd_mut                => "mut",
            .kwd_return             => "return",
            .kwd_while              => "while",
            .kwd_yield              => "yield",
            .left_brace             => "{",
            .left_paren             => "(",
            .less_than              => "<",
            .less_than_equals       => "<=",
            .minus                  => "-",
            .number_literal         => "number",
            .plus                   => "+",
            .right_brace            => "}",
            .right_paren            => ")",
            .semicolon              => ";",
            .star                   => "*",
        };
    }
};
