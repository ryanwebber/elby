const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "function return ir generation" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  return add(a: 1, b: 2);
        \\}
        \\
        \\fn add(a: Int, b: Int) -> Int {
        \\  return a + b;
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 3), result);
}

test "function void return" {
    var allocator = std.testing.allocator;
    const source =
        \\fn test(a: Int, b: Int) {
        \\}
        ;

    const expectedIR =
        \\return
        \\
        ;

    try utils.expectIR(&allocator, source, "test(a:b:)", expectedIR);
}

test "function param smashing" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  return foo(a: 1, b: foo(a: 2, b: 3));
        \\}
        \\
        \\fn foo(a: Int, b: Int) -> Int {
        \\  return a + b;
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 6), result);
}
