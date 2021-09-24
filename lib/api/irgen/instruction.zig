const std = @import("std");
const types = @import("../types.zig");
const slot = @import("slot.zig");

const BinOp = struct {
    dest: slot.Slot,
    lhs: slot.Slot,
    rhs: slot.Slot,

    pub fn format(self: *const BinOp, writer: anytype, operator: []const u8) !void {
        try self.dest.format(writer);
        try writer.print(" := ", .{});
        try self.lhs.format(writer);
        try writer.print(" {s} ", .{ operator });
        try self.rhs.format(writer);
    }
};

pub const Instruction = union(enum) {
    load_immediate: struct { dest: slot.Slot, value: types.Numeric, },
    addi: BinOp,
    addf: BinOp,

    const Self = @This();

    pub fn format(self: *const Instruction, writer: anytype) !void {
        switch (self.*) {
            .load_immediate => |load| {
                try load.dest.format(writer);
                try writer.print(" := ", .{});
                try load.value.format(writer);
            },
            .addi, .addf => |add| {
                try add.format(writer, "+");
            }
        }
    }
};

test "format load instruction" {

    var buf: [32]u8 = undefined;
    var writer = std.io.fixedBufferStream(&buf);

    const instruction = Instruction {
        .load_immediate = .{
            .dest = .{
                .local = .{
                    .index = 5
                }
            },
            .value = .{
                .int = 2
            }
        }
    };

    try instruction.format(writer.writer());
    try std.testing.expectEqualStrings("L5 := int(2)", writer.getWritten());
}

test "format add instruction" {

    var buf: [32]u8 = undefined;
    var writer = std.io.fixedBufferStream(&buf);

    const instruction = Instruction {
        .addi = .{
            .dest = .{
                .local = .{
                    .index = 2
                }
            },
            .lhs = .{
                .stack = .{
                    .index = 3
                }
            },
            .rhs = .{
                .param = .{
                    .index = 4
                }
            },
        }
    };

    try instruction.format(writer.writer());
    try std.testing.expectEqualStrings("L2 := S3 + P4", writer.getWritten());
}
