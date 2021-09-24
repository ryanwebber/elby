const std = @import("std");
const ast = @import("../parsing/ast.zig");
const Slot = @import("slot.zig").Slot;
const Instruction = @import("instruction.zig").Instruction;
const SystemError = @import("../error.zig").SystemError;

pub const SlotAllocator = struct {
    stackIndex: u32,

    pub fn init() SlotAllocator {
        return .{
            .stackIndex = 0,
        };
    }

    fn nextStackSlot(self: *SlotAllocator) Slot {
        const index = self.stackIndex;
        self.stackIndex += 1;
        return .{
            .stack = .{
                .index = index
            }
        };
    }
};

pub fn compileExpression(expr: *const ast.Expression, slotAllocator: *SlotAllocator, dest: *std.ArrayList(Instruction)) SystemError!Slot {
    switch (expr.*) {
        .number_literal => |node| {
            const slot = slotAllocator.nextStackSlot();
            try dest.append(.{
                .load_immediate = .{
                    .dest = slot,
                    .value = node.value
                }
            });

            return slot;
        },
        .identifier => |_| {
            // TODO: lookup variable
            return slotAllocator.nextStackSlot();
        },
        .binary_expression => |node| {
            const slot = slotAllocator.nextStackSlot();
            const lhs = try compileExpression(node.lhs, slotAllocator, dest);
            const rhs = try compileExpression(node.rhs, slotAllocator, dest);
            switch (node.op) {
                .op_plus => {
                    try dest.append(.{
                        .addi = .{
                            .dest = slot,
                            .lhs = lhs,
                            .rhs = rhs
                        }
                    });
                },
                else => {
                    // TODO
                }
            }

            return slot;
        }
    }
}

test "compile expression" {
    const expr: ast.Expression = .{
        .binary_expression = .{
            .lhs = &.{
                .number_literal = &.{
                    .value = .{
                        .int = 1
                    }
                }
            },
            .op = ast.BinOp.op_plus,
            .rhs = &.{
                .number_literal = &.{
                    .value = .{
                        .int = 0
                    }
                }
            }
        }
    };

    var slotAllocator = SlotAllocator.init();
    var destList = std.ArrayList(Instruction).init(std.testing.allocator);
    defer { destList.deinit(); }

    _ = try compileExpression(&expr, &slotAllocator, &destList);

    var irString = std.ArrayList(u8).init(std.testing.allocator);
    var stream = irString.writer();
    defer { irString.deinit(); }

    for (destList.items) |*instr| {
        try instr.format(&stream);
        try stream.print("\n", .{});
    }

    const expectedSource =
        \\S1 := int(1)
        \\S2 := int(0)
        \\S0 := S1 + S2
        \\
        ;

    try std.testing.expectEqualStrings(expectedSource, irString.items);
}
