const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "definition ir generation" {

    const source =
        \\fn main() -> Int {
        \\  let x: Int = 5 - 3 * 8 / (0x1 + 0b01);
        \\  let y: Int = x * x;
        \\  return y * 2;
        \\}
        ;

    const result = try utils.evaluateIR(std.testing.allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 98), result);
}

test "mutable var ir generation" {

    const source =
        \\fn main() -> Int {
        \\  mut x: Int = 1;
        \\  x = 2;
        \\  x = 3;
        \\  return x;
        \\}
        ;

    const result = try utils.evaluateIR(std.testing.allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 3), result);
}
