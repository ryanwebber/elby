const std = @import("std");
const ast = @import("ast.zig");
const types = @import("../types.zig");
const combinators = @import("combinators.zig");

const parse_number = combinators.map(types.Number, ast.NumberLiteral, combinators.token(.number_literal), mapNumber);
fn mapNumber(from: f64) ast.NumberLiteral {
    return .{
        .value = from
    };
}

pub const RootProduction = combinators.Production(ast.NumberLiteral);
pub const parser = parse_number;

// Testing

const Token = @import("token.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TokenIterator = @import("tokenizer.zig").TokenIterator;
const SystemError = @import("../error.zig").SystemError;
const ErrorAccumulator = combinators.ErrorAccumulator;

fn tryParse(allocator: *std.mem.Allocator, tokens: []const *Token) !RootProduction {
    var list = std.ArrayList(*Token).init(allocator);
    for(tokens) |token| {
        const token_copy = try allocator.create(Token);
        token_copy.* = token.*;
        try list.append(token_copy);
    }

    var tokenizer: Tokenizer = .{
        .allocator = allocator,
        .tokens = list,
        .err = null
    };

    var iterator = TokenIterator.init(tokenizer);
    var err_accumulator = ErrorAccumulator.init(allocator);

    defer {
        tokenizer.deinit();
        err_accumulator.deinit();
    }

    var context: combinators.Context = .{
        .allocator = allocator,
        .iterator =  &iterator,
        .errorHandler = &err_accumulator
    };

    const parser_result = parser(&context);
    try std.testing.expectEqual(err_accumulator.errors.items.len, 0);
    return parser_result;
}

fn makeNumberLiteral(comptime value: types.Number) Token {
    return .{
        .type = .{
            .number_literal = value
        },
        .range = "",
        .line = 0,
        .offset = 0,
    };
}

fn makeEof() Token {
    return .{
        .type = .eof,
        .range = "",
        .line = 0,
        .offset = 0,
    };
}

test "sanity check" {
    std.debug.print("\n\n\n", .{});
    var allocator = std.testing.allocator;
    var result = try tryParse(allocator, &.{
        &makeNumberLiteral(5),
        &makeEof(),
    });

    const expected_result = RootProduction {
        .value = ast.NumberLiteral {
            .value = 5,
        }
    };

    try std.testing.expectEqual(expected_result, result);
}
