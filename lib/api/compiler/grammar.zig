const std = @import("std");
const ast = @import("ast.zig");
const types = @import("../types.zig");
const combinators = @import("combinators.zig");

const Parser = combinators.Parser;

const any = combinators.any;
const expect = combinators.expect;
const map = combinators.map;
const mapAst = combinators.mapAst;
const sequence = combinators.sequence;
const token = combinators.token;

const NumberParser = struct {
    pub const parser: Parser(*ast.NumberLiteral) = mapAst(types.Number, ast.NumberLiteral, mapNumber, token(.number_literal));

    fn mapNumber(from: f64) ast.NumberLiteral {
        return .{
            .value = from
        };
    }
};

const IdentifierParser = struct {
    pub const parser: Parser(*ast.Identifier) = mapAst([]const u8, ast.Identifier, mapIdentifier, token(.identifier));

    fn mapIdentifier(from: []const u8) ast.Identifier {
        return .{
            .name = from,
        };
    }
};

const AdditionParser = struct {
};

const ExpressionParser = struct {
    pub const parser: Parser(*ast.Expression) = any(*ast.Expression, "expression", &[_]Parser(*ast.Expression){
        number,
        identifier,
    });

    pub const number: Parser(*ast.Expression) = mapAst(*ast.NumberLiteral, ast.Expression, mapNumber, NumberParser.parser);
    fn mapNumber(from: *ast.NumberLiteral) ast.Expression {
        return .{
            .number_literal = from,
        };
    }

    pub const identifier: Parser(*ast.Expression) = mapAst(*ast.Identifier, ast.Expression, mapIdentifier, IdentifierParser.parser);
    fn mapIdentifier(from: *ast.Identifier) ast.Expression {
        return .{
            .identifier = from,
        };
    }
};

const DefinitionParser = struct {
    pub const parser: Parser(*ast.Definition) = mapAst(DefinitionParse, ast.Definition, mapDefinition, sequence(DefinitionParse, "definition", &.{
        .let = token(.kwd_let),
        .identifier = IdentifierParser.parser,
        .assignment = token(.assignment),
        .expression = ExpressionParser.parser,
    }));

    const DefinitionParse = struct {
        let: void,
        identifier: *ast.Identifier,
        assignment: void,
        expression: *ast.Expression,
    };

    fn mapDefinition(from: DefinitionParse) ast.Definition {
        return .{
            .identifier  = from.identifier,
            .expression = from.expression,
        };
    }
};

pub const RootProduction = combinators.Production(ast.Program);
pub const parser = expect(*ast.Program, DefinitionParser.parser);
