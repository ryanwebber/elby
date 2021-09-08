const ast = @import("ast.zig");

pub fn Visitor(comptime Context: type) type {
    return struct {
        visitNumberLiteral: ?fn(context: Context, node: *const ast.NumberLiteral) void,
        visitIdentifier: ?fn(context: Context, node: *const ast.Identifier) void,
        visitExpression: ?fn(context: Context, node: *const ast.Expression) void,
        visitDefinition: ?fn(context: Context, node: *const ast.Definition) void,
        visitProgram: ?fn(context: Context, node: *const ast.Program) void,
    };
}

pub fn visit(comptime Context: type, ctx: Context, prg: *const ast.Program, vst: *const Visitor(Context)) void {
    const Functions = struct {

        fn visitNumberLiteral(context: Context, node: *const ast.NumberLiteral, visitor: *const Visitor(Context)) void {
            if (visitor.visitNumberLiteral) |function| {
                function(context, node);
            }
        }

        fn visitIdentifier(context: Context, node: *const ast.Identifier, visitor: *const Visitor(Context)) void {
            if (visitor.visitIdentifier) |function| {
                function(context, node);
            }
        }

        fn visitExpression(context: Context, node: *const ast.Expression, visitor: *const Visitor(Context)) void {
            switch (node.*) {
                .number_literal => |number_literal| {
                    visitNumberLiteral(context, number_literal, visitor);
                },
                .identifier => |identifier| {
                    visitIdentifier(context, identifier, visitor);
                },
                .binary_expression => |binexpr| {
                    visitExpression(context, binexpr.lhs, visitor);
                    visitExpression(context, binexpr.rhs, visitor);
                },
            }

            if (visitor.visitExpression) |function| {
                function(context, node);
            }
        }

        fn visitDefinition(context: Context, node: *const ast.Definition, visitor: *const Visitor(Context)) void {
            visitIdentifier(context, node.identifier, visitor);
            visitExpression(context, node.expression, visitor);
            if (visitor.visitDefinition) |function| {
                function(context, node);
            }
        }

        fn visitProgram(context: Context, node: *const ast.Program, visitor: *const Visitor(Context)) void {
            visitDefinition(context, node, visitor);
            if (visitor.visitProgram) |function| {
                function(context, node);
            }
        }
    };

    Functions.visitProgram(ctx, prg, vst);
}
