const std = @import("std");

const tokens = @import("token.zig");
const Token = tokens.Token;
const Id = Token.Id;

const Scanner = @import("scanner.zig").Scanner;
const types = @import ("../types.zig");

pub const Tokenizer = struct {
    allocator: *std.mem.Allocator,
    source: []const u8,
    tokens: std.ArrayList(*Token),
    err: ?Error,

    pub const Error = struct {
        line: usize,
        offset: usize,

        pub fn init(token: *Token, source: []const u8) Error {
            return .{
                .line = token.line,
                .offset = @ptrToInt(token.range.ptr) - @ptrToInt(source.ptr),
            };
        }
    };

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
                    err = .{
                        .line = e.line,
                        .offset = e.offset,
                    };

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
};

test "tokenize: parse tokens success" {
    var allocator = std.testing.allocator;
    var tokenizer = try Tokenizer.tokenize(allocator, "{$ let i = 2 + 6512 $}");
    defer { tokenizer.deinit(); }

    try std.testing.expectEqual(Token.Id { .number_literal = 2 }, tokenizer.tokens.items[4].type);
    try std.testing.expectEqual(Token.Id { .number_literal = 6512 }, tokenizer.tokens.items[6].type);

    try std.testing.expectEqual(tokenizer.err, null);
    try std.testing.expectEqual(@intCast(usize, 8), tokenizer.tokens.items.len);
}
