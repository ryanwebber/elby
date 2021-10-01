const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "function return ir generation" {

    const source =
        \\fn main() -> int {
        \\  return add(a: 1, b: 2);
        \\}
        \\
        \\fn add(a: int, b: int) -> int {
        \\  return a + b;
        \\}
        ;

    const result = try utils.evaluateIR(std.testing.allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 3), result);
}

test "function void return" {

    const source =
        \\fn test(a: int, b: int) {
        \\  return;
        \\}
        ;

    const expectedIR =
        \\return
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, "test(a:b:)", expectedIR);
}

test "function param smashing" {

    const source =
        \\fn main() -> int {
        \\  return foo(a: 1, b: foo(a: 2, b: 3));
        \\}
        \\
        \\fn foo(a: int, b: int) -> int {
        \\  return a + b;
        \\}
        ;

    const result = try utils.evaluateIR(std.testing.allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 6), result);
}
