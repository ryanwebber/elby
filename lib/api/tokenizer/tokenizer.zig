const std = @import("std");

const tokens = @import("token.zig");
const Token = tokens.Token;
const Id = Token.Id;

const Scanner = @import("scanner.zig").Scanner;

pub const Tokenizer = struct {
    allocator: *std.mem.Allocator,
    tokens: std.ArrayList(*Token),
    err: ?Error,

    pub const Error = struct {
        line: usize,
        offset: usize,
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
                    if (try Self.evaluate(token)) |e| {
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

    fn evaluate(token: *Token) !?Error {
        if (token.lineno == 0) {
            return null;
        }

        return null;
    }
};

test "tokenize: parse tokens success" {
    var allocator = std.testing.allocator;
    var tokenizer = try Tokenizer.tokenize(allocator, "{$ let i = 9 + 1 $}");
    defer { tokenizer.deinit(); }

    try std.testing.expectEqual(tokenizer.err, null);
    try std.testing.expectEqual(@intCast(usize, 8), tokenizer.tokens.items.len);
}
