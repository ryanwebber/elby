const std = @import("std");
const func = @import("../function.zig");
const types = @import("../../types.zig");
const Scheme = @import("../scheme.zig").Scheme;
const FunctionRegistry = @import("../scheme.zig").FunctionRegistry;
const Slot = @import("../slot.zig").Slot;
const FunctionDefinition = func.FunctionDefinition;
const Numeric = types.Numeric;

pub const IntType = i32;

pub const InterpreterError = error {
    FunctionNotFound, LabelNotFound,
};

pub const SimpleInterpreter = struct {
    allocator: *std.mem.Allocator,
    scheme: *const Scheme,
    data: *std.StringHashMap(FunctionData),

    const Self = @This();

    pub const supportedTypes: []const types.Type = &.{
        .{
            .name = "Int",
            .value = .{
                .numeric = .{
                    .type = .int,
                    .size = 1
                }
            }
        },
        types.Types.boolean,
        types.Types.void,
    };

    pub fn init(allocator: *std.mem.Allocator, scheme: *const Scheme,) !Self {
        var data = try allocator.create(std.StringHashMap(FunctionData));
        data.* = std.StringHashMap(FunctionData).init(allocator);

        errdefer {
            var itr = data.valueIterator();
            while (itr.next()) |d| {
                d.deinit();
            }

            data.deinit();
        }

        for (scheme.functions.definitions) |defn| {
            var fnData = try FunctionData.init(allocator, data, defn);
            try data.put(defn.prototype.identifier, fnData);
        }

        return Self {
            .allocator = allocator,
            .scheme = scheme,
            .data = data,
        };
    }

    pub fn deinit(self: *Self) void {
        var itr = self.data.valueIterator();
        while (itr.next()) |d| {
            d.deinit();
        }

        self.data.deinit();
        self.allocator.destroy(self.data);
    }

    pub fn evaluate(self: *Self) !IntType {
        const main = "main()";
        if (self.scheme.functions.mapping.get(main)) |defn| {
            try self.evaluateFunction(defn);
            const entryData = self.data.getPtr(main) orelse { unreachable; };
            return entryData.returnValue;
        } else {
            return InterpreterError.FunctionNotFound;
        }
    }

    fn evaluateFunction(self: *Self, definition: *const FunctionDefinition) anyerror!void {
        var pc: usize = 0;
        var fnData = self.data.getPtr(definition.prototype.identifier) orelse {
            return InterpreterError.FunctionNotFound;
        };

        while (true) {

            if (pc >= definition.body.instructions.len) {
                return;
            }

            switch (definition.body.instructions[pc]) {
                .load => |load| {
                    (try fnData.getPtr(&load.dest)).* = getIntValue(&load.value);
                },
                .move => |move| {
                    (try fnData.getPtr(&move.dest.slot)).* = (try fnData.getPtr(&move.src.slot)).*;
                },
                .add => |add| {
                    (try fnData.getPtr(&add.dest)).* = (try fnData.getPtr(&add.lhs)).* + (try fnData.getPtr(&add.rhs)).*;
                },
                .sub => |add| {
                    (try fnData.getPtr(&add.dest)).* = (try fnData.getPtr(&add.lhs)).* - (try fnData.getPtr(&add.rhs)).*;
                },
                .mul => |add| {
                    (try fnData.getPtr(&add.dest)).* = (try fnData.getPtr(&add.lhs)).* * (try fnData.getPtr(&add.rhs)).*;
                },
                .div => |add| {
                    (try fnData.getPtr(&add.dest)).* = @divFloor((try fnData.getPtr(&add.lhs)).*, (try fnData.getPtr(&add.rhs)).*);
                },
                .cmp_eq => |op| {
                    (try fnData.getPtr(&op.dest)).* = @boolToInt((try fnData.getPtr(&op.lhs)).* == (try fnData.getPtr(&op.rhs)).*);
                },
                .cmp_neq => |op| {
                    (try fnData.getPtr(&op.dest)).* = @boolToInt((try fnData.getPtr(&op.lhs)).* != (try fnData.getPtr(&op.rhs)).*);
                },
                .cmp_lt => |op| {
                    (try fnData.getPtr(&op.dest)).* = @boolToInt((try fnData.getPtr(&op.lhs)).* < (try fnData.getPtr(&op.rhs)).*);
                },
                .cmp_gt => |op| {
                    (try fnData.getPtr(&op.dest)).* = @boolToInt((try fnData.getPtr(&op.lhs)).* > (try fnData.getPtr(&op.rhs)).*);
                },
                .cmp_lt_eq => |op| {
                    (try fnData.getPtr(&op.dest)).* = @boolToInt((try fnData.getPtr(&op.lhs)).* <= (try fnData.getPtr(&op.rhs)).*);
                },
                .cmp_gt_eq => |op| {
                    (try fnData.getPtr(&op.dest)).* = @boolToInt((try fnData.getPtr(&op.lhs)).* >= (try fnData.getPtr(&op.rhs)).*);
                },
                .call => |call| {
                    const callFunction = self.scheme.functions.mapping.get(call.functionId) orelse {
                        return InterpreterError.FunctionNotFound;
                    };

                    try self.evaluateFunction(callFunction);
                },
                .goto => |op| {
                    const offset = definition.body.labels.get(op.label) orelse {
                        return InterpreterError.LabelNotFound;
                    };

                    pc = offset - 1;
                },
                .goto_unless => |op| {
                    const slotValue = (try fnData.getPtr(&op.slot)).*;
                    if (slotValue == 0) {
                        const offset = definition.body.labels.get(op.label) orelse {
                            return InterpreterError.LabelNotFound;
                        };

                        pc = offset - 1;
                    }
                },
                .ret => {
                    return;
                }
            }

            pc += 1;
        }
    }
};

const FunctionData = struct {
    allocator: *std.mem.Allocator,
    globalData: *const std.StringHashMap(FunctionData),

    returnValue: IntType,
    parameterValues: []IntType,
    localValues: []IntType,
    stackValues: []IntType,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, globalData: *const std.StringHashMap(FunctionData), definition: *const FunctionDefinition) !Self {
        var parameterValues = try allocator.alloc(IntType, definition.layout.params.len);
        errdefer { allocator.free(parameterValues); }

        var localValues = try allocator.alloc(IntType, definition.layout.locals.len);
        errdefer { allocator.free(localValues); }

        var stackValues = try allocator.alloc(IntType, definition.layout.workspace.mapping.len);
        errdefer { allocator.free(stackValues); }

        return Self {
            .allocator = allocator,
            .globalData = globalData,
            .returnValue = 0,
            .parameterValues = parameterValues,
            .localValues = localValues,
            .stackValues = stackValues,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.parameterValues);
        self.allocator.free(self.localValues);
        self.allocator.free(self.stackValues);
    }

    pub fn getPtr(self: *Self, slot: *const Slot) !*IntType {
        switch (slot.*) {
            .local => |s| {
                return &self.localValues[s.index];
            },
            .param => |s| {
                return &self.parameterValues[s.index];
            },
            .temp => |s| {
                return &self.stackValues[s.index];
            },
            .retval => {
                return &self.returnValue;
            },
            .call => |call| {
                var callFunctionData = self.globalData.get(call.functionId) orelse {
                    return InterpreterError.FunctionNotFound;
                };

                switch (call.slot) {
                    .param => |s| {
                        return &callFunctionData.parameterValues[s.index];
                    },
                    .retval => {
                        return &callFunctionData.returnValue;
                    }
                }
            }
        }
    }
};

fn getIntValue(numeric: *const Numeric) IntType {
    return switch (numeric.*) {
        .int => |value| @intCast(IntType, value),
        .float => |value| @floatToInt(IntType, value),
    };
}
