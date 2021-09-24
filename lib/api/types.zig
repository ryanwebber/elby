const std = @import("std");

pub const FloatType = f32;
pub const IntType = i32;

pub const Numeric = union(enum) {
    float: FloatType,
    int: IntType,

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
