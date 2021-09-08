const std = @import("std");
const ast = @import("ast.zig");
const types = @import("../types.zig");
const combinators = @import("combinators.zig");

const expect = combinators.expect;
const id = combinators.id;
const map = combinators.map;
const sequence = combinators.sequence;
const token = combinators.token;

const NumberParser = struct {
    pub const parser = map(types.Number, ast.NumberLiteral, mapNumber, token(.number_literal));

    fn mapNumber(from: f64) ast.NumberLiteral {
        return .{
            .value = from
        };
    }
};

const IdentifierParser = struct {
    pub const parser = map([]const u8, ast.Identifier, mapIdentifier, token(.identifier));

    fn mapIdentifier(from: []const u8) ast.Identifier {
        return .{
            .name = from,
        };
    }
};

const ExpressionParser = struct {
    pub const parser = map(ast.NumberLiteral, ast.Expression, mapExpression, NumberParser.parser);

    fn mapExpression(from: ast.NumberLiteral) ast.Expression {
        return .{
            .number_literal = from,
        };
    }
};

const DefinitionParser = struct {
    pub const parser = map(DefinitionParse, ast.Definition, mapDefinition, sequence(DefinitionParse, "definition", &.{
        .let = id(.kwd_let),
        .identifier = IdentifierParser.parser,
        .assignment = id(.assignment),
        .expression = ExpressionParser.parser,
    }));

    const DefinitionParse = struct {
        let: void,
        identifier: ast.Identifier,
        assignment: void,
        expression: ast.Expression,
    };

    fn mapDefinition(from: DefinitionParse) ast.Definition {
        return .{
            .identifier  = from.identifier,
            .expression = from.expression,
        };
    }
};

pub const RootProduction = combinators.Production(ast.Program);
pub const parser = expect(ast.Program, DefinitionParser.parser);
