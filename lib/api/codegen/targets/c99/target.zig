const std = @import("std");
const target = @import("../../target.zig");

const Scheme = target.Scheme;
const Context = target.Context;
const Type = target.Type;
const Numeric = target.Numeric;
const FunctionPrototype = target.FunctionPrototype;
const FunctionDefinition = target.FunctionDefinition;
const FunctionLayout = target.FunctionLayout;
const FunctionRegistry = target.FunctionRegistry;
const PrototypeRegistry = target.PrototypeRegistry;
const Slot = target.Slot;
const fatal = target.fatal;

const cTypes: []const Type = &.{
    .{
        .name = "uint8_t",
        .value = .{
            .numeric = .{
                .type = .int,
                .size = 1
            }
        }
    },
};

const ErrorType = anyerror;
const UserContext = struct {
    context: *Context,
    const Self = @This();

    pub fn init(context: *Context) ErrorType!Self {
        return Self {
            .context = context
        };
    }

    pub fn deinit(_: *Self) void {
    }
};

pub const Target = target.Target(UserContext, ErrorType, struct {
    pub const name: []const u8 = "c99";
    pub const types: []const Type = cTypes;

    pub fn compileScheme(uc: *UserContext, scheme: *const Scheme) ErrorType!void {
        var stream = try uc.context.requestOutputStream("main.c");
        var writer = stream.writer();
        try writer.print("#include <stdint.h>\n\n", .{});

        for (scheme.functions.definitions) |definition| {
            try writeFunctionParameters(scheme, writer, definition);
            try writer.print("void ", .{});
            try writeMangledName(scheme, writer, &definition.prototype);
            try writer.print("();\n\n", .{});
        }


        try writer.print("\n", .{});

        for (scheme.functions.definitions) |definition| {
            try writer.print("// fn {s}\n", .{ definition.prototype.signature });
            try writer.print("void ", .{});
            try writeMangledName(scheme, writer, &definition.prototype);
            try writer.print("()\n{{\n", .{});
            try writeFunctionWorkspace(scheme, writer, &definition.layout);
            try writer.print("\n", .{});
            try writeFunctionBody(scheme, writer, definition);
            try writer.print("}}\n\n", .{});
        }
    }

    fn writeFunctionParameters(scheme: *const Scheme, writer: anytype, definition: *const FunctionDefinition) !void {
        for (definition.layout.params) |param, i| {
            try writer.print("{s} ", .{ param.type.name });
            try writeMangledName(scheme, writer, &definition.prototype);
            try writer.print("__param__{d};\n", .{ i });
        }
    }

    fn writeFunctionWorkspace(_: *const Scheme, writer: anytype, layout: *const FunctionLayout) !void {
        for (layout.locals) |*local| {
            try writer.print("\t{s} {s};\n", .{ local.type.name, local.name });
        }

        try writer.print("\n", .{});

        for (layout.workspace.mapping) |*tmp, i| {
            try writer.print("\t{s} __temp_{d};\n", .{ tmp.type.name, i });
        }
    }

    fn writeFunctionBody(scheme: *const Scheme, writer: anytype, function: *const FunctionDefinition) !void {
        for (function.body.instructions) |instruction| {
            switch (instruction) {
                .load => |load| {
                    const destType = try function.getSlotType(&load.dest, &scheme.functions.prototypeRegistry);
                    try writer.print("\t", .{});
                    try writeName(scheme, writer, &load.dest, function);
                    try writer.print(" = ({s})", .{ destType.name });
                    try writeNumeric(scheme, writer, &load.value);
                    try writer.print(";\n", .{});
                },
                .move => |move| {
                    try writer.print("\t", .{});
                    try writeName(scheme, writer, &move.dest.slot, function);
                    try writer.print(" = ", .{});
                    try writeName(scheme, writer, &move.src.slot, function);
                    try writer.print(";\n", .{});
                },
                .add => |add| {
                    try writeBinOp(scheme, writer, &add.dest, &add.lhs, &add.rhs, "+", function);
                },
                .sub => |sub| {
                    try writeBinOp(scheme, writer, &sub.dest, &sub.lhs, &sub.rhs, "+", function);
                },
                .mul => |mul| {
                    try writeBinOp(scheme, writer, &mul.dest, &mul.lhs, &mul.rhs, "+", function);
                },
                .div => |div| {
                    try writeBinOp(scheme, writer, &div.dest, &div.lhs, &div.rhs, "+", function);
                },
                .call => |call| {
                    const callPrototype = scheme.functions.prototypeRegistry.lookupTable.getPtr(call.functionId) orelse {
                        return fatal("Unknown function: {s}", .{ call.functionId });
                    };

                    try writer.print("\t", .{});
                    try writeMangledName(scheme, writer, callPrototype);
                    try writer.print("();\n", .{});
                }
            }
        }
    }

    fn writeBinOp(scheme: *const Scheme, writer: anytype, dest: *const Slot, lhs: *const Slot, rhs: *const Slot, op: []const u8, function: *const FunctionDefinition) !void {
        try writer.print("\t", .{});
        try writeName(scheme, writer, dest, function);
        try writer.print(" = ", .{});
        try writeName(scheme, writer, lhs, function);
        try writer.print(" {s} ", .{ op });
        try writeName(scheme, writer, rhs, function);
        try writer.print(";\n", .{});
    }

    fn writeMangledName(_: *const Scheme, writer: anytype, prototype: *const FunctionPrototype) !void {
        try writer.print("{s}", .{ prototype.name });
    }

    fn writeType(_: *const Scheme, writer: anytype, slot: *const Slot, definition: *const FunctionDefinition) !void {
        const slotType = definition.getSlotType(slot);
        try writer.print("{s}", .{ slotType.name });
    }

    fn writeName(scheme: *const Scheme, writer: anytype, slot: *const Slot, definition: *const FunctionDefinition) !void {
        const layout = definition.layout;
        const prototype = definition.prototype;
        switch (slot.*) {
            .local => |s| {
                const namedSlot = layout.locals[s.index];
                try writer.print("{s}", .{ namedSlot.name });
            },
            .param => |s| {
                try writeMangledName(scheme, writer, &definition.prototype);
                try writer.print("__param__{d}", .{ s.index });
            },
            .temp => |s| {
                // Can't use the mapping here because the types can't mismatch
                try writer.print("__temp_{d}", .{ s.index });
            },
            .retval => {
                try writer.print("__ret_", .{});
                try writeMangledName(scheme, writer, &prototype);
            },
            .call => |call| {
                const callPrototype = scheme.functions.prototypeRegistry.lookupTable.getPtr(call.functionId) orelse {
                    return fatal("Unknown function: {s}", .{ call.functionId });
                };

                switch (call.slot) {
                    .param => |param| {
                        try writeMangledName(scheme, writer, callPrototype);
                        try writer.print("__param__{d}", .{ param.index });
                    },
                    .retval => {
                        try writeMangledName(scheme, writer, callPrototype);
                        try writer.print("__retval", .{});
                    }
                }
            }
        }
    }

    fn writeNumeric(_: *const Scheme, writer: anytype, numeric: *const Numeric) !void {
        switch (numeric.*) {
            .float => |floatValue| {
                try writer.print("{d}", .{floatValue});
            },
            .int => |intValue| {
                try writer.print("{d}", .{intValue});
            }
        }
    }
});
