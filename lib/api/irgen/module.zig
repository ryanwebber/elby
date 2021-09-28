const std = @import("std");
const FunctionDefinition = @import("function.zig").FunctionDefinition;

pub const Module = struct {
    allocator: *std.mem.Allocator,
    functions: FunctionRegistry,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, functions: FunctionRegistry) !Self {
        return .{
            .allocator = allocator,
            .functions = functions,
        };
    }

    pub fn deinit(_: *const Self) void {
    }
};

pub const FunctionRegistry = struct {
    allocator: *std.mem.Allocator,
    definitions: []const *FunctionDef,
    mapping: std.StringHashMap(*const FunctionDefinition),

    const Self = @This();

    pub fn initOwned(allocator: *std.mem.Allocator, definitions: []const *const FunctionDefinition) !Self {

        var mapping = std.StringHashMap(*const FunctionDefinition).init(allocator);
        for (definitions) |def| {
            mapping.put(def.prototype.identifier, def);
        }

        return .{
            .allocator = allocator,
            .definitions = definitions,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.mapping.deinit();
        for (self.definitions) |definition| {
            self.allocator.destroy(definition);
        }

        self.allocator.free(self.definitions);
    }
};
