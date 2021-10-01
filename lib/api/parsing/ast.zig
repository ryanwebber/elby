const std = @import("std");
const types = @import("../types.zig");

pub const BinOp = enum {
    op_plus,
    op_minus,
    op_mul,
    op_div,

    pub fn jsonStringify(self: BinOp, _: anytype, out_stream: anytype) !void {
        try out_stream.writeAll(@tagName(self));
    }
};

pub const NumberLiteral = struct {
    value: types.Numeric,
};

pub const Identifier = struct {
    name: []const u8,
};

pub const BinaryExpression = struct {
    lhs: *const Expression,
    op: BinOp,
    rhs: *const Expression
};

pub const Expression = union(enum) {
    number_literal: *const NumberLiteral,
    identifier: *const Identifier,
    binary_expression: *const BinaryExpression,
    function_call: *const FunctionCall,
};

pub const Argument = struct {
    identifier: *const Identifier,
    expression: *const Expression,
};

pub const ArgumentList = struct {
    arguments: []const *const Argument,
};

pub const FunctionCall = struct {
    identifier: *const Identifier,
    arglist: *const ArgumentList,
};

pub const TypeAssociation = struct {
    identifier: *const Identifier,
};

pub const Assignment = struct {
    identifier: *const Identifier,
    type: *const TypeAssociation,
    expression: *const Expression,
};

pub const Statement = union(enum) {
    assignment: *const Assignment,
    call: *const FunctionCall,
    ret: ?*const Expression,
};

pub const Parameter = struct {
    identifier: *const Identifier,
    type: *const Identifier,
};

pub const ParameterList = struct {
    parameters: []const *const Parameter,
};

pub const Function = struct {
    identifier: *const Identifier,
    paramlist: *const ParameterList,
    returnType: ?*const Identifier,
    body: []const *const Statement,
};

pub const Program = struct {
    functions: []const *const Function,
};
