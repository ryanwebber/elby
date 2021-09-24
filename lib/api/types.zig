const std = @import("std");

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

pub const ArchType = struct {
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
                type: *const ArchType
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

pub const ArchTypeRegistry = struct {
    types: []const ArchType,

    const Self = @This();

    pub fn init(comptime types: []const ArchType) Self {
        comptime {
            inline for (types) |*t1| {
                inline for (types) |*t2| {
                    if (t1 != t2 and std.mem.eql(u8, t1.name, t2.name)) {
                        @compileLog("Duplicatly named type: ", t1.name);
                    }
                }
            }
        }

        return .{
            .types = types,
        };
    }

    pub fn getType(self: *const Self, name: []const u8) ?*const ArchType {
        for (self.types) |*t| {
            if (std.mem.eql(u8, name, t.name)) {
                return t;
            }
        }

        return null;
    }
};

test {
    const types = &[_]ArchType {
        .{
            .name = "a1",
            .value = .{
                .numeric = .{
                    .type = Numeric.Type.int,
                    .size = 12
                }
            }
        },
        .{
            .name = "a2",
            .value = .{
                .numeric = .{
                    .type = Numeric.Type.int,
                    .size = 11
                }
            }
        },
    };

    _ = ArchTypeRegistry.init(types);
    try std.testing.expect(types[0].equals(&types[0]));
    try std.testing.expectEqual(@intCast(usize, 11), types[1].size());
}
