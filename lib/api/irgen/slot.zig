
pub const SlotIndex = struct {
    index: u32,
};

pub const Slot = union(enum) {
    local: SlotIndex,
    param: SlotIndex,
    stack: SlotIndex,
    retval,

    pub fn format(self: *const Slot, writer: anytype) !void {
        switch (self.*) {
            .local => |slot| {
                try writer.print("L{}", .{ slot.index });
            },
            .param => |slot| {
                try writer.print("P{}", .{ slot.index });
            },
            .stack => |slot| {
                try writer.print("S{}", .{ slot.index });
            },
            .retval => {
                try writer.print("RET", .{});
            }
        }
    }
};
