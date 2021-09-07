const std = @import("std");

const tokens = @import("token.zig");
const Token = tokens.Token;
const Id = Token.Id;

const Result = @import("../result.zig").Result;
const SyntaxError = @import("syntax_error.zig").SyntaxError;

const verbose_logging = false;

pub const Scanner = struct {
    allocator: *std.mem.Allocator,
    iterator: std.unicode.Utf8Iterator,
    source: []const u8,
    current_line: usize,
    buffered_token: ?*Token,

    const Self = @This();

    const ScannerError = error {
        invalid_state,
        unimplemented, // TODO: Remove this
        unimplemented_error, // TODO: Remove this
    };

    const Keyword = struct {
        pub const keywords = std.ComptimeStringMap(Token.Value, .{
            .{ "let", .kwd_let },
        });

        pub fn asID(name: []const u8) ?Token.Value {
            return keywords.get(name);
        }
    };

    pub fn initUtf8(allocator: *std.mem.Allocator, source: []const u8) !Self {
        const view = try std.unicode.Utf8View.init(source);
        return Self {
            .allocator = allocator,
            .iterator = view.iterator(),
            .source = source,
            .current_line = 1,
            .buffered_token = null,
        };
    }

    pub fn next(self: *Self) !Result(*Token, SyntaxError) {
        if (verbose_logging) {
            std.debug.print("\n[Lex] === Begin scan ===\n", .{});
        }

        const result = try self.nextInternal();

        if (verbose_logging) {
            switch (result) {
                .ok => |token| {
                    std.debug.print("[Lex] Got lex: {}\n", .{token.type});
                },
                .fail => {
                    std.debug.print("[Lex] Got error\n", .{});
                }
            }
        }

        return result;
    }

    fn nextInternal(self: *Self) !Result(*Token, SyntaxError) {

        // If we've pre-buffered something, yield it now
        if (self.buffered_token) |value| {
            self.buffered_token = null;
            return Result(*Token, SyntaxError) {
                .ok = value,
            };
        }

        const token = try self.allocator.create(Token);
        token.type = .eof;

        errdefer { self.allocator.destroy(token); }

        var state: union(enum) {
            capture_source,
            capture_identifier,
            capture_number,
        } = .capture_source;

        // The offset to where this capture started
        var tok_start = self.iterator.i;

        // An offset to where this capture will end. Will be added to the final
        // token range, and can be modified to account for ex. pre-buffered tokens
        var tok_end_backtrack = @intCast(usize, 0);

        while (self.iterator.nextCodepointSlice()) |slice| {

            if (verbose_logging) {
                std.debug.print("[Lex] State: {}\n", .{state});
            }

            switch (state) {
                .capture_source => {
                    switch (slice[0]) {
                        '\t', ' ', '\x0b', '\x0c' => {
                            // Whitespace. Skip it
                            tok_start += 1;
                        },
                        '\n' => {
                            // Line break, skip it
                            self.current_line += 1;
                            tok_start += 1;
                        },
                        '\r' => {
                            // Line break, check for a \r\n style break and skip past it
                            const nextSlice = self.iterator.peek(1);
                            if (nextSlice.len == 1 and '\n' == nextSlice[0]) {
                                self.iterator.i += 1;
                                tok_start += 1;
                            }

                            tok_start += 1;
                            self.current_line += 1;
                        },
                        '=' => {
                            token.type = .assignment;
                            break;
                        },
                        '+' => {
                            token.type = .plus;
                            break;
                        },
                        '-' => {
                            token.type = .minus;
                            break;
                        },
                        '*' => {
                            token.type = .star;
                            break;
                        },
                        '0'...'9' => {
                            state = .capture_number;
                            token.type = .{
                                .number_literal = 0
                            };
                        },
                        'a'...'z', 'A'...'Z', '_' => {
                            // The beginning of an identifier
                            state = .capture_identifier;
                            token.type = .identifier;
                        },
                        else => {
                            std.debug.print("[Lex] Got unimplemented source token: {s}\n", .{slice});
                            return ScannerError.unimplemented;
                        },
                    }
                },
                .capture_identifier => {
                    switch (slice[0]) {
                        'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                            // Noop, capture and loop
                        },
                        else => {
                            // End of the identifier. Backup and handle this next call
                            self.backtrack(slice);
                            break;
                        }
                    }
                },
                .capture_number => {
                    switch (slice[0]) {
                        '0'...'9' => {
                            // Noop, capture and loop
                        },
                        else => {
                            // End of the number. Backup and handle this next call
                            self.backtrack(slice);
                            break;
                        }
                    }
                }
            }
        } else {
            // EOF while scanning token
            switch (state) {
                else => {
                    // Noop, state is good to exit this way
                    // (ex. scanning a non-empty number/template/identifier)
                }
            }
        }

        // Assign the range according to any backtrack adjustments
        token.range = self.source[tok_start..self.iterator.i - tok_end_backtrack];
        token.offset = tok_start;
        token.line = self.current_line;

        // Fixup for reading nothing at all
        if (self.iterator.i == tok_start) {
            token.type = .eof;
        }

        // Fixup for IDs that are actually kwds
        if (token.type == .identifier) {
            if (verbose_logging) {
                std.debug.print("[Lex] Got identifier: {s}\n", .{token.range});
            }

            if (Keyword.asID(token.range)) |id| {
                token.type = id;

                if (verbose_logging) {
                    std.debug.print("[Lex] Substituting id for kwd: {}\n", .{id});
                }
            }
        }

        return Result(*Token, SyntaxError) {
            .ok = token
        };
    }

    fn backtrack(self: *Scanner, slice: []const u8) void {
        self.iterator.i -= slice.len;
    }

    fn seek(self: *Scanner, position: usize) void {
        self.iterator.i = position;
    }
};

// Tests

fn expectId(id: Token.Id, scanner: *Scanner) !void {
    const result = try scanner.next();
    switch (result) {
        .ok => |token| {
            try std.testing.expectEqual(id, token.type);
            scanner.allocator.destroy(token);
        },
        else => {
            try std.testing.expect(false);
        }
    }
}

fn expectIdRange(id: Token.Id, str: []const u8, scanner: *Scanner) !void {
    const result = try scanner.next();
    switch (result) {
        .ok => |token| {
            try std.testing.expectEqual(id, token.type);
            try std.testing.expectEqualStrings(str, token.range);
            scanner.allocator.destroy(token);
        },
        else => {
            try std.testing.expect(false);
        }
    }
}

fn expectTemplate(str: []const u8, scanner: *Scanner) !void {
    try expectIdRange(.template, str, scanner);
}

fn expectIdentifier(str: []const u8, scanner: *Scanner) !void {
    try expectIdRange(.identifier, str, scanner);
}

test "scan: empty string" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "");
    try expectId(.eof, &scanner);
}

test "scan: identifier" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "hello_world");
    try expectIdentifier("hello_world", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: skip whitespace and new lines" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "\t\n\nabc\r\n def \t\n");
    try expectIdentifier("abc", &scanner);
    try expectIdentifier("def", &scanner);
    try expectId(.eof, &scanner);
    try std.testing.expectEqual(@intCast(usize, 5), scanner.current_line);
}


test "scan: whitespace only" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "\t\n ");
    try expectId(.eof, &scanner);
}

test "scan: simple assignment" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "x= y z =w");
    try expectIdentifier("x", &scanner);
    try expectId(.assignment, &scanner);
    try expectIdentifier("y", &scanner);
    try expectIdentifier("z", &scanner);
    try expectId(.assignment, &scanner);
    try expectIdentifier("w", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: simple number" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, " x=35 z = 0");
    try expectIdentifier("x", &scanner);
    try expectId(.assignment, &scanner);
    try expectIdRange(.number_literal, "35", &scanner);
    try expectIdentifier("z", &scanner);
    try expectId(.assignment, &scanner);
    try expectIdRange(.number_literal, "0", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: simple addition" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "x=35 z = x + 1");
    try expectIdentifier("x", &scanner);
    try expectId(.assignment, &scanner);
    try expectIdRange(.number_literal, "35", &scanner);
    try expectIdentifier("z", &scanner);
    try expectId(.assignment, &scanner);
    try expectIdentifier("x", &scanner);
    try expectId(.plus, &scanner);
    try expectIdRange(.number_literal, "1", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: simple arithmetic" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "3*-z+2--1");
    try expectIdRange(.number_literal, "3", &scanner);
    try expectId(.star, &scanner);
    try expectId(.minus, &scanner);
    try expectIdentifier("z", &scanner);
    try expectId(.plus, &scanner);
    try expectIdRange(.number_literal, "2", &scanner);
    try expectId(.minus, &scanner);
    try expectId(.minus, &scanner);
    try expectIdRange(.number_literal, "1", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: let kwds" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, " let letx let\nlet");
    try expectId(.kwd_let, &scanner);
    try expectIdentifier("letx", &scanner);
    try expectId(.kwd_let, &scanner);
    try expectId(.kwd_let, &scanner);
    try expectId(.eof, &scanner);
}
