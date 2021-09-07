const std = @import("std");
const ast = @import("ast.zig");
const types = @import("../types.zig");
const combinators = @import("combinators.zig");

const expect = combinators.expect;
const id = combinators.id;
const map = combinators.map;
const sequence = combinators.sequence;
const token = combinators.token;

const parse_number = map(types.Number, ast.NumberLiteral, mapNumber, token(.number_literal));
fn mapNumber(from: f64) ast.NumberLiteral {
    return .{
        .value = from
    };
}

const parse_identifier = map([]const u8, ast.Identifier, mapIdentifier, token(.identifier));
fn mapIdentifier(from: []const u8) ast.Identifier {
    return .{
        .name = from,
    };
}

const parse_expression = map(ast.NumberLiteral, ast.Expression, mapExpression, parse_number);
fn mapExpression(from: ast.NumberLiteral) ast.Expression {
    return .{
        .number_literal = from,
    };
}

const DefinitionParse = struct {
    let: void,
    identifier: ast.Identifier,
    assignment: void,
    expression: ast.Expression,
};

const parse_definition = map(DefinitionParse, ast.Definition, mapDefinition, sequence(DefinitionParse, "definition", &.{
    .let = id(.kwd_let),
    .identifier = parse_identifier,
    .assignment = id(.assignment),
    .expression = parse_expression,
}));

fn mapDefinition(from: DefinitionParse) ast.Definition {
    return .{
        .identifier  = from.identifier,
        .expression = from.expression,
    };
}

pub const RootProduction = combinators.Production(ast.Program);
pub const parser = expect(ast.Program, parse_definition);
