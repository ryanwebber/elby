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

const MoveOp = struct {
    src: OffsetAssignment,
    dest: OffsetAssignment,

    const OffsetAssignment = struct {
        slot: slot.Slot,
        offset: usize,
    };

    pub fn format(self: *const MoveOp, writer: anytype) !void {
        try self.dest.slot.format(writer);
        try writer.print("[{}] := ", .{ self.dest.offset });
        try self.src.slot.format(writer);
        try writer.print("[{}]", .{ self.src.offset });
    }
};

const LoadOp = struct {
    dest: slot.Slot,
    value: types.Numeric,

    pub fn format(self: *const LoadOp, writer: anytype) !void {
        try self.dest.format(writer);
        try writer.print(" := ", .{});
        try self.value.format(writer);
    }
};

pub const Instruction = union(enum) {
    load: LoadOp,
    move: MoveOp,
    add: BinOp,
    sub: BinOp,
    mul: BinOp,
    div: BinOp,

    // return
    // call <fn>
    // if <slot> goto <label>
    // if <overflow> goto <label>
    // cast
    // ...binary ops
    // ...unary ops

    const Self = @This();

    pub fn format(self: *const Instruction, writer: anytype) !void {
        switch (self.*) {
            .load => |load| {
                try load.format(writer);
            },
            .move => |move| {
                try move.format(writer);
            },
            .add => |add| {
                try add.format(writer, "+");
            },
            .sub => |add| {
                try add.format(writer, "-");
            },
            .mul => |add| {
                try add.format(writer, "*");
            },
            .div => |add| {
                try add.format(writer, "/");
            },
        }
    }
};

test "format load instruction" {

    var buf: [32]u8 = undefined;
    var writer = std.io.fixedBufferStream(&buf);

    const instruction = Instruction {
        .load = .{
            .dest = .{
                .local = .{
                    .index = 5
                }
            },
            .value = .{
                .int = 2
            },
        }
    };

    try instruction.format(writer.writer());
    try std.testing.expectEqualStrings("L5 := int(2)", writer.getWritten());
}

test "format add instruction" {

    var buf: [32]u8 = undefined;
    var writer = std.io.fixedBufferStream(&buf);

    const instruction = Instruction {
        .add = .{
            .dest = .{
                .local = .{
                    .index = 2
                }
            },
            .lhs = .{
                .temp = .{
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
    try std.testing.expectEqualStrings("L2 := T3 + P4", writer.getWritten());
}
