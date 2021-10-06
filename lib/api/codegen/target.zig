const std = @import("std");
const types = @import("../types.zig");
const functions = @import("../irgen/function.zig");
const slots = @import("../irgen/slot.zig");
const _scheme = @import("../irgen/scheme.zig");

const systemTypes = types.systemTypes;

pub const Type = types.Type;
pub const Numeric = types.Numeric;
pub const Slot = slots.Slot;
pub const SlotIndex = slots.SlotIndex;
pub const FunctionPrototype = functions.FunctionPrototype;
pub const FunctionDefinition = functions.FunctionDefinition;
pub const FunctionLayout = functions.FunctionLayout;
pub const ExternFunction = functions.ExternFunction;
pub const PrototypeRegistry = functions.PrototypeRegistry;
pub const FunctionRegistry = _scheme.FunctionRegistry;
pub const Scheme = _scheme.Scheme;
pub const Context = @import("context.zig").Context;
pub const StdTypes = types.Types;
pub const fatal = @import("../error.zig").fatal;

pub const Configuration = struct {
    name: []const u8,
    types: []const Type,
    externs: []const ExternFunction,
};

pub fn Target(comptime Generator: type, comptime configuration: *const Configuration) type {
    const compileScheme: fn(generator: *Generator, scheme: *const Scheme, options: *Generator.Options) anyerror!void = Generator.compileScheme;
    _ = compileScheme;

    return struct {
        generator: Generator,

        const Self = @This();
        pub const OptionsType = Generator.Options;

        pub const config = Configuration {
            .name = configuration.name,
            .types = configuration.types ++ systemTypes,
            .externs = configuration.externs,
        };

        pub fn init(context: *Context) Self {
            return .{
                .generator = Generator.init(context),
            };
        }

        pub fn deinit(self: *Self) void {
            self.generator.deinit();
        }
    };
}
