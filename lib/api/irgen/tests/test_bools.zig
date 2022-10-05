const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "bool ir generation" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  let x: Int = 5;
        \\  let y: Int = 5;
        \\  if (x == y) {
        \\    return 1;
        \\  } else if (x == 2) {
        \\    return 2;
        \\  } else {
        \\    return 3;
        \\  }
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 1), result);
}

test "bool ir generation else if" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  let x: Int = 2;
        \\  let y: Int = 5;
        \\  if (x == y) {
        \\    return 1;
        \\  } else if (x == 2) {
        \\    return 2;
        \\  } else {
        \\    return 3;
        \\  }
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 2), result);
}

test "bool ir generation else" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  let x: Int = 20;
        \\  let y: Int = 5;
        \\  if (x == y) {
        \\    return 1;
        \\  } else if (x == 2) {
        \\    return 2;
        \\  } else {
        \\    return 3;
        \\  }
        \\  let z: Int = 0;
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 3), result);
}


test "bool inequality" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  let x: Int = 1;
        \\  if (x != 2) {
        \\    return 3;
        \\  } else {
        \\    return 4;
        \\  }
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 3), result);
}

test "bool types" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  let x: Bool = true;
        \\  if (x) {
        \\    return 3;
        \\  } else {
        \\    return 4;
        \\  }
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 3), result);
}

test "relation expression" {
    var allocator = std.testing.allocator;
    const source =
        \\fn main() -> Int {
        \\  let x: Int = 8;
        \\  let y: Int = 10;
        \\  if (x + 5 < y) {
        \\    return 1;
        \\  } else if (y >= 10) {
        \\    return 2;
        \\  } else {
        \\    return 3;
        \\  }
        \\}
        ;

    const result = try utils.evaluateIR(&allocator, source);
    try std.testing.expectEqual(@intCast(@TypeOf(result), 2), result);
}
