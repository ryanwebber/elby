const std = @import("std");

const tokens = @import("token.zig");
const Token = tokens.Token;
const Id = Token.Id;

const Scanner = @import("scanner.zig").Scanner;
const Error = @import("../error.zig").SyntaxError;
const types = @import ("../types.zig");

pub const Tokenizer = struct {
    allocator: *std.mem.Allocator,
    source: []const u8,
    tokens: std.ArrayList(*Token),
    err: ?Error,

    const Self = @This();

    pub fn tokenize(allocator: *std.mem.Allocator, source: []const u8) !Self {
        var scanner = try Scanner.initUtf8(allocator, source);
        var list = std.ArrayList(*Token).init(allocator);
        var err: ?Error = null;

        while (true) {
            const result = try scanner.next();
            switch (result) {
                .ok => |token| {
                    if (try Self.evaluate(source, token)) |e| {
                        err = e;
                        break;
                    } else if (token.type == .eof) {
                        // Let's hide the EOF token from the parser. BUT this means
                        // we have to free it's memory now, since we won't have it in the list
                        allocator.destroy(token);
                        break;
                    } else {
                        try list.append(token);
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
            .source = source,
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

    fn evaluate(source: []const u8, token: *Token) !?Error {
        switch (token.type) {
            .number_literal => |*value| {
                value.* = types.parseNumber(token.range) catch {
                    return Error.init(token, source);
                };
            },
            else => {
                // Nothing to evaluate
            }
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
        if (self.offset < self.tokenizer.tokens.items.len) {
            defer { self.offset += 1; }
            return self.tokenizer.tokens.items[self.offset];
        } else {
            return null;
        }
    }
};

test "tokenize: parse tokens success" {
    var allocator = std.testing.allocator;
    var tokenizer = try Tokenizer.tokenize(allocator, "{$ let i = 2 + 6512 $}");
    defer { tokenizer.deinit(); }

    try std.testing.expectEqual(Token.Id { .number_literal = 2 }, tokenizer.tokens.items[4].type);
    try std.testing.expectEqual(Token.Id { .number_literal = 6512 }, tokenizer.tokens.items[6].type);

    try std.testing.expectEqual(@as(@TypeOf(tokenizer.err), null), tokenizer.err);
    try std.testing.expectEqual(@intCast(usize, 8), tokenizer.tokens.items.len);
}
