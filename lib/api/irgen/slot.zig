const std = @import("std");

pub const SlotIndex = struct {
    index: usize,
};

pub const Slot = union(enum) {
    local: SlotIndex,
    param: SlotIndex,
    temp: SlotIndex,
    retval,

    pub const Type = std.meta.TagType(Slot);

    pub fn format(self: *const Slot, writer: anytype) !void {
        switch (self.*) {
            .local => |slot| {
                try writer.print("L{}", .{ slot.index });
            },
            .param => |slot| {
                try writer.print("P{}", .{ slot.index });
            },
            .temp => |slot| {
                try writer.print("T{}", .{ slot.index });
            },
            .retval => {
                try writer.print("RET", .{});
            }
        }
    }
};
