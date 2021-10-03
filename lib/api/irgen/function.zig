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
        const definedReturnType = if (node.returnType) |id| typeRegistry.getType(id.name) else null;
        const resolvedReturnType = definedReturnType orelse &types.Types.void;

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
        try sigBuffer.writer().print(") -> {s}", .{ resolvedReturnType.name });

        const name = try allocator.dupe(u8, node.identifier.name);

        return Self {
            .allocator = allocator,
            .parameters = params.toOwnedSlice(),
            .returnType = resolvedReturnType,
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
                .instructions = std.ArrayList(Instruction).init(allocator),
                .labels = std.StringHashMap(usize).init(allocator),
            };
        }

        pub fn addInstruction(self: *Builder, instruction: Instruction) !void {
            try self.instructions.append(instruction);
        }

        pub fn addLabel(self: *Builder, offset: usize) ![]const u8 {
            const pc = offset + self.instructions.items.len;
            var buffer = std.ArrayList(u8).init(self.allocator);
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

            var labelLookup = LabelLookup.init(self.allocator);
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
                    current.value_ptr.* = std.ArrayList([]const u8).init(self.allocator);
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
