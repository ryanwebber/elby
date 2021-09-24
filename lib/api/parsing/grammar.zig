const std = @import("std");
const ast = @import("ast.zig");
const types = @import("../types.zig");
const combinators = @import("combinators.zig");

const Parser = combinators.Parser;
const SystemError = @import("../error.zig").SystemError;

const atLeast = combinators.atLeast;
const eof = combinators.eof;
const expect = combinators.expect;
const id = combinators.id;
const first = combinators.first;
const lazy = combinators.lazy;
const map = combinators.map;
const mapAlloc = combinators.mapAlloc;
const mapValue = combinators.mapValue;
const sequence = combinators.sequence;
const token = combinators.token;

fn Rule(comptime Value: type, comptime RuleStruct: type) type {
    return struct {
        pub const parser: Parser(Value) = lazy(Value, lazy_provider);

        // Prevents dependency cycles in zig
        fn lazy_provider() callconv(.Inline) Parser(Value) {
            return RuleStruct.parser;
        }
    };
}

const Number = Rule(*ast.NumberLiteral, struct {
    pub const parser = mapAlloc(types.Numeric, ast.NumberLiteral, mapNumber, token(.number_literal));

    fn mapNumber(from: types.Numeric) ast.NumberLiteral {
        return .{
            .value = from
        };
    }
});

const Identifier = Rule(*ast.Identifier, struct {
    pub const parser = mapAlloc([]const u8, ast.Identifier, mapIdentifier, token(.identifier));

    fn mapIdentifier(from: []const u8) ast.Identifier {
        return .{
            .name = from,
        };
    }
});

const Factor = Rule(*ast.Expression, struct {
    // factor  ::= NUM | IDENTIFIER | (expr)
    pub const parser = first(*ast.Expression, "factor", &.{
        mapAlloc(*ast.NumberLiteral, ast.Expression, mapNumber, Number.parser),
        mapAlloc(*ast.Identifier, ast.Expression, mapIdentifier, Identifier.parser),
        mapValue(BracketedExpr, *ast.Expression, mapBrackets, sequence(BracketedExpr, "( <expression> )", &.{
            .left_paren = token(.left_paren),
            .expr = Expression.parser,
            .right_paren = token(.right_paren),
        })),
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

    fn mapBrackets(from: BracketedExpr) *ast.Expression {
        return from.expr;
    }

    const BracketedExpr = struct {
        left_paren: void,
        expr: *ast.Expression,
        right_paren: void,
    };
});

const Term = Rule(*ast.Expression, struct {
    // term ::= factor { ( * | / ) factor } *
    const parser = map(LhsOpRhs, *ast.Expression, mapReduceLhsOpRhs, sequence(LhsOpRhs, "multaplicative expression", &.{
        .lhs = Factor.parser,
        .opRhs = atLeast(OpTermPair, 0, "", sequence(OpTermPair, "multaplicative term", &.{
            .op = first(ast.BinOp, "'*' or '/'", &.{
                id(.star, ast.BinOp.op_mul),
                id(.fslash, ast.BinOp.op_div)
            }),
            .rhs = Factor.parser
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

        return expr_node;
    }

    const OpTermPair = struct {
        op: ast.BinOp,
        rhs: *ast.Expression,
    };
});

const Expression = Rule(*ast.Expression, struct {
    // expression ::= term { ( + | - ) term } *
    const parser = map(LhsOpRhs, *ast.Expression, mapReduceLhsOpRhs, sequence(LhsOpRhs, "addative expression", &.{
        .lhs = Term.parser,
        .opRhs = atLeast(OpTermPair, 0, "", sequence(OpTermPair, "addative term", &.{
            .op = first(ast.BinOp, "'+' or '-'", &.{
                id(.plus, ast.BinOp.op_plus),
                id(.minus, ast.BinOp.op_minus)
            }),
            .rhs = Term.parser
        })),
    }));

    pub fn lazy() Parser(*ast.Expression) {
        return parser;
    }

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

        return expr_node;
    }

    const OpTermPair = struct {
        op: ast.BinOp,
        rhs: *ast.Expression,
    };
});

const Definition = Rule(*ast.Definition, struct {
    // definition ::= LET IDENTIFIER = expression
    pub const parser = mapAlloc(DefinitionParse, ast.Definition, mapDefinition, sequence(DefinitionParse, "definition", &.{
        .let = token(.kwd_let),
        .identifier = Identifier.parser,
        .assignment = token(.assignment),
        .expression = Expression.parser,
        .semicolon = token(.semicolon),
    }));

    const DefinitionParse = struct {
        let: void,
        identifier: *ast.Identifier,
        assignment: void,
        expression: *ast.Expression,
        semicolon: void,
    };

    fn mapDefinition(from: DefinitionParse) ast.Definition {
        return .{
            .identifier  = from.identifier,
            .expression = from.expression,
        };
    }
});

const Statement = Rule(*ast.Statement, struct {
    pub const parser = mapAlloc(*ast.Definition, ast.Statement, mapStatement, Definition.parser);

    fn mapStatement(from: *ast.Definition) ast.Statement {
        return .{
            .definition = from,
        };
    }
});

const Function = Rule(*ast.Function, struct {
    pub const parser = mapAlloc(FunctionParse, ast.Function, mapFunction, sequence(FunctionParse, "function", &.{
        .kwdfn = token(.kwd_fn),
        .name = Identifier.parser,
        .lparen = token(.left_paren),
        .rparen = token(.right_paren),
        .lbrace = token(.left_brace),
        .statements = atLeast(*ast.Statement, 0, "statements", Statement.parser),
        .rbrace = token(.right_brace),
    }));

    const FunctionParse = struct {
        kwdfn: void,
        name: *ast.Identifier,
        lparen: void,
        rparen: void,
        lbrace: void,
        statements: []const *ast.Statement,
        rbrace: void,
    };

    fn mapFunction(from: FunctionParse) ast.Function {
        return .{
            .identifier = from.name,
            .body = from.statements,
        };
    }
});

const Program = Rule(*ast.Program, struct {
    pub const parser = mapValue(ProgramParse, *ast.Program, mapProgram, sequence(ProgramParse, "program", &.{
        .program = Function.parser,
        .eof = eof(),
    }));

    const ProgramParse = struct {
        program: *ast.Program,
        eof: void,
    };

    fn mapProgram(from: ProgramParse) *ast.Function {
        return from.program;
    }
});

pub const parser = expect(*ast.Program, Program.parser);
