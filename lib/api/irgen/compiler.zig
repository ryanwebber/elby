const std = @import("std");
const ast = @import("../parsing/ast.zig");
const func = @import("function.zig");
const types = @import("../types.zig");
const errors = @import("../error.zig");
const Slot = @import("slot.zig").Slot;
const Scheme = @import("scheme.zig").Scheme;
const FunctionRegistry = @import("scheme.zig").FunctionRegistry;
const Instruction = @import("instruction.zig").Instruction;

const ExternFunction = func.ExternFunction;
const FunctionUtils = func.Utils;
const FunctionDefinition = func.FunctionDefinition;
const FunctionPrototype = func.FunctionPrototype;
const FunctionBody = func.FunctionBody;
const InstructionSetBuilder = FunctionBody.Builder;
const FunctionLayout = func.FunctionLayout;
const NamedSlot = func.NamedSlot;
const PrototypeRegistry = func.PrototypeRegistry;
const TypeRegistry = types.TypeRegistry;
const SystemError = errors.SystemError;

pub const Context = struct {
    allocator: *std.mem.Allocator,
    slotAllocator: SlotAllocator,
    prototypeRegistry: *PrototypeRegistry,
    typeRegistry: *const TypeRegistry,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator,
                prototype: *const FunctionPrototype,
                prototypeRegistry: *PrototypeRegistry,
                typeRegistry: *const TypeRegistry) !Self {

        return Self {
            .allocator = allocator,
            .slotAllocator = try SlotAllocator.init(allocator, prototype),
            .prototypeRegistry = prototypeRegistry,
            .typeRegistry = typeRegistry,
        };
    }

    pub fn deinit(self: *Self) void {
        self.slotAllocator.deinit();
    }

    pub fn currentPrototype(self: *const Self) *const FunctionPrototype {
        return self.slotAllocator.prototype;
    }
};

pub const SlotAllocator = struct {
    allocator: *std.mem.Allocator,
    prototype: *const FunctionPrototype,
    paramSlots: std.StringArrayHashMap(NamedSlot),
    localSlots: std.StringArrayHashMap(NamedSlot),
    tempSlots: std.ArrayList(*const types.Type),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, prototype: *const FunctionPrototype) !Self {

        var paramSlots = std.StringArrayHashMap(NamedSlot).init(allocator);
        errdefer { paramSlots.deinit(); }

        for (prototype.parameters) |parameter| {
            try paramSlots.put(parameter.name, .{
                .name = parameter.name,
                .type = parameter.type,
            });
        }

        var localSlots = std.StringArrayHashMap(NamedSlot).init(allocator);
        var tempSlots = std.ArrayList(*const types.Type).init(allocator);

        return Self {
            .allocator = allocator,
            .prototype = prototype,
            .paramSlots = paramSlots,
            .localSlots = localSlots,
            .tempSlots = tempSlots,
        };
    }

    pub fn deinit(self: *Self) void {
        self.paramSlots.deinit();
        self.localSlots.deinit();
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

    pub fn allocateLocalSlot(self: *Self, name: []const u8, slotType: *const types.Type) !Slot {
        const index = self.localSlots.count();
        try self.localSlots.put(name, .{
            .name = name,
            .type = slotType,
        });

        return Slot {
            .local = .{
                .index = index
            }
        };
    }

    pub fn lookupNamedSlot(self: *const Self, name: []const u8) !Slot {
        if (self.paramSlots.getIndex(name)) |index| {
            return Slot {
                .param = .{
                    .index = index
                }
            };
        }

        if (self.localSlots.getIndex(name)) |index| {
            return Slot {
                .local = .{
                    .index = index
                }
            };
        }

        return errors.fatal("Unknown named slot: {s}", .{ name });
    }
};

const SlotTypePair = struct {
    slot: Slot,
    type: *const types.Type,
};

pub fn compileScheme(allocator: *std.mem.Allocator,
                     program: *const ast.Program,
                     typeRegistry: *const TypeRegistry,
                     externs: []const ExternFunction) !Scheme {

    var prototypeRegistry = PrototypeRegistry.init(allocator);
    errdefer {
        prototypeRegistry.deinit();
    }

    var functions = std.ArrayList(*FunctionDefinition).init(allocator);
    errdefer {
        for (functions.items) |f| {
            f.deinit();
            allocator.destroy(f);
        }
    }
    defer { functions.deinit(); }

    for (program.functions) |function| {
        const prototype = try FunctionPrototype.init(allocator, function, typeRegistry);
        errdefer { prototype.deinit(); }

        try prototypeRegistry.lookupTable.put(prototype.identifier, prototype);
    }

    for (externs) |e| {
        const prototype = try FunctionUtils.toPrototype(allocator, &e);
        try prototypeRegistry.externals.put(prototype.identifier, prototype);
    }

    for (program.functions) |function| {
        const prototype = try FunctionPrototype.init(allocator, function, typeRegistry);
        errdefer { prototype.deinit(); }

        var context = try Context.init(allocator, &prototype, &prototypeRegistry, typeRegistry);
        defer { context.deinit(); }

        var builder = InstructionSetBuilder.init(allocator);
        errdefer { builder.deinit(); }

        try compileFunction(function, &builder, &context);

        var body = try builder.buildAndDispose();
        errdefer { body.deinit(); }

        const layout = calculateLayout: {
            const locals = context.slotAllocator.localSlots.values();
            const params = context.slotAllocator.paramSlots.values();
            const temps = context.slotAllocator.tempSlots.items;
            break :calculateLayout try FunctionLayout.init(allocator, params, locals, temps);
        };
        errdefer { layout.deinit(); }

        var definition = try allocator.create(FunctionDefinition);
        definition.* = FunctionDefinition.init(prototype, layout, body);

        functions.append(definition) catch |err| {
            allocator.destroy(definition);
            return err;
        };
    }

    const registry = try FunctionRegistry.initManaged(allocator, functions.toOwnedSlice(), prototypeRegistry);
    return Scheme.init(allocator, registry);
}

pub fn compileFunction(function: *const ast.Function, builder: *InstructionSetBuilder, context: *Context) SystemError!void {
    try compileBlock(function.body, builder, context);

    // RET here is for situations where there's a label pointing
    // to the end of the function. We need a ret to make sure generators
    // don't simply fall through to the next function body
    try builder.addInstruction(Instruction.ret);
}

fn compileBlock(statements: []const *const ast.Statement, builder: *InstructionSetBuilder, context: *Context) SystemError!void {
    for (statements) |statement| {
        try compileStatement(statement, builder, context);
    }
}

fn compileStatement(statement: *const ast.Statement, builder: *InstructionSetBuilder, context: *Context) SystemError!void {
    switch (statement.*) {
        .assignment => |assignment| {
            try compileAssignment(assignment, builder, context);
        },
        .call => |call| {
            _ = try compileFunctionCall(call, builder, context);
        },
        .ret => |expr| {
            const returnType = context.currentPrototype().returnType;
            if ((returnType.size() > 0) != (expr != null)) {
                return errors.fatal("Unexpected return type expression for type: {s}", .{ returnType.name });
            }

            if (returnType.size() > 0 and expr != null) {
                const retvalSlot = try compileExpression(expr.?, returnType, builder, context);
                try builder.addInstruction(.{
                    .move = .{
                        .src = .{
                            .offset = 0,
                            .slot = retvalSlot,
                        },
                        .dest = .{
                            .offset = 0,
                            .slot = Slot.retval,
                        }
                    }
                });
            }

            try builder.addInstruction(Instruction.ret);
        },
        .ifchain => |ifnode| {
            const endLabel = try builder.addLabel(0);
            var nextNode: ?*const ast.IfChain = ifnode;
            while (nextNode) |currentNode| {
                const exprSlot = try compileExpression(currentNode.expr, &types.Types.boolean, builder, context);
                const nextCondLabel = try builder.addLabel(0);

                try builder.addInstruction(.{
                    .if_not_goto = .{
                        .slot = exprSlot,
                        .label = nextCondLabel,
                    }
                });

                try compileBlock(currentNode.statements, builder, context);

                try builder.addInstruction(.{
                    .goto = .{
                        .label = endLabel,
                    }
                });

                builder.updateLabel(nextCondLabel, 0);

                // This needs to be set in the case there are else-ifs
                nextNode = null;

                if (currentNode.next) |elseIf| {
                    switch (elseIf) {
                        .conditional => |ifElseNode| {
                            nextNode = ifElseNode;
                        },
                        .terminal => |elseStatements| {
                            try compileBlock(elseStatements, builder, context);
                        },
                    }
                }
            }

            builder.updateLabel(endLabel, 0);
        }
    }
}

fn compileFunctionCall(call: *const ast.FunctionCall, builder: *InstructionSetBuilder, context: *Context) SystemError!?SlotTypePair {

    const functionIdentifier = try FunctionUtils.callToOwnedIdentifier(context.allocator, call);
    defer { context.allocator.free(functionIdentifier); }

    const functionPrototype = context.prototypeRegistry.lookupPrototype(functionIdentifier) orelse {
        return errors.fatal("Function not found: {s}", .{ functionIdentifier });
    };

    // Move expressions into temp slots first, and _then_ move them into param slots
    // to avoid `foo(1, foo(2))` param smashing
    var argSlots = try context.allocator.alloc(Slot, call.arglist.arguments.len);
    defer { context.allocator.free(argSlots); }

    for (call.arglist.arguments) |arg, i| {
        const targetType = functionPrototype.parameters[i].type;
        argSlots[i] = try compileExpression(arg.expression, targetType, builder, context);
    }

    for (call.arglist.arguments) |_, i| {
        try builder.addInstruction(.{
            .move = .{
                .src = .{
                    .offset = 0,
                    .slot = argSlots[i],
                },
                .dest = .{
                    .offset = 0,
                    .slot = .{
                        .call = .{
                            .functionId = functionPrototype.identifier,
                            .slot = .{
                                .param = .{
                                    .index = i,
                                }
                            }
                        }
                    },
                }
            }
        });
    }

    try builder.addInstruction(.{
        .call = .{
            .functionId = functionPrototype.identifier,
        }
    });

    if (functionPrototype.returnType.size() > 0) {
        return SlotTypePair {
            .slot = .{
                .call = .{
                    .functionId = functionPrototype.identifier,
                    .slot = .retval,
                }
            },
            .type = functionPrototype.returnType,
        };
    } else {
        return null;
    }
}

fn compileAssignment(assignment: *const ast.Assignment, builder: *InstructionSetBuilder, context: *Context) SystemError!void {
    const typeName = assignment.type.identifier.name;
    const targetType = context.typeRegistry.getType(typeName) orelse {
        return errors.fatal("Unknown type: {s}", .{ typeName });
    };

    const exprSlot = try compileExpression(assignment.expression, targetType, builder, context);
    const destSlot = try context.slotAllocator.allocateLocalSlot(assignment.identifier.name, targetType);
    try builder.addInstruction(.{
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

fn compileExpression(expr: *const ast.Expression, targetType: *const types.Type, builder: *InstructionSetBuilder, context: *Context) SystemError!Slot {
    switch (expr.*) {
        .number_literal => |node| {
            const slot = try context.slotAllocator.allocateTemporarySlot(targetType);
            try builder.addInstruction(.{
                .load = .{
                    .dest = slot,
                    .value = node.value,
                }
            });

            return slot;
        },
        .identifier => |identifier| {
            return try context.slotAllocator.lookupNamedSlot(identifier.name);
        },
        .binary_expression => |node| {
            const lhs = try compileExpression(node.lhs, targetType, builder, context);
            const rhs = try compileExpression(node.rhs, targetType, builder, context);
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
                .op_equality => .{
                    .cmp_eq = .{
                        .dest = slot,
                        .lhs = lhs,
                        .rhs = rhs
                    }
                },
            };

            try builder.addInstruction(instruction);

            return slot;
        },
        .function_call => |call| {
            if (try compileFunctionCall(call, builder, context)) |returnInfo| {
                const destSlot = try context.slotAllocator.allocateTemporarySlot(returnInfo.type);
                try builder.addInstruction(.{
                    .move = .{
                        .src = .{
                            .slot = returnInfo.slot,
                            .offset = 0
                        },
                        .dest = .{
                            .slot = destSlot,
                            .offset = 0
                        },
                    }
                });

                return destSlot;
            } else {
                return errors.fatal("Return type not usable as expression (call to {s})", .{ call.identifier.name });
            }
        }
    }
}

test {
    const utils = @import("../testing/utils.zig");
    const source =
        \\fn main() {
        \\    let x: i = 9;
        \\}
        ;

    const typeRegistry = TypeRegistry.init(&.{
        .{
            .name = "i",
            .value = .{
                .numeric = .{
                    .type = .int,
                    .size = 1
                }
            }
        },
    });

    var allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer { arena.deinit(); }
    const program = try utils.toProgramAst(&arena, source);

    var scheme = try compileScheme(allocator, program, &typeRegistry, &.{});
    defer { scheme.deinit(); }
}
