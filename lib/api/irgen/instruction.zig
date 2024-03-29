const std = @import("std");
const types = @import("../types.zig");
const slot = @import("slot.zig");

pub const BinOp = struct {
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

pub const UnaryOp = struct {
    dest: slot.Slot,
    rhs: slot.Slot,

    pub fn format(self: *const UnaryOp, writer: anytype, operator: []const u8) !void {
        try self.dest.format(writer);
        try writer.print(" := ", .{});
        try writer.print(" {s} ", .{ operator });
        try self.rhs.format(writer);
    }
};

pub const MoveOp = struct {
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

pub const LoadOp = struct {
    dest: slot.Slot,
    value: types.Numeric,

    pub fn format(self: *const LoadOp, writer: anytype) !void {
        try self.dest.format(writer);
        try writer.print(" := ", .{});
        try self.value.format(writer);
    }
};

pub const CallOp = struct {
    functionId: []const u8,

    pub fn format(self: *const CallOp, writer: anytype) !void {
        try writer.print("call {s}", .{ self.functionId });
    }
};

pub const ConditionalGoto = struct {
    slot: slot.Slot,
    label: []const u8,

    pub fn format(self: *const ConditionalGoto, writer: anytype) !void {
        try writer.print("goto :{s} unless ", .{ self.label });
        try self.slot.format(writer);
    }
};

pub const Instruction = union(enum) {
    load: LoadOp,
    move: MoveOp,
    add: BinOp,
    sub: BinOp,
    mul: BinOp,
    div: BinOp,
    cmp_eq: BinOp,
    cmp_neq: BinOp,
    cmp_lt: BinOp,
    cmp_lt_eq: BinOp,
    cmp_gt: BinOp,
    cmp_gt_eq: BinOp,
    call: CallOp,
    goto: struct { label: []const u8 },
    goto_unless: ConditionalGoto,
    ret,

    // return
    // if <slot> goto <label>
    // if <overflow> goto <label>
    // cast
    // ...binary ops
    // ...unary ops

    const Self = @This();

    pub fn format(self: *const Instruction, writer: anytype) !void {
        switch (self.*) {
            .load => |op| {
                try op.format(writer);
            },
            .move => |op| {
                try op.format(writer);
            },
            .add => |op| {
                try op.format(writer, "+");
            },
            .sub => |op| {
                try op.format(writer, "-");
            },
            .mul => |op| {
                try op.format(writer, "*");
            },
            .div => |op| {
                try op.format(writer, "/");
            },
            .cmp_eq => |op| {
                try op.format(writer, "==");
            },
            .cmp_neq => |op| {
                try op.format(writer, "!=");
            },
            .cmp_lt => |op| {
                try op.format(writer, "<");
            },
            .cmp_lt_eq => |op| {
                try op.format(writer, "<=");
            },
            .cmp_gt => |op| {
                try op.format(writer, ">");
            },
            .cmp_gt_eq => |op| {
                try op.format(writer, ">=");
            },
            .call => |call| {
                try call.format(writer);
            },
            .goto => |op| {
                try writer.print("goto :{s}", .{ op.label });
            },
            .goto_unless => |op| {
                try op.format(writer);
            },
            .ret => {
                try writer.print("return", .{});
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
