const std = @import("std");
const ast = @import("ast.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const SyntaxError = @import("syntax_error.zig").SyntaxError;
const Context = @import("combinators.zig").Context;
const ErrorAccumulator = @import("combinators.zig").ErrorAccumulator;

const visitor = @import("visitor.zig");
const parseProgram = @import("grammar.zig").parser;

pub const Parse = struct {
    allocator: *std.mem.Allocator,
    result: Result,

    const Self = @This();
    const Result = union(enum) {
        ok: *ast.Program,
        fail: []const SyntaxError
    };

    pub fn init(allocator: *std.mem.Allocator, result: Result) Self {
        return .{
            .allocator = allocator,
            .result = result,
        };
    }

    pub fn deinit(self: *Self) void {
        switch (self.result) {
            .ok => |program| {

                visitor.visit(*Self, self, program, &.{
                    .visitNumberLiteral = NodeDeallocator(ast.NumberLiteral),
                    .visitIdentifier = NodeDeallocator(ast.Identifier),
                    .visitExpression = NodeDeallocator(ast.Expression),
                    .visitDefinition = NodeDeallocator(ast.Definition),
                    .visitProgram = null,
                });
            },
            .fail => |errors| {
                self.allocator.free(errors);
            }
        }
    }

    fn NodeDeallocator(comptime NodeType: type) fn(parse: *Self, node: *const NodeType) void {
        const Local = struct {
            fn visit(self: *Self, node: *const NodeType) void {
                self.allocator.destroy(node);
            }
        };

        return Local.visit;
    }
};

pub const Parser = struct {
    pub fn parse(allocator: *std.mem.Allocator, source: []const u8) !Parse {
        var tokenizer = try Tokenizer.tokenize(allocator, source);
        var iterator = tokenizer.iterator();
        var err_accumulator = ErrorAccumulator.init(allocator);

        defer {
            // Free all tokens, all we want is the ast
            tokenizer.deinit();

            // Free error accumulator, we either empty it or drop errors
            err_accumulator.deinit();
        }

        var context: Context = .{
            .allocator = allocator,
            .iterator =  &iterator,
            .errorHandler = &err_accumulator
        };

        const parser_result = try parseProgram(&context);
        switch (parser_result) {
            .value => |value| {
                return Parse.init(allocator, .{
                    .ok = value,
                });
            },
            else => {
                return Parse.init(allocator, .{
                    .fail = err_accumulator.errors.toOwnedSlice(),
                });
            }
        }
    }
};
