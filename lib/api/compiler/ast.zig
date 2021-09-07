const types = @import("../types.zig");

pub const NumberLiteral = struct {
    value: types.Number,
};

pub const Identifier = struct {
    name: []const u8,
};

pub const Expression = union(enum) {
    number_literal: NumberLiteral,
};

pub const Definition = struct {
    identifier: Identifier,
    expression: Expression,
};

pub const Program = Definition;
