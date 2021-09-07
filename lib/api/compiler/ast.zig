const types = @import("../types.zig");

pub const NumberLiteral = struct {
    value: types.Number,
};

pub const Expression = union(enum) {
    number_literal: NumberLiteral,
};

pub const Definition = struct {
    name: []const u8,
    expr: Expression,
};
