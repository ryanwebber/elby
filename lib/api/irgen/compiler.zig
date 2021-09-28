const std = @import("std");
const ast = @import("../parsing/ast.zig");
const func = @import("function.zig");
const types = @import("../types.zig");
const Slot = @import("slot.zig").Slot;
const Module = @import("module.zig").Module;
const FunctionRegistry = @import("module.zig").FunctionRegistry;
const Instruction = @import("instruction.zig").Instruction;
const SystemError = @import("../error.zig").SystemError;

const FunctionDefinition = func.FunctionDefinition;
const FunctionPrototype = func.FunctionPrototype;
const FunctionBody =func.FunctionBody;
const FunctionLayout = func.FunctionLayout;
const NamedSlot = func.NamedSlot;
const TypeRegistry = types.TypeRegistry;

pub const Context = struct {
    slotAllocator: SlotAllocator,
    typeRegistry: *const TypeRegistry,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, prototype: *const FunctionPrototype, typeRegistry: *const TypeRegistry) !Self {
        return Self {
            .slotAllocator = try SlotAllocator.init(allocator, prototype),
            .typeRegistry = typeRegistry,
        };
    }

    pub fn deinit(self: *Self) void {
        self.slotAllocator.deinit();
    }

    pub fn computeLayout(_: *const Context) FunctionLayout {
        return FunctionLayout {
            .locals = &.{},
            .params = &.{},
            .workspace = .{
                .size = 0,
                .mapping = &.{},
            }
        };
    }
};

pub const SlotAllocator = struct {
    allocator: *std.mem.Allocator,
    prototype: *const FunctionPrototype,
    namedSlots: std.StringHashMap(NamedSlot),
    tempSlots: std.ArrayList(*const types.Type),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, prototype: *const FunctionPrototype) !Self {

        var namedSlots = std.StringHashMap(NamedSlot).init(allocator);
        errdefer { namedSlots.deinit(); }

        for (prototype.parameters) |parameter| {
            try namedSlots.put(parameter.name, .{
                .name = parameter.name,
                .type = parameter.type,
            });
        }

        var tempSlots = std.ArrayList(*const types.Type).init(allocator);

        return Self {
            .allocator = allocator,
            .prototype = prototype,
            .namedSlots = namedSlots,
            .tempSlots = tempSlots,
        };
    }

    pub fn deinit(self: *Self) void {
        self.namedSlots.deinit();
        self.tempSlots.deinit();
    }

    pub fn allocateTemporarySlot(self: *Self, slotType: *const types.Type) !Slot {
        const index = self.tempSlots.items.len;
        try self.tempSlots.append(slotType);
        return Slot {
            .temp = .{
                .index = @intCast(u32, index),
            }
        };
    }

    pub fn allocateLocalSlot(_: *Self, name: []const u8, _: *const types.Type) !Slot {
        // TODO: pull out the right slot for the identifier
        return Slot {
            .local = .{
                .index = @intCast(u32, name[0])
            }
        };
    }

    pub fn lookupNamedSlot(_: *const Self, identifier: *const ast.Identifier) Slot {
        return .{
            .local = .{
                .index = @intCast(u32, identifier.name[0])
            }
        };
    }
};

pub fn compileModule(allocator: *std.mem.Allocator, program: *const ast.Program) !Module {
    var functions = std.ArrayList(*const FunctionDefinition).init(allocator);
    defer { functions.deinit(); }

    var instructions = std.ArrayList(Instruction).init(allocator);
    defer { instructions.deinit(); }

    for (program.functions) |function| {
        const prototype = try FunctionPrototype.init(allocator, function);
        const context = Context.init(allocator, prototype);
        defer { context.deinit(); }

        try compileFunction(function, instructions, &context);

        const body = FunctionBody.initManaged(allocator, instructions.toOwnedSlice());
        const layout = slotAllocator.computeCurrentLayout();

        var definition = allocator.create(FunctionDefinition);
        definition.* = try FunctionDefinition.init(prototype, layout, body);

        try functions.append(definition) catch |err| {
            allocator.destroy(definition);
            return err;
        };
    }

    const registry = FunctionRegistry.initOwned(allocator, functions);
    return Module.init(allocator, registry);
}

pub fn compileFunction(function: *const ast.Function, dest: *std.ArrayList(Instruction), context: *Context) SystemError!void {
    for (function.body) |statement| {
        try compileStatement(statement, dest, context);
    }
}

fn compileStatement(statement: *const ast.Statement, dest: *std.ArrayList(Instruction), context: *Context) SystemError!void {
    switch (statement.*) {
        .assignment => |assignment| {
            return compileAssignment(assignment, dest, context);
        }
    }
}

fn compileAssignment(assignment: *const ast.Assignment, dest: *std.ArrayList(Instruction), context: *Context) SystemError!void {
    const targetType = &types.Types.void; // TODO
    const exprSlot = try compileExpression(assignment.expression, targetType, dest, context);
    const destSlot = try context.slotAllocator.allocateLocalSlot(assignment.identifier.name, &types.Types.void);
    try dest.append(.{
        .move = .{
            .src = .{
                .slot = exprSlot,
                .offset = 0
            },
            .dest = .{
                .slot = destSlot,
                .offset = 0
            },
        }
    });
}

fn compileExpression(expr: *const ast.Expression, targetType: *const types.Type, dest: *std.ArrayList(Instruction), context: *Context) SystemError!Slot {
    switch (expr.*) {
        .number_literal => |node| {
            const slot = try context.slotAllocator.allocateTemporarySlot(targetType);
            try dest.append(.{
                .load = .{
                    .dest = slot,
                    .value = node.value,
                }
            });

            return slot;
        },
        .identifier => |identifier| {
            return context.slotAllocator.lookupNamedSlot(identifier);
        },
        .binary_expression => |node| {
            const lhs = try compileExpression(node.lhs, targetType, dest, context);
            const rhs = try compileExpression(node.rhs, targetType, dest, context);
            const slot = try context.slotAllocator.allocateTemporarySlot(targetType);
            const instruction: Instruction = switch (node.op) {
                .op_plus => .{
                    .add = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
                .op_minus => .{
                    .sub = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
                .op_mul => .{
                    .mul = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
                .op_div => .{
                    .div = .{
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
