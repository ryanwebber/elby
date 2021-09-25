const std = @import("std");
const ast = @import("../parsing/ast.zig");
const types = @import("../types.zig");

const Slot = @import("slot.zig").Slot;

pub const FunctionDef = struct {
    node: *const ast.Function,
    locals: []const NamedSlot,
    params: []const NamedSlot,
    returnType: *const types.Type,
    identifier: []const u8,
    allocator: *std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, node: *const ast.Function) !Self {

        // +6 is the exact size for a function with no parameters and a void return type
        var buffer = try std.ArrayList(u8).initCapacity(allocator, node.identifier.name.len + 2);
        defer { buffer.deinit(); }

        try buffer.writer().print("{s}()", .{ node.identifier.name });

        return Self {
            .node = node,
            .locals = &.{},
            .params = &.{},
            .returnType = types.Types.void,
            .identifier = buffer.toOwnedSlice(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const FunctionDef) void {
        self.allocator.free(self.identifier);
    }
};

pub const NamedSlot = struct {
    name: *const ast.Identifier,
    type: *const types.Type,
    mutable: bool,
    slot: Slot,
};
