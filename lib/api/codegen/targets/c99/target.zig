const std = @import("std");
const target = @import("../../target.zig");

const Scheme = target.Scheme;
const Context = target.Context;
const Type = target.Type;
const StdTypes = target.StdTypes;
const Numeric = target.Numeric;
const FunctionPrototype = target.FunctionPrototype;
const FunctionDefinition = target.FunctionDefinition;
const FunctionLayout = target.FunctionLayout;
const FunctionRegistry = target.FunctionRegistry;
const PrototypeRegistry = target.PrototypeRegistry;
const Slot = target.Slot;
const fatal = target.fatal;

const C_Types = .{
    .uint8_t = .{
        .name = "uint8_t",
        .value = .{
            .numeric = .{
                .type = .int,
                .size = 1
            }
        }
    },
};

pub const Target = target.Target(Generator, &.{
    .name = "c99",
    .types = &.{
        C_Types.uint8_t,
    },
    .externs = &.{
        .{
            .name = "exit",
            .returnType = &StdTypes.void,
            .parameters = &.{
                .{
                    .name = "status",
                    .type = &C_Types.uint8_t,
                }
            },
        }
    }
});

pub const Generator = struct {
    context: *Context,

    const Self = @This();
    pub const Options = struct {
        outputStream: std.io.StreamSource,
    };

    pub fn init(context: *Context) Self {
        return .{
            .context = context,
        };
    }

    pub fn deinit(_: *Self) void {
        // Noop
    }

    pub fn compileScheme(self: *Self, scheme: *const Scheme, options: *Options) !void {
        try self.compileSchemeWithWriter(scheme, options.outputStream.writer());
    }

    pub fn compileSchemeWithWriter(self: *Self, scheme: *const Scheme, writer: anytype) !void {
        var buffer = std.ArrayList(u8).init(self.context.allocator.*);
        defer { buffer.deinit(); }

        try writeScheme(buffer.writer(), scheme);

        const template = @embedFile("template.c.in");
        try writer.print(template, .{ .body = buffer.items });
    }

    pub fn writeScheme(writer: anytype, scheme: *const Scheme) !void {
        for (scheme.functions.definitions) |definition| {
            try writeFunctionHeader(scheme, writer, definition);
            try writer.print("void ", .{});
            try writeMangledName(scheme, writer, &definition.prototype);
            try writer.print("();\n\n", .{});
        }

        try writer.print("\n", .{});

        for (scheme.functions.definitions) |definition| {
            try writer.print("// fn {s}\n", .{ definition.prototype.signature });
            try writer.print("void ", .{});
            try writeMangledName(scheme, writer, &definition.prototype);
            try writer.print("(void)\n{{\n", .{});
            try writeFunctionWorkspace(scheme, writer, &definition.layout);
            try writer.print("\n", .{});
            try writeFunctionBody(scheme, writer, definition);
            try writer.print("}}\n\n", .{});
        }
    }

    fn writeFunctionHeader(scheme: *const Scheme, writer: anytype, definition: *const FunctionDefinition) !void {
        for (definition.layout.params) |param, i| {
            try writeType(writer, param.type);
            try writer.print(" ", .{});
            try writeMangledName(scheme, writer, &definition.prototype);
            try writer.print("__param__{d};\n", .{ i });
        }

        if (definition.prototype.returnType.size() > 0) {
            try writeType(writer, definition.prototype.returnType);
            try writer.print(" ", .{});
            try writeMangledName(scheme, writer, &definition.prototype);
            try writer.print("__retval;\n", .{});
        }
    }

    fn writeFunctionWorkspace(_: *const Scheme, writer: anytype, layout: *const FunctionLayout) !void {
        for (layout.locals) |*local| {
            try writer.print("\t", .{});
            try writeType(writer, local.type);
            try writer.print(" {s};\n", .{ local.name });
        }

        try writer.print("\n", .{});

        for (layout.workspace.mapping) |*tmp, i| {
            try writer.print("\t", .{});
            try writeType(writer, tmp.type);
            try writer.print(" __temp_{d};\n", .{ i });
        }
    }

    fn writeFunctionBody(scheme: *const Scheme, writer: anytype, function: *const FunctionDefinition) !void {
        for (function.body.instructions) |instruction, i| {
            if (function.body.labelLookup.get(i)) |labels| {
                for (labels.items) |label| {
                    try writer.print("{s}:\n", .{ label });
                }
            }

            switch (instruction) {
                .load => |load| {
                    const destType = try function.getSlotType(&load.dest, &scheme.functions.prototypeRegistry);
                    try writer.print("\t", .{});
                    try writeName(scheme, writer, &load.dest, function);
                    try writer.print(" = (", .{});
                    try writeType(writer, destType);
                    try writer.print(")", .{});
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
                    try writeBinOp(scheme, writer, &sub.dest, &sub.lhs, &sub.rhs, "-", function);
                },
                .mul => |mul| {
                    try writeBinOp(scheme, writer, &mul.dest, &mul.lhs, &mul.rhs, "*", function);
                },
                .div => |div| {
                    try writeBinOp(scheme, writer, &div.dest, &div.lhs, &div.rhs, "/", function);
                },
                .cmp_eq => |op| {
                    try writeBinOp(scheme, writer, &op.dest, &op.lhs, &op.rhs, "==", function);
                },
                .cmp_neq => |op| {
                    try writeBinOp(scheme, writer, &op.dest, &op.lhs, &op.rhs, "!=", function);
                },
                .cmp_lt => |op| {
                    try writeBinOp(scheme, writer, &op.dest, &op.lhs, &op.rhs, "<", function);
                },
                .cmp_lt_eq => |op| {
                    try writeBinOp(scheme, writer, &op.dest, &op.lhs, &op.rhs, "<=", function);
                },
                .cmp_gt => |op| {
                    try writeBinOp(scheme, writer, &op.dest, &op.lhs, &op.rhs, ">", function);
                },
                .cmp_gt_eq => |op| {
                    try writeBinOp(scheme, writer, &op.dest, &op.lhs, &op.rhs, ">=", function);
                },
                .call => |call| {
                    const callPrototype = scheme.functions.prototypeRegistry.lookupPrototype(call.functionId) orelse {
                        return fatal("Unknown function in call: {s}", .{ call.functionId });
                    };

                    try writer.print("\t", .{});
                    try writeMangledName(scheme, writer, callPrototype);
                    try writer.print("();\n", .{});
                },
                .goto => |op| {
                    try writer.print("\tgoto {s};\n", .{ op.label });
                },
                .goto_unless => |op| {
                    try writer.print("\tif(!", .{});
                    try writeName(scheme, writer, &op.slot, function);
                    try writer.print(")\n", .{});
                    try writer.print("\t\tgoto {s};\n", .{ op.label });
                },
                .ret => {
                    try writer.print("\treturn;\n", .{});
                }
            }
        }

        // Need a statement after a label, this is harmless even if there
        // is no label
        try writer.print("\t;", .{});
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
        try writer.print("__{s}", .{ prototype.name });
    }

    fn writeType(writer: anytype, typeDef: *const Type) !void {
        try writer.print("{s}", .{ typeDef.name });
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
                try writeMangledName(scheme, writer, &prototype);
                try writer.print("__retval", .{});
            },
            .call => |call| {
                const callPrototype = scheme.functions.prototypeRegistry.lookupPrototype(call.functionId) orelse {
                    return fatal("Unknown function name for slot: {s}", .{ call.functionId });
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
};
