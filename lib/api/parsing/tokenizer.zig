const std = @import("std");

const tokens = @import("token.zig");
const Token = tokens.Token;
const Id = Token.Id;

const Scanner = @import("scanner.zig").Scanner;
const types = @import ("../types.zig");

const syntax_error = @import("syntax_error.zig");
const SyntaxError = syntax_error.SyntaxError;

pub const Tokenizer = struct {
    allocator: *std.mem.Allocator,
    tokens: std.ArrayList(*Token),
    err: ?SyntaxError,

    const Self = @This();

    pub fn tokenize(allocator: * std.mem.Allocator, source: []const u8) !Self {
        var scanner = try Scanner.initUtf8(allocator, source);
        var list = std.ArrayList(*Token).init(allocator);
        var err: ?SyntaxError = null;

        while (true) {
            const result = try scanner.next();
            switch (result) {
                .ok => |token| {
                    if (try Self.evaluate(token)) |e| {
                        err = e;
                        break;
                    } else {
                        try list.append(token);
                        if (token.type == .eof) {
                            break;
                        }
                    }
                },
                .fail => |e| {
                    err = e;
                    break;
                },
            }
        }

        return Self {
            .allocator = allocator,
            .tokens = list,
            .err = err,
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        for (self.tokens.items) |token| {
            self.allocator.destroy(token);
        }

        self.tokens.deinit();
    }

    fn evaluate(token: *Token) !?SyntaxError {
        switch (token.type) {
            .number_literal => |*value| {
                value.* = types.Numeric.parse(token.range) catch {
                    return syntax_error.invalidNumberFormat(token);
                };
            },
            .identifier => |*value| {
                value.* = token.range;
            },
            else => {
                // Nothing to evaluate
            },
        }

        return null;
    }

    pub fn iterator(self: *Tokenizer) TokenIterator {
        return TokenIterator.init(self.*);
    }
};

pub const TokenIterator = struct {
    tokenizer: Tokenizer,
    offset: usize,

    const Self = @This();

    pub fn init(tokenizer: Tokenizer) Self {
        return .{
            .tokenizer = tokenizer,
            .offset = 0
        };
    }

    pub fn next(self: *TokenIterator) ?*Token {
        if (self.current().type != .eof) {
            defer { self.offset += 1; }
            return self.tokenizer.tokens.items[self.offset];
        } else {
            return null;
        }
    }

    pub fn current(self: *TokenIterator) *Token {
        std.debug.assert(self.offset < self.tokenizer.tokens.items.len);
        return self.tokenizer.tokens.items[self.offset];
    }
};

test "tokenize: parse tokens success" {
    var allocator = std.testing.allocator;
    var tokenizer = try Tokenizer.tokenize(allocator, "let i = 0o2 + 6512.3");
    defer { tokenizer.deinit(); }

    try std.testing.expectEqual(Token.Value { .number_literal = .{ .int = 2, } }, tokenizer.tokens.items[3].type);
    try std.testing.expectEqual(Token.Value { .number_literal = .{ .float = 6512.3, } }, tokenizer.tokens.items[5].type);

    try std.testing.expect(tokenizer.err == null);
    try std.testing.expectEqual(@intCast(usize, 7), tokenizer.tokens.items.len);
}
