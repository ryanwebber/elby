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

    pub fn deinit(self: *Self) void {
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
        const returnType = Utils.getReturnType(node, typeRegistry);

        // Parameters
        var params = std.ArrayList(Parameter).init(allocator.*);
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
        const identifier = try Utils.functionToOwnedIdentifier(allocator, node);
        errdefer { allocator.free(identifier); }

        const signature = try Utils.functionToOwnedSignature(allocator, node);
        errdefer { allocator.free(signature); }

        const name = try allocator.dupe(u8, node.identifier.name);
        errdefer { allocator.free(signature); }

        return Self {
            .allocator = allocator,
            .parameters = params.toOwnedSlice(),
            .returnType = returnType,
            .identifier = identifier,
            .signature = signature,
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

        var tempMapping = try std.ArrayList(TempSlot).initCapacity(allocator.*, temps.len);
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
    labels: std.StringHashMap(usize),
    labelLookup: LabelLookup,

    const Self = @This();

    pub const LabelLookup = std.AutoHashMap(usize, std.ArrayList([]const u8));

    fn internalInit(allocator: *std.mem.Allocator,
                    instructions: []const Instruction,
                    labels: std.StringHashMap(usize),
                    labelLookup: LabelLookup) Self {

        return Self {
            .allocator = allocator,
            .instructions = instructions,
            .labels = labels,
            .labelLookup = labelLookup
        };
    }

    pub fn deinit(self: *Self) void {

        var iterator2 = self.labelLookup.valueIterator();
        while (iterator2.next()) |list| {
            list.deinit();
        }

        var iterator = self.labels.keyIterator();
        while (iterator.next()) |label| {
            self.allocator.free(label.*);
        }

        self.labels.deinit();
        self.labelLookup.deinit();
        self.allocator.free(self.instructions);
    }

    pub fn write(self: *const Self, writer: anytype) !void {
        for (self.instructions) |*instr, i| {
            if (self.labelLookup.get(i)) |labels| {
                for (labels.items) |label| {
                    try writer.print("{s}:\n", .{ label });
                }
            }

            try writer.print("\t", .{});
            try instr.format(writer);
            try writer.print("\n", .{});
        }
    }

    pub const Builder = struct {
        allocator: *std.mem.Allocator,
        instructions: std.ArrayList(Instruction),
        labels: std.StringHashMap(usize),

        pub fn init(allocator: *std.mem.Allocator) Builder {
            return .{
                .allocator = allocator,
                .instructions = std.ArrayList(Instruction).init(allocator.*),
                .labels = std.StringHashMap(usize).init(allocator.*),
            };
        }

        pub fn addInstruction(self: *Builder, instruction: Instruction) !void {
            try self.instructions.append(instruction);
        }

        pub fn addLabel(self: *Builder, offset: usize) ![]const u8 {
            const pc = offset + self.instructions.items.len;
            var buffer = std.ArrayList(u8).init(self.allocator.*);
            try buffer.writer().print("label_{d}", .{ self.labels.count() });
            const label = buffer.toOwnedSlice();
            errdefer { self.allocator.free(label); }

            try self.labels.put(label, pc);
            return label;
        }

        pub fn updateLabel(self: *Builder, label: []const u8, offset: usize) void {
            const pc = offset + self.instructions.items.len;
            if (self.labels.getPtr(label)) |value| {
                value.* = pc;
            }
        }

        pub fn deinit(self: *Builder) void {
            var iterator = self.labels.keyIterator();
            while (iterator.next()) |label| {
                self.allocator.free(label.*);
            }

            self.labels.deinit();
            self.instructions.deinit();
        }

        pub fn buildAndDispose(self: *Builder) !FunctionBody {
            defer { self.instructions.deinit(); }

            var labelLookup = LabelLookup.init(self.allocator.*);
            errdefer {
                var iterator = labelLookup.valueIterator();
                while (iterator.next()) |list| {
                    list.deinit();
                }

                labelLookup.deinit();
            }

            var iterator = self.labels.iterator();
            while (iterator.next()) |entry| {
                var current = try labelLookup.getOrPut(entry.value_ptr.*);
                if (!current.found_existing) {
                    current.value_ptr.* = std.ArrayList([]const u8).init(self.allocator.*);
                }

                try current.value_ptr.append(entry.key_ptr.*);
            }

            return FunctionBody.internalInit(self.allocator, self.instructions.toOwnedSlice(), self.labels, labelLookup);
        }
    };
};

pub const PrototypeRegistry = struct {
    allocator: *std.mem.Allocator,
    lookupTable: std.StringHashMap(FunctionPrototype),
    externals: std.StringHashMap(FunctionPrototype),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .lookupTable = std.StringHashMap(FunctionPrototype).init(allocator.*),
            .externals = std.StringHashMap(FunctionPrototype).init(allocator.*),
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.lookupTable.valueIterator();
        while (iterator.next()) |value| {
            value.deinit();
        }

        iterator = self.externals.valueIterator();
        while (iterator.next()) |value| {
            value.deinit();
        }

        self.lookupTable.deinit();
        self.externals.deinit();
    }

    pub fn lookupPrototype(self: *const Self, identifier: []const u8) ?*const FunctionPrototype {
        if (self.lookupTable.getPtr(identifier)) |prototype| {
            return prototype;
        } else if (self.externals.getPtr(identifier)) |prototype| {
            return prototype;
        } else {
            return null;
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

pub const Utils = struct {

    pub fn partsToOwnedIdentifier(allocator: *std.mem.Allocator, name: []const u8, parameters: []const Parameter) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator.*, name.len + 2);
        errdefer { buffer.deinit(); }

        try buffer.writer().print("{s}(", .{ name });
        for (parameters) |param| {
            try buffer.writer().print("{s}:", .{ param.name });
        }
        try buffer.writer().print(")", .{});

        return buffer.toOwnedSlice();
    }

    pub fn partsToOwnedSignature(allocator: *std.mem.Allocator, name: []const u8, parameters: []const Parameter, returnType: *const types.Type) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator.*, name.len + 6);
        errdefer { buffer.deinit(); }

        try buffer.writer().print("{s}(", .{ name });
        for (parameters) |param| {
            try buffer.writer().print("{s}:{s},", .{ param.name, param.type.name });
        }
        try buffer.writer().print("){s}", .{ returnType.name });

        return buffer.toOwnedSlice();
    }

    pub fn functionToOwnedSignature(allocator: *std.mem.Allocator, function: *const ast.Function) ![]const u8 {
        const returnType = if (function.returnType) |t| t.name else types.Types.void.name;
        var buffer = try std.ArrayList(u8).initCapacity(allocator.*, function.identifier.name.len + 6);
        errdefer { buffer.deinit(); }

        try buffer.writer().print("{s}(", .{ function.identifier.name });
        for (function.paramlist.parameters) |param| {
            try buffer.writer().print("{s}:{s},", .{ param.identifier.name, param.type.name });
        }
        try buffer.writer().print("){s}", .{ returnType });

        return buffer.toOwnedSlice();
    }

    pub fn functionToOwnedIdentifier(allocator: *std.mem.Allocator, function: *const ast.Function) ![]const u8 {
        var buffer = try std.ArrayList(u8).initCapacity(allocator.*, function.identifier.name.len + 2);
        errdefer { buffer.deinit(); }

        try buffer.writer().print("{s}(", .{ function.identifier.name });
        for (function.paramlist.parameters) |param| {
            try buffer.writer().print("{s}:", .{ param.identifier.name });
        }
        try buffer.writer().print(")", .{});

        return buffer.toOwnedSlice();
    }

    pub fn callToOwnedIdentifier(allocator: *std.mem.Allocator, call: *const ast.FunctionCall) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator.*);
        errdefer { buffer.deinit(); }

        var writer = buffer.writer();
        try writer.print("{s}(", .{ call.identifier.name });
        for (call.arglist.arguments) |arg| {
            try writer.print("{s}:", .{ arg.identifier.name });
        }
        try writer.print(")", .{});

        return buffer.toOwnedSlice();
    }

    pub fn getReturnType(function: *const ast.Function, typeRegistry: *const TypeRegistry) *const types.Type {
        const definedReturnType = if (function.returnType) |id| typeRegistry.getType(id.name) else null;
        return definedReturnType orelse &types.Types.void;
    }

    pub fn toPrototype(allocator: *std.mem.Allocator, externFn: *const ExternFunction) !FunctionPrototype {
        const name = try allocator.dupe(u8, externFn.name);
        errdefer { allocator.free(name); }

        const parameters = try allocator.alloc(Parameter, externFn.parameters.len);
        for (externFn.parameters) |param, i| {
            parameters[i] = .{
                .name = try allocator.dupe(u8, param.name), // Ugh, ignore freeing this on error for now
                .type = param.type,
            };
        }

        const identifier = try partsToOwnedIdentifier(allocator, name, parameters);
        errdefer { allocator.free(identifier); }

        const signature = try partsToOwnedSignature(allocator, name, parameters, externFn.returnType);
        errdefer { allocator.free(signature); }

        return FunctionPrototype {
            .allocator = allocator,
            .parameters = parameters,
            .returnType = externFn.returnType,
            .identifier = identifier,
            .signature = signature,
            .name = name,
        };
    }
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

pub const ExternFunction = struct {
    name: []const u8,
    parameters: []const Parameter,
    returnType: *const types.Type,
};

test {
    _ = NamedSlot;
}

test "function signature" {
    const functionAst = &.{
        .identifier = &.{
            .name = "foo",
        },
        .paramlist = &.{
            .parameters = &.{
                &.{
                    .identifier = &.{
                        .name = "bar",
                    },
                    .type = &.{
                        .name = "baz"
                    }
                },
            }
        },
        .returnType = &.{
            .name = "qux",
        },
        .body = &.{}
    };

    var allocator = std.testing.allocator;
    var identifier = try Utils.functionToOwnedSignature(&allocator, functionAst);
    defer { allocator.free(identifier); }

    try std.testing.expectEqualStrings(identifier, "foo(bar:baz,)qux");
}
