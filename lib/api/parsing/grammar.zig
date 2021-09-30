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
const list = combinators.list;
const map = combinators.map;
const mapAlloc = combinators.mapAlloc;
const mapValue = combinators.mapValue;
const orElse = combinators.orElse;
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

pub const Number = Rule(*ast.NumberLiteral, struct {
    pub const parser = mapAlloc(types.Numeric, ast.NumberLiteral, mapNumber, token(.number_literal));

    fn mapNumber(from: types.Numeric) ast.NumberLiteral {
        return .{
            .value = from
        };
    }
});

pub const Identifier = Rule(*ast.Identifier, struct {
    pub const parser = mapAlloc([]const u8, ast.Identifier, mapIdentifier, token(.identifier));

    fn mapIdentifier(from: []const u8) ast.Identifier {
        return .{
            .name = from,
        };
    }
});

pub const Factor = Rule(*ast.Expression, struct {
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

pub const Term = Rule(*ast.Expression, struct {
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

pub const Expression = Rule(*ast.Expression, struct {
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

pub const TypeAssociation = Rule(*ast.TypeAssociation, struct {
    pub const parser = mapAlloc(*ast.Identifier, ast.TypeAssociation, mapTypeAssociation, Identifier.parser);

    fn mapTypeAssociation(from: *ast.Identifier) ast.TypeAssociation {
        return .{
            .identifier  = from,
        };
    }
});

pub const Definition = Rule(*ast.Assignment, struct {
    // definition ::= LET IDENTIFIER : TYPE = expression
    pub const parser = mapAlloc(DefinitionParse, ast.Assignment, mapDefinition, sequence(DefinitionParse, "definition", &.{
        .let = token(.kwd_let),
        .identifier = Identifier.parser,
        .colon = token(.colon),
        .type = TypeAssociation.parser,
        .assignment = token(.assignment),
        .expression = Expression.parser,
        .semicolon = token(.semicolon),
    }));

    const DefinitionParse = struct {
        let: void,
        identifier: *ast.Identifier,
        colon: void,
        type: *ast.TypeAssociation,
        assignment: void,
        expression: *ast.Expression,
        semicolon: void,
    };

    fn mapDefinition(from: DefinitionParse) ast.Assignment {
        return .{
            .identifier  = from.identifier,
            .type = from.type,
            .expression = from.expression,
        };
    }
});

pub const Argument = Rule(*ast.Argument, struct {
    pub const parser = mapAlloc(ArgumentParse, ast.Argument, mapArgument, sequence(ArgumentParse, "argument", &.{
        .identifier = Identifier.parser,
        .colon = token(.colon),
        .expression = Expression.parser,
    }));

    const ArgumentParse = struct {
        identifier: *ast.Identifier,
        colon: void,
        expression: *ast.Expression,
    };

    fn mapArgument(from: ArgumentParse) ast.Argument {
        return .{
            .identifier = from.identifier,
            .expression = from.expression,
        };
    }
});

pub const ArgumentList = Rule(*ast.ArgumentList, struct {
    pub const parser = mapAlloc([]const *ast.Argument, ast.ArgumentList, mapArgumentList, zeroOrMoreArguments);
    const zeroOrMoreArguments = list(*ast.Argument, "arguments", Argument.parser, token(.comma));

    fn mapArgumentList(from: []const *ast.Argument) ast.ArgumentList {
        return .{
            .arguments = from,
        };
    }
});

pub const FunctionCall = Rule(*ast.FunctionCall, struct {
    pub const parser = mapAlloc(FunctionCallParse, ast.FunctionCall, mapFunctionCall, sequence(FunctionCallParse, "function call", &.{
        .identifier = Identifier.parser,
        .lparen = token(.left_paren),
        .arglist = ArgumentList.parser,
        .rparen = token(.right_paren),
        .semicolon = token(.semicolon),
    }));

    const FunctionCallParse = struct {
        identifier: *ast.Identifier,
        lparen: void,
        arglist: *ast.ArgumentList,
        rparen: void,
        semicolon: void,
    };

    fn mapFunctionCall(from: FunctionCallParse) ast.FunctionCall {
        return .{
            .identifier = from.identifier,
            .arglist = from.arglist,
        };
    }
});

pub const Statement = Rule(*ast.Statement, struct {
    pub const parser = first(*ast.Statement, "statement", &.{
        mapAlloc(*ast.Assignment, ast.Statement, mapAssignment, Definition.parser),
        mapAlloc(*ast.FunctionCall, ast.Statement, mapFunctionCall, FunctionCall.parser),
    });

    fn mapAssignment(from: *ast.Assignment) ast.Statement {
        return .{
            .assignment = from,
        };
    }

    fn mapFunctionCall(from: *ast.FunctionCall) ast.Statement {
        return .{
            .call = from,
        };
    }
});

pub const Parameter = Rule(*ast.Parameter, struct {
    pub const parser = mapAlloc(ParameterParse, ast.Parameter, mapParameter, sequence(ParameterParse, "parameter", &.{
        .identifier = Identifier.parser,
        .colon = token(.colon),
        .type = Identifier.parser,
    }));

    const ParameterParse = struct {
        identifier: *ast.Identifier,
        colon: void,
        type: *ast.Identifier,
    };

    fn mapParameter(from: ParameterParse) ast.Parameter {
        return .{
            .identifier = from.identifier,
            .type = from.type,
        };
    }
});

pub const ParameterList = Rule(*ast.ParameterList, struct {
    pub const parser = mapAlloc([]const *ast.Parameter, ast.ParameterList, mapParameterList, zeroOrMoreParameters);
    const zeroOrMoreParameters = list(*ast.Parameter, "parameters", Parameter.parser, token(.comma));

    fn mapParameterList(from: []const *ast.Parameter) ast.ParameterList {
        return .{
            .parameters = from,
        };
    }
});

pub const Function = Rule(*ast.Function, struct {
    pub const parser = mapAlloc(FunctionParse, ast.Function, mapFunction, sequence(FunctionParse, "function", &.{
        .kwdfn = token(.kwd_fn),
        .name = Identifier.parser,
        .lparen = token(.left_paren),
        .parameters = ParameterList.parser,
        .rparen = token(.right_paren),
        .lbrace = token(.left_brace),
        .statements = atLeast(*ast.Statement, 0, "statements", Statement.parser),
        .rbrace = token(.right_brace),
    }));

    const FunctionParse = struct {
        kwdfn: void,
        name: *ast.Identifier,
        lparen: void,
        parameters: *ast.ParameterList,
        rparen: void,
        lbrace: void,
        statements: []const *ast.Statement,
        rbrace: void,
    };

    fn mapFunction(from: FunctionParse) ast.Function {
        return .{
            .identifier = from.name,
            .paramlist = from.parameters,
            .body = from.statements,
        };
    }
});

pub const Program = Rule(*ast.Program, struct {
    pub const parser = mapAlloc(ProgramParse, ast.Program, mapProgram, sequence(ProgramParse, "program", &.{
        .functions = atLeast(*ast.Function, 1, "functions", Function.parser),
        .eof = eof(),
    }));

    const ProgramParse = struct {
        functions: []const *ast.Function,
        eof: void,
    };

    fn mapProgram(from: ProgramParse) ast.Program {
        return .{
            .functions = from.functions
        };
    }
});

pub const parser = expect(*ast.Program, Program.parser);
