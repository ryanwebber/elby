const std = @import("std");

pub const Number = f64;

pub fn parseNumber(str: []const u8) !Number {
    if (Number == f64 or Number == f32) {
        return try std.fmt.parseFloat(Number, str);
    } else {
        @compileError("Invalid number type");
    }
}
