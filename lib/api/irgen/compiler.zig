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

    fn lookupLocalSlot(_: *SlotAllocator, identifier: *const ast.Identifier) Slot {
        // TODO: bottom-up search scope-tree
        return .{
            .local = .{
                .index = @intCast(u32, identifier.name[0])
            }
        };
    }
};

pub fn compileFunction(function: *const ast.Function, slotAllocator: *SlotAllocator, dest: *std.ArrayList(Instruction)) SystemError!void {
    for (function.body) |statement| {
        try compileStatement(statement, slotAllocator, dest);
    }
}

pub fn compileStatement(statement: *const ast.Statement, slotAllocator: *SlotAllocator, dest: *std.ArrayList(Instruction)) SystemError!void {
    switch (statement.*) {
        .assignment => |assignment| {
            return compileAssignment(assignment, slotAllocator, dest);
        }
    }
}

pub fn compileAssignment(assignment: *const ast.Assignment, slotAllocator: *SlotAllocator, dest: *std.ArrayList(Instruction)) SystemError!void {
    const exprSlot = try compileExpression(assignment.expression, slotAllocator, dest);
    const destSlot = slotAllocator.lookupLocalSlot(assignment.identifier);
    try dest.append(.{
        .move = .{
            .src = exprSlot,
            .dest = destSlot,
        }
    });
}

pub fn compileExpression(expr: *const ast.Expression, slotAllocator: *SlotAllocator, dest: *std.ArrayList(Instruction)) SystemError!Slot {
    switch (expr.*) {
        .number_literal => |node| {
            const slot = slotAllocator.nextStackSlot();
            try dest.append(.{
                .load = .{
                    .dest = slot,
                    .value = node.value
                }
            });

            return slot;
        },
        .identifier => |identifier| {
            return slotAllocator.lookupLocalSlot(identifier);
        },
        .binary_expression => |node| {
            const lhs = try compileExpression(node.lhs, slotAllocator, dest);
            const rhs = try compileExpression(node.rhs, slotAllocator, dest);
            const slot = slotAllocator.nextStackSlot();
            const instruction: Instruction = switch (node.op) {
                .op_plus => .{
                    .addi = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
                .op_minus => .{
                    .subi = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
                .op_mul => .{
                    .muli = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
                .op_div => .{
                    .divi = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
            };

            try dest.append(instruction);

            return slot;
        }
    }
}
