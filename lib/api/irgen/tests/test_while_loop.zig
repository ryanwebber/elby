const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "false while loop" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  let i: Int = 0;
        \\  while (i != 0) {
        \\  }
        \\  return 6;
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 6), result);
}
