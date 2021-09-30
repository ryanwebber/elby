const std = @import("std");

pub const SlotIndex = struct {
    index: usize,
};

pub const CallSlot = struct {
    functionId: []const u8,
    slot: union(enum) {
        param: SlotIndex,
        retval,
    },

    pub fn format(self: *const CallSlot, writer: anytype) !void {
        try writer.print("{s}/", .{ self.functionId });
        switch (self.slot) {
            .param => |index| {
                try formatParam(writer, &index);
            },
            .retval => {
                try formatRet(writer);
            },
        }
    }
};

pub const Slot = union(enum) {
    local: SlotIndex,
    param: SlotIndex,
    temp: SlotIndex,
    call: CallSlot,
    retval,

    pub const Type = std.meta.TagType(Slot);

    pub fn format(self: *const Slot, writer: anytype) !void {
        switch (self.*) {
            .local => |slot| {
                try formatLocal(writer, &slot);
            },
            .param => |slot| {
                try formatParam(writer, &slot);
            },
            .temp => |slot| {
                try formatTemp(writer, &slot);
            },
            .call => |call| {
                try call.format(writer);
            },
            .retval => {
                try formatRet(writer);
            },
        }
    }
};

fn formatLocal(writer: anytype, slot: *const SlotIndex) !void {
    try writer.print("L{}", .{ slot.index });
}

fn formatParam(writer: anytype, slot: *const SlotIndex) !void {
    try writer.print("P{}", .{ slot.index });
}

fn formatTemp(writer: anytype, slot: *const SlotIndex) !void {
    try writer.print("T{}", .{ slot.index });
}

fn formatRet(writer: anytype, ) !void {
    try writer.print("RET", .{});
}
