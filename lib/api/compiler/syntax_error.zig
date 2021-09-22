const std = @import("std");
const Token = @import("token.zig").Token;

pub fn invalidNumberFormat(token: *Token) SyntaxError {
    return .{
        .line = token.line,
        .offset = token.offset,
        .type = .{
            .invalid_number_format = .{
                .range = token.range
            },
        },
    };
}

pub fn unexpectedToken(expected: Token.Id, found: *Token) SyntaxError {
    return .{
        .line = found.line,
        .offset = found.offset,
        .type = .{
            .unexpected_token = .{
                .expected = expected,
                .found = found.range,
            },
        },
    };
}

pub fn unexpectedEof(expected: Token.Id, position: *Token) SyntaxError {
    return .{
        .line = position.line,
        .offset = position.offset,
        .type = .{
            .unexpected_eof = .{
                .expected = expected,
            },
        },
    };
}

pub fn expectedSequence(description: []const u8, position: *Token) SyntaxError {
    return .{
        .line = position.line,
        .offset = position.offset,
        .type = .{
            .expected_sequence = .{
                .description = description,
            },
        },
    };
}

pub fn unmatchedSet(description: []const u8, position: *Token) SyntaxError {
    return .{
        .line = position.line,
        .offset = position.offset,
        .type = .{
            .unmatched_set = .{
                .description = description,
            },
        },
    };
}

pub const SyntaxError = struct {
    line: usize,
    offset: usize,

    type: union(enum) {
        invalid_number_format: struct {
            range: []const u8,
        },
        unexpected_token: struct {
            expected: Token.Id,
            found: []const u8,
        },
        unexpected_eof: struct {
            expected: Token.Id,
        },
        expected_sequence: struct {
            description: []const u8,
        },
        unmatched_set: struct {
            description: []const u8,
        }
    },

    fn column(self: *const SyntaxError) usize {
        return self.offset;
    }

    pub fn format(self: *const SyntaxError, buf: []u8) ![]const u8 {
        switch (self.type) {
            .invalid_number_format => |err| {
                return std.fmt.bufPrint(buf, "[line {}:{}] invalid number format: '{s}'", .{ self.line, self.column(), err.range });
            },
            .unexpected_token => |err| {
                return std.fmt.bufPrint(buf, "[line {}:{}] expected: '{s}', found: '{s}'", .{ self.line, self.column(),Token.description(err.expected), err.found });
            },
            .unexpected_eof => |err| {
                return std.fmt.bufPrint(buf, "[line {}:{}] unexpected end of source, expected: '{s}'", .{ self.line, self.column(),Token.description(err.expected) });
            },
            .expected_sequence => |err| {
                return std.fmt.bufPrint(buf, "[line {}:{}] incomplete: {s}", .{ self.line, self.column(),err.description });
            },
            .unmatched_set => |err| {
                return std.fmt.bufPrint(buf, "[line {}:{}] expected: {s}", .{ self.line, self.column(),err.description });
            }
        }
    }
};
