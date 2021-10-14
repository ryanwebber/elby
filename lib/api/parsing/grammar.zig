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

pub const Block = Rule([]const *ast.Statement, struct {
    pub const parser = mapValue(BlockExpr, []const *ast.Statement, mapBlockExpr, sequence(BlockExpr, "block", &.{
        .lbrace = token(.left_brace),
        .statements = atLeast(*ast.Statement, 1, "statements", Statement.parser),
        .rbrace = token(.right_brace),
    }));

    const BlockExpr = struct {
        lbrace: void,
        statements: []const *ast.Statement,
        rbrace: void,
    };

    fn mapBlockExpr(from: BlockExpr) []const *ast.Statement {
        return from.statements;
    }
});

pub const Primary = Rule(*ast.Expression, struct {
    // primary  ::= NUM | IDENTIFIER | ( expr ) | '{' { STATEMENTS }+ '}' | FUNCTION_CALL
    pub const parser = first(*ast.Expression, "factor", &.{
        mapAlloc(*ast.NumberLiteral, ast.Expression, mapNumber, Number.parser),
        mapAlloc(*ast.FunctionCall, ast.Expression, mapFunctionCall, FunctionCall.parser),
        mapAlloc(*ast.Identifier, ast.Expression, mapIdentifier, Identifier.parser),
        mapAlloc([]const *ast.Statement, ast.Expression, mapBlock, Block.parser),
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

    fn mapBlock(from: []const *ast.Statement) ast.Expression {
        return .{
            .block = from,
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

pub const Unary = Rule(*ast.Expression, struct {
    pub const parser = first(*ast.Expression, "unary expression", &.{
        Primary.parser,
        mapAlloc(*ast.UnaryExpression, ast.Expression, mapUnaryExpr, unaryParser),
    });

    const unaryParser = mapAlloc(UnaryParse, ast.UnaryExpression, mapUnary, sequence(UnaryParse, "unary expression", &.{
        .operator = first(ast.UnaryOp, "unary operator", &.{
            id(.bang, ast.UnaryOp.op_not),
            id(.minus, ast.UnaryOp.op_negate)
        }),
        .expression = Unary.parser,
    }));

    const UnaryParse = struct {
        operator: ast.UnaryOp,
        expression: *ast.Expression,
    };

    fn mapUnary(from: UnaryParse) ast.UnaryExpression {
        return .{
            .op = from.operator,
            .rhs = from.expression,
        };
    }

    fn mapUnaryExpr(from: *ast.UnaryExpression) ast.Expression {
        return .{
            .unary_expression = from
        };
    }
});

pub const Multaplicative = Rule(*ast.Expression, struct {
    // multaplicative ::= unary { ( * | / ) unary } *
    pub const parser = associativeBinOpParser("multaplicative expression", Unary.parser, first(ast.BinOp, "product", &.{
        id(.star, ast.BinOp.op_mul),
        id(.fslash, ast.BinOp.op_div)
    }));
});

pub const Addative = Rule(*ast.Expression, struct {
    // addative ::= term { ( + | - ) term } *
    pub const parser = associativeBinOpParser("addative expression", Multaplicative.parser, first(ast.BinOp, "addition", &.{
        id(.plus, ast.BinOp.op_plus),
        id(.minus, ast.BinOp.op_minus)
    }));
});

pub const Relational = Rule(*ast.Expression, struct {
    // relationl ::= addative { ( + | - ) addative } *
    pub const parser = associativeBinOpParser("relational expression", Addative.parser, first(ast.BinOp, "relational comparison", &.{
        id(.less_than_equals, ast.BinOp.op_lt_eq),
        id(.less_than, ast.BinOp.op_lt),
        id(.greater_than_equals, ast.BinOp.op_gt_eq),
        id(.greater_than, ast.BinOp.op_gt),
    }));
});

pub const Equality = Rule(*ast.Expression, struct {
    // equality ::= relationl { ( + | - ) relationl } *
    pub const parser = associativeBinOpParser("equality expression", Relational.parser, first(ast.BinOp, "equality comparison", &.{
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

pub const Assignment = Rule(*ast.Assignment, struct {
    // assignment ::= IDENTIFIER = expression
    pub const parser = mapAlloc(AssignmentParse, ast.Assignment, mapAssignment, sequence(AssignmentParse, "assignment", &.{
        .identifier = Identifier.parser,
        .equals = token(.assignment),
        .expression = Expression.parser,
        .semicolon = token(.semicolon),
    }));

    const AssignmentParse = struct {
        identifier: *ast.Identifier,
        equals: void,
        expression: *ast.Expression,
        semicolon: void,
    };

    fn mapAssignment(from: AssignmentParse) ast.Assignment {
        return .{
            .identifier  = from.identifier,
            .expression = from.expression,
        };
    }
});

pub const Definition = Rule(*ast.Definition, struct {
    // definition ::= LET IDENTIFIER : TYPE = expression
    pub const parser = mapAlloc(DefinitionParse, ast.Definition, mapDefinition, sequence(DefinitionParse, "definition", &.{
        .decl = first(DeclType, "declaration", &.{
            id(.kwd_let, DeclType.let),
            id(.kwd_mut, DeclType.mut),
        }),
        .identifier = Identifier.parser,
        .colon = token(.colon),
        .type = TypeAssociation.parser,
        .equals = token(.assignment),
        .expression = Expression.parser,
        .semicolon = token(.semicolon),
    }));

    const DefinitionParse = struct {
        decl: DeclType,
        identifier: *ast.Identifier,
        colon: void,
        type: *ast.TypeAssociation,
        equals: void,
        expression: *ast.Expression,
        semicolon: void,
    };

    fn mapDefinition(from: DefinitionParse) ast.Definition {
        return .{
            .identifier  = from.identifier,
            .type = from.type,
            .expression = from.expression,
            .mutable = from.decl == .mut,
        };
    }

    const DeclType = enum {
        let, mut,
    };
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

pub const YieldStatement = Rule(*ast.Expression, struct {
    pub const parser = mapValue(YieldParse, *ast.Expression, mapYield, sequence(YieldParse, "yield statement", &.{
        .yield = token(.kwd_yield),
        .expression = Expression.parser,
        .semicolon = token(.semicolon),
    }));

    const YieldParse = struct {
        yield: void,
        expression: *ast.Expression,
        semicolon: void,
    };

    fn mapYield(from: YieldParse) *ast.Expression {
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

pub const While = Rule(*ast.WhileLoop, struct {
    pub const parser = mapAlloc(WhileParse, ast.WhileLoop, mapWhileLoop, sequence(WhileParse, "while loop", &.{
        .whilekwd = token(.kwd_while),
        .lparen = token(.left_paren),
        .expression = Expression.parser,
        .rparen = token(.right_paren),
        .lbrace = token(.left_brace),
        .statements = atLeast(*ast.Statement, 0, "statements", Statement.parser),
        .rbrace = token(.right_brace),
    }));

    const WhileParse = struct {
        whilekwd: void,
        lparen: void,
        expression: *ast.Expression,
        rparen: void,
        lbrace: void,
        statements: []const *ast.Statement,
        rbrace: void,
    };

    fn mapWhileLoop(from: WhileParse) ast.WhileLoop {
        return .{
            .expr = from.expression,
            .statements = from.statements,
        };
    }
});

pub const Statement = Rule(*ast.Statement, struct {
    pub const parser = first(*ast.Statement, "statement", &.{
        mapAlloc(*ast.Definition, ast.Statement, mapDefinition, Definition.parser),
        mapAlloc(*ast.Assignment, ast.Statement, mapAssignment, Assignment.parser),
        mapAlloc(*ast.FunctionCall, ast.Statement, mapFunctionCall, FunctionCallStatement.parser),
        mapAlloc(*ast.Expression, ast.Statement, mapYield, YieldStatement.parser),
        mapAlloc(?*ast.Expression, ast.Statement, mapReturn, ReturnStatement.parser),
        mapAlloc(*ast.IfChain, ast.Statement, mapIfChain, IfChain.parser),
        mapAlloc(*ast.WhileLoop, ast.Statement, mapWhileLoop, While.parser),
    });

    fn mapDefinition(from: *ast.Definition) ast.Statement {
        return .{
            .definition = from,
        };
    }

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

    fn mapYield(from: *ast.Expression) ast.Statement {
        return .{
            .yield = from,
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

    fn mapWhileLoop(from: *ast.WhileLoop) ast.Statement {
        return .{
            .whileLoop = from,
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
