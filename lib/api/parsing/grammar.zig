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
const maybe = combinators.maybe;
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

pub fn associativeBinOpParser(name: []const u8, comptime nextParser: Parser(*ast.Expression), comptime binopParser: Parser(ast.BinOp)) Parser(*ast.Expression) {
    const Local = struct {
        const parser = map(LhsOpRhs, *ast.Expression, mapReduceLhsOpRhs, sequence(LhsOpRhs, name, &.{
            .lhs = nextParser,
            .opRhs = atLeast(OpTermPair, 0, "", sequence(OpTermPair, name, &.{
                .op = binopParser,
                .rhs = nextParser
            })),
        }));

        const LhsOpRhs = struct {
            lhs: *ast.Expression,
            opRhs: []const OpTermPair,
        };

        fn mapReduceLhsOpRhs(allocator: *std.mem.Allocator, from: LhsOpRhs) SystemError!*ast.Expression {
            var expr_node = from.lhs;
            for (from.opRhs) |pair| {
                var node = try allocator.create(ast.Expression);
                var binexpr = try allocator.create(ast.BinaryExpression);
                binexpr.* = .{
                    .lhs = expr_node,
                    .op = pair.op,
                    .rhs = pair.rhs
                };

                // Left-associativity
                node.* = .{
                    .binary_expression = binexpr
                };

                expr_node = node;
            }

            return expr_node;
        }

        const OpTermPair = struct {
            op: ast.BinOp,
            rhs: *ast.Expression,
        };
    };

    return Local.parser;
}

// ----------- Grammar ---------------

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
    // factor  ::= NUM | IDENTIFIER | ( expr )
    pub const parser = first(*ast.Expression, "factor", &.{
        mapAlloc(*ast.NumberLiteral, ast.Expression, mapNumber, Number.parser),
        mapAlloc(*ast.FunctionCall, ast.Expression, mapFunctionCall, FunctionCall.parser),
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

    fn mapFunctionCall(from: *ast.FunctionCall) ast.Expression {
        return .{
            .function_call = from,
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
    pub const parser = associativeBinOpParser("multaplicative expression", Factor.parser, first(ast.BinOp, "product", &.{
        id(.star, ast.BinOp.op_mul),
        id(.fslash, ast.BinOp.op_div)
    }));
});

pub const Addative = Rule(*ast.Expression, struct {
    // addative ::= term { ( + | - ) term } *
    pub const parser = associativeBinOpParser("addative expression", Term.parser, first(ast.BinOp, "addition", &.{
        id(.plus, ast.BinOp.op_plus),
        id(.minus, ast.BinOp.op_minus)
    }));
});

pub const Equality = Rule(*ast.Expression, struct {
    // equality ::= addative { ( + | - ) addative } *
    pub const parser = associativeBinOpParser("equality expression", Addative.parser, first(ast.BinOp, "equality comparison", &.{
        id(.equality, ast.BinOp.op_equality),
        id(.inequality, ast.BinOp.op_inequality),
    }));
});

pub const Expression = Rule(*ast.Expression, struct {
    // expression ::= equality
    const parser = Equality.parser;
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
    }));

    const FunctionCallParse = struct {
        identifier: *ast.Identifier,
        lparen: void,
        arglist: *ast.ArgumentList,
        rparen: void,
    };

    fn mapFunctionCall(from: FunctionCallParse) ast.FunctionCall {
        return .{
            .identifier = from.identifier,
            .arglist = from.arglist,
        };
    }
});

pub const FunctionCallStatement = Rule(*ast.FunctionCall, struct {
    pub const parser = mapValue(FunctionCallStatementParse, *ast.FunctionCall, mapFunctionCallStatement, sequence(FunctionCallStatementParse, "function call statement", &.{
        .call = FunctionCall.parser,
        .semicolon = token(.semicolon),
    }));

    const FunctionCallStatementParse = struct {
        call: *ast.FunctionCall,
        semicolon: void,
    };

    fn mapFunctionCallStatement(from: FunctionCallStatementParse) *ast.FunctionCall {
        return from.call;
    }
});

pub const ReturnStatement = Rule(?*ast.Expression, struct {
    pub const parser = mapValue(ReturnParse, ?*ast.Expression, mapReturn, sequence(ReturnParse, "return statement", &.{
        .ret = token(.kwd_return),
        .expression = maybe(*ast.Expression, Expression.parser),
        .semicolon = token(.semicolon),
    }));

    const ReturnParse = struct {
        ret: void,
        expression: ?*ast.Expression,
        semicolon: void,
    };

    fn mapReturn(from: ReturnParse) ?*ast.Expression {
        return from.expression;
    }
});

pub const ElseIf = Rule(?ast.ElseIf, struct {
    pub const parser = maybe(ast.ElseIf, mapValue(ElseIfChainParse, ast.ElseIf, mapElseIfChain, sequence(ElseIfChainParse, "else if statements", &.{
        .elsetok = token(.kwd_else),
        .elseIf = first(ast.ElseIf, "else if statement", &.{
            mapValue(*ast.IfChain, ast.ElseIf, mapElseIf, IfChain.parser),
            mapValue(ElseParse, ast.ElseIf, mapElse, sequence(ElseParse, "else statement", &.{
                .lbrace = token(.left_brace),
                .statements = atLeast(*ast.Statement, 0, "statements", Statement.parser),
                .rbrace = token(.right_brace),
            })),
        }),
    })));

    const ElseIfChainParse = struct {
        elsetok: void,
        elseIf: ast.ElseIf,
    };

    fn mapElseIfChain(from: ElseIfChainParse) ast.ElseIf {
        return from.elseIf;
    }

    fn mapElseIf(from: *ast.IfChain) ast.ElseIf {
        return .{
            .conditional = from
        };
    }

    const ElseParse = struct {
        lbrace: void,
        statements: []const *ast.Statement,
        rbrace: void,
    };

    fn mapElse(from: ElseParse) ast.ElseIf {
        return .{
            .terminal = from.statements
        };
    }
});

pub const IfChain = Rule(*ast.IfChain, struct {
    pub const parser = mapAlloc(IfChainParse, ast.IfChain, mapChain, sequence(IfChainParse, "if statement", &.{
        .ifkwd = token(.kwd_if),
        .lparen = token(.left_paren),
        .expression = Expression.parser,
        .rparen = token(.right_paren),
        .lbrace = token(.left_brace),
        .statements = atLeast(*ast.Statement, 0, "statements", Statement.parser),
        .rbrace = token(.right_brace),
        .tail = ElseIf.parser,
    }));

    const IfChainParse = struct {
        ifkwd: void,
        lparen: void,
        expression: *ast.Expression,
        rparen: void,
        lbrace: void,
        statements: []const *ast.Statement,
        rbrace: void,
        tail: ?ast.ElseIf,
    };

    fn mapChain(from: IfChainParse) ast.IfChain {
        return .{
            .expr = from.expression,
            .statements = from.statements,
            .next = from.tail
        };
    }
});

pub const Statement = Rule(*ast.Statement, struct {
    pub const parser = first(*ast.Statement, "statement", &.{
        mapAlloc(*ast.Assignment, ast.Statement, mapAssignment, Definition.parser),
        mapAlloc(*ast.FunctionCall, ast.Statement, mapFunctionCall, FunctionCallStatement.parser),
        mapAlloc(?*ast.Expression, ast.Statement, mapReturn, ReturnStatement.parser),
        mapAlloc(*ast.IfChain, ast.Statement, mapIfChain, IfChain.parser),
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

    fn mapReturn(from: ?*ast.Expression) ast.Statement {
        return .{
            .ret = from,
        };
    }

    fn mapIfChain(from: *ast.IfChain) ast.Statement {
        return .{
            .ifchain = from,
        };
    }
});

pub const ReturnType = Rule(*ast.Identifier, struct {
    pub const parser = mapValue(ReturnTypeParse, *ast.Identifier, mapReturnType, sequence(ReturnTypeParse, "return type", &.{
        .arrow = token(.arrow),
        .identifier = Identifier.parser,
    }));

    const ReturnTypeParse = struct {
        arrow: void,
        identifier: *ast.Identifier,
    };

    fn mapReturnType(from: ReturnTypeParse) *ast.Identifier {
        return from.identifier;
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
        .returnType = maybe(*ast.Identifier, ReturnType.parser),
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
        returnType: ?*ast.Identifier,
        lbrace: void,
        statements: []const *ast.Statement,
        rbrace: void,
    };

    fn mapFunction(from: FunctionParse) ast.Function {
        return .{
            .identifier = from.name,
            .paramlist = from.parameters,
            .returnType = from.returnType,
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
