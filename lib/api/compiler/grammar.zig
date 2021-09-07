const std = @import("std");
const ast = @import("ast.zig");
const types = @import("../types.zig");
const combinators = @import("combinators.zig");

const expect = combinators.expect;
const map = combinators.map;
const token = combinators.token;

const parse_number = map(types.Number, ast.NumberLiteral, token(.number_literal), mapNumber);
fn mapNumber(from: f64) ast.NumberLiteral {
    return .{
        .value = from
    };
}

pub const RootProduction = combinators.Production(ast.Program);
pub const parser = expect(ast.Program, parse_number);
