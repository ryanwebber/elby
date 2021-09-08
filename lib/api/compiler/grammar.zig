const std = @import("std");
const ast = @import("ast.zig");
const types = @import("../types.zig");
const combinators = @import("combinators.zig");

const Parser = combinators.Parser;
const SystemError = @import("../error.zig").SystemError;

const atLeast = combinators.atLeast;
const expect = combinators.expect;
const id = combinators.id;
const map = combinators.map;
const mapAlloc = combinators.mapAlloc;
const mapAst = combinators.mapAst;
const oneOf = combinators.oneOf;
const sequence = combinators.sequence;
const token = combinators.token;

const Number = struct {
    pub const parser: Parser(*ast.NumberLiteral) = mapAst(types.Number, ast.NumberLiteral, mapNumber, token(.number_literal));

    fn mapNumber(from: f64) ast.NumberLiteral {
        return .{
            .value = from
        };
    }
};

const Identifier = struct {
    pub const parser: Parser(*ast.Identifier) = mapAst([]const u8, ast.Identifier, mapIdentifier, token(.identifier));

    fn mapIdentifier(from: []const u8) ast.Identifier {
        return .{
            .name = from,
        };
    }
};

const Primary = struct {
    pub const parser: Parser(*ast.Expression) = oneOf(*ast.Expression, "primary", &[_]Parser(*ast.Expression) {
        mapAst(*ast.NumberLiteral, ast.Expression, mapNumber, Number.parser),
        mapAst(*ast.Identifier, ast.Expression, mapIdentifier, Identifier.parser),
    });

    fn mapNumber(from: *ast.NumberLiteral) ast.Expression {
        return .{
            .number_literal = from,
        };
    }

    fn mapIdentifier(from: *ast.Identifier) ast.Expression {
        return .{
            .identifier = from,
        };
    }
};

const Factor = Primary;

const Term = Factor;

const Expression = struct {
    const parser: Parser(*ast.Expression) = mapAlloc(LhsOpRhs, *ast.Expression, mapReduceLhsOpRhs, sequence(LhsOpRhs, "(addition|subtraction)", &.{
        .lhs = Term.parser,
        .opRhs = atLeast(OpTermPair, 0, "{ ((+|-) Term)* }", sequence(OpTermPair, "(+|-) Term", &.{
            .op = oneOf(ast.BinOp, "(+|-)", &[_]Parser(ast.BinOp) {
                id(.plus, ast.BinOp.op_plus),
                id(.minus, ast.BinOp.op_minus)
            }),
            .rhs = Term.parser
        })),
    }));

    const LhsOpRhs = struct {
        lhs: *ast.Expression,
        opRhs: []const OpTermPair,
    };

    fn mapReduceLhsOpRhs(allocator: *std.mem.Allocator, from: LhsOpRhs) SystemError!*ast.Expression {
        var expr_node = from.lhs;
        for (from.opRhs) |pair| {
            var binexpr = try allocator.create(ast.Expression);

            // Left-associativity
            binexpr.* = .{
                .binary_expression = .{
                    .lhs = expr_node,
                    .op = pair.op,
                    .rhs = pair.rhs
                }
            };

            expr_node = binexpr;
        }

        // Free the list of OpTermPairs since we've constructed a tree from it
        allocator.free(from.opRhs);

        return expr_node;
    }

    const OpTermPair = struct {
        op: ast.BinOp,
        rhs: *ast.Expression,
    };

    const operator = oneOf(ast.BinOp, "(+|-)", &[_]Parser(ast.BinOp) {
        id(.plus, ast.BinOp.op_plus),
        id(.minus, ast.BinOp.op_minus)
    });
};

const Definition = struct {
    pub const parser: Parser(*ast.Definition) = mapAst(DefinitionParse, ast.Definition, mapDefinition, sequence(DefinitionParse, "definition", &.{
        .let = token(.kwd_let),
        .identifier = Identifier.parser,
        .assignment = token(.assignment),
        .expression = Expression.parser,
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
pub const parser = expect(*ast.Program, Definition.parser);
