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
        self.prototype.deinit();
    }
};

pub const FunctionPrototype = struct {
    allocator: *std.mem.Allocator,
    parameters: []const Parameter,
    returnType: *const types.Type,
    identifier: []const u8,
    signature: []const u8,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, node: *const ast.Function) !Self {

        const returnType = &types.Types.void;

        var idBuffer = try std.ArrayList(u8).initCapacity(allocator, node.identifier.name.len + 2);
        defer { idBuffer.deinit(); }
        try idBuffer.writer().print("{s}()", .{ node.identifier.name });

        var sigBuffer = try std.ArrayList(u8).initCapacity(allocator, node.identifier.name.len + 6);
        defer { sigBuffer.deinit(); }
        try sigBuffer.writer().print("{s}() -> {s}", .{ node.identifier.name, returnType.name, });

        return Self {
            .allocator = allocator,
            .parameters = &.{},
            .returnType = returnType,
            .identifier = idBuffer.toOwnedSlice(),
            .signature = sigBuffer.toOwnedSlice(),
        };
    }

    pub fn deinit(self: *const FunctionPrototype) void {
        self.allocator.free(self.identifier);
        self.allocator.free(self.signature);
    }
};

pub const FunctionLayout = struct {
    locals: []const NamedSlot,
    params: []const NamedSlot,
    workspace: struct {
        size: usize,
        mapping: []const TempSlot,
    },
};

pub const FunctionBody = struct {
    allocator: *std.mem.Allocator,
    body: []const Instruction,

    const Self = @This();

    pub fn initManaged(allocator: *std.mem.Allocator, body: []const Instruction) !Self {
        return .{
            .allocator = allocator,
            .body = body,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.allocator.destroy(self.body);
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
