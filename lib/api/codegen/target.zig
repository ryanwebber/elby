const std = @import("std");
const types = @import("../types.zig");
const functions = @import("../irgen/function.zig");
const slots = @import("../irgen/slot.zig");
const _scheme = @import("../irgen/scheme.zig");

const systemTypes = types.systemTypes;

pub const Type = types.Type;
pub const StdTypes = types.Types;
pub const Numeric = types.Numeric;
pub const Slot = slots.Slot;
pub const SlotIndex = slots.SlotIndex;
pub const FunctionPrototype = functions.FunctionPrototype;
pub const FunctionDefinition = functions.FunctionDefinition;
pub const FunctionLayout = functions.FunctionLayout;
pub const PrototypeRegistry = functions.PrototypeRegistry;
pub const FunctionRegistry = _scheme.FunctionRegistry;
pub const Scheme = _scheme.Scheme;
pub const fatal = @import("../error.zig").fatal;

pub var temp: [4096]u8 = undefined;

pub const Context = struct {
    allocator: *std.mem.Allocator,
    __stream: std.io.StreamSource,
    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .__stream = std.io.StreamSource {
                .buffer = std.io.fixedBufferStream(&temp)
            }
        };
    }

    pub fn requestOutputStream(self: *Self, _: []const u8) !*std.io.StreamSource {
        return &self.__stream;
    }

    pub fn deinit(_: *Self) void {
    }
};

pub fn Target(comptime UserContext: type, comptime ErrorType: type, comptime Builder: type) type {
    const targetName: []const u8 = Builder.name;
    const userTypes: []const Type = Builder.types;
    const compileSchemeFn: fn(userContext: *UserContext, scheme: *const Scheme) ErrorType!void = Builder.compileScheme;

    const contextInitFn: fn(context: *Context) anyerror!UserContext = UserContext.init;
    const contextDeinitFn: fn(userContext: *UserContext) void = UserContext.deinit;

    // End type validation

    return struct {
        name: []const u8 = name,
        userContext: UserContext,

        const Self = @This();

        pub const name = targetName;
        pub const types = systemTypes ++ userTypes;

        pub fn init(context: *Context) !Self {
            return Self {
                .userContext = try contextInitFn(context),
            };
        }

        pub fn compileScheme(self: *Self, scheme: *const Scheme) ErrorType!void {
            return compileSchemeFn(&self.userContext, scheme);
        }

        pub fn deinit(self: *Self) void {
            contextDeinitFn(&self.userContext);
        }
    };
}

test {
    const TestErrorType = std.mem.Allocator.Error;
    const TestContextType = struct {
        const Self = @This();

        pub fn init(_: *const Context) TestErrorType!Self {
            return Self {};
        }

        pub fn deinit(_: *Self) void {
        }
    };

    _ = Target(TestContextType, TestErrorType, struct {
        pub const name: []const u8 = "TestTarget";
        pub const types: []const Type = &.{};

        pub fn compileScheme(_: *TestContextType, _: *const Scheme) TestErrorType!void {
        }
    });
}
