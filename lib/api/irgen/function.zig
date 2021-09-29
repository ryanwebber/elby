const std = @import("std");
const ast = @import("../parsing/ast.zig");
const types = @import("../types.zig");

const Slot = @import("slot.zig").Slot;
const Instruction = @import("instruction.zig").Instruction;

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

    pub fn getSlotType(self: *const Self, slot: *const Slot) *const types.Type {
        return switch (slot.*) {
            .local => |s| self.layout.locals[s.index].type,
            .param => |s| self.layout.params[s.index].type,
            .temp => |s|  self.layout.workspace.mapping[s.index].type,
            .retval => self.prototype.returnType,
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

    pub fn init(allocator: *std.mem.Allocator, node: *const ast.Function) !Self {

        const returnType = &types.Types.void;

        var idBuffer = try std.ArrayList(u8).initCapacity(allocator, node.identifier.name.len + 2);
        defer { idBuffer.deinit(); }
        try idBuffer.writer().print("{s}()", .{ node.identifier.name });

        var sigBuffer = try std.ArrayList(u8).initCapacity(allocator, node.identifier.name.len + 6);
        defer { sigBuffer.deinit(); }
        try sigBuffer.writer().print("{s}() -> {s}", .{ node.identifier.name, returnType.name, });

        const name = try allocator.dupe(u8, node.identifier.name);

        return Self {
            .allocator = allocator,
            .parameters = &.{},
            .returnType = returnType,
            .identifier = idBuffer.toOwnedSlice(),
            .signature = sigBuffer.toOwnedSlice(),
            .name = name,
        };
    }

    pub fn deinit(self: *const FunctionPrototype) void {
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
