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
        invalid_token: struct {
            range: []const u8,
        },
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

    pub fn format(self: *const SyntaxError, writer: anytype) !void {
        switch (self.type) {
            .invalid_token => |err| {
                try writer.print("[line {}:{}] invalid token: '{s}'", .{ self.line, self.column(), err.range });
            },
            .invalid_number_format => |err| {
                try writer.print("[line {}:{}] invalid number format: '{s}'", .{ self.line, self.column(), err.range });
            },
            .unexpected_token => |err| {
                try writer.print("[line {}:{}] expected: '{s}', found: '{s}'", .{ self.line, self.column(), Token.description(err.expected), err.found });
            },
            .unexpected_eof => |err| {
                try writer.print("[line {}:{}] unexpected end of source, expected: '{s}'", .{ self.line, self.column(), Token.description(err.expected) });
            },
            .expected_sequence => |err| {
                try writer.print("[line {}:{}] incomplete: {s}", .{ self.line, self.column(), err.description });
            },
            .unmatched_set => |err| {
                try writer.print("[line {}:{}] expected: {s}", .{ self.line, self.column(), err.description });
            }
        }
    }
};
