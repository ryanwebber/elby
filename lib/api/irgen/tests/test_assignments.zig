const std = @import("std");
const ast = @import("../../parsing/ast.zig");
const utils = @import("../../testing/utils.zig");

test "assignment ir generation" {

    const source =
        \\fn main() {
        \\  let x: i = 5 - 3 * 2 / (0x1 + 0);
        \\  let y: i = x * x;
        \\}
        ;

    const expectedIR =
        \\T0 := int(5)
        \\T1 := int(3)
        \\T2 := int(2)
        \\T3 := T1 * T2
        \\T4 := int(1)
        \\T5 := int(0)
        \\T6 := T4 + T5
        \\T7 := T3 / T6
        \\T8 := T0 - T7
        \\L0[0] := T8[0]
        \\T9 := L0 * L0
        \\L1[0] := T9[0]
        \\
        ;

    try utils.expectIR(std.testing.allocator, source, expectedIR);
}
