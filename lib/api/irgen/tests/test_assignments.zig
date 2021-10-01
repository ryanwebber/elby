const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "assignment ir generation" {

    const source =
        \\fn main() -> int {
        \\  let x: int = 5 - 3 * 8 / (0x1 + 0b01);
        \\  let y: int = x * x;
        \\  return y * 2;
        \\}
        ;

    const result = try utils.evaluateIR(std.testing.allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 98), result);
}
