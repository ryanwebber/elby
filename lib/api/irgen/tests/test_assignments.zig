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

test "block expression" {

    const source =
        \\fn main() -> Int {
        \\  let x: Int = {
        \\    let a: Int = 1;
        \\    let b: Int = 2;
        \\    yield { yield a + b; };
        \\  };
        \\
        \\  return { yield x + 1; };
        \\}
        ;

    const result = try utils.evaluateIR(std.testing.allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 4), result);
}

test "negation" {
    const source =
        \\fn main() -> Int {
        \\  let x: Int = -5;
        \\  let y: Int = 1 + -x;
        \\
        \\  return -y;
        \\}
        ;

    const result = try utils.evaluateIR(std.testing.allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), -6), result);
}
