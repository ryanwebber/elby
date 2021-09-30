const std = @import("std");
const ast = @import("../parsing/ast.zig");
const types = @import("../types.zig");
const errors = @import("../error.zig");

const Slot = @import("slot.zig").Slot;
const Instruction = @import("instruction.zig").Instruction;
const TypeRegistry = types.TypeRegistry;

pub const FunctionDefinition = struct {
    prototype: FunctionPrototype,
    layout: FunctionLayout,
    body: FunctionBody,

    const Self = @This();

    pub fn init(prototype: FunctionPrototype, layout: FunctionLayout, body: FunctionBody) Self {
        return .{
            .prototype = prototype,
            .layout = layout,
            .body = body,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.body.deinit();
        self.layout.deinit();
        self.prototype.deinit();
    }

    pub fn getSlotType(self: *const Self, slot: *const Slot, prototypes: *const PrototypeRegistry) !*const types.Type {
        return switch (slot.*) {
            .local => |s| self.layout.locals[s.index].type,
            .param => |s| self.layout.params[s.index].type,
            .temp => |s|  self.layout.workspace.mapping[s.index].type,
            .retval => self.prototype.returnType,
            .call => |call| {
                const targetProto = prototypes.lookupTable.get(call.functionId) orelse {
                    return errors.fatal("Unknown type in function: {s}", .{ call.functionId });
                };

                switch (call.slot) {
                    .param => |param| {
                        return targetProto.parameters[param.index].type;
                    },
                    .retval => {
                        return targetProto.returnType;
                    }
                }
            }
        };
    }
};

pub const FunctionPrototype = struct {
    allocator: *std.mem.Allocator,
    parameters: []const Parameter,
    returnType: *const types.Type,
    identifier: []const u8,
    signature: []const u8,
    name: []const u8,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, node: *const ast.Function, typeRegistry: *const TypeRegistry) !Self {
        const returnType = &types.Types.void; // TODO

        // Parameters
        var params = std.ArrayList(Parameter).init(allocator);
        errdefer {
            for (params.items) |p| {
                allocator.free(p.name);
            }

            params.deinit();
        }

        for (node.paramlist.parameters) |p| {
            const paramType = typeRegistry.getType(p.type.name) orelse {
                return errors.fatal("Unknown type '{s}' in function definition", .{ p.type.name });
            };

            try params.append(.{
                .name = try allocator.dupe(u8, p.identifier.name),
                .type = paramType
            });
        }

        // ID format
        var idBuffer = try std.ArrayList(u8).initCapacity(allocator, node.identifier.name.len + 2);
        defer { idBuffer.deinit(); }
        try idBuffer.writer().print("{s}(", .{ node.identifier.name });
        for (node.paramlist.parameters) |param| {
            try idBuffer.writer().print("{s}:", .{ param.identifier.name });
        }
        try idBuffer.writer().print(")", .{});

        // Signature format
        var sigBuffer = try std.ArrayList(u8).initCapacity(allocator, node.identifier.name.len + 6);
        defer { sigBuffer.deinit(); }
        try sigBuffer.writer().print("{s}(", .{ node.identifier.name });
        for (node.paramlist.parameters) |param| {
            try sigBuffer.writer().print("{s}:", .{ param.identifier.name });
        }
        try sigBuffer.writer().print(") -> {s}", .{ returnType.name });

        const name = try allocator.dupe(u8, node.identifier.name);

        return Self {
            .allocator = allocator,
            .parameters = params.toOwnedSlice(),
            .returnType = returnType,
            .identifier = idBuffer.toOwnedSlice(),
            .signature = sigBuffer.toOwnedSlice(),
            .name = name,
        };
    }

    pub fn deinit(self: *const FunctionPrototype) void {
        for (self.parameters) |p| {
            self.allocator.free(p.name);
        }

        self.allocator.free(self.parameters);
        self.allocator.free(self.identifier);
        self.allocator.free(self.signature);
        self.allocator.free(self.name);
    }
};

pub const FunctionLayout = struct {
    allocator: *std.mem.Allocator,
    params: []const NamedSlot,
    locals: []const NamedSlot,
    workspace: struct {
        size: usize,
        mapping: []const TempSlot,
    },

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator,
                params: []const NamedSlot,
                locals: []const NamedSlot,
                temps: []const *const types.Type) !Self {

        var tempMapping = try std.ArrayList(TempSlot).initCapacity(allocator, temps.len);
        defer { tempMapping.deinit(); }

        for (temps) |tempType, i| {
            try tempMapping.append(.{
                .offset = i, // TODO: Is this right?
                .type = tempType
            });
        }

        return Self {
            .allocator = allocator,
            .params = try allocator.dupe(NamedSlot, params),
            .locals = try allocator.dupe(NamedSlot, locals),
            .workspace = .{
                .size = temps.len, // TODO: Is this right?
                .mapping = tempMapping.toOwnedSlice(),
            }
        };
    }

    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.params);
        self.allocator.free(self.locals);
        self.allocator.free(self.workspace.mapping);
    }
};

pub const FunctionBody = struct {
    allocator: *std.mem.Allocator,
    instructions: []const Instruction,

    const Self = @This();

    pub fn initManaged(allocator: *std.mem.Allocator, instructions: []const Instruction) !Self {
        return Self {
            .allocator = allocator,
            .instructions = instructions,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.instructions);
    }
};

pub const PrototypeRegistry = struct {
    allocator: *std.mem.Allocator,
    lookupTable: std.StringHashMap(FunctionPrototype),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .lookupTable = std.StringHashMap(FunctionPrototype).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.lookupTable.valueIterator();
        while (iterator.next()) |value| {
            value.deinit();
        }

        self.lookupTable.deinit();
    }

    pub fn lookupCall(self: *const Self, call: *const ast.FunctionCall) !AllocatedResult {
        var buffer = std.ArrayList(u8).init(self.allocator);
        var writer = buffer.writer();
        defer { buffer.deinit(); }

        try writer.print("{s}(", .{ call.identifier.name });
        for (call.arglist.arguments) |arg| {
            try writer.print("{s}:", .{ arg.identifier.name });
        }
        try writer.print(")", .{});

        if (self.lookupTable.getPtr(buffer.items)) |prototype| {
            return AllocatedResult {
                .allocator = self.allocator,
                .result = .{
                    .found = prototype
                }
            };
        } else {
            return AllocatedResult {
                .allocator = self.allocator,
                .result = .{
                    .missing = buffer.toOwnedSlice(),
                }
            };
        }
    }

    pub const AllocatedResult = struct {
        allocator: *std.mem.Allocator,
        result: union(enum) {
            found: *const FunctionPrototype,
            missing: []const u8,
        },

        pub fn deinit(self: *const AllocatedResult) void {
            switch (self.result) {
                .missing => |id| {
                    self.allocator.free(id);
                },
                else => {}
            }
        }
    };
};

pub const Parameter = struct {
    name: []const u8,
    type: *const types.Type,
};

pub const NamedSlot = struct {
    name: []const u8,
    type: *const types.Type,
};

pub const TempSlot = struct {
    offset: usize,
    type: *const types.Type
};

test {
    _ = NamedSlot;
}
