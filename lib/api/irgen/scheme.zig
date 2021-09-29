const std = @import("std");
const FunctionDefinition = @import("function.zig").FunctionDefinition;

pub const Scheme = struct {
    allocator: *std.mem.Allocator,
    functions: FunctionRegistry,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, functions: FunctionRegistry) !Self {
        return Self {
            .allocator = allocator,
            .functions = functions,
        };
    }

    pub fn deinit(self: *Self) void {
        self.functions.deinit();
    }
};

pub const FunctionRegistry = struct {
    allocator: *std.mem.Allocator,
    definitions: []const *const FunctionDefinition,
    mapping: std.StringHashMap(*const FunctionDefinition),

    const Self = @This();

    pub fn initManaged(allocator: *std.mem.Allocator, definitions: []const *const FunctionDefinition) !Self {

        var mapping = std.StringHashMap(*const FunctionDefinition).init(allocator);
        errdefer { mapping.deinit(); }

        for (definitions) |def| {
            try mapping.put(def.prototype.identifier, def);
        }

        return Self {
            .allocator = allocator,
            .definitions = definitions,
            .mapping = mapping,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mapping.deinit();
        for (self.definitions) |definition| {
            definition.deinit();
            self.allocator.destroy(definition);
        }

        self.allocator.free(self.definitions);
    }
};
