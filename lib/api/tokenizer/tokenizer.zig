const std = @import("std");

const tokens = @import("token.zig");
const Token = tokens.Token;
const Id = Token.Id;

const Result = @import("../result.zig").Result;

const verbose_logging = true;

pub const Scanner = struct {
    allocator: *std.mem.Allocator,
    iterator: std.unicode.Utf8Iterator,
    source: []const u8,
    current_line: usize,
    in_template: bool,
    buffered_lexeme: ?*Lexeme,

    const Self = @This();

    pub const Lexeme = struct {
        range: []const u8,
        type: Token.Id
    };

    pub const Error = struct {
        line: usize,
        offset: usize,
    };

    const ScannerError = error {
        invalid_state,
        unimplemented, // TODO: Remove this
        unimplemented_error, // TODO: Remove this
    };

    pub fn initUtf8(allocator: *std.mem.Allocator, source: []const u8) !Self {
        const view = try std.unicode.Utf8View.init(source);
        return Self {
            .allocator = allocator,
            .iterator = view.iterator(),
            .source = source,
            .current_line = 1,
            .in_template = true,
            .buffered_lexeme = null,
        };
    }

    pub fn next(self: *Self) !Result(*Lexeme, *Error) {
        if (verbose_logging) {
            std.debug.print("\n[Lex] === Begin scan ===\n", .{});
        }

        const result = try self.nextInternal();

        if (verbose_logging) {
            switch (result) {
                .ok => |lexeme| {
                    std.debug.print("[Lex] Got lex: {}\n", .{lexeme.type});
                },
                .fail => {
                    std.debug.print("[Lex] Got error\n", .{});
                }
            }
        }

        return result;
    }

    fn nextInternal(self: *Self) !Result(*Lexeme, *Error) {

        // If we've pre-buffered something, yield it now
        if (self.buffered_lexeme) |value| {
            self.buffered_lexeme = null;
            return Result(*Lexeme, *Error) {
                .ok = value,
            };
        }

        const lexeme = try self.allocator.create(Lexeme);
        lexeme.type = .eof;

        errdefer { self.allocator.destroy(lexeme); }

        var state: union(enum) {
            capture_template,
            capture_template_break: usize,
            capture_source,
            capture_source_break,
            capture_identifier,
        } = if (self.in_template) .capture_template else .capture_source;

        // The offset to where this capture started
        const tok_start = self.iterator.i;

        // An offset to where this capture will end. Will be added to the final
        // token range, and can be modified to account for ex. pre-buffered tokens
        var tok_end_backtrack = @intCast(usize, 0);

        while (self.iterator.nextCodepointSlice()) |slice| {

            if (verbose_logging) {
                std.debug.print("[Lex] State: {}\n", .{state});
            }

            switch (state) {
                .capture_template => {
                    lexeme.type = .template;
                    switch (slice[0]) {
                        '{' => {
                            state = .{
                                .capture_template_break = self.iterator.i - slice.len,
                            };
                        },
                        else => {
                            // noop, capure and loop
                        }
                    }
                },
                .capture_template_break => |position| {
                    switch (slice[0]) {
                        '$' => {
                            // We're now scanning source code
                            self.in_template = false;

                            // We now also know the next lexeme
                            const buffered_lexeme = try self.allocator.create(Lexeme);
                            buffered_lexeme.type = .source_block_open;
                            buffered_lexeme.range = self.iterator.bytes[position..self.iterator.i];
                            self.buffered_lexeme = buffered_lexeme;

                            // Adjust the final template range to exclude the pre-buffered token
                            tok_end_backtrack = buffered_lexeme.range.len;

                            // break off, we still yield a template id
                            break;
                        },
                        else => {
                            // Not actually exiting the template, false alarm
                            state = .capture_template;
                        }
                    }
                },
                .capture_source => {
                    switch (slice[0]) {
                        '\t', ' ', '\x0b', '\x0c' => {
                            // Whitespace. Skip it
                        },
                        '$' => {
                            // Maybe the start of a source break
                            state = .capture_source_break;
                        },
                        'a'...'z', 'A'...'Z', '_' => {
                            // The beginning of an identifier
                            lexeme.type = .identifier;
                            state = .capture_identifier;
                        },
                        else => {
                            std.debug.print("[Lex] Got unimplemented source token: {s}\n", .{slice});
                            return ScannerError.unimplemented;
                        },
                    }
                },
                .capture_source_break => {
                    switch (slice[0]) {
                        '}' => {
                            // Transition to scanning template
                            self.in_template = true;
                            lexeme.type = .source_block_close;
                            break;
                        },
                        else => {
                            // Invalid char sequence
                            return ScannerError.unimplemented_error;
                        }
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
                }
            }
        } else {
            // EOF while scanning token
            switch (state) {
                .capture_template_break => {
                    // Didn't completely break from tempate capture, this is ok
                    lexeme.type = .template;
                },
                .capture_source_break => {
                    // Error, got only a partial token match in a source block for ending it ('$')
                    return ScannerError.unimplemented_error;
                },
                else => {
                    // Noop, state is good to exit this way
                }
            }
        }

        // Fixup for reading nothing at all
        if (self.iterator.i == tok_start) {
            lexeme.type = .eof;
        }

        lexeme.range = self.source[tok_start..self.iterator.i - tok_end_backtrack];

        return Result(*Lexeme, *Error) {
            .ok = lexeme
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
        .ok => |lexeme| {
            try std.testing.expectEqual(id, lexeme.type);
            scanner.allocator.destroy(lexeme);
        },
        else => {
            try std.testing.expect(false);
        }
    }
}

fn expectIdRange(id: Token.Id, str: []const u8, scanner: *Scanner) !void {
    const result = try scanner.next();
    switch (result) {
        .ok => |lexeme| {
            try std.testing.expectEqual(id, lexeme.type);
            try std.testing.expectEqualStrings(str, lexeme.range);
            scanner.allocator.destroy(lexeme);
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

test "scan: utf-8 source + eof" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "  { \n\t\r\nhello \u{1F30E}");
    try expectTemplate("  { \n\t\r\nhello 🌎", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: template + source open + identifier" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "hello  {$world");
    try expectTemplate("hello  ", &scanner);
    try expectId(.source_block_open, &scanner);
    try expectIdentifier("world", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: template ending with half break" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "hello{");
    try expectTemplate("hello{", &scanner);
    try expectId(.eof, &scanner);
}

test "scan: simple source block (no ws)" {
    var allocator = std.testing.allocator;
    var scanner = try Scanner.initUtf8(allocator, "hello{$world$}!");
    try expectTemplate("hello", &scanner);
    try expectId(.source_block_open, &scanner);
    try expectIdentifier("world", &scanner);
    try expectId(.source_block_close, &scanner);
    try expectTemplate("!", &scanner);
    try expectId(.eof, &scanner);
}
