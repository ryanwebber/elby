const std = @import("std");
const tokens = @import("token.zig");

const Token = tokens.Token;
const TokenRef = tokens.TokeRef;

const new_line_terminators = [_][]const u8{
    "\r\n", "\n", "\r",
};

const whitespace_characters = [_]u8 {
    ' ', '\t', '\x0b', '\x0c'
};

const variable_length_tokens = .{
    .{
        .{
            .literal = "=",
            .token = Token.assignment
        },
        .{
            .literal = "==",
        }
    }
};

pub const Tokenizer = struct {
    allocator: *std.mem.Allocator,
    iterator: std.unicode.Utf8Iterator,
    source: []const u8,
    current_line: usize,

    const Self = @This();

    pub fn initUtf8(allocator: *std.mem.Allocator, source: []const u8) !Self {
        const view = try std.unicode.Utf8View.init(source);
        return Self {
            .allocator = allocator,
            .iterator = view.iterator(),
            .source = source,
            .current_line = 1,
        };
    }

    pub fn next(self: *Self) !*TokenRef {

        const tok_ref = try self.allocator.create(TokenRef);

        // Scan past whitespace
        loop: while (true) {
            const slice = self.iterator.peek(2);
            if (slice.len == 0) {
                break;
            }

            for (new_line_terminators) |terminator| {
                if (std.mem.startsWith(u8, slice, terminator)) {
                    self.current_line += 1;
                    self.iterator.i += terminator.len;
                    continue :loop;
                }
            }

            for (whitespace_characters) |c| {
                if (slice[0] == c) {
                    self.iterator.i += 1;
                    continue :loop;
                }
            }

            break;
        }

        const tok_start = self.current_offset();
        const tok_peek = self.iterator.peek(1);
        if (tok_peek.len > 0) {

        }

        while (self.iterator.nextCodepointSlice()) |_| {
            // Noop, reading to end of iterator currently
        }
        const tok_end = self.current_offset();

        tok_ref.lineno = self.current_line;

        if (tok_end > tok_start) {
            tok_ref.token = Token.identifier;
            tok_ref.range = self.source[tok_start..tok_end];
        } else {
            // EOF
            tok_ref.token = Token.eof;
            tok_ref.range = self.source[tok_end..tok_end];
        }

        return tok_ref;
    }

    fn current_offset(self: *Tokenizer) usize {
        return self.iterator.i;
    }
};

test "sanity check" {
    var allocator = std.testing.allocator;
    var tokenizer = try Tokenizer.initUtf8(allocator, "    \n\t\r\nhello\u{1F4A3}");
    var tok_ref = try tokenizer.next();

    try std.testing.expectEqual(@intCast(usize, 3), tok_ref.lineno);
    try std.testing.expectEqual(Token.identifier, tok_ref.token);
    try std.testing.expectEqualSlices(u8, "hello💣", tok_ref.range);

    allocator.destroy(tok_ref);
}
