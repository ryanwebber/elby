const std = @import("std");
const Token = @import("token.zig").Token;
const TokenIterator = @import("tokenizer.zig").TokenIterator;
const SystemError = @import("../error.zig").SystemError;

const deviations = @import("deviation.zig");
const types = @import("../types.zig");

pub const ErrorAccumulator = struct {
    errors: std.ArrayList(deviations.Deviation),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .errors = std.ArrayList(deviations.Deviation).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.errors.deinit();
    }

    pub fn push(self: *Self, err: deviations.Deviation) !void {
        try self.errors.append(err);
    }
};

pub const Context = struct {
    allocator: *std.mem.Allocator,
    iterator: *TokenIterator,
    errorHandler: *ErrorAccumulator
};

pub fn Production(comptime Value: type) type {
    return union(enum) {
        value: Value,
        err: deviations.Deviation,
    };
}

pub fn Parser(comptime Value: type) type {
    return fn(context: *Context) SystemError!Production(Value);
}

// Combinators

pub fn immediate(comptime value: anytype) Parser(@TypeOf(value)) {
    const ImmediateProduction = Production(@TypeOf(value));
    const Local = struct {
        fn parse(_: *Context) SystemError!ImmediateProduction {
            return ImmediateProduction {
                .value = value,
            };
        }
    };

    return Local.parse;
}

pub fn token(comptime expected_id: Token.Id) Parser(Token.valueType(expected_id)) {
    const TokenProduction = Production(Token.valueType(expected_id));
    const Local = struct {
        fn parse(context: *Context) SystemError!TokenProduction {
            const iterator = context.iterator;
            if (iterator.next()) |tok| {
                switch (tok.type) {
                    expected_id => |value| {
                        return TokenProduction {
                            .value = value,
                        };
                    },
                    else => {
                        return TokenProduction {
                            .err = deviations.static(iterator.current(), "Unexpected token: TODO"),
                        };
                    }
                }
            } else {
                return TokenProduction {
                    .err = deviations.static(iterator.current(), "Unexpected end of source"),
                };
            }
        }
    };

    return Local.parse;
}

pub fn expect(comptime Value: type, comptime parser: Parser(Value)) Parser(Value) {
    const Local = struct {
        fn parse(context: *Context) SystemError!Production(Value) {
            const result = try parser(context);
            switch (result) {
                .err => |err| {
                    try context.errorHandler.push(err);
                },
                else => {}
            }

            return result;
        }
    };

    return Local.parse;
}

pub fn map(
        comptime FromValue: type,
        comptime ToValue: type,
        parser: Parser(FromValue),
        mapFn: fn(from: FromValue) ToValue)Parser(ToValue) {
    const MappedProduction = Production(ToValue);
    const Local = struct {
        fn parse(context: *Context) SystemError!MappedProduction {
            switch (try parser(context)) {
                .value => |value| {
                    return MappedProduction {
                        .value = mapFn(value)
                    };
                },
                .err => |err| {
                    return MappedProduction {
                        .err = err
                    };
                }
            }
        }
    };

    return Local.parse;
}

/// Produces a struct with the same field names and order as the given one
/// but the types of each field are mapped to a Parser of the fields
/// original type
fn SequenceParseStruct(comptime TupleType: type) type {
    var new_fields: [std.meta.fields(TupleType).len]std.builtin.TypeInfo.StructField = undefined;
    inline for (std.meta.fields(TupleType)) |field, idx| {
        new_fields[idx] = .{
            .name = field.name,
            .alignment = 0,
            .is_comptime = false,
            .field_type = Parser(field.field_type),
            .default_value = null,
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &new_fields,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .is_tuple = false,
        }
    });
}

pub fn sequence(comptime ResultType: type, parsers: *const SequenceParseStruct(ResultType)) Parser(ResultType) {
    const SequenceProduction = Production(ResultType);
    const Local = struct {
        fn parse(context: *Context) SystemError!SequenceProduction {
            const token_start = context.iterator.current();
            var result: ResultType = undefined;
            inline for (std.meta.fields(ResultType)) |field_info| {
                const field_parser: Parser(field_info.field_type) = @field(parsers, field_info.name);
                const production = try field_parser(context);
                switch (production) {
                    .value => |value| {
                        @field(result, field_info.name) = value;
                    },
                    else => { // `.err => {...}` crashes zig?
                        return SequenceProduction {
                            .err = deviations.static(token_start, "Invalid sequence: TODO better message"),
                        };
                    }
                }
            }

            return SequenceProduction {
                .value = result
            };
        }
    };

    return Local.parse;
}

test {
    comptime {
        const parser1 = token(.number_literal);
        _ = expect(types.Number, parser1);
        _ = map(types.Number, u8, parser1, testMapFn);
    }
}

test {
    comptime {
        const MyStruct = struct {
            a: u8,
            b: bool,
        };

        const ParserStruct = SequenceParseStruct(MyStruct);
        const parseSequence: ParserStruct = .{
            .a = immediate(@intCast(u8, 3)),
            .b = immediate(false),
        };

        _ = sequence(MyStruct, &parseSequence);
    }
}

fn testMapFn(_:
 types.Number) u8 {
    return 0;
}
