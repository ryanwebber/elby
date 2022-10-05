const std = @import("std");
const Token = @import("token.zig").Token;
const TokenIterator = @import("tokenizer.zig").TokenIterator;
const SystemError = @import("../error.zig").SystemError;

const syntax_error = @import("syntax_error.zig");
const SyntaxError = syntax_error.SyntaxError;

const types = @import("../types.zig");

pub const ErrorAccumulator = struct {
    errors: std.ArrayList(SyntaxError),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .errors = std.ArrayList(SyntaxError).init(allocator.*),
        };
    }

    pub fn deinit(self: *Self) void {
        self.errors.deinit();
    }

    pub fn push(self: *Self, err: SyntaxError) !void {
        try self.errors.append(err);
    }
};

pub const Context = struct {
    allocator: *std.mem.Allocator,
    iterator: *TokenIterator,
    errorHandler: *ErrorAccumulator,

    const Self = @This();

    fn swapIn(self: *Self, errorHandler: *ErrorAccumulator) Context {
        return .{
            .allocator = self.allocator,
            .iterator = self.iterator,
            .errorHandler = errorHandler,
        };
    }
};

pub fn Production(comptime Value: type) type {
    return union(enum) {
        value: Value,
        err: SyntaxError,
    };
}

pub fn Parser(comptime Value: type) type {
    return struct {
        parse: fn(context: *Context) SystemError!Production(Value),

        const Self = @This();
        pub const ParseValue = Value;

        pub fn init(comptime Container: type) Self {
            return .{
                .parse = Container.parse,
            };
        }
    };
}

// Combinators

pub fn immediate(comptime value: anytype) Parser(@TypeOf(value)) {
    const Value = @TypeOf(value);
    const ImmediateProduction = Production(Value);
    return Parser(Value).init(struct {
        fn parse(_: *Context) SystemError!ImmediateProduction {
            return ImmediateProduction {
                .value = value,
            };
        }
    });
}

pub fn eof() Parser(void) {
    const Value = void;
    const VoidProduction = Production(void);
    return Parser(Value).init(struct {
        fn parse(context: *Context) SystemError!VoidProduction {
            if (context.iterator.next()) |tok| {
                return VoidProduction {
                    .err = syntax_error.unexpectedToken(.eof, tok),
                };
            } else {
                return VoidProduction.value;
            }
        }
    });
}

pub fn token(comptime expected_id: Token.Id) Parser(Token.valueType(expected_id)) {
    const Value = Token.valueType(expected_id);
    const TokenProduction = Production(Value);
    return Parser(Value).init(struct {
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
                            .err = syntax_error.unexpectedToken(expected_id, tok),
                        };
                    }
                }
            } else {
                return TokenProduction {
                    .err = syntax_error.unexpectedEof(expected_id, iterator.current()),
                };
            }
        }
    });
}

pub fn id(comptime expected_id: Token.Id, comptime value: anytype) Parser(@TypeOf(value)) {
    const FromType = Token.valueType(expected_id);
    const ToType = @TypeOf(value);

    const Local = struct {
        fn map(_: FromType) ToType {
            return value;
        }
    };

    return mapValue(FromType, ToType, Local.map, token(expected_id));
}

pub fn expect(comptime Value: type, comptime parser: Parser(Value)) Parser(Value) {
    return Parser(Value).init(struct {
        fn parse(context: *Context) SystemError!Production(Value) {
            const result = try parser.parse(context);
            switch (result) {
                .err => |err| {
                    try context.errorHandler.push(err);
                },
                else => {}
            }
            return result;
        }
    });
}

pub fn map(
        comptime FromValue: type,
        comptime ToValue: type,
        mapFn: fn(allocator: *std.mem.Allocator, from: FromValue) SystemError!ToValue,
        parser: Parser(FromValue)) Parser(ToValue) {
    const MappedProduction = Production(ToValue);
    return Parser(ToValue).init(struct {
        fn parse(context: *Context) SystemError!MappedProduction {
            switch (try parser.parse(context)) {
                .value => |value| {
                    return MappedProduction {
                        .value = try mapFn(context.allocator, value)
                    };
                },
                .err => |err| {
                    return MappedProduction {
                        .err = err
                    };
                }
            }
        }
    });
}

pub fn mapValue(
        comptime FromValue: type,
        comptime ToValue: type,
        mapFn: fn(from: FromValue) ToValue,
        parser: Parser(FromValue)) Parser(ToValue) {

    const Local = struct {
        fn mapValueInternal(_: *std.mem.Allocator, from: FromValue) SystemError!ToValue {
            return mapFn(from);
        }
    };

    return map(FromValue, ToValue, Local.mapValueInternal, parser);
}

pub fn mapAlloc(
        comptime FromValue: type,
        comptime ToValue: type,
        mapFn: fn(from: FromValue) ToValue,
        parser: Parser(FromValue)) Parser(*ToValue) {

    const Local = struct {
        fn mapInternal(allocator: *std.mem.Allocator, from: FromValue) SystemError!*ToValue {
            var node = try allocator.create(ToValue);
            node.* = mapFn(from);
            return node;
        }
    };

    return map(FromValue, *ToValue, Local.mapInternal, parser);
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

pub fn sequence(
        comptime Value: type,
        description: []const u8,
        parsers: *const SequenceParseStruct(Value)) Parser(Value) {
    const SequenceProduction = Production(Value);
    return Parser(Value).init(struct {
        fn parse(context: *Context) SystemError!SequenceProduction {
            const token_start = context.iterator.current();
            var result: Value = undefined;
            inline for (std.meta.fields(Value)) |field_info, idx| {
                const field_parser: Parser(field_info.field_type) = @field(parsers, field_info.name);

                // After the first parser in the sequence, publish the errors
                const enhanced_parser = if (idx > 0)
                    expect(field_info.field_type, field_parser)
                else
                    field_parser
                ;

                switch (try enhanced_parser.parse(context)) {
                    .value => |value| {
                        @field(result, field_info.name) = value;
                    },
                    else => { // `.err => {...}` crashes zig?
                        return SequenceProduction {
                            .err = syntax_error.expectedSequence(description, token_start),
                        };
                    }
                }
            }

            return SequenceProduction {
                .value = result
            };
        }
    });
}

pub fn first(comptime Value: type, description: []const u8, parsers: []const Parser(Value)) Parser(Value) {
    const OneOfProduction = Production(Value);
    return Parser(Value).init(struct {
        fn parse(context: *Context) SystemError!OneOfProduction {
            const offset = context.iterator.offset;
            for (parsers) |parser| {
                switch (try parser.parse(context)) {
                    .value => |value| {
                        return OneOfProduction {
                            .value = value,
                        };
                    },
                    .err => {
                        // reset the offset and try the next parser
                        context.iterator.offset = offset;
                    }
                }
            }

            return OneOfProduction {
                .err = syntax_error.unmatchedSet(description, context.iterator.tokenizer.tokens.items[offset])
            };
        }
    });
}

pub fn list(comptime Value: type, description: []const u8, parser: Parser(Value), separator: Parser(void)) Parser([]const Value) {
    const Local = struct {
        const flatParser = map(JoinedParse, []const Value, joinList, sequence(JoinedParse, description, &.{
            .head = parser,
            .tail = tailParser,
        }));

        const JoinedParse = struct {
            head: Value,
            tail: []const TailParse,
        };

        const tailParser = atLeast(TailParse, 0, description, sequence(TailParse, description, &.{
            .separator = separator,
            .element = parser,
        }));

        const TailParse = struct {
            separator: void,
            element: Value,
        };

        fn joinList(allocator: *std.mem.Allocator, from: JoinedParse) SystemError![]const Value {

            defer { allocator.free(from.tail); }

            const values = try allocator.alloc(Value, 1 + from.tail.len);
            values[0] = from.head;
            for (from.tail) |tail, i| {
                values[i + 1] = tail.element;
            }

            return values;
        }
    };

    return orElse([]const Value, Local.flatParser, &.{});
}

pub fn atLeast(comptime Value: type, comptime n: usize, description: []const u8, parser: Parser(Value)) Parser([]const Value) {
    const AtLeastProduction = Production([]const Value);
    return Parser([]const Value).init(struct {
        fn parse(context: *Context) SystemError!AtLeastProduction {

            // Content are owned by the caller when this returns
            var parses = std.ArrayList(Value).init(context.allocator.*);
            defer { parses.deinit(); }

            var offset = context.iterator.offset;
            var i: usize = 0;
            while (true) {
                switch (try parser.parse(context)) {
                    .value => |value| {
                        i += 1;
                        offset = context.iterator.offset;
                        try parses.append(value);
                    },
                    .err => {
                        if (i < n) {
                            // Didn't parse enough. Propogate errors and exit
                            return AtLeastProduction {
                                .err = syntax_error.expectedSequence(description, context.iterator.tokenizer.tokens.items[offset])
                            };
                        } else {
                            // Parsed enough times. Wipe the error, reset the iterator to the
                            // last successful position, and exit
                            context.iterator.offset = offset;
                            return AtLeastProduction {
                                .value = parses.toOwnedSlice()
                            };
                        }
                    }
                }
            }
        }
    });
}

pub fn lazy(comptime Value: type, provider: fn() callconv(.Inline) Parser(Value)) Parser(Value) {
    return Parser(Value).init(struct {
        fn parse(context: *Context) SystemError!Production(Value) {
            return try provider().parse(context);
        }
    });
}

pub fn maybe(comptime Value: type, parser: Parser(Value)) Parser(?Value) {
    const Local = struct {
        fn mapOptional(value: Value) ?Value {
            return value;
        }
    };

    return orElse(?Value, mapValue(Value, ?Value, Local.mapOptional, parser), null);
}

pub fn orElse(comptime Value: type, parser: Parser(Value), elseVal: Value) Parser(Value) {
    const MappedProduction = Production(Value);
    return Parser(Value).init(struct {
        fn parse(context: *Context) SystemError!MappedProduction {
            const offset = context.iterator.offset;
            switch (try parser.parse(context)) {
                .value => |value| {
                    return MappedProduction {
                        .value = value
                    };
                },
                .err => {
                    context.iterator.offset = offset;
                    return MappedProduction {
                        .value = elseVal
                    };
                }
            }
        }
    });
}

test {
    comptime {

        const Local = struct {
            fn testMapFn(_:types.Numeric) u8 {
                return 0;
            }
        };

        const parser1 = token(.number_literal);
        _ = expect(types.Numeric, parser1);
        _ = mapValue(types.Numeric, u8, Local.testMapFn, parser1);
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

        _ = sequence(MyStruct, "test", &parseSequence);
    }
}
