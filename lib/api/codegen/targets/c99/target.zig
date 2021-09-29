const std = @import("std");
const target = @import("../../target.zig");

const Scheme = target.Scheme;
const Context = target.Context;
const Type = target.Type;
const Numeric = target.Numeric;
const FunctionPrototype = target.FunctionPrototype;
const FunctionDefinition = target.FunctionDefinition;
const FunctionLayout = target.FunctionLayout;
const Slot = target.Slot;

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

const ErrorType = error {} || std.mem.Allocator.Error || std.io.StreamSource.WriteError;
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
            try writer.print("void ", .{});
            try writeMangledName(writer, &definition.prototype);
            try writer.print("();\n", .{});
        }

        try writer.print("\n", .{});

        for (scheme.functions.definitions) |definition| {
            try writer.print("// fn {s}\nvoid ", .{ definition.prototype.signature });
            try writeMangledName(writer, &definition.prototype);
            try writer.print("()\n{{\n", .{});
            try writeFunctionWorkspace(writer, &definition.layout);
            try writer.print("\n", .{});
            try writeFunctionBody(writer, definition);
            try writer.print("}}\n\n", .{});
        }
    }

    fn writeFunctionWorkspace(writer: anytype, layout: *const FunctionLayout) !void {
        for (layout.locals) |*local| {
            try writer.print("\t{s} {s};\n", .{ local.type.name, local.name });
        }

        try writer.print("\n", .{});

        for (layout.workspace.mapping) |*tmp, i| {
            try writer.print("\t{s} __temp_{d};\n", .{ tmp.type.name, i });
        }
    }

    fn writeFunctionBody(writer: anytype, function: *const FunctionDefinition) !void {
        for (function.body.instructions) |instruction| {
            switch (instruction) {
                .load => |load| {
                    const destType = function.getSlotType(&load.dest);
                    try writer.print("\t", .{});
                    try writeName(writer, &load.dest, function);
                    try writer.print(" = ({s})", .{ destType.name });
                    try writeNumeric(writer, &load.value);
                    try writer.print(";\n", .{});
                },
                .move => |move| {
                    try writer.print("\t", .{});
                    try writeName(writer, &move.dest.slot, function);
                    try writer.print(" = ", .{});
                    try writeName(writer, &move.src.slot, function);
                    try writer.print(";\n", .{});
                },
                .add => |add| {
                    try writeBinOp(writer, &add.dest, &add.lhs, &add.rhs, "+", function);
                },
                .sub => |sub| {
                    try writeBinOp(writer, &sub.dest, &sub.lhs, &sub.rhs, "+", function);
                },
                .mul => |mul| {
                    try writeBinOp(writer, &mul.dest, &mul.lhs, &mul.rhs, "+", function);
                },
                .div => |div| {
                    try writeBinOp(writer, &div.dest, &div.lhs, &div.rhs, "+", function);
                },
            }
        }
    }

    fn writeBinOp(writer: anytype, dest: *const Slot, lhs: *const Slot, rhs: *const Slot, op: []const u8, function: *const FunctionDefinition) !void {
        try writer.print("\t", .{});
        try writeName(writer, dest, function);
        try writer.print(" = ", .{});
        try writeName(writer, lhs, function);
        try writer.print(" {s} ", .{ op });
        try writeName(writer, rhs, function);
        try writer.print(";\n", .{});
    }

    fn writeMangledName(writer: anytype, prototype: *const FunctionPrototype) !void {
        try writer.print("{s}", .{ prototype.name });
    }

    fn writeType(writer: anytype, slot: *const Slot, definition: *const FunctionDefinition) !void {
        const slotType = definition.getSlotType(slot);
        try writer.print("{s}", .{ slotType.name });
    }

    fn writeName(writer: anytype, slot: *const Slot, definition: *const FunctionDefinition) !void {
        const layout = definition.layout;
        const prototype = definition.prototype;
        switch (slot.*) {
            .local => |s| {
                const namedSlot = layout.locals[s.index];
                try writer.print("{s}", .{ namedSlot.name });
            },
            .param => |s| {
                const namedSlot = layout.params[s.index];
                try writer.print("{s}", .{ namedSlot.name });
            },
            .temp => |s| {
                try writer.print("__temp_{d}", .{ s.index });
            },
            .retval => {
                try writer.print("__ret_", .{});
                try writeMangledName(writer, &prototype);
            }
        }
    }

    fn writeNumeric(writer: anytype, numeric: *const Numeric) !void {
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
