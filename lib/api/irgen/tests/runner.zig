const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const compiler = @import("../compiler.zig");
const Instruction = @import("../instruction.zig").Instruction;
const SlotAllocator = compiler.SlotAllocator;

pub fn expectIR(allocator: *std.mem.Allocator, expectedIR: []const u8, function: *const ast.Function) !void {
    var slotAllocator = SlotAllocator.init();
    var destList = std.ArrayList(Instruction).init(allocator);
    defer { destList.deinit(); }

    try compiler.compileFunction(function, &slotAllocator, &destList);

    var actualIR = std.ArrayList(u8).init(&std.testing.allocator);
    var stream = actualIR.writer();
    defer { actualIR.deinit(); }

    for (destList.items) |*instr| {
        try instr.format(&stream);
        try stream.print("\n", .{});
    }

    try std.testing.expectEqualStrings(expectedIR, actualIR.items);
}
