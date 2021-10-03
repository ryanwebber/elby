const std = @import("std");
const Keyword = @import("parsing/scanner.zig").Scanner.Keyword;

pub const FloatType = f32;
pub const IntType = i32;

pub const Numeric = union(enum) {
    float: FloatType,
    int: IntType,

    pub const Type = std.meta.TagType(Numeric);

    pub const NumberFormatError = error {
        MalformedString,
    };

    pub fn parse(str: []const u8) !Numeric {
        if (std.fmt.parseInt(IntType, str, 0)) |intValue| {
            return Numeric {
                .int = intValue,
            };
        } else |_| {}

        if (std.fmt.parseFloat(FloatType, str)) |floatValue| {
            return Numeric {
                .float = floatValue,
            };
        } else |_| {}

        return NumberFormatError.MalformedString;
    }

    pub fn format(self: *const Numeric, writer: anytype) !void {
        switch (self.*) {
            .float => |floatValue| {
                try writer.print("float({})", .{floatValue});
            },
            .int => |intValue| {
                try writer.print("int({})", .{intValue});
            }
        }
    }
};

pub const Type = struct {
    name: []const u8,
    value: Value,

    const String = []const u8;
    const Self = @This();

    pub const Value = union(enum) {
        numeric: struct {
            type: Numeric.Type,
            size: usize,
        },
        enumerable: struct {
            values: []const String,
            size: usize,
        },
        object: struct {
            members: []const struct {
                name: []const u8,
                type: *const Type
            },

            const ObjSelf = @This();

            pub fn size(self: *const ObjSelf) usize {
                var cummulative: usize = 0;
                for (self.members) |*member| {
                    cummulative += member.type.size();
                }

                return cummulative;
            }
        }
    };

    pub fn size(self: *const Self) usize {
        return switch (self.*.value) {
            .numeric => |num| num.size,
            .enumerable => |enumerable| enumerable.size,
            .object => |obj| obj.size(),
        };
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        return self.name.ptr == other.name.ptr;
    }
};

pub const TypeRegistry = struct {
    types: []const Type,

    const Self = @This();

    pub fn init(comptime types: []const Type) Self {
        comptime {
            inline for (types) |*t1| {
                inline for (types) |*t2| {
                    if (t1 != t2 and std.mem.eql(u8, t1.name, t2.name)) {
                        @compileLog("Duplicatly named Type: ", t1.name);
                    }
                }

                if (Keyword.asID(t1.name)) |tok| {
                    @compileLog("Type conflicts with keyword token: ", tok.description());
                }
            }
        }

        return .{
            .types = types,
        };
    }

    pub fn deinit(_: *const Self) void {
    }

    pub fn getType(self: *const Self, name: []const u8) ?*const Type {
        for (self.types) |*t| {
            if (std.mem.eql(u8, name, t.name)) {
                return t;
            }
        }

        return null;
    }
};

/// Types that get included for all targets
pub const systemTypes: []const Type = &.{
    Types.void,
    Types.boolean,
};

pub const Types = .{
    .void = Type {
        .name = "Void",
        .value = .{
            .enumerable = .{
                .size = 0,
                .values = &.{ "Void" }
            }
        }
    },
    .boolean = Type {
        .name = "Bool",
        .value = .{
            .enumerable = .{
                .size = 1,
                .values = &.{ "false", "true", }
            }
        }
    }
};

test {
    const types = &[_]Type {
        .{
            .name = "a1",
            .value = .{
                .numeric = .{
                    .type = Numeric.Type.int,
                    .size = 1
                }
            }
        },
        .{
            .name = "a2",
            .value = .{
                .numeric = .{
                    .type = Numeric.Type.int,
                    .size = 2
                }
            }
        },
    };

    _ = TypeRegistry.init(types);
    try std.testing.expect(types[0].equals(&types[0]));
    try std.testing.expectEqual(@intCast(usize, 2), types[1].size());
    try std.testing.expect(Types.void.equals(&Types.void));
}
